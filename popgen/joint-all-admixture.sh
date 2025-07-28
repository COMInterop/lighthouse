#!/bin/bash

#SBATCH --job-name=admix
#SBATCH --output=%x.txt
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=168

# Prepare the environment

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate popgen
set -euo pipefail

# Set shell variables

DIR=/data_HPC02/bpike/lh/pan/align/joint/all
OUT=joint-all-recode-structure
K=4
THREADS=168

# Run ADMIXTURE

cd $DIR

admixture $OUT.bed $K -j$THREADS
