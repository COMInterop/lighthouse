#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=170
#SBATCH --job-name=13-yahs-ctg-dotpl-xargs-dual
#SBATCH --output=13-yahs-ctg-dotpl-xargs-dual.txt

# Source conda and activate the environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base || { echo "Failed to activate conda environment"; exit 1; }

# Define the base and output directories
export BASE="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-new/2-sort"

# Define a function to process each directory
process_dir() {
    DIR=$1
    CHR=$(basename "$DIR")
    
    # Change to the yahs subdirectory
    DUAL="$BASE/$CHR/yahs/dual"
    if [ ! -d "$DUAL" ]; then
        echo "Directory $DUAL does not exist, skipping $DIR"
        return
    fi

    cd "$DUAL" || { echo "Failed to change directory to $DUAL"; return; }

    # Define reference and query files
    REF="$BASE/$CHR/SODLb-$CHR.fasta"
    QUERY="$BASE/$CHR/${CHR}-contigs.fasta"
    PAIR="$CHR-sdb-ctg"

    if [ -f "$REF" ] && [ -f "$QUERY" ]; then
        PAF_FILE="$PAIR.srt.paf"

        if [ ! -f "$PAF_FILE" ]; then
            minimap2 -x asm5 -t 16 -K 100g -2 "$REF" "$QUERY" | sort -k6,6 -k8,8n > "$PAF_FILE"
            if [ $? -ne 0 ]; then
                echo "Failed to execute minimap2 for $PAIR"
                return
            fi
        fi

        /data_HPC02/bpike/apps/paf2dotplot/paf2dotplot.r -c 0.8 -f -s "$PAF_FILE" || { echo "Failed to execute paf2dotplot for $PAIR"; return; }
    else
        echo "Reference file $REF or query file $QUERY does not exist"
    fi
}

export -f process_dir

# Find all directories starting with "chr" and parallelize the processing
find "$BASE" -maxdepth 1 -type d -name 'chr*' -exec basename {} \; | xargs -I {} -n 1 -P 10 bash -c 'process_dir "$@"' _ {}
