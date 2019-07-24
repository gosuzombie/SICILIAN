# Wrapper script for STAR and statistical modeling
# Created by Julia Olivieri
# 17 June 2019

import glob
import os
import subprocess
import sys
import time
import argparse

def sbatch_file(file_name, job_name, time, mem, command, dep="", dep_type = "afterok"):
  """Write sbatch script given parameters"""
  job_file = open(file_name, "w")
  job_file.write("#!/bin/bash\n#\n")
  job_file.write("#SBATCH --job-name=" + job_name + "\n")
  job_file.write("#SBATCH --output=job_output/{}.%j.out\n".format(job_name))
  job_file.write("#SBATCH --error=job_output/{}.%j.err\n".format(job_name))
  job_file.write("#SBATCH --time={}\n".format(time))
 # job_file.write("#SBATCH --qos=normal\n")
#  job_file.write("#SBATCH -p horence\n")
  job_file.write("#SBATCH -p owners\n")
  job_file.write("#SBATCH --nodes=1\n")
  job_file.write("#SBATCH --mem={}\n".format(mem)) 
  if dep != "":
    job_file.write("#SBATCH --dependency={}:{}\n".format(dep_type,dep))
    job_file.write("#SBATCH --kill-on-invalid-dep=yes\n")
  job_file.write("date\n")
  job_file.write(command + "\n")
  job_file.write("date\n")
  job_file.close()


def star_fusion(out_path, name, single, dep = ""):
  """Run star-fusion on chimeric alignments by STAR"""
  command = "/scratch/PI/horence/Roozbeh/STAR-Fusion/STAR-Fusion --genome_lib_dir /scratch/PI/horence/Roozbeh/STAR-Fusion/GRCh38_gencode_v29_CTAT_lib_Mar272019.plug-n-play/ctat_genome_lib_build_dir/ -J "
  if single:
    command += "   {}{}/2Chimeric.out.junction --output_dir {}{}/star_fusion ".format(out_path, name,out_path,name)
  else:
    command += " {}{}/1Chimeric.out.junction --output_dir {}{}/star_fusion ".format(out_path, name,out_path,name)
  sbatch_file("run_star_fusion.sh", "fusion_{}".format(name), "12:00:00", "20Gb", command, dep=dep)
  return submit_job("run_star_fusion.sh")

def compare(out_path, name, single, dep = ""):
  """Run script to comapre the junctions in the class input file with those in the STAR SJ.out, Chim.out and STAR-Fusion file"""
  command = "Rscript scripts/compare_class_input_STARchimOut.R {}{}/ ".format(out_path, name)
  if single:
    command += " 1 "
  else:
    command += " 0 "
  sbatch_file("run_compare.sh", "compare_{}".format(name), "12:00:00", "25Gb", command, dep=dep)
  return submit_job("run_compare.sh")

def ensembl(out_path, name, single, dep = ""):
  """Run script to add both ensembl gene ids and gene counts to the class input files"""
  command = "Rscript scripts/add_ensembl_id.R {}{}/ ".format(out_path, name)
  if single:
    command += " 1 "
  else:
    command += " 0 " 
  sbatch_file("run_ensembl.sh", "ensembl_{}".format(name), "12:00:00", "25Gb", command, dep=dep)
  return submit_job("run_ensembl.sh")


def ann_SJ(out_path, name, assembly, gtf_file, single, dep = ""):
  """Run script to add gene names to SJ.out.tab and Chimeric.out.junction"""
  command = "python3 scripts/annotate_SJ.py -i {}{}/ -a {} -g {} ".format(out_path, name, assembly, gtf_file)
  if single:
    command += "--single "
  sbatch_file("run_ann_SJ.sh", "ann_SJ_{}".format(name), "24:00:00", "40Gb", command, dep=dep)
  return submit_job("run_ann_SJ.sh")

def class_input(out_path, name, assembly, gtf_file, single,dep=""):
  """Run script to create class input file"""
  command = "python3 scripts/create_class_input.py -i {}{}/ -a {} -g {} ".format(out_path, name, assembly, gtf_file)
  if single:
    command += "--single"
  sbatch_file("run_class_input.sh", "class_input_{}".format(name), "24:00:00", "40Gb", command, dep=dep)
  return submit_job("run_class_input.sh")


def STAR_map(out_path, data_path, name, r_ends, assembly, gzip, cSM, cJOM, aSJMN, cSRGM, single, gtf_file):
  """Run script to perform mapping job for STAR"""
  command = "mkdir -p {}{}\n".format(out_path, name)
  command += "STAR --version\n"
  if single:
    l = 1
  else:
    l = 0
  for i in range(l,2):
    command += "/scratch/PI/horence/Roozbeh/STAR-2.7.1a/bin/Linux_x86_64/STAR --runThreadN 4 "
    command += "--alignIntronMax 21 "
    command += "--genomeDir /scratch/PI/horence/JuliaO/single_cell/STAR_output/{}_index_2.7.1a ".format(assembly)
    command += "--readFilesIn {}{}{} ".format(data_path, name, r_ends[i])
    if gzip:
      command += "--readFilesCommand zcat "
    command += "--twopassMode Basic "
    command += "--outFileNamePrefix {}{}/{} ".format(out_path, name, i + 1)
    command += "--outSAMtype SAM "
    command += "--chimSegmentMin {} ".format(cSM)
    command += "--outSAMattributes All "
    command += "--chimOutType Junctions SeparateSAMold "
    command += "--chimJunctionOverhangMin {} ".format(cJOM)
    command += "--alignSJstitchMismatchNmax {} -1 {} {} ".format(aSJMN, aSJMN, aSJMN)
    command += "--chimSegmentReadGapMax {} ".format(cSRGM)
    command += "--quantMode GeneCounts "
    command += "--sjdbGTFfile {} ".format(gtf_file)
    command += "--outReadsUnmapped Fastx \n\n"
  sbatch_file("run_map.sh", "map_{}".format(name), "12:00:00", "60Gb", command)
  return submit_job("run_map.sh")

def log(out_path, name, jobs, dep = ""):
  """Run job to concatenate all individual job outputs for the sample into one file"""
  command = "python3 scripts/create_log.py -i {}{}/ -j {}".format(out_path,name, " ".join(jobs))
  sbatch_file("run_log.sh", "log_{}".format(name), "5:00", "500", command, dep = dep,dep_type = "afterany")
  return submit_job("run_log.sh")

def submit_job(file_name):
  """Submit sbatch job to cluster"""
  status, job_num = subprocess.getstatusoutput("sbatch {}".format(file_name))
  if status == 0:
    print("{} ({})".format(job_num, file_name))
    return job_num.split()[-1]
  else:
    print("Error submitting job {} {} {}".format(status, job_num, file_name))

def main():

  parser = argparse.ArgumentParser()
  parser.add_argument('-s', '--sample', required=True, help='the name of the smartseq sample')
  args = parser.parse_args()

  chimSegmentMin = [10] 
  chimJunctionOverhangMin = [10]
  alignSJstitchMismatchNmax = [0]
  chimSegmentReadGapMax = [0]


  # benchmarking
  data_path = "/scratch/PI/horence/Roozbeh/single_cell_project/data/benchmarking/"
  assembly = "hg38"
  run_name = "benchmarking"
  r_ends = ["_2.fastq", "_2.fastq"]
  names = ["SRR6782109", "SRR6782110", "SRR6782111", "SRR6782112", "SRR8606521"]
  gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/grch38_genes.gtf"
  single = True


# Tabula Sapiens pilot (10X)
  data_path = "/scratch/PI/horence/Roozbeh/single_cell_project/data/tabula_sapiens/pilot/raw_data/10X/TSP1_muscle_1/"
  assembly = "hg38"
  run_name = "TS_pilot_10X"
  r_ends = ["_001.fastq.gz", "_001.fastq.gz"]
  names = ["TSP1_muscle_1_S19_L001_R2","TSP1_muscle_1_S19_L002_R2","TSP1_muscle_1_S19_L003_R2","TSP1_muscle_1_S19_L004_R2"]
  gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/grch38_genes.gtf"
  single = True


# Tabula Sapiens pilot (smartseq)
#  data_path = "/scratch/PI/horence/Roozbeh/single_cell_project/data/tabula_sapiens/pilot/raw_data/smartseq2/B107809_J2_S29/"
#  assembly = "hg38"
#  run_name = "TS_pilot_smartseq"
#  r_ends = ["_R1_001.fastq.gz", "_R2_001.fastq.gz"]
#  names = ["B107809_J2_S29"]
#  gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/grch38_genes.gtf"
#  single = False


# Tabula Sapiens pilot (smartseq)
  data_path = "/scratch/PI/horence/Roozbeh/single_cell_project/data/tabula_sapiens/pilot/raw_data/smartseq2/"+args.sample+"/"
  assembly = "hg38"
  run_name = "TS_pilot_smartseq"
  r_ends = ["_R1_001.fastq.gz", "_R2_001.fastq.gz"]
  names = [args.sample]
  gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/grch38_genes.gtf"
  single = False

#Engstrom sim1
#  data_path = "/scratch/PI/horence/Roozbeh/data/Engstrom/"
#  assembly = "hg38"
#  run_name = "Engstrom"
#  r_ends = ["_R1.fq", "_R2.fq"]
#  names = ["Engstrom_sim1_trimmed"]
#  gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/grch38_genes.gtf"
#  single = False


  # path that contains fastqs
#  data_path = ""

  # assembly and gtf file to use for alignment
#  assembly = "mm10"

  # unique endings for the file names of read one (location 0) and read 2 (location 1)
#  r_ends = ["_1.fastq.gz", "_2.fastq.gz"]

  # unique identifiers for each fastq; file location for read 1 should be <data_path><name><r_ends[0]>
#  names = ["SRR65462{}".format(i) for i in range(73,85)]

  run_map = False
  run_star_fusion = False
  run_ann = False
  run_class = False
  run_ensembl = True
  run_compare = True
 
  if r_ends[0].split(".")[-1] == "gz":
    gzip = True
  else:
    gzip = False

  for cSM in chimSegmentMin:
    for cJOM in chimJunctionOverhangMin:
      for aSJMN in alignSJstitchMismatchNmax:
        for cSRGM in chimSegmentReadGapMax:
          cond_run_name = run_name + "_cSM_{}_cJOM_{}_aSJMN_{}_cSRGM_{}".format(cSM, cJOM, aSJMN, cSRGM)
          out_path = "/scratch/PI/horence/Roozbeh/single_cell_project/output/{}/".format(cond_run_name)
        #  gtf_file = "/scratch/PI/horence/JuliaO/single_cell/STAR_output/{}_files/{}.gtf".format(assembly, assembly)
#          gtf_file = "/share/PI/horence/circularRNApipeline_Cluster/index/{}_genes.gtf".format(assembly)
        
        
          total_jobs = []
          total_job_names = []
          for name in names:
            jobs = []
            if run_map:
              map_jobid = STAR_map(out_path, data_path, name, r_ends, assembly, gzip, cSM, cJOM, aSJMN, cSRGM, single, gtf_file)
              jobs.append("map_{}.{}".format(name,map_jobid))
              total_jobs.append(map_jobid)
            else:
              map_jobid = ""
            if run_star_fusion:
              star_fusion_jobid = star_fusion(out_path, name, single, dep=map_jobid)
              jobs.append("star_fusion_{}.{}".format(name,star_fusion_jobid))
              total_jobs.append(star_fusion_jobid)
            else:
              star_fusion_jobid = ""
        
            if run_ann:
              ann_SJ_jobid = ann_SJ(out_path, name, assembly, gtf_file, single, dep = star_fusion_jobid)
              jobs.append("ann_SJ_{}.{}".format(name,ann_SJ_jobid))
              total_jobs.append(ann_SJ_jobid)
            else:
              ann_SJ_jobid =  ""
        
            if run_class:
              class_input_jobid = class_input(out_path, name, assembly, gtf_file, single, dep=ann_SJ_jobid)
              jobs.append("class_input_{}.{}".format(name,class_input_jobid))
              total_jobs.append(class_input_jobid)
            else:
              class_input_jobid = ""
                 
            if run_ensembl:
             ensembl_jobid = ensembl(out_path, name, single, dep=class_input_jobid)
             jobs.append("ensembl_{}.{}".format(name,ensembl_jobid))
             total_jobs.append(ensembl_jobid)
            else:
              ensembl_jobid =  ""
            
            if run_compare:
             compare_jobid = compare(out_path, name, single, dep=ensembl_jobid)
             jobs.append("compare_{}.{}".format(name,compare_jobid))
             total_jobs.append(compare_jobid)
            else:
              compare_jobid =  ""

        
            log_jobid = log(out_path, name, jobs, dep = compare_jobid)
            jobs.append("log_{}.{}".format(name,log_jobid))
            total_jobs.append(log_jobid)
        
            total_job_names += jobs 
          log(out_path, "", sorted(total_job_names), dep = ":".join(total_jobs))

main()