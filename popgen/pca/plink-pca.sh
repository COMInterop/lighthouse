#!/bin/bash

#SBATCH --job-name=pca-plink
#SBATCH --output=%x.txt
#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate popgen
set -euo pipefail

# Set shell variables

DIR={directory}
BASE={name for output files}
VCF={input vcf.gz}
W=50
OUT="${BASE}-plink-${W}"
PC={number of samples minus one}

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
--pca $PC \
--out $OUT
