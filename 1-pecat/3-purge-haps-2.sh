#!/bin/bash

source /path/to/conda/conda.sh
conda activate purge-haps

#These figures were typical for our assemblies set to output 88x of corrected reads

LO=4
MED=72
HI=180

PRI=$DIR/output/6-polish/medaka/pri/b-pri-clair.fasta
ALT=$DIR/output/6-polish/medaka/alt/b-alt-clair.fasta


GT=pri

cd $DIR/output/7-purge-haps/$GT

purge_haplotigs cov -i $GT-ph.srt.bam.gencov -l $LO -m $MED -h $HI

purge_haplotigs purge \
-g $PRI \
-c coverage_stats.csv \
-t $THREADS \
-d \
-b $GT-ph.srt.bam \
-v

GT=alt

cd $DIR/output/7-purge-haps/$GT

purge_haplotigs cov -i $GT-ph.srt.bam.gencov -l $LO -m $MED -h $HI

purge_haplotigs purge \
-g $ALT \
-c coverage_stats.csv \
-t $THREADS \
-d \
-b $GT-ph.srt.bam \
-v

# This is a good sanity check if you have the BBMap package installed

bash stats.sh curated.fasta > curated.stats.txt -Xmx2g

bash curated.haplotigs.fasta > curated.haplotigs.stats.txt -Xmx2g
