#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=11-yahs-purge-2
#SBATCH --output=11-yahs-purge-2-log.txt

# Activate the conda environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the working directory
WORKDIR=/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/2-sort
BAM="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/a-pri-alt-hic.srt.bam"
YAHS_APP="/data_HPC02/bpike/apps/yahs/./yahs"

# Loop through each chromosome directory
for CHR_DIR in $WORKDIR/chr{1..9} $WORKDIR/chrX; do
    PURGE2_DIR="$CHR_DIR/purge-2"
    if [ -d "$PURGE2_DIR" ]; then
        mkdir -p "$PURGE2_DIR/yahs"
        
        # Loop through each haplotype file
        for HAP_FILE in $PURGE2_DIR/*contigs-revised-2.fasta; do
            # Extract chromosome and haplotype information
            FILENAME=$(basename "$HAP_FILE")
            CHR=$(echo "$FILENAME" | cut -d'-' -f1)
            HAP=$(echo "$FILENAME" | cut -d'-' -f2)
            
            # Define output directory and prefix for yahs
            OUT_DIR="$PURGE2_DIR/yahs/${HAP}"
            mkdir -p "$OUT_DIR"
            OUT_PREFIX="$OUT_DIR/${CHR}-${HAP}"
            OUT_FINAL="${OUT_PREFIX}_scaffolds_final.fa"
            NEW_OUT_FINAL="$OUT_DIR/${CHR}-${HAP}_scaffolds_renamed.fa"
            
            # Create index file for the FASTA if it does not exist
            if [ ! -f "$HAP_FILE.fai" ]; then
                samtools faidx "$HAP_FILE"
            fi
            
            # Check if final output file already exists
            if [ ! -s "$OUT_FINAL" ]; then
                # Run yahs
                {
                    $YAHS_APP -o "$OUT_PREFIX" -v 2 "$HAP_FILE" "$BAM" &
                }
            else
                echo "$OUT_FINAL already exists. Skipping yahs."
            fi
            
            # Do the renaming
            wait
            awk -v prefix="${CHR}-${HAP}-scaffold" 'BEGIN{count=1} /^>/{print ">" prefix count++; next} 1' "$OUT_FINAL" > "$NEW_OUT_FINAL"
            echo "Renamed scaffolds in $OUT_FINAL and saved to $NEW_OUT_FINAL."
        done
    fi
done

# Wait for all background processes to finish
wait

echo "Hi-C scaffolding completed."
