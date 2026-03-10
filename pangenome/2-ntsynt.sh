#!/bin/bash

# NOTE: Installation and other information available at https://github.com/bcgsc/ntSynt and https://github.com/bcgsc/ntSynt-viz

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate ntsynt
set -euo pipefail

export PATH=/path/to/ntSynt-viz-1.0.0/bin:$PATH
export HOME=/path/to/tmp/snakemake_home
mkdir -p "$HOME"

# set shell variables

IN=/path/to/input
OUT=/path/to/output
NAME=
TARGET=
THREADS=

BLOCKS=ntSynt.k24.w1000.synteny_blocks.tsv
FAIS=${NAME}-FAIS.txt
INDEX=/path/to/index.tsv

mkdir -p $OUT
cd $OUT

# Run ntSynt 

if [[ ! -s "$BLOCKS" ]]; then
	ntSynt -d 5 -t "$THREADS" "$IN"/*.fasta
else
	echo "[INFO] Found $BLOCKS — skipping ntSynt."
fi

if [[ ! -s "$FAIS" ]]; then
	ls *.fai > ${NAME}-FAIS.txt
else
	echo "[INFO] Found $FAIS — skipping concatenation."
fi

# do the viz

/path/to/ntsynt_viz.py \
	--blocks $BLOCKS \
	--fais $FAIS \
	--length 1000 \
	--prefix ${NAME} \
	--name_conversion $INDEX \
	--target-genome $TARGET \
	--normalize \
	--height 50 \
	--width 30 \
	--format png \
	--scale 1e9
