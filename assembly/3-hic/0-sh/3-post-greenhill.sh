#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=3-post-greenhill
#SBATCH --output=%x.txt

# Define the base directory where the chromosome folders are located

BASE_DIR="$DIR/output/9-hic/2-sort"

# Source conda and activate the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate greenhill

# Navigate to the base directory

cd "$BASE_DIR"

# Loop through each chromosome directory

for dir in "$BASE_DIR"/chr*; do
  if [ -d "$dir/gh" ]; then
    echo "Processing directory: $dir/gh"
    cd "$dir/gh"
    
    # Construct file names based on directory name

    CHR_NAME=$(basename "$dir")
    OUT="pr"
    GH="${CHR_NAME}-${OUT}_afterPhase.fa"
    
    # Extract haplotypes

    grep "hap0" "$GH" | sed 's/^>//' > $CHR_NAME-hap0-headers.txt
    grep "hap1" "$GH" | sed 's/^>//' > $CHR_NAME-hap1-headers.txt

    seqkit grep -f $CHR_NAME-hap0-headers.txt "$GH" > "$CHR_NAME-gh-hap0.fasta"
    seqkit grep -f $CHR_NAME-hap1-headers.txt "$GH" > "$CHR_NAME-gh-hap1.fasta"
  fi
done
