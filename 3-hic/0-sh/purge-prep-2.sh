#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=purge-prep-2
#SBATCH --output=purge-prep-2-log.txt

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

BASE=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort
THREADS=48

# Initialize log file

echo "Purge preparation started at $(date)"

cd $BASE || { echo "Failed to change directory to BASE: $BASE"; exit 1; }

# Extract the contigs

for DIR in chr*; do
    echo "Processing directory: $DIR"
    cd $BASE/$DIR/purge-2 || { echo "Failed to enter purge-2 directory for $DIR"; exit 1; }

    if [ ! -s "$DIR-hap0-contigs-revised-2.fasta" ]; then
        seqkit grep -f "$DIR-hap0-contigs-revised-2.txt" $BASE/$DIR/$DIR-contigs.fasta > $DIR-hap0-contigs-revised-2.fasta
        if [ $? -ne 0 ]; then
            echo "Failed to grep sequence for $DIR hap0"
            exit 1
        fi
    else
        echo "$DIR-hap0-contigs-revised-2.fasta already exists and is not empty. Skipping."
    fi

    if [ ! -s "$DIR-hap1-contigs-revised-2.fasta" ]; then
        seqkit grep -f "$DIR-hap1-contigs-revised-2.txt" $BASE/$DIR/$DIR-contigs.fasta > $DIR-hap1-contigs-revised-2.fasta
        if [ $? -ne 0 ]; then
            echo "Failed to grep sequence for $DIR hap1"
            exit 1
        fi
    else
        echo "$DIR-hap1-contigs-revised-2.fasta already exists and is not empty. Skipping."
    fi
done

echo "Contigs extraction completed at $(date)"

# Navigate to the base directory

cd "$BASE" || { echo "Failed to change directory to $BASE"; exit 1; }

# Process each chromosome directory in parallel with minimap2

for DIR in chr*; do
    for HAP in hap0 hap1; do
        (
            echo "Processing directory: $DIR/purge-2 for $HAP"
            cd "$BASE/$DIR/purge-2" || { echo "Failed to change directory to $DIR/purge-2"; exit 1; }

            CHR=$(basename "$DIR")
            REF="/data_HPC02/bpike/refs/SODLb.${CHR}.fasta"
            CONTIGS="${CHR}-${HAP}-contigs-revised-2.fasta"
            PAF=${CHR}-${HAP}-revised-2.srt.paf

            # Check if the index file exists, if not, create it

            if [ ! -f "${CONTIGS}.fai" ]; then
                samtools faidx "$CONTIGS" || { echo "Failed to index $CONTIGS"; exit 1; }
            fi

            # Check if the final scaffolds file exists

            if [ ! -s "$PAF" ]; then
                # Do the mapping

                minimap2 -x asm5 -t $THREADS -K100g -2 --secondary=no --cs --eqx "$REF" "$CONTIGS" | sort -k6,6 -k8,8n > $PAF || { echo "Failed to create PAF for $CHR $HAP"; exit 1; }
            else
                echo "$PAF already exists. Skipping minimap."
            fi
        ) &
    done
done

wait

# Process each PAF file with paf2dotplot

for DIR in chr*; do
    for HAP in hap0 hap1; do
        echo "Creating dotplot for $DIR/$HAP"
        cd "$BASE/$DIR/purge-2" || { echo "Failed to change directory to $DIR/purge-2"; exit 1; }
        CHR=$(basename "$DIR")
        PAF=${CHR}-${HAP}-revised-2.srt.paf
        PDF=${PAF}.pdf
        if [ -s "$PAF" ]; then
            if [ ! -f "$PDF" ]; then
                /data_HPC02/bpike/apps/paf2dotplot/paf2dotplot.r -s -f $PAF || { echo "Failed to create dotplot for $PAF"; exit 1; }
            else
                echo "$PDF already exists. Skipping dotplot."
            fi
        else
            echo "$PAF does not exist. Skipping dotplot."
        fi
    done
done

echo "All processing completed at $(date)"
