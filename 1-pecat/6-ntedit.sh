#!/bin/bash

#SBATCH --partition=$PARTITION
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$THREADS
#SBATCH --job-name=ntedit
#SBATCH --output=%x.txt

# Activate ntedit
ulimit -u 8096
source /path/to/conda/conda.sh
conda activate ntedit

# Set shell variables

THREADS=$THREADS
WD=$DIR/output/8-polish/pri-alt/ntedit
REF0=$DIR/output/8-polish/pri-alt/clair3-ilmn-2/b-pri-alt-clair3-ilmn-2.fa
K40=/path/to/kmers/ntedit/$NAME_k40.bf
K26=/path/to/kmers/ntedit/$NAME_k26.bf
REF1=40_edited.fa
REF2=40-26_edited.fa
REF3=40-26-40_edited.fa
REF4=40-26-40-26_edited.fa
OUT=ntedit.fasta

YAK=/path/to/kmers/yak/lh-b-21.yak

mkdir -p $WD
cd $WD

# run ntEdit
# NOTE: we used ntEdit v1.4.3, which has been superseded by v2.1.1, which uses different syntax. 
# In particular v2.1.1 does not require precalculating the kmer databases. We imagine, but cannot confirm, that v2.1.1 is preferred.

# count the kmers

READS=/path/to/reads/trim-clean-pe150.fq
K=40
nthits -b 36 -k $K -t $THREADS -p $NAME --outbloom --solid $READS
K=26
nthits -b 36 -k $K -t $THREADS -p $NAME --outbloom --solid $READS

# Do the polish

ln -s $REF0 .

ntedit -f $REF0 -r $K40 -b 40 -t $THREADS
ntedit -f $REF1 -r $K26 -b 40-26 -t $THREADS
ntedit -f $REF2 -r $K40 -b 40-26-40 -t $THREADS
ntedit -f $REF3 -r $K26 -b 40-26-40-26 -t $THREADS

cp $REF4 $OUT

# Estimate QV with yak

yak qv -t $THREADS -p -K 3.2g -l 100k $YAK $REF1 > $(basename $REF1).yak-21.txt
yak qv -t $THREADS -p -K 3.2g -l 100k $YAK $REF2 > $(basename $REF2).yak-21.txt
yak qv -t $THREADS -p -K 3.2g -l 100k $YAK $REF3 > $(basename $REF3).yak-21.txt
yak qv -t $THREADS -p -K 3.2g -l 100k $YAK $REF4 > $(basename $REF4).yak-21.txt

