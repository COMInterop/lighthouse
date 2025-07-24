#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=ont-prep
#SBATCH --output=ont-prep-log.txt

THREADS=48

#BEGIN 4-ONT-DIP-MAP

echo -e "\nBEGIN 4-ONT-DIP-MAP\n"

# Set mapping variables

BASE_DIR=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic
GT=b-pri-alt

DRAFT=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/8-polish/pri-alt/ntedit/lh-b-ntedit.fasta
READS=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/1-correct/corrected_reads.fasta

# Function to check command success
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Conditionally index the $REF
if [ ! -f "$DRAFT.ann" ]; then
    echo "Indexing reference file..."
    samtools faidx $DRAFT
    check_command "samtools faidx"
else
    echo "Reference annotation file $REF.ann already exists. Skipping indexing."
fi

# Set base directory

mkdir -p $BASE_DIR/1-map/ont
cd $BASE_DIR/1-map/ont || { echo "Error: Could not change directory to $DIR/1-map/ont"; exit 1; }

echo "PWD is $PWD."

# Check if the output BAM file already exists
if [ ! -f "$GT-ont.srt.bam" ]; then

    # Run minimap2 and sort the output BAM file
    echo "Mapping $READS to $DRAFT to make $GT-ont.srt.bam..."
    minimap2 -t $THREADS -K 100g -ax map-ont -k19 -w30 -2 --secondary=no $DRAFT $READS | samtools sort -@ $THREADS -o $GT-ont.srt.bam -
    
    # Check if the commands are available
    check_command "minimap2"
    check_command "samtools sort"

else
    echo "$GT-ont.srt.bam already exists. Skipping minimap2 and samtools sort."
fi

#BEGIN 5-ONT-EXTRACT

echo -e "\nBEGIN 5-ONT-EXTRACT\n"

# Set variables
BAM="$(realpath $GT-ont.srt.bam)"

CONTIG_DIR="$BASE_DIR/1-map/ctg"
OUTPUT_DIR="$BASE_DIR/2-sort"

# Check if BAM file is indexed; if not, index it
if [ ! -f "${BAM}.bai" ]; then
    echo "Indexing BAM file..."
    samtools index -@ $THREADS "${BAM}"
    if [ $? -eq 0 ]; then
        echo "Successfully indexed BAM file."
    else
        echo "Failed to index BAM file."
        exit 1
    fi
else
    echo "The ONT BAM file is already indexed."
fi

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Loop through each contig list file
for CONTIG_FILE in "${CONTIG_DIR}"/*chr*.txt; do

   
    # Extract the first part of the basename to use as CHR_NAME
	CHR_NAME=$(basename "${CONTIG_FILE}" | grep -o 'chr.')

    # Create directory for each chromosome if it doesn't exist
    mkdir -p "${OUTPUT_DIR}/${CHR_NAME}"

    # Read each contig name from the contig file and process them sequentially
    while IFS= read -r CONTIG; do

        # Extract readset for the contig 
        samtools view -@ $THREADS -b "${BAM}" "${CONTIG}" -o "${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.bam"

        # Check if extraction was successful
        if [ $? -eq 0 ]; then
            echo "Successfully extracted BAM for ${CONTIG} (${CHR_NAME})"
            
            # Convert BAM to FASTA 
            bash reformat.sh in="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.bam" out="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.fasta" overwrite=true ref=$DRAFT -Xmx40g

            if [ $? -eq 0 ]; then
                echo "Successfully converted BAM to FASTA for ${CONTIG} (${CHR_NAME})"
                echo "------------------------------------------------"
                rm -f "${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.bam"
            else
                echo "Failed to convert BAM to FASTA for ${CONTIG} (${CHR_NAME})"
            fi
        else
            echo "Failed to extract BAM for ${CONTIG} (${CHR_NAME})"
        fi
    done < "${CONTIG_FILE}"

    # Concatenate all FASTA files into one and then delete individual contig-level FASTA files
    cat "${OUTPUT_DIR}/${CHR_NAME}"/*-ont.fasta > "${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-ont.fasta"
    rm -f ${OUTPUT_DIR}/${CHR_NAME}/ctg*-ont.fasta
    echo "ONT reads successfully concatenated for ${CHR_NAME}"

done

echo "Pipeline completed successfully."
