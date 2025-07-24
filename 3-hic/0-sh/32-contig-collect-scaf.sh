#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=16-contig-collect-scaf
#SBATCH --output=16-contig-collect-scaf.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Define the base and output directories
BASE="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort"
OUT="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/3-scaf"

mkdir -p $OUT

cd $BASE

for DIR in chr*; do
    CHR_NAME=$(basename "$DIR")
    
    for HAP in hap0 hap1; do
        FILE="$DIR/purge-2/yahs/${HAP}/${CHR_NAME}-${HAP}_scaffolds_renamed.fa"
        
        if [ -f "$FILE" ]; then
            cp "$FILE" "$OUT"
            echo "$FILE copied to $OUT"
        fi
    done
done

cd $OUT

# Concatenate files
cat *hap0_scaffolds* > a-hap0-scaf.fasta
cat *hap1_scaffolds* > a-hap1-scaf.fasta

# Run stats.sh
bash stats.sh -Xmx22g a-hap0-scaf.fasta > a-hap0-scaf.stats.txt
bash stats.sh -Xmx22g a-hap1-scaf.fasta > a-hap1-scaf.stats.txt

# Define reference
REF=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=a-hap0-scaf.fasta
PAIR=sodlb-a-hap0-scaf
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=a-hap1-scaf.fasta
PAIR=sodlb-a-hap1-scaf
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
