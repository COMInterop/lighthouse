#!/bin/bash


# Activate clair3 and set ulimit appropriately

ulimit -u 65336
source /path/to/conda/conda.sh
conda activate clair3

#prepare clima

mkdir -p $DIR/output/8-polish/pri-alt
cd $DIR/output/8-polish/pri-alt

cat $DIR/output/7-purge-haps/pri/curated.fasta $DIR/output/7-purge-haps/alt/curated.fasta > pri-alt-curated.fasta

REF=$DIR/output/8-polish/pri-alt/pri-alt-curated.fasta
READS=/path/to/reads/trimmed-cleaned-pe150.fq
GT=pri-alt
OUT=clair3-ilmn-1

if [ ! -f "$REF.fai" ]; then
    samtools faidx "$REF"
fi

# Check if bwa-mem2 index files exist before indexing

if [ ! -f "$REF.pac" ]; then
    bwa-mem2 index $REF
fi

# Align reads to the reference and convert to BAM format if BAM output doesn't exist

if [ ! -f "$GT-pe150-1.srt.bam" ]; then
    bwa-mem2 mem -t 168 -p $REF $READS | samtools view -bh -o $GT-pe150-1.bam -
fi

# Sort and index the BAM file if sorted BAM output doesn't exist

if [ ! -f "$GT-pe150-1.srt.bam.bai" ]; then
    samtools sort -@ 96 -o $GT-pe150-2.srt.bam $GT-pe150-2.bam
    samtools index -@ 96 $GT-pe150-2.srt.bam
fi


# Note: for the ILMN model we have better luck with the Singularity container.

/path/to/singularity/bin/./singularity exec \
  -B $DIR,/path/to/models \
  /path/to/clair3_latest.sif \
  /opt/bin/run_clair3.sh \
  --bam_fn=$GT-pe150-1.srt.bam \
  --ref_fn=$REF \
  --platform=ilmn \
  --threads=$THREADS \
  --include_all_ctgs \
  --no_phasing_for_fa \
  --sample_name=$GT-pe150-1 \
  --model_path /path/to/models/ilmn \
  --haploid_precise \
  --output=$DIR/output/8-polish/pri-alt/$OUT
  

cat $REF | bcftools consensus merge_output.vcf.gz > $GT-$OUT-ilmn-polished.fasta 


