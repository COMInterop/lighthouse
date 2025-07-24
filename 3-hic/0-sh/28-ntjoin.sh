#!/bin/bash

#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --job-name=13-ntjoin
#SBATCH --output=13-ntjoin-log.txt

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate ntjoin

SDB=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta
PR=/data/bpike/prcp/assembly/pr-salk-chromos.fasta

BASE="/data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/3-scaf/purge-2"

# Check if BASE directory exists
if [ ! -d "$BASE" ]; then
  echo "Error: BASE directory does not exist."
  exit 1
fi

cd "$BASE" || exit

mkdir -p ntjoin

cd ntjoin || exit

for i in "$BASE"/chr*.fa; do
  ln -s "$i" .
done

# First assembly
for i in *renamed.fa; do
  QUERY=$(basename "$i" | cut -c1-9)
  CHR=$(echo "$QUERY" | cut -c4)

  QUERY_OUTPUT="${QUERY}.k56.w16000.n1.assigned.scaffolds.fa"
  PAIR="sdb-$QUERY"

  if [ ! -f "$QUERY_OUTPUT" ]; then
    echo "Doing the ntJoin assemble for $QUERY."

    ntJoin assemble \
      target="$i" \
      references="SODLb.chr${CHR}.fasta" \
      reference_weights='2' \
      k=56 \
      w=16000 \
      G=100 \
      agp=True \
      no_cut=True \
      overlap=false \
      t=5
  fi
done

for i in *.fa; do
   FILENAME=$(basename "$i")
   CHR=$(echo "$FILENAME" | cut -d'-' -f1 | cut -c4)
   HAP=$(echo "$FILENAME" | cut -d'-' -f2 | cut -c4)
   sed -i "s/>ntJoin0/>chr${CHR}-hap${HAP}/" "$i"
 done

mkdir -p assigned
mkdir -p unassigned
mkdir -p all

mv *.assigned.* assigned
mv *.unassigned.* unassigned
mv *.all.* all

cd assigned

cat *hap0* > hap0-assigned.fasta
grep ">" hap0-assigned.fasta
cat *hap1* > hap1-assigned.fasta
grep ">" hap1-assigned.fasta

REF=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta
QUERY=hap0-assigned.fasta
PAIR=sdb-hap0-assigned

minimap2 -cx asm5 -k19 -w30 -t 48 -K100g -2 --secondary=no --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -s -$PAIR.srt.paf

REF=/data_HPC02/bpike/other/sodl/SODLb-chromos.fasta
QUERY=hap1-assigned.fasta
PAIR=sdb-hap1-assigned

minimap2 -cx asm5 -k19 -w30 -t 48 -K100g -2 --secondary=no --cs --eqx "$REF" "$QUERY" | sort -k6,6 -k8,8n > $PAIR.srt.paf

/apps/bpike/paf2dotplot/paf2dotplot.r -s -$PAIR.srt.paf

