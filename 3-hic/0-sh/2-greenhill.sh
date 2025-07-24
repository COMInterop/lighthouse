#!/bin/bash

#SBATCH --partition=
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=
#SBATCH --job-name=2-greenhill
#SBATCH --output=%x.txt

# Define the base directory where the chromosome folders are located
BASE_DIR="$DIR/output/9-hic/2-sort"

# Source conda and activate the environment
source /path/to/conda/conda.sh
conda activate greenhill

# Navigate to the base directory
cd "$BASE_DIR"

# Export BASE_DIR to be available in the subshell
export BASE_DIR

# Use xargs to run commands in each chromosome directory in parallel
find "$BASE_DIR" -maxdepth 1 -type d -name 'chr*' -print0 | xargs -0 -I {} -P 10 bash -c '
  echo "Processing directory: {}"
  cd "{}"
  
  # Construct file names based on directory name
  CHR_NAME=$(basename "{}")
  CONTIGS_FILE="${CHR_NAME}-contigs.fasta"
  ONT_FILE="${CHR_NAME}-ont.fasta"
  HIC_FILE="${CHR_NAME}-hic.repaired.fastq"
  OUT="pr"
  
  # Execute the greenhill command and redirect output to a file
  mkdir -p gh 
  cd gh
  greenhill \
    -cph "../$CONTIGS_FILE" \
    -p "../$ONT_FILE" \
    -hic "../$HIC_FILE" \
    -mapper "minimap2 -k19 -w30 -K100g -2" \
    -t 16 \
    -o "$CHR_NAME-$OUT" \
    2>&1 | tee "${CHR_NAME}-${OUT}.txt"
    
  GH="${CHR_NAME}-${OUT}_afterPhase.fa"
  
  # Check if GH file exists before proceeding
  if [[ ! -f "$GH" ]]; then
    echo "File $GH not found! Exiting."
    exit 1
  fi
  
  # Run stats.sh and save the output
  bash stats.sh -Xmx22g "$GH" > "${CHR_NAME}-${OUT}_afterPhase.stats.txt"
  
  # Make a dotplot
  seqkit grep -p $REF_${CHR_NAME} $REFERENCE.fasta > $REF-${CHR_NAME}.fasta
  REF=PR-${CHR_NAME}.fasta
  QUERY="$GH"
  minimap2 -cx asm5 -t 16 -K 100g --cs --eqx $REF $QUERY | sort -k6,6 -k8,8n > pr-"$CHR_NAME-$OUT.paf"
  /path/to/paf2dotplot/paf2dotplot.r -s pr-"$CHR_NAME-$OUT.paf" -f
  
  # Extract haplotypes
  grep "hap0" "$GH" | sed "s/^>//" > hap0_headers.txt
  grep "hap1" "$GH" | sed "s/^>//" > hap1_headers.txt
  seqkit grep -f hap0_headers.txt "$GH" > "$CHR_NAME-hap0.fasta"
  seqkit grep -f hap1_headers.txt "$GH" > "$CHR_NAME-hap1.fasta"
' _ {}
