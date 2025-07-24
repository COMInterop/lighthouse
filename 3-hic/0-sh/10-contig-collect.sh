#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=10-contig-collect
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories
BASE="$DIR/output/9-hic/per-chr-pr/2-sort"
OUT="$DIR/output/9-hic/per-chr-pr/3-scaf/purge-2"


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
cat *hap0_scaffolds_renamed.fa > hap0-scaf.fasta
cat *hap1_scaffolds_renamed.fa > hap1-scaf.fasta

# Run stats.sh
bash stats.sh -Xmx22g hap0-scaf.fasta > hap0-scaf.stats.txt
bash stats.sh -Xmx22g hap1-scaf.fasta > hap1-scaf.stats.txt

# Define reference
REF=/path/to/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=hap0-scaf.fasta
PAIR=sodlb-hap0
minimap2 -cx asm5 -k19 -w30 -t68 -K100g -2 --cs --eqx --secondary=no "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=hap1-scaf.fasta
PAIR=sodlb-hap1
minimap2 -cx asm5 -k19 -w30 -t68 -K100g -2 --cs --eqx --secondary=no "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
