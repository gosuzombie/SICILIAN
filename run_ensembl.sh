#!/bin/bash
#
#SBATCH --job-name=ensembl_B107920_N20_S235
#SBATCH --output=/oak/stanford/groups/horence/Roozbeh/single_cell_project/output/TS_pilot_smartseq_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/B107920_N20_S235/log_files/ensembl_B107920_N20_S235.%j.out
#SBATCH --error=/oak/stanford/groups/horence/Roozbeh/single_cell_project/output/TS_pilot_smartseq_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/B107920_N20_S235/log_files/ensembl_B107920_N20_S235.%j.err
#SBATCH --time=12:00:00
#SBATCH --account=horence
#SBATCH --partition=nih_s10
#SBATCH --nodes=1
#SBATCH --mem=50Gb
#SBATCH --dependency=afterok:12869184
#SBATCH --kill-on-invalid-dep=yes
date
Rscript scripts/add_ensembl_id.R /oak/stanford/groups/horence/Roozbeh/single_cell_project/output/TS_pilot_smartseq_cSM_10_cJOM_10_aSJMN_0_cSRGM_0/B107920_N20_S235/  0 
date
