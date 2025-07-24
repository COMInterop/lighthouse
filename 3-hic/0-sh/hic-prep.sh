#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=168
#SBATCH --job-name=hic-prep
#SBATCH --output=hic-prep-log.txt

THREADS=168

ulimit -u 8192
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# BEGIN 2-HIC-DIP-MAP

echo -e "\nBEGIN 2-HIC-DIP-MAP\n"

# Set mapping variables

DRAFT=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/8-polish/pri-alt/ntedit/lh-b-ntedit.fasta
R1=/data_HPC02/bpike/lh/b/fq/pe150/hic/Casat_El.Chapo_Leaf-1_220330_HiC2_230310-trim-1.fastq
R2=/data_HPC02/bpike/lh/b/fq/pe150/hic/Casat_El.Chapo_Leaf-1_220330_HiC2_230310-trim-2.fastq
GT=b-pri-alt

# Conditionally index the $DRAFT

if [ ! -f "$DRAFT.ann" ]; then
    bwa-mem2 index $DRAFT
else
    echo "Reference annotation file $DRAFT.ann already exists. Skipping indexing and alignment."
fi

# Set base directory

BASE_DIR=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic
mkdir -p $BASE_DIR/1-map/hic
cd $BASE_DIR/1-map/hic

# Do the mapping

if [ ! -f "$GT-hic.bam" ]; then

bwa-mem2 mem -5SP -t $THREADS $DRAFT $R1 $R2 | samtools view - -@ $THREADS -S -h -b -F 3340 -o $GT-hic.bam

else
    echo "$GT-hic.bam already exists. Skipping Hi-C mapping."
fi

# Filter the alignments with MAPQ 1 (mapping quality ≥ 1) and NM 3 (edit distance < 3)
# Note - this step appears to not be necessary and results might be better with the entire readset.

if [ ! -f "$GT-hic.haphic-flt.bam" ]; then
/home/bpike/haphic/utils/filter_bam $GT-hic.bam 1 --nm 3 --threads $THREADS | samtools view - -b -@ $THREADS -o $GT-hic.haphic-flt.bam
else
    echo "$GT-hic.haphic-flt.bam already exists. Skipping Hi-C filtering."
fi

# BEGIN 3-HIC-EXTRACT

echo -e "\nBEGIN 3-HIC-EXTRACT\n"

# Set variables

BAM=$(realpath "$GT-hic.haphic-flt.srt.bam")
CONTIG_DIR="$BASE_DIR/1-map/ctg"
OUTPUT_DIR="$BASE_DIR/2-sort"

# Check if BAM file exists

if [ ! -f "${BAM}" ]; then
    echo "BAM file not found: ${BAM}"
    exit 1
fi

# Check if BAM file is indexed; if not, index it

if [ ! -f "${BAM}.bai" ]; then
    echo "Indexing Hi-C BAM file..."
    samtools index -@ "$THREADS" "${BAM}"
    if [ $? -eq 0 ]; then
        echo "Successfully indexed Hi-C BAM file."
    else
        echo "Failed to index Hi-C BAM file."
        exit 1
    fi
else
    echo "The Hi-C BAM file is already indexed."
fi

# Create output directory if it doesn't exist

mkdir -p "${OUTPUT_DIR}"

# Loop through each contig list file

for CONTIG_FILE in ${CONTIG_DIR}/*chr*.txt; do

    # Extract 'chr' followed by the next character from the basename to use as CHR_NAME

    CHR_NAME=$(basename "${CONTIG_FILE}" | grep -o 'chr.')

    # Create directory for each chromosome if it doesn't exist

    mkdir -p "${OUTPUT_DIR}/${CHR_NAME}"

    # Read each contig name from the contig file and process them sequentially

    while IFS= read -r CONTIG; do

        OUTPUT_BAM="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-hic.bam"

        # Extract readset for the contig

        samtools view -@ "$THREADS" -b "${BAM}" "${CONTIG}" -o "${OUTPUT_BAM}"

        # Check if extraction was successful

        if [ $? -eq 0 ]; then
            echo "Successfully extracted BAM for ${CONTIG}"

            # Convert BAM to FASTQ

            bash reformat.sh -Xmx21g overwrite=true in="${OUTPUT_BAM}" out="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-hic.fastq" ref="${DRAFT}"

            if [ $? -eq 0 ]; then
                echo "Successfully converted BAM to FASTQ for ${CONTIG}"

                # Remove the BAM file after successfully creating the FASTQ file

                rm -f "${OUTPUT_BAM}"
            else
                echo "Failed to convert BAM to FASTQ for ${CONTIG}"
            fi
        else
            echo "Failed to extract BAM for ${CONTIG}"
        fi
    done < "${CONTIG_FILE}"

    # Concatenate all FASTQ files into one and then delete individual contig-level FASTQ files

    cat "${OUTPUT_DIR}/${CHR_NAME}"/*-hic.fastq > "${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-hic.fq"
    rm -f "${OUTPUT_DIR}/${CHR_NAME}"/*-hic.fastq
    echo "Hi-C reads successfully concatenated for ${CHR_NAME}"

    # Run repair.sh on the concatenated FASTQ file

    bash repair.sh -Xmx40g overwrite=true in="${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-hic.fq" out="${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-hic.repaired.fastq"

    # Check if repair was successful

    if [ $? -eq 0 ]; then
        echo "Successfully repaired FASTQ for ${CHR_NAME}"

        # Optionally, remove the original concatenated FASTQ file after successful repair

        rm -f "${OUTPUT_DIR}/${CHR_NAME}/${CHR_NAME}-hic.fq"
    else
        echo "Failed to repair FASTQ for ${CHR_NAME}"
    fi

done


