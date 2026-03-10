#!/bin/bash

 # Installation is straightforward: mamba create -n pangenome -c bioconda -c conda-forge pggb panacus

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate pangenome
set -euo pipefail

# Set shell variables

# NOTE: You will compute most efficiently with 1 thread for each input genotype, plus a few extra for I/O. More will not be used.

THREADS= 

IN="/path/to/in"
OUT="/path/to/out"

mkdir -p "$OUT"

# Index all .fasta files before running PGGB
# NOTE: this assumes that your input has been decomposed into one fasta per chromosome, for example with split-per-chr.py. 

for i in "$IN"/*.fasta; do
	if [[ ! -f "${i}.fai" ]]; then
		samtools faidx "$i"
	fi
done

# Run PGGB on all .fasta files

for i in "$IN"/*.fasta; do
	
	base=$(basename "$i" .fasta)
	outdir="$OUT/$base"
	
	if [[ -d "$outdir" ]]; then
		echo "Skipping $base, output already exists."
		continue
	fi

	echo "Processing $base..."
	
# NOTE: the -V flag will generate VCFs relative to the haploptype listed here, as described in https://pggb.readthedocs.io/en/latest/rst/optional_parameters.html#variant-calling
# Other flags are described in https://pggb.readthedocs.io/en/latest/rst/essential_parameters.html
	
	pggb \
		-i "$i" \
		-o "$outdir" \
		-K 50 \
		-s 100k \
		-p 95 \
		-k 100 \
		-F 10 \
		-V "SODL#2:1000" \
		-m \
		-S \
		-t $THREADS \
		-T $THREADS 

	echo "Finished $base" 
done
