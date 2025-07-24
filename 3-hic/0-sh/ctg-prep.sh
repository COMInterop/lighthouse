#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=168
#SBATCH --job-name=turbo-1-5
#SBATCH --output=turbo-1-5.txt

THREADS=168

ulimit -u 8192
source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

# Set file paths for the reference genome and reads

REF=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/3-assemble/chromos/pri-alt-x-sdb/3-scaf/b-pri-alt-haphic.fasta
DRAFT=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/8-polish/pri-alt/ntedit/lh-b-ntedit.fasta
PAIR=pri-pri-alt

# BEGIN 1-CTG-DIP-SORT

echo -e "\n1-CTG-DIP-SORT\n"

# Set base directory

BASE_DIR=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic
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
