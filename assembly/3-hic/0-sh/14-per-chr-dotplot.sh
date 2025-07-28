#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=14-per-chr-dotplot
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the base and output directories
BASE="$DIR/output/9-hic/per-chr-new/2-sort"

# Change to the base directory
cd $BASE || { echo "Failed to change directory to $BASE"; exit 1; }

# Loop through each directory starting with "chr"
for DIR in chr*; do
    CHR=$(basename "$DIR")
    
    # Change to the yahs subdirectory
    cd "$BASE/$DIR/yahs" || { echo "Failed to change directory to $BASE/$DIR/yahs"; continue; }
    
    # Create dual directory if it doesn't exist
    mkdir -p dual || { echo "Failed to create directory dual in $BASE/$DIR/yahs"; continue; }
    
    # Loop through hap0 and hap1
    for HAP in hap0 hap1; do
        FILE="$BASE/$DIR/yahs/$HAP/${CHR}-${HAP}_scaffolds_final.fa"
        
        if [ -f "$FILE" ]; then
            cp "$FILE" "$BASE/$DIR/yahs/dual" || { echo "Failed to move $FILE to $BASE/$DIR/yahs/dual"; continue; }
            echo "$FILE moved to $BASE/$DIR/yahs/dual"
        else
            echo "File $FILE does not exist"
        fi
    done
    
    # Change to the dual directory
    cd "$BASE/$DIR/yahs/dual" || { echo "Failed to change directory to $BASE/$DIR/yahs/dual"; continue; }
    
    # Check if $CHR-dual.fasta exists and has nonzero file size
    if [ ! -s "$CHR-dual.fasta" ]; then
        cat *.fa > "$CHR-dual.fasta" || { echo "Failed to concatenate files into $CHR-dual.fasta"; continue; }
    else
        echo "$CHR-dual.fasta already exists and has nonzero file size. Skipping concatenation."
    fi
    
    REF="$BASE/$DIR/SODLb-$CHR.fasta"
    QUERY="$CHR-dual.fasta"
    PAIR="sodlb-$CHR-dual"
    
    if [ -f "$REF" ] && [ -f "$QUERY" ]; then
        minimap2 -x asm5 -k19 -w30 -t48 -K100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > "$PAIR.srt.paf" && /path/to/paf2dotplot/paf2dotplot.r -f -s "$PAIR.srt.paf" || { echo "Failed to execute minimap2 or paf2dotplot for $PAIR"; continue; }
    else
        echo "Reference file $REF or query file $QUERY does not exist"
    fi
done
