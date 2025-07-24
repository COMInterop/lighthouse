#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=4-gh-ctg-map-sort
#SBATCH --output=%x.txt

BASE_DIR="$DIR/output/9-hic/2-sort"
OUT="sdb"

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

export BASE_DIR OUT

cd $BASE_DIR || { echo "Failed to change directory to $BASE_DIR"; exit 1; }

# Parallelize the mapping of contigs to Greenhill scaffolds

find . -type d -name "chr*" | xargs -I{} -P $THREADS bash -c '
    DIR={}
    cd $BASE_DIR/$DIR/gh || { echo "Failed to change directory to $BASE_DIR/$DIR/gh"; exit 1; }
    CHR_NAME=$(basename "$DIR")
    REF="${CHR_NAME}-${OUT}_afterPhase.fa"
    CONTIGS="../${CHR_NAME}-contigs.fasta"
    PAIR="${CHR_NAME}-gh-pri-alt"
    PAF="${PAIR}.srt.paf"

    if [ ! -f "$PAF" ] || [ ! -s "$PAF" ]; then
        echo "Running minimap2 for $PAF"
        minimap2 -x asm5 -k19 -t16 --secondary=no --cs --eqx -K100g "$REF" "$CONTIGS" | sort -k6,6 -k8,8n > "$PAF"
        if [ $? -ne 0 ]; then
            echo "minimap2 failed for $PAF"; exit 1;
        fi
    else
        echo "PAF file $PAF already exists and is not empty, skipping minimap2."
    fi
'

# Sequential processing for sorting contigs between hap0 and hap1

for DIR in chr*; do
    cd "$BASE_DIR/$DIR/gh" || { echo "Failed to change directory to $BASE_DIR/$DIR/gh"; exit 1; }
    CHR_NAME=$(basename "$DIR")
    CONTIGS="../${CHR_NAME}-contigs.fasta"
    PAIR="${CHR_NAME}-gh-pri-alt"
    PAF="${PAIR}.srt.paf"
    TSV="${PAIR}.max-align.tsv"
    HAP0_LIST="${CHR_NAME}-hap0-contigs.txt"
    HAP1_LIST="${CHR_NAME}-hap1-contigs.txt"

    echo "Processing $PAF to create $TSV"
    awk -v OFS="\t" '
    {
        CONTIG_NAME = $1;
        CHR_NAME = $6;
        ALIGN_LENGTH = $11;
        QUERY_LENGTH = $2;
        ALIGN_SUM[CONTIG_NAME, CHR_NAME] += ALIGN_LENGTH;
        QUERY_LEN[CONTIG_NAME] = QUERY_LENGTH;
    } END {
        for (KEY in ALIGN_SUM) {
            split(KEY, INDICES, SUBSEP);
            CONTIG_NAME = INDICES[1];
            CHR_NAME = INDICES[2];
            if (!(CONTIG_NAME in MAX_SUM) || ALIGN_SUM[KEY] > MAX_SUM[CONTIG_NAME]) {
                MAX_SUM[CONTIG_NAME] = ALIGN_SUM[KEY];
                CHR_MAPPING[CONTIG_NAME] = CHR_NAME;
                MAX_QUERY_LEN[CONTIG_NAME] = QUERY_LEN[CONTIG_NAME];
            }
        }
        for (CONTIG in CHR_MAPPING) {
            FRACTION = MAX_SUM[CONTIG] / MAX_QUERY_LEN[CONTIG];
            print CONTIG, CHR_MAPPING[CONTIG], MAX_SUM[CONTIG], MAX_QUERY_LEN[CONTIG], FRACTION;
        }
    }' "$PAF" > "$TSV"
    if [ $? -ne 0 ]; then
        echo "awk processing failed for $PAF"; exit 1;
    fi
    echo "Created $TSV"

    echo "Reading $TSV to create $HAP0_LIST and $HAP1_LIST"
    while read -r line; do
        CONTIG=$(echo "$line" | cut -f1)
        SCAFFOLD=$(echo "$line" | cut -f2)
        if [[ "$SCAFFOLD" == *hap0* ]]; then
            echo "$CONTIG" >> "$HAP0_LIST"
            echo "Added $CONTIG to $HAP0_LIST"
        elif [[ "$SCAFFOLD" == *hap1* ]]; then
            echo "$CONTIG" >> "$HAP1_LIST"
            echo "Added $CONTIG to $HAP1_LIST"
        fi
    done < "$TSV"
    if [ $? -ne 0 ]; then
        echo "Reading $TSV failed"; exit 1;
    fi

    echo "Extracting contigs for $CHR_NAME"
    seqkit grep -f "$HAP0_LIST" "$CONTIGS" > "${CHR_NAME}-hap0-contigs.fasta"
    if [ $? -ne 0 ]; then
        echo "seqkit grep failed for $HAP0_LIST"; exit 1;
    fi
    echo "Created ${CHR_NAME}-hap0-contigs.fasta"

    seqkit grep -f "$HAP1_LIST" "$CONTIGS" > "${CHR_NAME}-hap1-contigs.fasta"
    if [ $? -ne 0 ]; then
        echo "seqkit grep failed for $HAP1_LIST"; exit 1;
    fi
    echo "Created ${CHR_NAME}-hap1-contigs.fasta"
done
