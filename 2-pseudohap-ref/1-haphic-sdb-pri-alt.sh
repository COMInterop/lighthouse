#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=pseudohap-haphic
#SBATCH --output=%x.txt

ulimit -u 8192
source /path/to/conda.sh

conda activate base

# Set file paths for the reference genome and reads
#NOTE: This assumes the use of SODLb (aka sdb), chromosomes only, as reference. If this is not your case please adjust the names accordingly.
REF=/path/to/SODLb-chromos.fasta
BASE_DIR=$DIR/output/3-assemble/pri-alt-chromos-sdb
DRAFT=$BASE_DIR/../pri-alt.fasta
GT=pri-alt
PAIR=sdb-$GT
THREADS=

# Set variables for Hi-C mapping
R1=/path/to/hic-r1.fastq
R2=/path/to/hic-r2.fastq

# Set working directory for contig sorting
WD=$BASE_DIR/1-map
mkdir -p $WD/ctg
cd $WD/ctg

PAF_FILE="$PAIR.srt.paf"

# Check if PAF file already exists
if [ ! -f "$PAF_FILE" ]; then
    # Run Minimap2 alignment and sort the output
    minimap2 -cx asm5 -k19 -w30 -t $THREADS -K100g --secondary=no --cs --eqx "$REF" "$DRAFT" | sort -k6,6 -k8,8n > "$PAF_FILE"
    echo "Minimap2 has made the PAF: $PAF_FILE."

    # Make the dotplot
    /path/to/paf2dotplot/paf2dotplot.r -f -s "$PAF_FILE"
    echo "Dotplot drafted."
else
    echo "PAF file already exists: $PAF_FILE. Skipping Minimap2 step."
fi

# Proceed to scoring
# Check if the file exists and is readable
if [ ! -f "$PAF_FILE" ] || [ ! -r "$PAF_FILE" ]; then
    echo "Error: PAF does not exist or cannot be read."
    exit 1
fi

# Define output filename based on the input filename
OUTPUT_FILE="$(basename "$PAF_FILE" .paf).max-align.tsv"

# Check if OUTPUT_FILE already exists
if [ ! -f "$OUTPUT_FILE" ]; then
    # Create a temporary file to store results
    TMP_FILE=$(mktemp)

    # Parse the PAF file and extract contig-to-chromosome mappings with sum of alignments
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

    # Sort by the reference chromosome (second column), remove the header, and save the output
    sort -k2,2 "$TMP_FILE" > "$OUTPUT_FILE"

    # Clean up temporary file
    rm "$TMP_FILE"
    echo "Alignment summaries written to $OUTPUT_FILE"
else
    echo "Output file already exists: $OUTPUT_FILE. Skipping awk processing step."
fi

# Create .txt files for each chromosome with corresponding contigs
while IFS=$'\t' read -r contig chr _; do
    echo "$contig" >> "${chr}.txt"
done < "$OUTPUT_FILE"

echo "Contigs have been written to respective chromosome files."

# Create the 2-sort directory
mkdir -p $BASE_DIR/2-sort

# Extract contigs from $DRAFT into separate folders based on the .txt files
# List all txt files to be parsed
echo "List of txt files to be parsed:"

ls $BASE_DIR/1-map/ctg/*.txt

for txt_file in $(ls $BASE_DIR/1-map/ctg/*.txt); do
    # Get chromosome name from the .txt file name, removing the 'PR_' prefix
    chr_name=$(basename "$txt_file" .txt | sed 's/^PR\_//')

    # Announce the chromosome name being parsed
    echo "Parsing chromosome: $chr_name"

    # Create directory for the chromosome inside 2-sort
    mkdir -p "$BASE_DIR/2-sort/$chr_name"

    # Check if the contigs file already exists
    CONTIGS_FILE="$BASE_DIR/2-sort/$chr_name/${chr_name}-contigs.fasta"
    if [ ! -f "$CONTIGS_FILE" ]; then
        # Extract contigs listed in the .txt file from $DRAFT and save to the corresponding folder
        seqkit grep -f "$txt_file" "$DRAFT" -o "$CONTIGS_FILE"
        echo "Contigs from $txt_file have been extracted to $CONTIGS_FILE"
    else
        echo "Contigs file already exists: $CONTIGS_FILE. Skipping seqkit grep step."
    fi

    # Create a list of contigs in the output FASTA
    grep ">" "$CONTIGS_FILE" | sed 's/^>//' | cut -d ' ' -f 1 > "$BASE_DIR/2-sort/$chr_name/${chr_name}_contig-check.txt"

    # Compare the contig lists and identify discrepancies
    sort "$BASE_DIR/2-sort/$chr_name/${chr_name}_contig-check.txt" "$txt_file" | uniq -u > "$BASE_DIR/2-sort/$chr_name/${chr_name}_contig-errors.txt"

    # Check if the error file is empty and provide appropriate feedback
    if [ -s "$BASE_DIR/2-sort/$chr_name/${chr_name}_contig-errors.txt" ]; then
        echo "Discrepancies found for $chr_name. See $BASE_DIR/2-sort/$chr_name/${chr_name}_contig-errors.txt for details."
    else
        echo "No discrepancies found for $chr_name."
        rm "$BASE_DIR/2-sort/$chr_name/${chr_name}_contig-errors.txt" # Remove the error file if it's empty
    fi
done

echo "Extraction and error checking complete."


# SHIFT TO HIC SORTING

#conditionally index the $REF

echo "Considering to index $DRAFT."

if [ ! -f "$DRAFT.ann" ]; then
     bwa-mem2 index $DRAFT
else
     echo "Reference annotation file $DRAFT.ann already exists. Skipping indexing and alignment."
fi

# Set base directory

DIR=$WD/hic
mkdir -p $DIR
cd $DIR

# Do the mapping

if [ ! -f "$GT-hic.bam" ]; then

bwa-mem2 mem -5SP -t $THREADS $DRAFT $R1 $R2 | samtools view - -@ $THREADS -S -h -b -F 3340 -o $GT-hic.bam

else
     echo "$GT-hic.bam already exists. Skipping bwa-mem2 mapping."
fi

# (2) Filter the alignments with MAPQ 1 (mapping quality ≥ 1) and NM 3 (edit distance < 3)

if [ ! -f "$GT-hic.haphic-flt.bam" ]; then

/apps/bpike/haphic/utils/filter_bam $GT-hic.bam 1 --nm 3 --threads $THREADS | samtools view - -b -@ $THREADS -o $GT-hic.haphic-flt.bam

else
     echo "$GT-hic.haphic-flt.bam already exists. Skipping HapHiC filtering."
fi

# Set the BAM variable

BAM=$( realpath $GT-hic.haphic-flt.bam)

if [ ! -f "$BAM" ]; then
    echo "BAM file $BAM does not exist."
    exit 1
fi

echo "BAM file set to $BAM"

# Export BAM so it's available in subshells used by xargs

export BAM

# DO THE HAPHIC

echo "Activating mamba environment..."
source /path/to/conda/conda.sh

if ! conda activate haphic; then
    echo "Failed to activate environment 'haphic'"
    exit 1
fi

# Define the command to run in each CTG directory

RUN_COMMAND() {
    local DIR_PATH="$1"
    local CHROMO=$(basename "$DIR_PATH")
    REF="${CHROMO}-contigs.fasta"

    echo "Preparing to run haphic pipeline in directory: $DIR_PATH"
    echo "Reference file: $REF"
    echo "BAM file: $BAM"

    if cd "$DIR_PATH"; then
        echo "Successfully changed directory to $DIR_PATH"
        if [[ -f "$REF" ]]; then
            if [ -f "04.build/scaffolds.agp" ]; then
                echo "scaffolds.agp file already exists, skipping haphic pipeline."
            else
                echo "Starting haphic-quickview pipeline..."
                /apps/bpike/haphic/haphic pipeline "$REF" "$BAM" 1 --quick_view --correct_nrounds 2 --threads 4 --processes 4
                if [ $? -eq 0 ]; then
                    echo "haphic-quickview pipeline completed for $REF"
                else
                    echo "haphic-quickview pipeline failed for $REF"
                    exit 1
                fi
            fi
        else
            echo "Reference file $REF does not exist in $DIR_PATH"
        fi

        # Rename scaffolds.fa to $CHROMO-haphic.fasta and move it to output directory
        RENAMED="${REF%.fasta}-haphic.fasta"

        if mv 04.build/scaffolds.fa "04.build/$RENAMED"; then
            # Process the renamed file
            awk -v basename="$RENAMED" '
            BEGIN {seq_num=1}
            /^>/ {
                new_name = basename "-" seq_num
                print ">" new_name
                print "Contig " substr($0, 2) " renamed to " new_name | "cat >&2"
                seq_num++
                next
            }
            {print}
            ' "04.build/$RENAMED" > "04.build/${RENAMED}.tmp" && mv "04.build/${RENAMED}.tmp" "04.build/$RENAMED"

            DEST=$DIR_PATH/3-scaffold/haphic-per-chr
            mkdir -p $DEST
            cp "04.build/$RENAMED" $DEST
            echo "Output copied to $DIR_PATH/haphic folder"
        else
            echo "Failed to move scaffolds.fa to $RENAMED"
            exit 1
        fi
    else
        echo "Failed to change directory to $DIR_PATH"
        exit 1
    fi
}

export -f RUN_COMMAND

# Find all CTG directories and pass each to RUN_COMMAND using xargs for parallel execution

echo "Finding CTG directories and starting parallel processing..."
find $BASE_DIR/2-sort -type d -name "*" -print0 | xargs -0 -P 10 -n 1 bash -c 'RUN_COMMAND "$@"' _

echo "All processes initiated."

# Collect the contigs, concatenate, count, and cross-validate

conda activate base

# Define the base and output directories
REF="/path/to/SODLb-chromos.fasta"
BASE_DIR="$DIR/output/3-assemble/chromos"
WD="$BASE_DIR/2-sort"
OUT="$BASE_DIR/3-scaf"
DRAFT="pri-haphic.fasta"
PAIR="sdb-$YOUR_GENOTYPE-haphic"

# Create output directory if it doesn't exist
mkdir -p "$OUT"

# Change to working directory or exit if it fails
cd "$WD" || { echo "Failed to change directory to $WD"; exit 1; }

# Loop through directories and copy the appropriate files
for DIR in chr*; do
    CHR_NAME=$(basename "$DIR")
    FILE="$DIR/04.build/${CHR_NAME}_contigs-haphic.fasta"
    
    if [ -f "$FILE" ]; then
        cp "$FILE" "$OUT"
        echo "$FILE moved to $OUT"
    else
        echo "File $FILE not found."
    fi
done

# Change to output directory or exit if it fails
cd "$OUT" || { echo "Failed to change directory to $OUT"; exit 1; }

# Concatenate all .fasta files into one draft file
if [ ! -f "$DRAFT" ]; then
    cat *.fasta > "$DRAFT"
    echo "Concatenated to $DRAFT."
else
    echo "$DRAFT already exists. Skipping concatenation step."
fi

# Run stats.sh on the concatenated draft
STATS_FILE="${DRAFT%.fasta}.stats.txt"
if [ ! -f "$STATS_FILE" ]; then
    bash stats.sh -Xmx22g "$DRAFT" > "$STATS_FILE"
    echo "$STATS_FILE calculated."
else
    echo "$STATS_FILE already exists. Skipping stats.sh step."
fi

# Run minimap2 and paf2dotplot
if [ ! -f "$PAIR.srt.paf" ]; then
    minimap2 -cx asm5 -k19 -w30 -t $THREADS -K100g --secondary=no --cs --eqx -2 "$REF" "$DRAFT" | sort -k6,6 -k8,8n > "$PAIR.srt.paf"
    echo "$DRAFT mapped to $REF to make $PAIR.srt.paf."
    /path/to/paf2dotplot/paf2dotplot.r -f -s "$PAIR.srt.paf"
    echo "Dotplot made from $PAIR.srt.paf."
else
    echo "$PAIR.srt.paf already exists. Skipping minimap2 and dotplot steps."
fi

echo "Script execution complete."
