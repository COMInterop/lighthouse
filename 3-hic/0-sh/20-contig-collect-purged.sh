#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=22-contig-collect
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Define the base and output directories
BASE="$DIR/output/9-hic/2-sort"
OUT="$DIR/output/9-hic/3-scaf/purged/contigs"

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
cat *hap0* > hap0-contigs.fasta
cat *hap1* > hap1-contigs.fasta

# Run stats.sh
bash stats.sh -Xmx22g hap0-contigs.fasta > hap0-contigs.stats.txt
bash stats.sh -Xmx22g hap1-contigs.fasta > hap1-contigs.stats.txt

# Define reference
REF=/path/to/SODLb-chromos.fasta

# Run minimap2 and paf2dotplot for hap0
QUERY=hap0-contigs.fasta
PAIR=sodlb-a-hap0-contigs
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf

# Run minimap2 and paf2dotplot for hap1
QUERY=hap1-contigs.fasta
PAIR=sodlb-hap1-contigs
minimap2 -cx asm5 -t48 -K100g -2 --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf
/path/to/paf2dotplot/paf2dotplot.r -f -s $PAIR.srt.paf
