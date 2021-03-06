#!/usr/bin/env Rscript

require(data.table)

###### Input arguments ##############
args = commandArgs(trailingOnly = TRUE)
directory = args[1]
assembly = args[2]
#####################################

### arguments for debugging ######
#class_input = fread("/scratch/PI/horence/Roozbeh/single_cell_project/output/sim_101_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/sim1_reads/test.txt",sep="\t",header = TRUE)
##################################

###### read in class input file #####################
class_input_file = list.files(directory,pattern = "class_input_WithinBAM.tsv")
class_input = fread(paste(directory,class_input_file,sep = ""),sep = "\t",header = TRUE)
###############################################

if (assembly %like% "hg38"){
  gene_strand_info_file = "/oak/stanford/groups/horence/Roozbeh/single_cell_project/utility_files/hg38_gene_strand.txt"
} else if(assembly %like% "Mmur"){ 
  gene_strand_info_file = "/oak/stanford/groups/horence/Roozbeh/single_cell_project/utility_files/Mmur3_gene_strand.txt"
}

gene_strand_info = fread(gene_strand_info_file,sep="\t",header = TRUE)

class_input[fileTypeR1=="Aligned",read_strandR1B:=read_strandR1A]


#need to get the gene information from the unmodified junction id "refName_ABR1" so that if I rerun this script for a dataset I can still use the raw infomration rather than the modified information 
class_input[,chrR1A:=strsplit(refName_ABR1,split=":",fixed=TRUE)[[1]][1],by=refName_ABR1]
class_input[,chrR1B:=strsplit(refName_ABR1,split="[:|]")[[1]][5],by=refName_ABR1]
class_input[,juncPosR1A:=as.integer(strsplit(refName_ABR1,split=":",fixed=TRUE)[[1]][3]),by=refName_ABR1]
class_input[,juncPosR1B:=as.integer(strsplit(refName_ABR1,split=":",fixed=TRUE)[[1]][6]),by=refName_ABR1]
class_input[,gene_strandR1A:=strsplit(refName_ABR1,split="[:|]")[[1]][4],by=refName_ABR1]
class_input[,gene_strandR1B:=strsplit(refName_ABR1,split="[:|]")[[1]][8],by=refName_ABR1]
class_input[,geneR1A:=strsplit(refName_ABR1,split=":",fixed=TRUE)[[1]][2],by=refName_ABR1]
class_input[,geneR1B:=strsplit(refName_ABR1,split=":",fixed=TRUE)[[1]][5],by=refName_ABR1]


class_input[,numgeneR1A:=length(strsplit(geneR1A,split = ",")[[1]]),by = geneR1A] # the number of overlapping genes on the R1A side
class_input[,numgeneR1B:=length(strsplit(geneR1B,split = ",")[[1]]),by = geneR1B] # the number of overlapping genes on the R1B side
class_input[,gene_strandR1A_new:=NULL] #if I rerun this script for a class input file, need to delete these columns because otherwise I would get an error
class_input[,gene_strandR1B_new:=NULL]

# I remove SNORA and other weird gene names from the list of gene names on each side of junction if the strand inforamtion is already known or there are many genes in the junction id (after each removal one is deducted from the number of genes)
# TRNA genes are mostly observed in the lemur data
#class_input[((numgeneR1A>2) & (geneR1A%like%"SNORA")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"SNORA")),`:=`(geneR1A = gsub("^SNORA[[:digit:]]+,?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
#class_input[((numgeneR1B>2) & (geneR1B%like%"SNORA")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"SNORA")),`:=`(geneR1B = gsub("^SNORA[[:digit:]]+,?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"SNORA")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"SNORA")),`:=`(geneR1A = gsub("^SNORA[[:digit:]]+,?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"SNORA")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"SNORA")),`:=`(geneR1B = gsub("^SNORA[[:digit:]]+,?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"RP11")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"RP11")),`:=`(geneR1A = gsub("RP11-*[[:alnum:]]+[[:punct:]][[:digit:]]+,?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"RP11")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"RP11")),`:=`(geneR1B = gsub("RP11-*[[:alnum:]]+[[:punct:]][[:digit:]]+,?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"RP4-")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"RP4-")),`:=`(geneR1A = gsub("RP4-*[[:alnum:]]+[[:punct:]][[:digit:]]+,?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"RP4-")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"RP4-")),`:=`(geneR1B = gsub("RP4-*[[:alnum:]]+[[:punct:]][[:digit:]]+,?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"SCARNA")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"SCARNA")),`:=`(geneR1A = gsub("SCARNA[[:digit:]]{2},?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"SCARNA")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"SCARNA")),`:=`(geneR1B = gsub("SCARNA[[:digit:]]{2},?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"DLEU2")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"DLEU2")),`:=`(geneR1A = gsub("DLEU2_[[:digit:]]{1},?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"DLEU2")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"DLEU2")),`:=`(geneR1B = gsub("DLEU2_[[:digit:]]{1},?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"SNORD")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"SNORD")),`:=`(geneR1A = gsub("SNORD[[:digit:]]{1,3},?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"SNORD")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"SNORD")),`:=`(geneR1B = gsub("SNORD[[:digit:]]{1,3},?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[((numgeneR1A>2) & (geneR1A%like%"CTSLP2")) | ((numgeneR1A>1) & !(gene_strandR1A=="?") & (geneR1A%like%"CTSLP2")),`:=`(geneR1A = gsub("CTSLP2,?", "", geneR1A), numgeneR1A = numgeneR1A-1)]
class_input[((numgeneR1B>2) & (geneR1B%like%"CTSLP2")) | ((numgeneR1B>1) & !(gene_strandR1B=="?") & (geneR1B%like%"CTSLP2")),`:=`(geneR1B = gsub("CTSLP2,?", "", geneR1B), numgeneR1B = numgeneR1B-1)]
class_input[,geneR1A := gsub(",$", "", geneR1A),by=geneR1A]
class_input[,geneR1B := gsub(",$", "", geneR1B),by=geneR1B]

# if there is a shared gene between the two anchors of the splice, we select that as the common gene for the junction id
class_input[,shared_gene:=paste(intersect(strsplit(geneR1A,split = ",")[[1]],strsplit(geneR1B,split = ",")[[1]]),collapse = ","),by = refName_ABR1] # the genes that are shared between R1A and R1B 
class_input[,num_shared_genes:=length(strsplit(shared_gene,split = ",")[[1]]),by = shared_gene] #number of shared genes between R1A and R1B
class_input[(num_shared_genes>0) & ((numgeneR1A>1) | (numgeneR1B>1)), geneR1B:=tail(strsplit(shared_gene,split=",")[[1]],n=1), by = refName_ABR1] 
class_input[(num_shared_genes>0) & ((numgeneR1A>1) | (numgeneR1B>1)), geneR1A:=tail(strsplit(shared_gene,split=",")[[1]],n=1), by = refName_ABR1]


# if there is an ambiguous strand and the read strands are not compatible with the gene strand, we select the second (from the last) gene name 
class_input[,geneR1A_uniq := geneR1A]
class_input[,geneR1B_uniq := geneR1B]
class_input[(numgeneR1A>1) & (num_shared_genes==0), geneR1A_uniq := tail(strsplit(geneR1A,split = ",")[[1]],n=1),by = refName_ABR1]
class_input[(numgeneR1B>1) & (num_shared_genes==0), geneR1B_uniq := tail(strsplit(geneR1B,split = ",")[[1]],n=1),by = refName_ABR1]
if (assembly %like% "hg38"){
  class_input = merge(class_input,gene_strand_info,all.x = TRUE,all.y = FALSE,by.x="geneR1A_uniq",by.y = "gene_name")
} else if(assembly %like% "Mmur"){ 
  class_input = merge(class_input,gene_strand_info,all.x = TRUE,all.y = FALSE, by.x = c("geneR1A_uniq","chrR1A"), by.y = c("gene_name","chr"))
}

setnames(class_input, old = "strand", new = "gene_strandR1A_new")
if (assembly %like% "hg38"){
  class_input = merge(class_input,gene_strand_info,all.x = TRUE,all.y = FALSE, by.x = "geneR1B_uniq", by.y = "gene_name")
} else if(assembly %like% "Mmur"){ 
  class_input = merge(class_input,gene_strand_info,all.x = TRUE,all.y = FALSE, by.x = c("geneR1B_uniq","chrR1B"), by.y = c("gene_name","chr"))
}
setnames(class_input,old = "strand",new = "gene_strandR1B_new")

class_input[((gene_strandR1A_new!=read_strandR1A & gene_strandR1B_new==read_strandR1B) | (gene_strandR1A_new==read_strandR1A & gene_strandR1B_new!=read_strandR1B)) & (gene_strandR1A=="?") & (num_shared_genes == 0), geneR1A_uniq:=first(tail(strsplit(geneR1A,split=",")[[1]],n=2)),by = refName_ABR1]
class_input[,gene_strandR1A_new := NULL]
if (assembly %like% "hg38"){
  class_input = merge(class_input, gene_strand_info, all.x = TRUE, all.y = FALSE, by.x = "geneR1A_uniq", by.y = "gene_name")
} else if(assembly %like% "Mmur"){ 
  class_input = merge(class_input, gene_strand_info, all.x = TRUE, all.y = FALSE, by.x = c("geneR1A_uniq","chrR1A"), by.y = c("gene_name","chr"))
}
setnames(class_input, old = "strand", new = "gene_strandR1A_new")

class_input[((gene_strandR1A_new!=read_strandR1A & gene_strandR1B_new==read_strandR1B)  | (gene_strandR1A_new==read_strandR1A & gene_strandR1B_new!=read_strandR1B)) & (gene_strandR1B=="?") & (num_shared_genes == 0), geneR1B_uniq:=first(tail(strsplit(geneR1B,split=",")[[1]],n=2)),by = refName_ABR1]
class_input[,gene_strandR1B_new:=NULL]
if (assembly %like% "hg38"){
  class_input = merge(class_input, gene_strand_info, all.x = TRUE, all.y = FALSE, by.x = "geneR1B_uniq", by.y = "gene_name")
} else if(assembly %like% "Mmur"){ 
  class_input = merge(class_input, gene_strand_info, all.x = TRUE, all.y = FALSE, by.x = c("geneR1B_uniq","chrR1B"), by.y = c("gene_name","chr"))
}
setnames(class_input, old = "strand", new = "gene_strandR1B_new")
#################

## these vectors are being used to determine the orientation of the strand for the genes with unknown gene strand info
reverse = c()
reverse["+"] = "-"
reverse["-"] = "+"

same = c()
same["-"] = "-"
same["+"] = "+"

# for those junctions whose gene strand info is not available, we use the read strand information in such a way that the gene strands are compatible with read strands
class_input[is.na(gene_strandR1B_new) & (gene_strandR1A_new == read_strandR1A),gene_strandR1B_new:=same[read_strandR1B]]
class_input[is.na(gene_strandR1B_new) & (gene_strandR1A_new != read_strandR1A),gene_strandR1B_new:=reverse[read_strandR1B]]
class_input[is.na(gene_strandR1A_new) & (gene_strandR1B_new != read_strandR1B),gene_strandR1A_new:=reverse[read_strandR1A]]
class_input[is.na(gene_strandR1A_new) & (gene_strandR1B_new == read_strandR1B),gene_strandR1A_new:=same[read_strandR1A]]


class_input[fileTypeR1=="Aligned" & gene_strandR1A_new=="-" & (juncPosR1A < juncPosR1B),refName_newR1:=paste(chrR1B,":",geneR1B_uniq,":",juncPosR1B,":",gene_strandR1B_new,"|",chrR1A,":",geneR1A_uniq,":",juncPosR1A,":",gene_strandR1A_new,sep="")]
class_input[fileTypeR1=="Aligned" & gene_strandR1A_new=="-" & (juncPosR1A < juncPosR1B),c("chrR1A","geneR1A","juncPosR1A","gene_strandR1A","cigarR1A","MR1A","SR1A","numgeneR1A","gene_strandR1A_new","chrR1B","geneR1B","juncPosR1B","gene_strandR1B","cigarR1B","MR1B","SR1B","numgeneR1B","gene_strandR1B_new")] = class_input[fileTypeR1=="Aligned" & gene_strandR1A_new=="-",c("chrR1B","geneR1B","juncPosR1B","gene_strandR1B","cigarR1B","MR1B","SR1B","numgeneR1B","gene_strandR1B_new","chrR1A","geneR1A","juncPosR1A","gene_strandR1A","cigarR1A","MR1A","SR1A","numgeneR1A","gene_strandR1A_new")]
class_input[fileTypeR1=="Aligned" & gene_strandR1A_new=="+",refName_newR1:=paste(chrR1A,":",geneR1A_uniq,":",juncPosR1A,":",gene_strandR1A_new,"|",chrR1B,":",geneR1B_uniq,":",juncPosR1B,":",gene_strandR1B_new,sep="")]
class_input[,juncPosR1A_surrogate:=as.numeric(strsplit(refName_ABR1,split = ":",fixed = TRUE)[[1]][3]),by=1:nrow(class_input)]
class_input[(fileTypeR1=="Chimeric") & (gene_strandR1A_new!=read_strandR1A) & (juncPosR1A==juncPosR1A_surrogate), refName_newR1:=paste(chrR1B,":",geneR1B_uniq,":",juncPosR1B,":",gene_strandR1B_new,"|",chrR1A,":",geneR1A_uniq,":",juncPosR1A,":",gene_strandR1A_new,sep="")]
class_input[(fileTypeR1=="Chimeric") & (gene_strandR1A_new!=read_strandR1A) & (gene_strandR1B_new!=read_strandR1B)& (juncPosR1A==juncPosR1A_surrogate),c("chrR1A","geneR1A","juncPosR1A","gene_strandR1A","aScoreR1A","flagR1A","posR1A","qualR1A","MDR1A","nmmR1A","cigarR1A","MR1A","SR1A","NHR1A","HIR1A","nMR1A","NMR1A","jMR1A","jIR1A","read_strandR1A","numgeneR1A","gene_strandR1A_new","chrR1B","geneR1B","juncPosR1B","gene_strandR1B","aScoreR1B","flagR1B","posR1B","qualR1B","MDR1B","nmmR1B","cigarR1B","MR1B","SR1B","NHR1B","HIR1B","nMR1B","NMR1B","jMR1B","jIR1B","read_strandR1B","numgeneR1B","gene_strandR1B_new")] = class_input[(fileTypeR1=="Chimeric") & (gene_strandR1A_new!=read_strandR1A) & (gene_strandR1B_new!=read_strandR1B),c("chrR1B","geneR1B","juncPosR1B","gene_strandR1B","aScoreR1B","flagR1B","posR1B","qualR1B","MDR1B","nmmR1B","cigarR1B","MR1B","SR1B","NHR1B","HIR1B","nMR1B","NMR1B","jMR1B","jIR1B","read_strandR1B","numgeneR1B","gene_strandR1B_new","chrR1A","geneR1A","juncPosR1A","gene_strandR1A","aScoreR1A","flagR1A","posR1A","qualR1A","MDR1A","nmmR1A","cigarR1A","MR1A","SR1A","NHR1A","HIR1A","nMR1A","NMR1A","jMR1A","jIR1A","read_strandR1A","numgeneR1A","gene_strandR1A_new")]
class_input[(fileTypeR1=="Chimeric") & ((gene_strandR1A_new==read_strandR1A) | (gene_strandR1B_new==read_strandR1B)), refName_newR1:=paste(chrR1A,":",geneR1A_uniq,":",juncPosR1A,":",gene_strandR1A_new,"|",chrR1B,":",geneR1B_uniq,":",juncPosR1B,":",gene_strandR1B_new,sep="")]
class_input[,juncPosR1A_surrogate:=NULL]
class_input[is.na(refName_newR1),refName_newR1:=refName_ABR1]  # for the junctions for which we do not need to modify junction id, use the old junction id

# deleting redundant columns from the class input file
class_input[,shared_gene:=NULL]
class_input[,num_shared_genes:=NULL]
class_input[,numgeneR1A:=NULL]
class_input[,numgeneR1B:=NULL]
class_input[,geneR1A_name:=NULL]
class_input[,geneR1B_name:=NULL]


# since some of the gene names might have been flipped in the junction id, we again extract the chr and gene names for each part of the junction based on refName_newR1 
class_input[,chrR1A:=strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][1],by=refName_newR1]
class_input[,chrR1B:=strsplit(refName_newR1,split="[:|]")[[1]][5],by=refName_newR1]
class_input[,juncPosR1A:=as.integer(strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][3]),by=refName_newR1]
class_input[,juncPosR1B:=as.integer(strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][6]),by=refName_newR1]
class_input[,gene_strandR1A:=strsplit(refName_newR1,split="[:|]")[[1]][4],by=refName_newR1]
class_input[,gene_strandR1B:=strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][7],by=refName_newR1]
class_input[,geneR1A_uniq:=strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][2],by=refName_newR1]
class_input[,geneR1B_uniq:=strsplit(refName_newR1,split=":",fixed=TRUE)[[1]][5],by=refName_newR1]


write.table(class_input,paste(directory,"class_input_WithinBAM.tsv",sep = ""),row.names = FALSE,quote = FALSE,sep = "\t")
