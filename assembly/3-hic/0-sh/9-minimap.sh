#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=9-minimap
#SBATCH --output=%x.txt

# Load necessary modules
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base directory
BASE_DIR="$DIR/output/9-hic/per-chr-pr/2-sort"
cd $BASE_DIR


# Find directories and parallelize minimap2 tasks

cd $BASE_DIR

find . -type d -name "chr*" | xargs -I{} -P170 bash -c '
    DIR={}
    cd $DIR/purge-1/yahs
    CHR_NAME=$(basename "$DIR")

    for hap in hap0 hap1; do 
    	cd $DIR/purge-1/yahs/$hap
        BASE_DIR="$DIR/output/9-hic/per-chr-pr/2-sort"
        REF="$BASE_DIR/${CHR_NAME}/PR-${CHR_NAME}.fasta"
        CONTIGS="${CHR_NAME}-${hap}_scaffolds_final.fa"
        PAIR="${CHR_NAME}-${hap}-revised-1-scaffolds"
        PAF="$BASE_DIR/$DIR/purge-1/yahs/$hap/$PAIR.srt.paf"
        
        
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

cd $BASE_DIR

for DIR in chr*; do
    
    CHR_NAME=$(basename "$DIR")
    cd "$DIR/output/9-hic/per-chr-pr/2-sort/$CHR_NAME/purge-2"
    
    for hap in hap0 hap1; do 
    	cd purge-1/yahs/$hap
        PAIR="${CHR_NAME}-${hap}-revised-1-scaffolds"
        PAF="${PAIR}.srt.paf"
        
        if [ -s "$PAF" ]; then
            /apps/bpike/paf2dotplot/paf2dotplot.r -s -f "$PAF"
        else
            [ ! -f "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is missing."
            [ ! -s "$PAF" ] && echo "Skipping paf2dotplot: PAF file $PAF is empty."
        fi
    done
done
