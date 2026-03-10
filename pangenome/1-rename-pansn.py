from pathlib import Path
#NOTE: this assumes you are starting with assemblies from the Salk Institute Pangenome, purged of nonchromosomal contigs, whose chromosomes are named in the form ABCa.chrN and ABCb.chrN for the two haplotypes.
# You may note I also include a clause to handle assemblies whose headers are of the form ABC_chr_n. 
# Input and output file paths
input_fasta = "/path/to/old-names.fasta"
output_fasta = "/path/to/pansn-names.fasta"

# Open the input and output files
with open(input_fasta, "r") as infile, open(output_fasta, "w") as outfile:
	for line in infile:
		if line.startswith(">"):
			# Extract the header without '>'
			header = line.strip()[1:]

			# Handle the two exception cases: CP_chr_* and PR_chr_*
			if header.startswith("CP_chr_") or header.startswith("PR_chr_"):
				sample_name, chromosome = header.split("_chr_")  # Extract sample and chromosome
				new_header = f">{sample_name}#1#chr{chromosome}\n"

			else:
				# Extract sample name and haplotype
				sample_part, chromosome = header.split(".")
				sample_name = sample_part[:-1]  # Everything except last character (a/b)
				
				# Assign haplotype correctly
				haplotype = "1" if sample_part[-1] == "a" else "2" if sample_part[-1] == "b" else "error"

				# Construct new header and replace '.' with '#'
				new_header = f">{sample_name}#{haplotype}#{chromosome}\n"

			# Write renamed header to output
			outfile.write(new_header)

			# Print renaming process
			print(f"{line.strip()} renamed to {new_header.strip()}")
		else:
			# Write sequence lines unchanged
			outfile.write(line)

print(f"Renaming complete. Output saved to {output_fasta}") 
