#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=17-purge-2-mm-dp
#SBATCH --output=%x.txt

# Load necessary modules

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Define the base directory

BASE_DIR="$DIR/output/9-hic/2-sort"

export BASE_DIR

cd $BASE_DIR || { echo "Failed to change directory to $BASE_DIR"; exit 1; }

# Find directories and parallelize minimap2 tasks

find . -type d -name "chr*" | xargs -I{} -P $THREADS bash -c '
    DIR={}
    CHR_NAME=$(basename "$DIR")

    cd $BASE_DIR/$CHR_NAME/purge-2/yahs || { echo "Failed to change directory to $BASE_DIR/$CHR_NAME/purge-2/yahs"; exit 1; }

    for hap in hap0 hap1; do 
    
    	cd $hap
    	echo "PWD is $PWD."
 
        REF="/path/to/SODLb.${CHR_NAME}.fasta"
        SCAFFOLDS="${CHR_NAME}-${hap}_scaffolds_renamed.fa" 
        PAIR="${CHR_NAME}-${hap}-yahs"
        PAF="${PAIR}.srt.paf"

        if [ -f "$REF" ] && [ -f "$SCAFFOLDS" ]; then
            if [ ! -s "$PAF" ]; then
                minimap2 -x asm5 -t16 -K100g --cs --eqx --secondary=no "$REF" "$SCAFFOLDS" | sort -k6,6 -k8,8n > "$PAF" || { echo "minimap2 failed for $PAIR"; exit 1; }
            else
                echo "Skipping minimap2: PAF file $PAF already exists and is non-zero."
            fi
        else
            [ ! -f "$REF" ] && echo "Skipping minimap2: Reference file $REF is missing."
            [ ! -f "$SCAFFOLDS" ] && echo "Skipping minimap2: Scaffolds file $SCAFFOLDS is missing."
        fi
        cd .. || { echo "Failed to change directory back to yahs"; exit 1; }
    done
'

# Sequentially draw dotplots

cd $BASE_DIR || { echo "Failed to change directory to $BASE_DIR"; exit 1; }

for DIR in chr*; do
    CHR_NAME=$(basename "$DIR")
    cd "$BASE_DIR/$CHR_NAME/purge-2/yahs" || { echo "Failed to change directory to $BASE_DIR/$CHR_NAME/purge-2/yahs"; exit 1; }
    
    for hap in hap0 hap1; do 
        cd $hap || { echo "Failed to change directory to $hap"; exit 1; }
        echo "PWD is $PWD."
        PAIR="${CHR_NAME}-${hap}-yahs"
        PAF="${PAIR}.srt.paf"
        
        if [ -s "$PAF" ]; then
           /path/to/paf2dotplot/paf2dotplot.r -s -o ${CHR_NAME}-${hap}-no-flip "$PAF" || { echo "paf2dotplot failed for $PAIR"; exit 1; }
        else
            [ ! -f "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is missing."
            [ ! -s "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is empty."
        fi
        cd .. || { echo "Failed to change directory back to yahs"; exit 1; }
    done
    cd .. || { echo "Failed to change directory back to purge-2"; exit 1; }
done
