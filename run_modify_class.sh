#!/bin/bash
#
#SBATCH --job-name=modify_sim2_reads
#SBATCH --output=output/sim_101_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/sim2_reads/log_files/modify_sim2_reads.%j.out
#SBATCH --error=output/sim_101_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/sim2_reads/log_files/modify_sim2_reads.%j.err
#SBATCH --time=12:00:00
#SBATCH -p horence
#SBATCH --nodes=1
#SBATCH --mem=50Gb
#SBATCH --dependency=afterok:52051780
#SBATCH --kill-on-invalid-dep=yes
date
Rscript scripts/modify_junction_ids.R output/sim_101_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/sim2_reads/ 
date
