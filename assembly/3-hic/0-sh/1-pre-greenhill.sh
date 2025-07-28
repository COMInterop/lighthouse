
#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=1-pre-greenhill
#SBATCH --output=%x.txt

THREADS=168

ulimit -u 8192
source /path/to/conda.sh
conda activate base

# Set file paths for the reference genome and reads

REF=$DIR/output/3-assemble/chromos-SODLb/3-scaf/pri-alt-haphic.fasta
DRAFT=$DIR/output/8-polish/pri-alt/ntedit/ntedit.fasta
PAIR=pri-pri-alt

# BEGIN 1-CTG-DIP-SORT

echo -e "\n1-CTG-DIP-SORT\n"

# Set base directory

BASE_DIR=$DIR/output/9-hic
mkdir -p $BASE_DIR/1-map/ctg
cd $BASE_DIR/1-map/ctg

# Define PAF output

PAF_FILE="$PAIR.srt.paf"

# Map and sort

if [ ! -f "$PAF_FILE" ]; then
    minimap2 -cx asm5 -t $THREADS -K100g --secondary=no --cs --eqx "$REF" "$DRAFT" | sort -k6,6 -k8,8n > "$PAF_FILE"
    echo "Minimap2 has made the PAF: $PAF_FILE."
    /apps/bpike/paf2dotplot/paf2dotplot.r -f -s "$PAF_FILE"
    echo "Dotplot drafted."
else
    echo "PAF file already exists: $PAF_FILE. Skipping Minimap2 step."
fi

# Proceed to scoring

if [ ! -f "$PAF_FILE" ] || [ ! -r "$PAF_FILE" ]; then
    echo "Error: PAF does not exist or cannot be read."
    exit 1
fi

# Define output filename based on the input filename

OUTPUT_FILE="$(basename "$PAF_FILE" .paf).max-align.tsv"

# Parse the PAF file and extract contig-to-chromosome mappings with sum of alignments

if [ ! -f "$OUTPUT_FILE" ]; then
    TMP_FILE=$(mktemp)
    awk -v OFS='\t' '{
        contig_name = $1;
        chr_name = $6;
        align_length = $11;
        query_length = $2;  # Extracting query length which is the length of the contig
        align_sum[contig_name, chr_name] += align_length;
        query_len[contig_name] = query_length;  # Assuming query length is the same for all alignments of the contig
    } END {
        for (key in align_sum) {
            split(key, indices, SUBSEP);
            contig_name = indices[1];
            chr_name = indices[2];
            if (!(contig_name in max_sum) || align_sum[key] > max_sum[contig_name]) {
                max_sum[contig_name] = align_sum[key];
                chr_mapping[contig_name] = chr_name;
                max_query_len[contig_name] = query_len[contig_name];  # Store the max query length for the best hit
            }
        }
        for (contig in chr_mapping) {
            # Calculating the fraction of the query contained in the summed alignment
            fraction = max_sum[contig] / max_query_len[contig];
            print contig, chr_mapping[contig], max_sum[contig], max_query_len[contig], fraction;
        }
    }' "$PAF_FILE" > "$TMP_FILE"

    sort -k2,2 "$TMP_FILE" > "$OUTPUT_FILE"
    rm "$TMP_FILE"
    echo "Alignment summaries written to $OUTPUT_FILE"
else
    echo "Output file already exists: $OUTPUT_FILE. Skipping awk processing step."
fi

# Create .txt files for each chromosome with corresponding contigs

while IFS=$'\t' read -r contig chr _; do
    echo "$contig" >> "${chr}.txt"
done < "$OUTPUT_FILE"
echo "Contigs have been written to respective chromosome lists."

# Proceed to sort the contigs

mkdir -p $BASE_DIR/2-sort

# Extract contigs from $DRAFT into separate folders based on the .txt files

for txt_file in $BASE_DIR/1-map/ctg/*.txt; do

    chr_name="chr$(basename "$txt_file" | grep -o '[0-9X]' | head -n1)"
    output_fasta="$BASE_DIR/2-sort/$chr_name/${chr_name}-contigs.fasta"
    contig_check="$BASE_DIR/2-sort/$chr_name/${chr_name}-contig-check.txt"
    contig_errors="$BASE_DIR/2-sort/$chr_name/${chr_name}-contig-errors.txt"

    mkdir -p "$BASE_DIR/2-sort/$chr_name"

    if [ ! -f "$output_fasta" ]; then
        seqkit grep -f "$txt_file" "$DRAFT" -o "$output_fasta"
        echo "Contigs from $txt_file have been extracted to $output_fasta"
    else
        echo "$output_fasta already exists. Skipping seqkit grep."
    fi

    grep ">" "$output_fasta" | sed 's/^>//' | cut -d ' ' -f 1 > "$contig_check"
    sort "$contig_check" "$txt_file" | uniq -u > "$contig_errors"

    if [ -s "$contig_errors" ]; then
        echo "Discrepancies found for $chr_name. See $contig_errors for details."
    else
        echo "No discrepancies found for $chr_name."
        rm "$contig_errors"
    fi

done


echo "Extraction and error checking complete."

# BEGIN 2-HIC-DIP-MAP

echo -e "\nBEGIN 2-HIC-DIP-MAP\n"

# Set mapping variables

DRAFT=$DIR/output/8-polish/pri-alt/ntedit/ntedit.fasta
R1=/path/to/hic-r1.fastq
R2=/path/to/hic-r2.fastq
GT=pri-alt

# Conditionally index the $DRAFT

if [ ! -f "$DRAFT.ann" ]; then
    bwa-mem2 index $DRAFT
else
    echo "Reference annotation file $DRAFT.ann already exists. Skipping indexing and alignment."
fi

# Set base directory

BASE_DIR=$DIR/output/9-hic
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


#BEGIN 4-ONT-DIP-MAP

echo -e "\nBEGIN 4-ONT-DIP-MAP\n"

# Set mapping variables

DRAFT=$DIR/output/8-polish/pri-alt/ntedit/ntedit.fasta
READS=$DIR/output/1-correct/corrected_reads.fasta

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
            bash reformat.sh in="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.bam" out="${OUTPUT_DIR}/${CHR_NAME}/${CONTIG}-ont.fasta" overwrite=true ref=$REF -Xmx40g

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
