#!/usr/bin/env Rscript

## TheGLM script that first predict a per-read probability for each read alignment and then compute an aggregated score for each junction 
require(data.table)
library(glmnet)
library(glmtlp)
library(tictoc)
#library(ggplot2)
#library(plotROC)


compute_class_error <- function(train_class,glm_predicted_prob){
  totalerr = sum(abs(train_class - round(glm_predicted_prob)))
  print (paste("total reads:", length(train_class)))
  print(paste("both negative",sum(abs(train_class+round(glm_predicted_prob))==0), "out of ", length(which(train_class==0))))
  print(paste("both positive",sum(abs(train_class+round(glm_predicted_prob))==2), "out of ", length(which(train_class==1))))
  print(paste("classification errors for glm", totalerr, "out of", length(train_class), totalerr/length(train_class) ))
}

###### Input arguments ##############
args = commandArgs(trailingOnly = TRUE)
directory = args[1]
is.SE = as.numeric(args[2])
#####################################

### arguments for debugging ######
#is.SE = 0
#directory ="/scratch/PI/horence/Roozbeh/single_cell_project/output/Engstrom_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/Engstrom_sim1_trimmed/test.txt"
#class_input =  fread("/scratch/PI/horence/Roozbeh/single_cell_project/output/Engstrom_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/Engstrom_sim1_trimmed/test.txt",sep = "\t",header = TRUE)
##################################

###### read in class input file #####################
class_input_file = list.files(directory,pattern = "class_input_WithinBAM.tsv")
class_input =  fread(paste(directory,class_input_file,sep = ""),sep = "\t",header = TRUE)
###############################################


###### find the best alignment rank across all aligned reads for each junction ######   
#star_sj_output[,junction:=paste(V1,V2,V1,V3,sep=":"),by=1:nrow(star_sj_output)]
#class_input = merge(class_input,star_sj_output[,list(junction,V7,V8)],by.x = "junction_compatible",by.y="junction",all.x=TRUE,all.y=FALSE)
#class_input[,minHIR1A:=min(HIR1A),by=junction_compatible]
###################################################################################

class_input[,numReads:=length(unique(id)),by = refName_newR1]



### obtain fragment lengths for chimeric reads for computing length adjusted AS ##########
class_input[fileTypeR1 == "Aligned",length_adj_AS_R1:= aScoreR1A/readLenR1]
class_input[fileTypeR1 == "Chimeric",length_adj_AS_R1 := (aScoreR1A + aScoreR1B)/ (MR1A + MR1B + SR1A + SR1B)]
class_input[,length_adj_AS_R1A:= aScoreR1A / (MR1A + SR1A),by=1:nrow(class_input)]
class_input[,length_adj_AS_R1B:= aScoreR1B / (MR1B + SR1B),by=1:nrow(class_input)]
###########################################################################################

### obtain the number of smismatches per alignment ##########
class_input[fileTypeR1 == "Aligned",nmmR1:= nmmR1A]
class_input[fileTypeR1 == "Chimeric",nmmR1:= nmmR1A + nmmR1B]
###########################################################################################

#### obtain mapping quality values for chimeric reads ###################
class_input[fileTypeR1 == "Aligned",qual_R1 := qualR1A]
class_input[fileTypeR1 == "Chimeric",qual_R1 := (qualR1A + qualR1B) / 2]
#########################################################################

#### obtain junction overlap #########
class_input[,overlap_R1 := min(MR1A,MR1B),by=1:nrow(class_input)]
class_input[,max_overlap_R1 := max(MR1A,MR1B),by=1:nrow(class_input)]
class_input[,median_overlap_R1 := as.integer(round(median(overlap_R1))),by = refName_newR1]
######################################

### categorical variable for zero mismatches ###########
class_input[,is.zero_nmm:= 0]
class_input[nmmR1==0,is.zero_nmm:= 1]
#######################################################

###### categorical variable for multimapping ###########
class_input[,is.multimapping := 0]
class_input[NHR1A>2,is.multimapping := 1]
#####################################################

###### compute noisy junction score ########
round.bin = 50
class_input[,binR1A:=round(juncPosR1A/round.bin)*round.bin]
class_input[,binR1B:=round(juncPosR1B/round.bin)*round.bin]
class_input[,njunc_binR1A:=length(unique(refName_readStrandR1)),by=paste(binR1A,chrR1A)]
class_input[,njunc_binR1B:=length(unique(refName_readStrandR1)),by=paste(binR1B,chrR1B)]
class_input[,binR1A:=NULL]
class_input[,binR1B:=NULL]
############################################

#### get the number of distinct partners for each splice site ###########
class_input[,junc_pos1_R1:=paste(chrR1A,juncPosR1A,sep=":"),by = 1:nrow(class_input)]
class_input[,junc_pos2_R1:=paste(chrR1B,juncPosR1B,sep=":"),by = 1:nrow(class_input)]
class_input[,threeprime_partner_number_R1:=length(unique(junc_pos2_R1)),by = junc_pos1_R1]
class_input[,fiveprime_partner_number_R1:=length(unique(junc_pos1_R1)),by = junc_pos2_R1]
class_input[,junc_pos1_R1:=NULL]
class_input[,junc_pos2_R1:=NULL]
###########################################################################


## the same predictors for R2
### obtain fragment lengths for chimeric reads for computing length adjusted AS ##########
class_input[fileTypeR2 == "Aligned",length_adj_AS_R2:= aScoreR2A/readLenR2]
class_input[fileTypeR2 == "Chimeric",length_adj_AS_R2 := (aScoreR2A + aScoreR2B)/ (MR2A + MR2B + SR2A + SR2B)]
###########################################################################################

### obtain the number of mismatches per alignment ##########
class_input[fileTypeR2 == "Aligned",nmmR2:= nmmR2A]
class_input[fileTypeR2 == "Chimeric",nmmR2:=nmmR2A + nmmR2B]
##########################################################################

#### obtain mapping quality values for chimeric reads ###################
class_input[fileTypeR2 == "Aligned",qual_R2 := qualR2A]
class_input[fileTypeR2 == "Chimeric",qual_R2 := (qualR2A + qualR2B) / 2]
#########################################################################

#### obtain junction overlap #########
class_input[,overlap_R2 := min(MR2A,MR2B),by=1:nrow(class_input)]
class_input[,max_overlap_R2 := max(MR2A,MR2B),by=1:nrow(class_input)]
######################################


class_input[,cur_weight:=NULL]
class_input[,train_class:=NULL]
####### Assign pos and neg training data for GLM training #######  
n.neg = nrow(class_input[genomicAlignmentR1==1 & fileTypeR1=="Aligned"])
n.pos = nrow(class_input[genomicAlignmentR1==0 & fileTypeR1=="Aligned"])
n.neg = min(n.neg,150000)
n.pos = min(n.pos,150000)  # number of positive reads that we want to subsample from the list of all reads
all_neg_reads = which((class_input$genomicAlignmentR1==1) & (class_input$fileTypeR1=="Aligned"))
all_pos_reads = which((class_input$genomicAlignmentR1==0) & (class_input$fileTypeR1=="Aligned"))
class_input[sample(all_neg_reads,n.neg,replace=FALSE),train_class := 0]
class_input[sample(all_pos_reads,n.pos,replace=FALSE),train_class := 1]
#################################################################

#set the training reads and class-wise weights for the reads within the same class
class.weight = min(n.pos, n.neg)

if (n.pos >= n.neg){
  class_input[train_class == 0,cur_weight := 1]
  class_input[train_class == 1,cur_weight := n.neg / n.pos]
} else {
  class_input[train_class == 0,cur_weight := n.pos/n.neg]
  class_input[train_class == 1,cur_weight := 1]
}
####################################

# Add -1 to the formula to remove the intercept
# x$fitted.values gives the fitted value for the response variable 
# x$linear.predictors gives the fitted linear value for the response variable

# predict(x,newdata = ,..... ) performs the prediction based on the 
# if we use type = "link", it gives the fitted value in the scale of linear predictors, if we use type = "response", it gives the response in the scale of the response variable

if (is.SE == 0){
  regression_formula = as.formula("train_class ~ overlap_R1 * max_overlap_R1 + NHR1A + nmmR1 + MR1A:SR1A + MR1B:SR1B + length_adj_AS_R1 + nmmR2 + length_adj_AS_R2 + NHR2A + entropyR1*entropyR2 + location_compatible + read_strand_compatible")
} else {
  regression_formula = as.formula("train_class ~ overlap_R1 * max_overlap_R1 + NHR1A + nmmR1 + MR1A:SR1A +  MR1B:SR1B + entropyR1 + length_adj_AS_R1")
}


###########################
##### GLM model  ##########
###########################
print("first glm model")
tic("glm")
glm_model = glm( update(regression_formula, ~ . -1), data = class_input[!is.na(train_class)], family = binomial(link="logit"), weights = class_input[!is.na(train_class),cur_weight])
toc()
print(summary(glm_model))

#predict for all per-read alignment in class input
class_input$glm_per_read_prob = predict(glm_model,newdata = class_input, type = "response",se.fit = TRUE)$fit 

# compute aggregated score for each junction
class_input[,p_predicted_glm:= 1/( exp(sum(log( (1 - glm_per_read_prob)/glm_per_read_prob ))) + 1) ,by = refName_newR1]

#compute classification error for the trained model
compute_class_error(class_input[!is.na(train_class)]$train_class,class_input[!is.na(train_class)]$glm_per_read_prob)

# compute aggregated score for each junction
class_input[,p_predicted_glm:= 1/( exp(sum(log( (1 - glm_per_read_prob)/glm_per_read_prob ))) + 1) ,by = refName_newR1]
print("done with glm")

#for PE data we have the option of correcting per-read scores for anomalous reads
if (is.SE==0){
  class_input[,glm_per_read_prob_corrected := glm_per_read_prob]
  class_input[(location_compatible==0 | read_strand_compatible==0),glm_per_read_prob_corrected:=glm_per_read_prob/(1 + glm_per_read_prob)]
  class_input[,p_predicted_glm_corrected := 1/( exp(sum(log( (1 - glm_per_read_prob_corrected)/glm_per_read_prob_corrected ))) + 1) ,by = refName_newR1]
}
######################################
######################################
######################################


######################################
######### GLMnet model  ##############
######################################
tic("glmnet")
print("now glmnet model")
x_glmnet = model.matrix(regression_formula, class_input[!is.na(train_class)])
glmnet_model = cv.glmnet(x_glmnet, as.factor(class_input[!is.na(train_class)]$train_class), family=c("binomial"), class_input[!is.na(train_class)]$cur_weight, intercept = FALSE, alpha = 1, nlambda = 50,nfolds = 5)
toc()
print("done with fitting glmnet")

print(coef(glmnet_model, s = "lambda.1se"))
print(glmnet_model)

# predict for all read alignments in the class input file
class_input_glmnet = model.matrix(update(regression_formula, refName_newR1 ~ .) , class_input)
class_input$glmnet_per_read_prob = predict(glmnet_model,newx = class_input_glmnet, type = "response",s = "lambda.1se", se.fit = TRUE)

# compute the fitted classification error based on training data
compute_class_error(class_input[!is.na(train_class)]$train_class,class_input[!is.na(train_class)]$glmnet_per_read_prob)

# compute aggregated score for each junction
class_input[,p_predicted_glmnet:= 1/( exp(sum(log( (1 - glmnet_per_read_prob)/glmnet_per_read_prob ))) + 1) ,by = refName_newR1]


if (is.SE==0){
  class_input[,glmnet_per_read_prob_corrected := glmnet_per_read_prob]
  class_input[(location_compatible==0 | read_strand_compatible==0),glmnet_per_read_prob_corrected:=glmnet_per_read_prob/(1 + glmnet_per_read_prob)]
  class_input[,p_predicted_glmnet_corrected := 1/( exp(sum(log( (1 - glmnet_per_read_prob_corrected)/glmnet_per_read_prob_corrected ))) + 1) ,by = refName_newR1]
}

######################################################
######################################################
#### now we do the two-step GLM for chimeric reads ###
######################################################
######################################################
class_input[,train_class :=NULL]
class_input[,cur_weight :=NULL]
p_predicted_quantile = quantile(class_input[!(duplicated(refName_newR1)) & (fileTypeR1 == "Chimeric")]$p_predicted_glmnet,probs = c(0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9)) # the percentiles for the scores based on linear GLM
p_predicted_neg_cutoff = p_predicted_quantile[[2]]
p_predicted_pos_cutoff = p_predicted_quantile[[8]]

####### Assign pos and neg training data for GLM training #######  
n.neg = nrow(class_input[fileTypeR1=="Chimeric"][p_predicted_glmnet <= p_predicted_neg_cutoff])
n.pos = nrow(class_input[fileTypeR1=="Chimeric"][p_predicted_glmnet >= p_predicted_pos_cutoff])
n.neg = min(n.neg,150000)
n.pos = min(n.pos,150000)  # number of positive reads that we want to subsample from the list of all reads
all_neg_reads = which((class_input$fileTypeR1=="Chimeric") & (class_input$p_predicted_glmnet <= p_predicted_neg_cutoff))
all_pos_reads = which((class_input$fileTypeR1=="Chimeric") & (class_input$p_predicted_glmnet >= p_predicted_pos_cutoff))
class_input[sample(all_neg_reads,n.neg,replace=FALSE),train_class := 0]
class_input[sample(all_pos_reads,n.pos,replace=FALSE),train_class := 1]
#################################################################

class.weight = min(n.pos, n.neg)
if (n.pos >= n.neg){
  class_input[train_class == 0,cur_weight := 1]
  class_input[train_class == 1,cur_weight := n.neg / n.pos]
} else {
  class_input[train_class == 0,cur_weight := n.pos/n.neg]
  class_input[train_class == 1,cur_weight := 1]
}

regression_formula = as.formula("train_class ~ overlap_R1 * max_overlap_R1  + nmmR1 + length_adj_AS_R1A + length_adj_AS_R1B + nmmR2 + entropyR1*entropyR2 + length_adj_AS_R2")

################################################################
######## Building the GLMnet for chimeric junctions ############
################################################################
tic("glmnet")
print("now glmnet model")
x_glmnet = model.matrix(regression_formula, class_input[!is.na(train_class)])
glmnet_model = cv.glmnet(x_glmnet, as.factor(class_input[!is.na(train_class)]$train_class), family=c("binomial"), class_input[!is.na(train_class)]$cur_weight, intercept = FALSE, alpha = 1, nlambda = 50,nfolds = 5)
toc()
print("done with fitting glmnet")

print(coef(glmnet_model, s = "lambda.1se"))
print(glmnet_model)

# predict for all read alignments in the class input file
class_input_glmnet = model.matrix(update(regression_formula, refName_newR1 ~ .) , class_input[fileTypeR1=="Chimeric"])
class_input[fileTypeR1=="Chimeric",glmnet_twostep_per_read_prob:=0]
class_input[fileTypeR1=="Chimeric"]$glmnet_twostep_per_read_prob  = predict(glmnet_model,newx = class_input_glmnet, type = "response",s = "lambda.1se", se.fit = TRUE)

# compute the fitted classification error based on training data
compute_class_error(class_input[!is.na(train_class)]$train_class,class_input[!is.na(train_class)]$glmnet_twostep_per_read_prob)

# compute aggregated score for each junction
class_input[fileTypeR1=="Chimeric",p_predicted_glmnet_twostep:= 1/( exp(sum(log( (1 - glmnet_twostep_per_read_prob)/glmnet_twostep_per_read_prob ))) + 1) ,by = refName_newR1]


######################################
######################################

col_names_to_keep_in_junc_pred_file = c("refName_newR1","numReads","readClassR1","p_predicted_glm","p_predicted_glmnet","p_predicted_glm_corrected","p_predicted_glmnet_corrected","threeprime_partner_number_R1","fiveprime_partner_number_R1","is.STAR_Chim","is.STAR_SJ","is.STAR_Fusion","geneR1A_expression_stranded","geneR1A_expression_unstranded","geneR1B_expression_stranded","geneR1B_expression_unstranded","geneR1B_ensembl","geneR1A_ensembl","geneR1B_uniq","geneR1A_uniq","intron_motif","is.annotated","num_uniq_map_reads","num_multi_map_reads","maximum_SJ_overhang","is.TRUE_fusion","glmnet_twostep_per_read_prob","p_predicted_glmnet_twostep")

junction_prediction = unique(class_input[,colnames(class_input)%in%col_names_to_keep_in_junc_pred_file,with = FALSE])
junction_prediction = junction_prediction[!(duplicated(refName_newR1))]

class_input[,cur_weight:=NULL]
class_input[,train_class:=NULL]

write.table(junction_prediction,paste(directory,"GLM_output.txt",sep = ""),row.names = FALSE,quote = FALSE,sep = "\t")
write.table(class_input,paste(directory,"class_input_WithinBAM.tsv",sep = ""),row.names = FALSE,quote = FALSE,sep = "\t")


# ######################################
# ####### now glmtlp model  ############
# tic("glmtlp")
# print("now glmtlp model")
# glmtlp_model = cv.glmTLP(x_glmnet, as.factor(training_reads$train_class), family=c("binomial"),training_reads$cur_weight, intercept = FALSE, tau = 1, nlambda = 100,nfolds = 3)
# training_reads$glmtlp_per_read_prob = predict(glmtlp_model,newx = x_glmnet, type = "response",s="lambda.1se", se.fit = TRUE)  # predict()$fit gives the fitted linear values. it is the same as the x$linear.predictors
# toc()
# compute_class_error(training_reads$train_class,training_reads$glmtlp_per_read_prob)
# print(coef(glmtlp_model,s = "lambda.1se"))
# print(glmtlp_model)
# 
# # predict for all read alignments in the class input file
# class_input$glmtlp_per_read_prob = predict(glmtlp_model,newx = class_input_glmnet, type = "response",s = "lambda.1se", se.fit = TRUE)
# 
# # compute aggregated score for each junction
# class_input[,p_predicted_glmtlp:= 1/( exp(sum(log( (1 - glmtlp_per_read_prob)/glmtlp_per_read_prob ))) + 1) ,by = refNameR1]
# ######################################
# ######################################