#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=18-yahs-ctg-dotplot
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base || { echo "Failed to activate conda environment"; exit 1; }

# Define the base and output directories
BASE="$DIR/output/9-hic/per-chr-new/2-sort"

# Change to the base directory
cd "$BASE" || { echo "Failed to change directory to $BASE"; exit 1; }

# Loop through each directory starting with "chr"
for DIR in chr*; do
    CHR=$(basename "$DIR")
    
    # Change to the yahs subdirectory
    YAH_DIR="$BASE/$DIR/yahs"
    if [ ! -d "$YAH_DIR" ]; then
        echo "Directory $YAH_DIR does not exist, skipping $DIR"
        continue
    fi

    cd "$YAH_DIR" || { echo "Failed to change directory to $YAH_DIR"; continue; }

    # Loop through hap0 and hap1
    for HAP in hap0 hap1; do
        HAP_DIR="$YAH_DIR/$HAP"
        if [ ! -d "$HAP_DIR" ]; then
            echo "Directory $HAP_DIR does not exist, skipping $HAP"
            continue
        fi

        cd "$HAP_DIR" || { echo "Failed to change directory to $HAP_DIR"; continue; }

        REF="$BASE/$DIR/SODLb-$CHR.fasta"
        QUERY="$BASE/$DIR/${CHR}-${HAP}-contigs.fasta"    
        PAIR="$CHR-$HAP-yahs-ctg"

        if [ -f "$REF" ] && [ -f "$QUERY" ]; then
            PAF_FILE="$PAIR.srt.paf"

            if [ ! -f "$PAF_FILE" ]; then
                minimap2 -x asm5 -t48 -K100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > "$PAF_FILE"
                if [ $? -ne 0 ]; then
                    echo "Failed to execute minimap2 for $PAIR"
                    continue
                fi
            fi

            /path/to/paf2dotplot/paf2dotplot.r -f -s "$PAF_FILE" || { echo "Failed to execute paf2dotplot for $PAIR"; continue; }
        else
            echo "Reference file $REF or query file $QUERY does not exist"
        fi
    done
done
