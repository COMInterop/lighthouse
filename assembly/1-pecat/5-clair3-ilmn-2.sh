#!/bin/bash

# Activate clair3 environment
ulimit -u 65336
source /path/to/conda/conda.sh
conda activate clair3


# Navigate to polish directory

cd $DIR/output/8-polish/pri-alt

# Define reference and reads paths
REF=$DIR/output/8-polish/pri-alt/clair3-ilmn-1/b-pri-alt-clair3-ilmn-1-merged.fasta
READS=/path/to/reads/trimmed-cleaned-pe150.fq
GT=pri-alt
OUT=clair3-ilmn-2

# Index the reference if not already indexed
if [ ! -f "$REF.fai" ]; then
    samtools faidx "$REF"
fi

# Check if bwa-mem2 index files exist before indexing
if [ ! -f "$REF.pac" ]; then
    bwa-mem2 index $REF
fi

# Align reads to the reference and convert to BAM format if BAM output doesn't exist
if [ ! -f "$GT-pe150-2.srt.bam" ]; then
    bwa-mem2 mem -t $THREADS -p $REF $READS | samtools view -bh -o $GT-pe150-2.bam -
fi

# Sort and index the BAM file if sorted BAM output doesn't exist
if [ ! -f "$GT-pe150-2.srt.bam.bai" ]; then
    samtools sort -@ $THREADS -o $GT-pe150-2.srt.bam $GT-pe150-2.bam
    samtools index -@ $THREADS $GT-pe150-2.srt.bam
fi

# Run clair3
/data_HPC02/app/singularity/bin/./singularity exec \
  -B $DIR,/path/to/models \
  /path/to/clair3_latest.sif \
  /opt/bin/run_clair3.sh \
  --bam_fn=$GT-pe150-2.srt.bam \
  --ref_fn=$REF \
  --platform=ilmn \
  --threads=$THREADS \
  --include_all_ctgs \
  --sample_name=$GT-pe150-2 \
  --model_path /path/to/models/r941_prom_sup_g5014 \
  --haploid_precise \
  --output=$DIR/output/8-polish/pri-alt/$OUT
  
# Generate consensus sequence

cat $REF | bcftools consensus $OUT/merge_output.vcf.gz > $OUT/$GT-$OUT.fasta


