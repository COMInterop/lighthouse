#!/bin/bash

#SBATCH --job-name=admix
#SBATCH --output=%x.txt
#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate popgen
set -euo pipefail

# Set shell variables

DIR=
OUT=
K=4
THREADS=

# Run ADMIXTURE

cd $DIR

admixture $OUT.bed $K -j$THREADS
