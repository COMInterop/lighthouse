#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=12-contig-collect
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories
BASE="$DIR/output/9-hic/per-chr-new/2-sort"
OUT="$DIR/output/9-hic/per-chr-new/3-scaf/purged"

mkdir -p $OUT

cd $BASE

for DIR in chr*/; do
    CHR_NAME=$(basename "$DIR")
    
    for HAP in hap0 hap1; do
        FILE="$DIR/yahs/$HAP/${CHR_NAME}-${HAP}_scaffolds_final.fa"
        
        if [ -f "$FILE" ]; then
            awk -v prefix="${CHR_NAME}-${HAP}" '/^>/ {print ">" prefix "-" ++i; next} {print}' "$FILE" > "${FILE%.fa}_renamed.fa"
            mv "${FILE%.fa}_renamed.fa" "$FILE"
            cp "$FILE" "$OUT"
            echo "$FILE moved to $OUT"
        fi
    done
done

cd $OUT

# Concatenate files
cat *hap0* > hap0.fasta
cat *hap1* > hap1.fasta

# Run stats.sh
bash stats.sh -Xmx22g hap0.fasta > hap0.stats.txt
bash stats.sh -Xmx22g hap1.fasta > hap1.stats.txt

# Define reference
REF=/path/to/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=hap0.fasta
PAIR=sodlb-hap0
minimap2 -x asm5 -k19 -w30 -t168 -K100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=hap1.fasta
PAIR=sodlb-hap1
minimap2 -x asm5 -k19 -w30 -t168 -K100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
