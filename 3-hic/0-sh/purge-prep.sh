#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=170
#SBATCH --job-name=purge-prep
#SBATCH --output=purge-prep-log.txt

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate base

BASE=/data_HPC02/bpike/lh/b/drafts/pecat/25dic2023/output/9-hic/2-sort

# Initialize log file
# echo "Purge preparation started at $(date)"

# cd $BASE || { echo "Failed to change directory to BASE: $BASE"; exit 1; }

# Create new directories and process files
# for DIR in chr*; do
#     echo "Processing directory: $DIR" 

#     mkdir -p $BASE/$DIR/purge || { echo "Failed to create purge directory for $DIR"; exit 1; }

#     seqkit grep -p "SODLb.$DIR" /data_HPC02/bpike/other/sodl/SODLb.softmasked.fasta > $BASE/$DIR/purge/SODLb-$DIR.fasta
#     if [ $? -ne 0 ]; then
#         echo "Failed to grep sequence for $DIR" 
#         exit 1
#     fi

#     cd $BASE/$DIR/purge || { echo "Failed to change directory to purge for $DIR"; exit 1; }

#     ln -s ../$DIR-hap*-contigs.* . || { echo "Failed to create symlink for $DIR"; exit 1; }
	 cp $DIR-hap0-contigs.txt $DIR-hap0-contigs-revised.txt
	 cp $DIR-hap1-contigs.txt $DIR-hap1-contigs-revised.txt

#     cd $BASE || { echo "Failed to return to BASE directory"; exit 1; }

#     echo "Completed processing for $DIR" 
# done

# echo "Purge preparation completed at $(date)"


# Function to process each directory
process_directory() {
  local DIR=$1
  cd "$DIR/purge" || { echo "Failed to change directory to $DIR"; exit 1; }

  for HAP in hap0 hap1; do
    echo "Processing directory: $DIR/purge for $HAP"

    local CHR=$(basename "$DIR")
    local REF=SODLb-$CHR.fasta
    local CONTIGS="${CHR}-${HAP}-contigs.fasta"
    local OUT=$(basename "$CONTIGS" | cut -c1-9)
    local OUTDIR="$BASE/$CHR/purge"
    local LOG="$OUTDIR/$OUT-log.txt"
    local PAF=sdb-${CHR}-${HAP}.srt.paf

    # Check if the index file exists, if not, create it
    if [ ! -f "${CONTIGS}.fai" ]; then
      samtools index "$CONTIGS" || { echo "Failed to index $CONTIGS"; exit 1; }
    fi

    # Check if the final scaffolds file exists
    if [ ! -f "$PAF" ]; then
      # Do the mapping
      minimap2 -cx asm5 -t 8 -K100g -2 --cs --eqx "$REF" "$CONTIGS" | sort -k6,6 -k8,8n > $PAF || { echo "Failed to create PAF for $CHR $HAP"; exit 1; }

      /data_HPC02/bpike/apps/paf2dotplot/paf2dotplot.r -s -f $PAF || { echo "Failed to create dotplot for $PAF"; exit 1; }
    else
      echo "$PAF already exists. Skipping minimap."
    fi
  done
}

export -f process_directory
export BASE

# Navigate to the base directory
cd "$BASE" || { echo "Failed to change directory to $BASE"; exit 1; }

# Find all chromosome directories and process them in parallel
find "$BASE" -maxdepth 1 -name 'chr*' -type d | xargs -n 1 -P 20 bash -c 'process_directory "$@"' _

echo "All processing completed at $(date)"
