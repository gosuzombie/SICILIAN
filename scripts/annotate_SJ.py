import annotator
import argparse
import os
import pandas as pd
import pickle
import time

def get_gene1(row):
  gene, strand = ann.get_name_given_locus(row["donor_chromosome"], int(row["first_intron_base"]) - 1)
  return gene

def get_gene2(row):
  gene, strand = ann.get_name_given_locus(row["acceptor_chromosome"], int(row["last_intron_base"]) + 1)
  return gene

def chim_get_gene1(row):
  gene, strand =  ann.get_name_given_locus(row["donor_chromosome"], int(row["donor_first_intron_base"]) - 1)
  return gene

def chim_get_gene2(row):
  gene, strand = ann.get_name_given_locus(row["acceptor_chromosome"], int(row["acceptor_first_intron_base"]) - 1)
  return gene

def get_strand1(row):
  gene, strand = ann.get_name_given_locus(row["donor_chromosome"], int(row["first_intron_base"]) - 1)
  return strand

def get_strand2(row):
  gene, strand = ann.get_name_given_locus(row["acceptor_chromosome"], int(row["last_intron_base"]) + 1)
  return strand

def chim_get_strand1(row):
  gene, strand = ann.get_name_given_locus(row["donor_chromosome"], int(row["donor_first_intron_base"]) - 1)
  return strand

def chim_get_strand2(row):
  gene, strand = ann.get_name_given_locus(row["acceptor_chromosome"], int(row["acceptor_first_intron_base"]) - 1)
  return strand
 
parser = argparse.ArgumentParser(description="annotate genes in STAR output files")
parser.add_argument("-i", "--input_path", help="the prefix to the STAR Chimeric.out.junction and SJ.out.tab files")
parser.add_argument("-g", "--gtf_path", help="the path to the gtf file to use for annotation", default=False)
parser.add_argument("-a", "--assembly", help="The name of the assembly to pre-load annotation (so, mm10 for the 10th mouse assembly)")
args = parser.parse_args()

t0 = time.time()

wrapper_path = "/scratch/PI/horence/JuliaO/single_cell/STAR_wrapper/"
annotator_path = "{}annotators/{}.pkl".format(wrapper_path, args.assembly)

if os.path.exists(annotator_path):
  ann = pickle.load(open("/scratch/PI/horence/JuliaO/single_cell/STAR_wrapper/annotators/{}.pkl".format(args.assembly), "rb"))
else:
  ann = annotator.Annotator(args.gtf_path)
  pickle.dump(ann, open("/scratch/PI/horence/JuliaO/single_cell/STAR_wrapper/annotators/{}.pkl".format(args.assembly), "wb"))
  
print("initiated annotator: {}".format(time.time() - t0))

for i in range(1,3):
  SJ_df = pd.read_csv("{}{}SJ.out.tab".format(args.input_path, i), sep="\t", names = ["donor_chromosome", "first_intron_base", "last_intron_base", "strand", "intron_motif", "annotated", "num_uniquely_mapping", "num_multi_mapping", "max_spliced_overhang"])
  SJ_df["acceptor_chromosome"] = SJ_df["donor_chromosome"]
  SJ_df["donor_gene"] = SJ_df.apply(get_gene1, axis=1)
  SJ_df["acceptor_gene"] = SJ_df.apply(get_gene2, axis=1)
  SJ_df["donor_strand"] = SJ_df.apply(get_strand1, axis=1)
  SJ_df["acceptor_strand"] = SJ_df.apply(get_strand2, axis=1)  
  chim_df = pd.read_csv("{}{}Chimeric.out.junction".format(args.input_path, i), sep="\t", names = ["donor_chromosome", "donor_first_intron_base", "donor_strand", "acceptor_chromosome", "acceptor_first_intron_base", "acceptor_strand", "junction_type", "left_repeat_length", "right_repeat_length", "read_name", "first_base_of_first_segment", "CIGAR_first", "first_base_of_second_segment", "CIGAR_second"])
  chim_df["donor_gene"] = chim_df.apply(chim_get_gene1, axis=1)
  chim_df["acceptor_gene"] = chim_df.apply(chim_get_gene2, axis=1)
  chim_df["donor_strand"] = chim_df.apply(chim_get_strand1, axis=1)
  chim_df["acceptor_strand"] = chim_df.apply(chim_get_strand2, axis=1)  
  df = pd.concat([SJ_df, chim_df], axis=0, ignore_index=True, sort=False)
  df.to_csv("{}{}SJ_Chimeric.out".format(args.input_path, i), sep="\t", index=False)
  
