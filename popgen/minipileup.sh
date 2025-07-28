#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --job-name=minipileup  
#SBATCH --output=%x.txt 

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate popgen
set -euo pipefail

# Set shell variables

REF=/path/to/SODLb-chromos.fasta
N0="sdb"
DIR=/data_HPC02/bpike/lh/pan/align/popgen-85/ene2025
BASE={output name of choice}

samtools faidx $REF

# Index BAMs if necessary

directories=(
    "/first/path/to/bam"
    "/second/path/to/bam"
    "/third/path/to/bam"
)


for dir in "${directories[@]}"; do
    for bam in "$dir"/*.bam; do
        if [ ! -f "${bam}.bai" ]; then
            echo "Indexing $bam..."
            samtools index "$bam"
        else
            echo "Index for $bam already exists, skipping..."
        fi
    done
done

# make the calls

mkdir -p $DIR 
cd $DIR

if [[ -f "${BASE}.vcf" ]]; then
    echo "File ${BASE}.vcf already exists. Skipping minipileup step."
else
    echo "Running minipileup to generate ${BASE}.vcf..."

    /apps/bpike/minipileup/minipileup \
    -vc -a0 -s0 -q0 -Q0 \
    -f $REF \
    /first/path/to/bam/*.bam \
    /second/path/to/bam/*.bam \
    /third/path/to/bam/*.bam \
    > $BASE.vcf
fi

# Filter for biallelic SNPs with MAF > 0.05

if [[ -f "${BASE}-snps.vcf" ]]; then
    echo "SNP-only VCF ${BASE}-snps.vcf already exists, skipping filtering for ${BASE}.vcf."
else
    echo "Filtering ${BASE}.vcf for SNPs..."
    vcftools --vcf "${BASE}.vcf" \
    --min-alleles 2 \
    --max-alleles 2 \
    --max-missing 0.2 \
    --maf 0.05 \
    --remove-indels \
    --recode \
    --recode-INFO-all \
    --out "${BASE}-snps-maf-05"

    echo "SNP-only VCF created: $${BASE}-snps-maf-05.recode.vcf"

    # Compress and index the new VCF
    bgzip "${BASE}-snps-maf-05.recode.vcf"
    tabix -p vcf "${BASE}-snps-maf-05.recode.vcf.gz"
fi




