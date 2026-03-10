# NOTE: This will create individual FASTAs for chr1-9, and X and Y. You may like to include the X and Y in one structure; however, I did not do so.
# (This script assumes you have already concatenated your inputs to one fasta.) 

from pathlib import Path

# Input and output file paths
input_fasta = Path("/path/to/old-names.fasta")
output_dir = Path("/path/to/new-names.fasta")
output_dir.mkdir(exist_ok=True, parents=True)  # Ensure the directory exists

# Define chromosomes (X and Y will be grouped together as chrXY)
chromosomes = {f"chr{i}" for i in range(1, 10)} | {"chrXY"}

# Open file handles for each chromosome using 'with' to ensure proper closure
file_handles = {chrom: open(output_dir / f"{chrom}.fasta", "w") for chrom in chromosomes}

# Read the input FASTA and distribute sequences
current_file = None

with input_fasta.open("r") as infile:
    for line in infile:
        if line.startswith(">"):
            # Extract the chromosome part from the header
            chrom = line.strip().split("#")[-1]

            # Map chrX and chrY to chrXY
            if chrom in {"chrX", "chrY"}:
                chrom = "chrXY"

            # Get the correct file handle
            current_file = file_handles.get(chrom)

        if current_file:
            current_file.write(line)  # Write header or sequence to the correct file

# Close all file handles
for fh in file_handles.values():
    fh.close()

print(f"Chromosome FASTA files saved in '{output_dir}'")
