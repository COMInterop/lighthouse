# Purge haplotigs from primary and alternate assemblies

source /path/to/conda/conda.sh
conda activate purge-haps

mkdir -p $DIR/output/7-purge-haps

PRI=$DIR/output/6-polish/medaka/pri/b-pri-clair.fasta
ALT=$DIR/output/6-polish/medaka/alt/b-alt-clair.fasta
READS=$DIR/output/1-correct/corrected_reads.fasta

cd $DIR/output/7-purge-haps
GT=pri
mkdir $GT
cd $GT


if [ ! -f "$GT-ph.srt.bam" ]; then
    minimap2 \
    -t $THREADS \
    -K 200g \
    -2 \
    -ax map-ont \
    "$PRI" \
    "$READS" \
    --secondary=no | samtools sort -@ $THREADS -o "$DIR/output/7-purge-haps/$GT/$GT-ph.srt.bam" -
    samtools index -@ $THREADS "$DIR/output/7-purge-haps/$GT/$GT-ph.srt.bam"
fi

purge_haplotigs hist -b $GT-ph.srt.bam -g $PRI -t $THREADS


cd $DIR/output/7-purge-haps
GT=alt
mkdir $GT
cd $GT

if [ ! -f "$GT-ph.srt.bam" ]; then
    minimap2 \
    -t $THREADS \
    -K 200g \
    -2 \
    -ax map-ont \
    "$PRI" \
    "$READS" \
    --secondary=no | samtools sort -@ $THREADS -o "$DIR/output/7-purge-haps/$GT/$GT-ph.srt.bam" -
    samtools index -@ $THREADS "$DIR/output/7-purge-haps/$GT/$GT-ph.srt.bam"
fi

purge_haplotigs hist -b $GT-ph.srt.bam -g $PRI -t $THREADS

# After this step, it will be necessary to evaluate the histogram and manually pick thresholds for LO, MID, and HIGH
