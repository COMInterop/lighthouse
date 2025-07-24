#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=16-contig-collect
#SBATCH --output=16-contig-collect.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Define the base and output directories
BASE="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort"
OUT="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/3-scaf/purged/contigs"

mkdir -p $OUT

cd $BASE

for DIR in chr*; do
    CHR_NAME=$(basename "$DIR")
    
    for HAP in hap0 hap1; do
        FILE="$DIR/purge-2/${CHR_NAME}-${HAP}-contigs-revised-2.fasta"
        
        if [ -f "$FILE" ]; then
            cp "$FILE" "$OUT"
            echo "$FILE moved to $OUT"
        fi
    done
done

cd $OUT

# Concatenate files
cat *hap0* > a-hap0-contigs.fasta
cat *hap1* > a-hap1-contigs.fasta

# Run stats.sh
bash stats.sh -Xmx22g a-hap0-contigs.fasta > a-hap0-contigs.stats.txt
bash stats.sh -Xmx22g a-hap1-contigs.fasta > a-hap1-contigs.stats.txt

# Define reference
REF=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=a-hap0-contigs.fasta
PAIR=sodlb-a-hap0-contigs
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=a-hap1-contigs.fasta
PAIR=sodlb-a-hap1-contigs
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
