#!/bin/bash

# NOTE: Installation and other information available at https://github.com/marschall-lab/panacus 

# Prepare the environment

source /path/to/miniforge3/etc/profile.d/conda.sh
conda activate pangenome
set -euo pipefail

# set shell variables

THREADS=

GFA=/path/to/merged.gfa
BASE=
COV="1,1,1"
QUORUM="0.01,0.06,0.9"

# Run panacus 

export RUST_LOG=info

panacus ordered-histgrowth \
-c bp  \
--groupby-haplotype  \
-l $COV \
-q $QUORUM \
-o table \
-t $THREADS \
$GFA > $BASE-ordered-abc.tsv

panacus-visualize -e -f pdf $BASE-ordered-abc.tsv > $BASE.pdf



