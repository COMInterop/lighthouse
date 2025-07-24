#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=9.2-contig-collect
#SBATCH --output=9.2-contig-collect.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories
BASE="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/2-sort"
OUT="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/3-scaf/purge-2"


cd $BASE

for DIR in chr*/; do
    CHR_NAME=$(basename "$DIR")
    
    for HAP in hap0 hap1; do
        FILE="$DIR/purge-2/yahs/$HAP/${CHR_NAME}-${HAP}_scaffolds_renamed.fa"
        
        if [ -f "$FILE" ]; then
                       # cp "$FILE" "$OUT"
            echo "$FILE moved to $OUT"
        fi
    done
done

cd $OUT

# Concatenate files
cat *hap0_scaffolds_renamed.fa > a-hap0-scaf.fasta
cat *hap1_scaffolds_renamed.fa > a-hap1-scaf.fasta

# Run stats.sh
bash stats.sh -Xmx22g a-hap0-scaf.fasta > a-hap0-scaf.stats.txt
bash stats.sh -Xmx22g a-hap1-scaf.fasta > a-hap1-scaf.stats.txt

# Define reference
REF=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=a-hap0-scaf.fasta
PAIR=sodlb-a-hap0
minimap2 -cx asm5 -k19 -w30 -t68 -K100g -2 --cs --eqx --secondary=no "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=a-hap1-scaf.fasta
PAIR=sodlb-a-hap1
minimap2 -cx asm5 -k19 -w30 -t68 -K100g -2 --cs --eqx --secondary=no "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
