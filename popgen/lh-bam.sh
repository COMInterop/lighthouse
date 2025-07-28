#!/bin/bash

#SBATCH --job-name=lh-bam
#SBATCH --output=%x.txt 
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=168


# Prepare the environment

source /apps/bpike/miniforge3/etc/profile.d/conda.sh
conda activate syri


# Set shell variables

REF=/data_HPC02/bpike/refs/salk/SODLb-chromos.fasta
N0="sdb"
IN_DIR=/data_HPC02/bpike/lh/pan/assembly/labeled
DIR=/data_HPC02/bpike/lh/pan/align/lh-bam


# Decompress, process, and recompress FASTA files

#cd $IN_DIR

#pigz -d *.softmasked.fasta.gz

#for i in *.softmasked.fasta; do
#    reformat.sh in=$i out="$(basename "$i" .softmasked.fasta)-chromos.fasta" fastaminlen=10000000 overwrite=true
#    bash stats.sh "$(basename "$i" .softmasked.fasta)-chromos.fasta" > "$(basename "$i" .softmasked.fasta)-chromos.stats.txt" -Xmx22g
# done

#pigz *.fasta
 

# Create output directory and prepare REF

mkdir -p $DIR
cd $DIR

# pigz -dk $REF.gz
# samtools faidx $REF


# Define the function to process each file

function process_file {
    local Q1="$1"
    local N1=$(basename "$Q1" -chromos.fasta)

    # Check and run minimap2
    if [ ! -f "${N0}-${N1}-cs-eqx.bam" ]; then
        minimap2 -ax asm5 -w30 -t 16 -K1g --secondary=no --cs --eqx "$REF" "$Q1" | samtools view -b -o "${N0}-${N1}-cs-eqx.bam" -
        samtools sort -@ 16 "${N0}-${N1}-cs-eqx.bam" -o "${N0}-${N1}-cs-eqx.srt.bam"
        rm "${N0}-${N1}-cs-eqx.bam"
        samtools index "${N0}-${N1}-cs-eqx.srt.bam"  # Optional: Index the sorted BAM file
    else
        echo "Sorted BAM output ${N0}-${N1}-cs-eqx.srt.bam already exists; skipping."
    fi
}


export REF N0  

# Run the command with xargs, passing each file to the process_file function

ls $IN_DIR/*-labeled.fasta | \
    xargs -I {} -n 1 -P 8 bash -c "$(declare -f process_file); process_file '{}'"
   

# run minipileup

cd $DIR
#pigz -dk $REF
REF=/data_HPC02/bpike/refs/salk/SODLb-chromos.fasta
#samtools faidx $REF
/apps/bpike/minipileup/minipileup -vc -a0 -s0 -q0 -Q0 -f $REF $(ls *srt.bam) > salk-minipileup.vcf
