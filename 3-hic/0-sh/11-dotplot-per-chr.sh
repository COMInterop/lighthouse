#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=170
#SBATCH --job-name=9.3-dotplot-per-chr
#SBATCH --output=9.3-dotplot-per-chr-log.txt

# Source conda and activate the environment

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories

BASE="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/2-sort"
OUT="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/3-scaf/purge-1"

cd $OUT

PAF=pr-a-hap0.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="pr-hap0-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /apps/bpike/paf2dotplot/paf2dotplot.r -f -s -i PR_chr_$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done

PAF=pr-a-hap1.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="pr-hap1-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /apps/bpike/paf2dotplot/paf2dotplot.r -f -s -i PR_chr_$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done

PAF=sodlb-a-hap0.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="sd-hap0-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /apps/bpike/paf2dotplot/paf2dotplot.r -f -s -i SODLb.chr$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done

PAF=sodlb-a-hap1.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -f -s $PAF

for i in 1 2 3 4 5 6 7 8 9 X; do
    OUTPUT_FILE="sd-hap1-chr$i.pdf"
    if [ ! -f $OUTPUT_FILE ]; then
        /apps/bpike/paf2dotplot/paf2dotplot.r -f -s -i SODLb.chr$i -o $OUTPUT_FILE $PAF
    else
        echo "$OUTPUT_FILE already exists."
    fi
done
