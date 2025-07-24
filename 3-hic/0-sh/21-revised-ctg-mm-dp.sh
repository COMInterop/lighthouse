#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=21-revised-ctg-mm-dp
#SBATCH --output=%x.txt

# Source conda and activate the environment
source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate base || { echo "Failed to activate conda environment"; exit 1; }

# Define the base directory
export BASE="$DIR/output/9-hic/per-chr-new/2-sort"

# Function to perform seqkit grep
perform_seqkit_grep() {
    DIR=$1
    CHR=$(basename "${DIR}")
    REVISED="${DIR}/purge"

    if [ ! -d "${REVISED}" ]; then
        echo "Directory ${REVISED} does not exist, skipping ${DIR}"
        return
    fi

    cd "${REVISED}" || { echo "Failed to change directory to ${REVISED}"; return; }

    for HAP in hap0 hap1; do
        CONTIGS_LIST="${REVISED}/${CHR}-${HAP}-contigs-revised.txt"
        OUTPUT_FASTA="${CHR}-${HAP}-contigs-revised.fasta"
        REF="../${CHR}-contigs.fasta"

        if [ ! -f "${CONTIGS_LIST}" ]; then
            echo "Contigs list ${CONTIGS_LIST} does not exist, skipping haplotype ${HAP}"
            continue
        fi

        if [ ! -s "${OUTPUT_FASTA}" ]; then
            seqkit grep -f "${CONTIGS_LIST}" "${REF}" -o "${OUTPUT_FASTA}"
            echo "Grepping ${CONTIGS_LIST}."
            if [ $? -ne 0 ]; then
                echo "Failed to execute seqkit grep for ${OUTPUT_FASTA}"
                continue
            fi
        else
            echo "Output fasta ${OUTPUT_FASTA} already exists, skipping seqkit grep"
        fi
    done
}

# Find all directories starting with "chr" and perform seqkit grep
find "${BASE}" -maxdepth 1 -type d -name 'chr*' | while read dir; do
    perform_seqkit_grep "${dir}"
done

# Function to process each directory and create minimap2 commands
process_dir() {
    DIR=$1
    CHR=$(basename "${DIR}")
    REVISED="${DIR}/purge"

    if [ ! -d "${REVISED}" ]; then
        echo "Directory ${REVISED} does not exist, skipping ${DIR}"
        return
    fi

    cd "${REVISED}" || { echo "Failed to change directory to ${REVISED}"; return; }

    for HAP in hap0 hap1; do
        OUTPUT_FASTA="${CHR}-${HAP}-contigs-revised.fasta"
        REF="${REVISED}/SODLb-${CHR}.fasta"
        PAIR="sdb-${CHR}-${HAP}-purged"
        PAF="${PAIR}.srt.paf"

        if [ -f "${PAF}" ] && [ -s "${PAF}" ]; then
            echo "PAF file ${PAF} already exists and is not empty, skipping minimap2"
        else
            echo "cd ${REVISED} && minimap2 -cx asm5 -t 48 -K100g -2 --cs --eqx ${REF} ${OUTPUT_FASTA} | sort -k6,6 -k8,8n > ${PAF}"
        fi
    done
}

# Export the function to be available in subshells
export -f process_dir

# Find all directories starting with "chr" and process them to create minimap2 commands
find "${BASE}" -maxdepth 1 -type d -name 'chr*' | while read dir; do
    process_dir "${dir}"
done | xargs -I CMD -P 10 bash -c CMD

# Function to perform paf2dotplot serially
generate_dotplots() {
    DIR=$1
    CHR=$(basename "${DIR}")
    REVISED="${DIR}/purge"

    if [ ! -d "${REVISED}" ]; then
        echo "Directory ${REVISED} does not exist, skipping ${DIR}"
        return
    fi

    cd "${REVISED}" || { echo "Failed to change directory to ${REVISED}"; return; }

    for HAP in hap0 hap1; do
        PAIR="sdb-${CHR}-${HAP}-purged"
        PAF="${PAIR}.srt.paf"
        if [ -f "${PAF}" ] && [ -s "${PAF}" ]; then
            /path/to/paf2dotplot/paf2dotplot.r -f -s "${PAF}" || { echo "Failed to execute paf2dotplot for ${PAIR}"; continue; }
        fi
    done
}

# Find all directories starting with "chr" and generate dotplots
find "${BASE}" -maxdepth 1 -type d -name 'chr*' | while read dir; do
    generate_dotplots "${dir}"
done
