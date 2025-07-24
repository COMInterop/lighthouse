#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=11-dotplot-per-chr
#SBATCH --output=%x.txt

# Source conda and activate the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories

BASE="$DIR/output/9-hic/per-chr-pr/2-sort"
OUT="$DIR/output/9-hic/per-chr-pr/3-scaf/purge-1"

cd $OUT

PAF=sodlb-hap0.srt.paf

/path/to/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="sodlb-hap0-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /path/to/paf2dotplot/paf2dotplot.r -f -s -i sdb_chr_$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done

PAF=sodlb-hap1.srt.paf

/path/to/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="sodlb-hap1-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /path/to/paf2dotplot/paf2dotplot.r -f -s -i sdb_chr_$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done