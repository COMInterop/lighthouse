#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=15-yahs-purge-2-xargs
#SBATCH --output=%x.txt

# Activate the conda environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base

# Define the working directory
WORKDIR=$DIR/output/9-hic/2-sort
BAM="$DIR/output/9-hic/1-map/hic/b-pri-alt-hic.srt.bam"
YAHS_APP="/path/to/yahs/./yahs"

# Function to run yahs
run_yahs() {
    HAP_FILE="$1"
    FILENAME=$(basename "$HAP_FILE")
    CHR=$(echo "$FILENAME" | cut -d'-' -f1)
    HAP=$(echo "$FILENAME" | cut -d'-' -f2)
    
    PURGE2_DIR=$(dirname "$HAP_FILE")
    OUT_DIR="$PURGE2_DIR/yahs/${HAP}"
    mkdir -p "$OUT_DIR"
    OUT_PREFIX="$OUT_DIR/${CHR}-${HAP}"
    OUT_FINAL="${OUT_PREFIX}_scaffolds_final.fa"
    
    # Create index file for the FASTA if it does not exist
    if [ ! -f "$HAP_FILE.fai" ]; then
        samtools faidx "$HAP_FILE"
    fi
    
    # Run yahs if final output file does not exist
    if [ ! -s "$OUT_FINAL" ]; then
        $YAHS_APP -o "$OUT_PREFIX" -v 2 "$HAP_FILE" "$BAM"
    else
        echo "$OUT_FINAL already exists. Skipping yahs."
    fi
}

export -f run_yahs
export YAHS_APP BAM

# Loop through each chromosome directory and find haplotype files
find $WORKDIR/chr{1..9} $WORKDIR/chrX -name "*contigs-revised-2.fasta" | xargs -P 48 -I {} bash -c 'run_yahs "$@"' _ {}

# Wait for all background processes to finish
wait

# Sequentially perform renaming
for CHR_DIR in $WORKDIR/chr{1..9} $WORKDIR/chrX; do
    PURGE2_DIR="$CHR_DIR/purge-2"
    if [ -d "$PURGE2_DIR" ]; then
        for HAP_FILE in $PURGE2_DIR/*contigs-revised-2.fasta; do
            FILENAME=$(basename "$HAP_FILE")
            CHR=$(echo "$FILENAME" | cut -d'-' -f1)
            HAP=$(echo "$FILENAME" | cut -d'-' -f2)
            
            OUT_DIR="$PURGE2_DIR/yahs/${HAP}"
            OUT_PREFIX="$OUT_DIR/${CHR}-${HAP}"
            OUT_FINAL="${OUT_PREFIX}_scaffolds_final.fa"
            NEW_OUT_FINAL="$OUT_DIR/${CHR}-${HAP}_scaffolds_renamed.fa"
            
            if [ -s "$OUT_FINAL" ]; then
                awk -v prefix="${CHR}-${HAP}-scaffold" 'BEGIN{count=1} /^>/{print ">" prefix count++; next} 1' "$OUT_FINAL" > "$NEW_OUT_FINAL"
                echo "Renamed scaffolds in $OUT_FINAL and saved to $NEW_OUT_FINAL."
            fi
        done
    fi
done

echo "Hi-C scaffolding completed."
