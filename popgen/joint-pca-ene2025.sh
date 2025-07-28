#!/bin/bash

#SBATCH --job-name=joint-pca-ene2025
#SBATCH --output=%x.txt
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48

# Prepare the environment

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate popgen
set -euo pipefail

# Set shell variables

DIR="/data_HPC02/bpike/lh/pan/align/popgen-85/ene2025/maf010"
BASE="joint-85-ene2025"
VCF="/data_HPC02/bpike/lh/pan/align/popgen-85/ene2025/joint-85-ene2025-snps-maf-05.recode.vcf.gz"
W=50
OUT="${BASE}-plink-${W}"

mkdir -p $DIR
cd "$DIR"
echo "Changed directory to $DIR"

# Do the linkage pruning

echo "Converting VCF to PLINK format..."

plink2 --vcf $VCF \
--double-id \
--allow-extra-chr \
--set-missing-var-ids @:# \
--snps-only \
--min-alleles 2 \
--max-alleles 2 \
--maf 0.10 \
--indep-pairwise ${W} 10 0.1 \
--make-bed \
--out $OUT

# Do the PCA

echo "Performing PCA..."
plink --bfile $OUT \
--double-id \
--allow-extra-chr \
--set-missing-var-ids @:# \
--extract $OUT.prune.in \
--pca 84 \
--out $OUT
