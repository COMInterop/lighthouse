#!/bin/bash
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=repair-hic
#SBATCH --output=repair-hic-log.txt

# Load necessary modules or activate the conda environment
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Set variables
OUTPUT_DIR="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-new/2-sort"

# Loop through each FASTQ file
for FASTQ in ${OUTPUT_DIR}/chr*/chr*-hic.fastq; do
    # Extract the first 4 characters of the basename to use as CHR_NAME
    CHR_NAME=$(basename ${FASTQ} .fastq | cut -c 1-4)

    # Run repair.sh on the concatenated FASTQ file
    bash repair.sh -Xmx40g in=${FASTQ} out=${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-hic.repaired.fastq
    
    # Check if repair was successful
    if [ $? -eq 0 ]; then
        echo "Successfully repaired FASTQ for ${CHR_NAME}"
        # Optionally, remove the original concatenated FASTQ file after successful repair
        rm -f ${FASTQ}
    else
        echo "Failed to repair FASTQ for ${CHR_NAME}"
    fi
done
