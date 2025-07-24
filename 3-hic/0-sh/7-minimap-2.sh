#!/bin/bash

#SBATCH --job-name=8.7-minimap-2
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=170
#SBATCH --output=8.7-minimap-2-log.txt

# Load necessary modules
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base directory
BASE_DIR="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort"

cd $BASE_DIR

# Sequential processing for awk and subsequent parts
for DIR in chr*; do
    cd "$BASE_DIR/$DIR/purge-1"
    CHR_NAME=$(basename "$DIR")
    CONTIGS="../${CHR_NAME}-contigs.fasta"
    HAP0_LIST="${CHR_NAME}-hap0-contigs-revised-1.txt"
    HAP1_LIST="${CHR_NAME}-hap1-contigs-revised-1.txt"

    HAP0_OUTPUT="${CHR_NAME}-hap0-contigs-revised-1.fasta"
    HAP1_OUTPUT="${CHR_NAME}-hap1-contigs-revised-1.fasta"

    echo "Extracting contigs for $CHR_NAME"

    if [ ! -f "$HAP0_OUTPUT" ]; then
        seqkit grep -f "$HAP0_LIST" "$CONTIGS" > "$HAP0_OUTPUT"
        echo "Created $HAP0_OUTPUT"
    else
        echo "Skipping extraction: $HAP0_OUTPUT already exists."
    fi

    if [ ! -f "$HAP1_OUTPUT" ]; then
        seqkit grep -f "$HAP1_LIST" "$CONTIGS" > "$HAP1_OUTPUT"
        echo "Created $HAP1_OUTPUT"
    else
        echo "Skipping extraction: $HAP1_OUTPUT already exists."
    fi
done

# Find directories and parallelize minimap2 tasks
cd $BASE_DIR

find . -type d -name "chr*" | xargs -I{} -P170 bash -c '
    DIR={}
    mkdir -p $DIR/purge-2
    cd $DIR/purge-1
    CHR_NAME=$(basename "$DIR")

    for hap in hap0 hap1; do 
        BASE_DIR="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort"
        REF="/data_HPC02/bpike/refs/SODLb.${CHR_NAME}.fasta"
        CONTIGS="${CHR_NAME}-${hap}-contigs-revised-1.fasta"
        PAIR="${CHR_NAME}-${hap}-revised-1"
        PAF="$BASE_DIR/$DIR/purge-2/$PAIR.srt.paf"
        
        cp "${CHR_NAME}-${hap}-contigs-revised-1.txt" "$BASE_DIR/$CHR_NAME/purge-2/${CHR_NAME}-${hap}-contigs-revised-2.txt"
        
        if [ -f "$REF" ] && [ -f "$CONTIGS" ]; then
            if [ ! -s "$PAF" ]; then
                minimap2 -cx asm5 -t16 -K100g --cs --eqx --secondary=no "$REF" "$CONTIGS" | sort -k6,6 -k8,8n > "$PAF"
            else
                echo "Skipping minimap2: PAF file $PAF already exists and is non-zero."
            fi
        else
            [ ! -f "$REF" ] && echo "Skipping minimap2: Reference file $REF is missing."
            [ ! -f "$CONTIGS" ] && echo "Skipping minimap2: Contigs file $CONTIGS is missing."
        fi
    done
'

# Sequentially draw dotplots
BASE_DIR="/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort"
cd $BASE_DIR

for DIR in chr*; do
    
    CHR_NAME=$(basename "$DIR")
    cd "$BASE_DIR/$DIR/purge-2"
    
    echo "PWD is $PWD."
    
    for hap in hap0 hap1; do 
        PAIR="${CHR_NAME}-${hap}-revised-1"
        PAF="${PAIR}.srt.paf"
        
        if [ -s "$PAF" ]; then
            /apps/bpike/paf2dotplot/paf2dotplot.r -s -f "$PAF"
        else
            [ ! -f "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is missing."
            [ ! -s "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is empty."
        fi
    done
done
