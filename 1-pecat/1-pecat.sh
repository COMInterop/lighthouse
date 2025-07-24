#!/bin/bash

#set ulimit so as to permit Clair3 to run unimpeded

ulimit -u 65336

# Activate conda environnment
source /path/to/conda/conda.sh
conda activate pecat
cd $DIR

# Perform PECAT
pecat.pl unzip pecat.cfg

# Polish the primary and alternate assemblies with Clair3 in place of Medaka. 
#We use '--no_phasing_for_fa' with the assumption that PECAT has accurately filtered haplotype-specific readsets.

cd $DIR/output/6-polish/medaka/pri

run_clair3.sh \
--bam_fn rd_2_ctg_flt_sorted.bam \
--ref_fn $DIR/output/6-polish/racon/primary.fasta \
--threads $THREADS \
--model_path /path/to/models/r941_prom_sup_g5014 \
--platform ont \
--output $DIR/output/6-polish/medaka/pri/clair3 \
--include_all_ctgs \
--no_phasing_for_fa \
--haploid precise

cat "$DIR/output/6-polish/racon/primary.fasta" | bcftools consensus $DIR/output/6-polish/medaka/pri/clair3/merge_output.vcf.gz > "$DIR/output/6-polish/medaka/pri-clair.fasta"

cd $DIR/output/6-polish/medaka/alt

run_clair3.sh \
--bam_fn rd_2_ctg_flt_sorted.bam \
--ref_fn $DIR/output/6-polish/racon/alternate.fasta \
--threads 96 \
--model_path /path/to/models/r941_prom_sup_g5014 \
--platform ont \
--output $DIR/output/6-polish/medaka/alt/clair3 \
--include_all_ctgs \
--no_phasing_for_fa \
--haploid precise

cat "$DIR/output/6-polish/racon/alternate.fasta" | bcftools consensus $DIR/output/6-polish/medaka/alt/clair3/merge_output.vcf.gz > "$DIR/output/6-polish/medaka/alt-clair.fasta"

