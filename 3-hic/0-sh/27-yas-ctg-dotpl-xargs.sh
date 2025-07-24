#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=170
#SBATCH --job-name=12-yahs-ctg-dotpl-xargs
#SBATCH --output=12-yahs-ctg-dotpl-xargs.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base || { echo "Failed to activate conda environment"; exit 1; }

# Define the base and output directories
export BASE="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-new/2-sort"

# Change to the base directory
cd "$BASE" || { echo "Failed to change directory to $BASE"; exit 1; }

# Define a function to process each directory
process_dir() {
    DIR=$1
    CHR=$(basename "$DIR")
    
    # Change to the yahs subdirectory
    YAH_DIR="$BASE/$CHR/yahs"
    if [ ! -d "$YAH_DIR" ]; then
        echo "Directory $YAH_DIR does not exist, skipping $DIR"
        return
    fi

    cd "$YAH_DIR" || { echo "Failed to change directory to $YAH_DIR"; return; }

    # Loop through hap0 and hap1
    for HAP in hap0 hap1; do
        HAP_DIR="$YAH_DIR/$HAP"
        if [ ! -d "$HAP_DIR" ]; then
            echo "Directory $HAP_DIR does not exist, skipping $HAP"
            continue
        fi

        cd "$HAP_DIR" || { echo "Failed to change directory to $HAP_DIR"; continue; }

        REF="$BASE/$CHR/SODLb-$CHR.fasta"
        QUERY="$BASE/$CHR/${CHR}-${HAP}-contigs.fasta"    
        PAIR="$CHR-$HAP-yahs-ctg"

        if [ -f "$REF" ] && [ -f "$QUERY" ]; then
            PAF_FILE="$PAIR.srt.paf"

            if [ ! -f "$PAF_FILE" ]; then
                minimap2 -x asm5 -t 16 -K 100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > "$PAF_FILE"
                if [ $? -ne 0 ]; then
                    echo "Failed to execute minimap2 for $PAIR"
                    continue
                fi
            fi

            /data_HPC02/bpike/apps/paf2dotplot/paf2dotplot.r  -f -s "$PAF_FILE" || { echo "Failed to execute paf2dotplot for $PAIR"; continue; }
        else
            echo "Reference file $REF or query file $QUERY does not exist"
        fi
    done
}

export -f process_dir

# Find all directories starting with "chr" and parallelize the processing
find . -maxdepth 1 -type d -name 'chr*' -exec basename {} \; | xargs -I {} -n 1 -P 10 bash -c 'process_dir "$@"' _ {}
