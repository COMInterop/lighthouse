# can-pan
Code to build a pangenome with pggb, with parameters optimized for Cannabis sativa, whose genome is ~800Mb and 74% repeats.

# Notes
This pipeline is intended to align chromosome-scale pseudomolecules. I don't know if it will work with contigs. 

If your assemblies include scraps in addition to chromosomes, you will first want to purge them with:

seqkit seq -m 10000000 genotype.fasta > genotype-chromos.fasta
