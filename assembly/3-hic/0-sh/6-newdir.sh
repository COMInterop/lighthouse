#!/bin/bash


#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=6-newdir
#SBATCH --output=%x.txt

# Load necessary modules

source /path/to/miniforge3/etc/profile.d/conda.sh
if conda activate base; then
    echo "Successfully activated conda environment"
else
    echo "Failed to activate conda environment" >&2
    exit 1
fi

# Define the base directory

BASE_DIR="$DIR/output/9-hic/2-sort"
if cd "$BASE_DIR"; then
    echo "Changed directory to $BASE_DIR"
else
    echo "Failed to change directory to $BASE_DIR" >&2
    exit 1
fi

# Find directories and process them sequentially

for DIR in $(find . -type d -name "chr*"); do
    if cd "$DIR"; then
        echo "Processing directory $DIR"
    else
        echo "Failed to change directory to $DIR" >&2
        continue
    fi
    
    CHR_NAME=$(basename "$DIR")
    mkdir -p purge-1
    if [ -f "purge-1/${CHR_NAME}-revisions.txt" ]; then
    echo "File purge-1/${CHR_NAME}-revisions.txt already exists. Skipping to the next step."
else
    if touch "purge-1/${CHR_NAME}-revisions.txt"; then
        echo "Created file purge-1/${CHR_NAME}-revisions.txt"
    else
        echo "Failed to create file purge-1/${CHR_NAME}-revisions.txt" >&2
        cd "$BASE_DIR"
        continue
    fi
fi

    for hap in hap0 hap1; do 
        REF="sdb-${CHR_NAME}.fasta"
        CONTIGS="${CHR_NAME}-${hap}-contigs.fasta"
        PAIR="${CHR_NAME}-$hap"
        PAF="${PAIR}.srt.paf"
        
        if cp "${PAF}.pdf" purge-1; then
            echo "Copied ${PAF}.pdf to purge-1"
        else
            echo "Failed to copy ${PAF}.pdf to purge-1" >&2
            continue
        fi
        
        if sort -u "gh/${CHR_NAME}-${hap}-contigs.txt" -o "purge-1/${CHR_NAME}-${hap}-contigs-revised-1.txt"; then
            echo "Copied ${CHR_NAME}-${hap}-contigs.txt to purge-1/${CHR_NAME}-${hap}-contigs-revised-1.txt"
        else
            echo "Failed to copy ${CHR_NAME}-${hap}-contigs.txt to purge-1/${CHR_NAME}-${hap}-contigs-revised-1.txt" >&2
            continue
        fi
    done
    
    if cd "$BASE_DIR"; then
        echo "Returned to base directory $BASE_DIR"
    else
        echo "Failed to return to base directory $BASE_DIR" >&2
        exit 1
    fi
done
