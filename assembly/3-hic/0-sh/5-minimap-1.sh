#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=5-minimap-1
#SBATCH --output=%x.txt

# Load necessary modules

echo "Loading conda environment..."
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Define the base directory

BASE_DIR="$DIR/output/9-hic/2-sort"
echo "Changing directory to $BASE_DIR"
cd $BASE_DIR || { echo "Failed to change directory to $BASE_DIR"; exit 1; }

# Find directories and parallelize minimap2 tasks

export BASE_DIR

echo "Finding directories and parallelizing minimap2 tasks..."
find . -type d -name "chr*" | xargs -I{} -P $THREADS bash -c '
    DIR={}
    echo "Processing directory $DIR"
    cd "$DIR" || { echo "Failed to change directory to $DIR"; exit 1; }
    CHR_NAME=$(basename "$DIR")
    echo "Chromosome name: $CHR_NAME"

    for hap in hap0 hap1; do 
        echo "Processing haplotype $hap"
        REF="/path/to/SODLb.${CHR_NAME}.fasta"
        CONTIGS="${CHR_NAME}-${hap}-contigs.fasta"
        PAIR="${CHR_NAME}-$hap"
        PAF="${PAIR}.srt.paf"    

        # Check if the necessary files exist before running minimap2

        if [ -f "$REF" ] && [ -f "$CONTIGS" ]; then
            if [ ! -s "$PAF" ]; then
                echo "Running minimap2 for $PAIR..."
                minimap2 -cx asm5 -t8 -K100g --cs --eqx --secondary=no "$REF" "$CONTIGS" | sort -k6,6 -k8,8n > "$PAF"
                if [ $? -ne 0 ]; then
                    echo "minimap2 command failed for $PAIR"
                    exit 1
                else
                    echo "minimap2 completed successfully for $PAIR"
                fi
            else
                echo "Skipping minimap2: PAF file $PAF already exists and is non-zero."
            fi
        else
            if [ ! -f "$REF" ]; then
                echo "Skipping minimap2: Reference file $REF is missing."
            fi
            if [ ! -f "$CONTIGS" ]; then
                echo "Skipping minimap2: Contigs file $CONTIGS is missing."
            fi
        fi

        # Check if PAF file exists and has nonzero size before running paf2dotplot.r

        if [ -s "$PAF" ]; then
            echo "Running paf2dotplot.r for $PAF..."
            /path/to/paf2dotplot/paf2dotplot.r -s -f -m 5000 -q 20000 -o ${PAIR}-m5k-q20k "$PAF"
            if [ $? -ne 0 ]; then
                echo "paf2dotplot.r command failed for $PAF"
                exit 1
            else
                echo "paf2dotplot.r completed successfully for $PAF"
            fi
        else
            if [ ! -f "$PAF" ]; then
                echo "Skipping paf2dotplot: PAF file $PAF is missing."
            elif [ ! -s "$PAF" ]; then
                echo "Skipping paf2dotplot: PAF file $PAF is empty."
            fi
        fi
    done
'
