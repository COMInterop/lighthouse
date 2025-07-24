#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=8-yahs
#SBATCH --output=%x.txt

# Activate the conda environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the working directory
WORKDIR=$DIR/output/9-hic/2-sort
BAM="$DIR/output/9-hic/1-map/hic/b-pri-alt-hic.srt.bam"
YAHS_APP="/path/to/yahs/./yahs"

# Loop through each chromosome directory
for CHR_DIR in $WORKDIR/chr{1..9} $WORKDIR/chrX; do
    PURGE1_DIR="$CHR_DIR/purge-2"
    if [ -d "$PURGE1_DIR" ]; then
        mkdir -p "$PURGE1_DIR/yahs"
        
        # Loop through each haplotype file
        for HAP_FILE in $PURGE1_DIR/*contigs-revised-2.fasta; do
            # Extract chromosome and haplotype information
            FILENAME=$(basename "$HAP_FILE")
            CHR=$(echo "$FILENAME" | cut -d'-' -f1)
            HAP=$(echo "$FILENAME" | cut -d'-' -f2)
            
            # Define output directory and prefix for yahs
            OUT_DIR="$PURGE1_DIR/yahs/${HAP}"
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
                # Run yahs and log errors
                {
                    $YAHS_APP -o "$OUT_PREFIX" -v 2 "$HAP_FILE" "$BAM"
                } 2>> "$OUT_DIR/yahs-error.log" &
            else
                echo "$OUT_FINAL already exists. Skipping yahs."
            fi
            
            # Wait for all background processes to finish
            wait

            # Do the renaming
            awk -v prefix="${CHR}-${HAP}-scaffold" 'BEGIN{count=1} /^>/{print ">" prefix count++; next} 1' "$OUT_FINAL" > "$NEW_OUT_FINAL"
            echo "Renamed scaffolds in $OUT_FINAL and saved to $NEW_OUT_FINAL."
        done
    fi
done

# Wait for all background processes to finish
wait

echo "Hi-C scaffolding completed."
