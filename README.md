# Introducion

Hello,

Here, you may find the code used to make diploid assemblies from ultra-long ONT R9 libraries, with Hi-C phasing and scaffolding, as described in our preprint, where we assembled 8 Cannabis haplotypes: (citation).

In re: HMW DNA, our samples were prepared from isolated nuclei, and then size-selected above 50kb on the Blue Pippin. If you don't have access to one, there are selective precipitation kits that eliminate some short fragments. But the Blue Pippin is much more effective. 

The contigs are created with PECAT, which does haplotype-aware error correction, probably not as well as HERRO, but without needing GPU. If you have GPU, you should probably try HERRO. We include a sample config file which has comments on the optimized parameters. You will need to remove the #comment lines from the .cfg prior to using it. 

Once you have diploid contigs, the tricky bit is phasing them with Hi-C libraries. Here, we begin by binning psuedohaploid contigs among chromosomes using a reference, and then assembling them to pseudomolecules with HapHiC. Next, dual contigs are binned among the pseudohaps to create 10 piles of contigs. Each pile is then phased, frequently to chromosome scale, with GreenHill. Greenhill advances the theory of Falcon-Phase, and also incorporates the long reads. It is also able to incorporate a typical paired-end library, but we have not done so. The paper is worth reading: https://genomebiology.biomedcentral.com/articles/10.1186/s13059-023-03006-8

However: Greenhill does not always orient contigs correctly, and also necessarily trims homologous contigs to equal length as part of its process. Therefore, the dual GreenHill scaffolds are used to again bin each chromosome's pile of dual contigs into Haplotype 1 and Haplotype 2. 

The most labor-intensive part of this process is the manually purging and reassingment of contigs, in cases where both haplotigs map to one GreenHill scaffold, or in cases where the coverage of the reference is more than 2. This process probably can and should be automated, based on some simple heuristics, but we have not yet done so. 

Next, the phased contigs are scaffolded, frequently to the scale of chromosome arms, with YaHS, which appears to do a much better job of orienting contigs, and discarding duplicates, than HapHiC, 3D-DNA, or any of the other programs we tried. There is a second round of manual purging to discard scrap haplo-scaffolds.

Lastly, the YaHS scaffolds are aligned to the reference, which permits discarding scrap haplotigs, and then you must manually reverse-complement as necessary and fuse them together to make pseudomolecules.

This pipeline is not straightforward to use and I apologize for that. If you have R10 reads you're probably better off using Hifiasm or Verkko. But, if you want to make dual assemblies from old R9 reads, this will get the job done. 

# Software required

## Conda packages (recommend each in its own environment):

PECAT (https://github.com/lemene/PECAT)

purge_haplotigs (https://bitbucket.org/mroachawri/purge_haplotigs/src/master/)

Clair3 (https://github.com/HKU-BAL/Clair3)

ntEdit (https://github.com/bcgsc/ntEdit)

HapHiC (https://github.com/zengxiaofei/HapHiC)

Greenhill (https://github.com/ShunOuchi/GreenHill)

You may also like to install the BBMap package (https://archive.jgi.doe.gov/data-and-tools/software-tools/bbtools/) into these environments in order to perform frequent sanity checks with its stats.sh utility. 


## Others:

paf2dotplot (https://github.com/moold/paf2dotplot)

YaHS (https://github.com/c-zhou/yahs)

# Instructions

All scripts have the placeholder $DIR to indicate the directory where PECAT runs. If you use the stock project title of 'output' in the .cfg, the numbered output folders will therefore appear in $DIR/output. PECAT inherently generates folders 1 through 6, and these scripts will add 7-purge-haps, 8-polish, 9-hic, and 10-chromos.  

## Assembling with PECAT and polishing 

These scripts are in the folder 1-pecat, and are self-explanatory. After assembling with 1-pecat.sh, purge the haplotigs from the primary and alternate assemblies with 2-purge-haps-1.sh and 3-purge-haps-2.sh. In between you will need to pick thresholds for LO, MED, and HI coverage, as described in the instructions for purge_haplotigs.

Next, you may use Clair3 to polish two times with short reads, if you have them. Scripts 4-clair3-ilmn-1.sh and 5-clair3-ilmn-2.sh are written for this purpose.

Lastly, with 6-ntedit.sh you may polish 4 times with ntEdit, using kmers derived from short reads. We use 40-mers and 26-mers, and then repeat. As noted in the script, the new version of ntEdit (v2.2.1) uses different syntax, and appears to be more advanced, but we have not tested it. 

## Making pseudohaploid reference chromosomes

This scripts are in the folder 2-pseudohap-ref. The concept is that the intermediate, unphased contigs (in PECAT's 3-assemble folder) are arranged into linkage groups after binning against a reference, in this case Sour Diesel B, from the Salk Institute Cannabis Pangenome project. Each chromosome's contigs are arranged into pseudomolecules with HapHiC, which runs 10 times, once for each chromosome, to avoid megascaffolds. This structure, which contains both the primary and alternate contigs of the initial draft, is then used to bin the dual contigs, which are shorter.

## Phasing dual contigs with GreenHill

The scripts which accomplish this task are in the 3-hic folder. They number 21, and surely could be condensed into fewer, but this arrangement helps to guarantee that each step has completed correctly before proceeding. These scripts have dummy SLURM headers that may be modified or ignored. You will need to revise each of these scripts to provide appropriate paths for your filesystem. They were all written by ChatGPT and, if you should have problems with their operation, I suggest asking ChatGPT first, as it composes and parses code much better than I do. However, if you like, I will endeavour to assist where I can. 

The pipeline requires manual evaluation at several points. After 6-newdir.sh completes, there will be a list of contigs per haplotype, to be found at ${DIR}/output/9-hic/2-sort/{CHR_NAME}/purge-1/${CHR_NAME}-${hap}-contigs-revised-1.txt. This list will be used by 7-minimap-2.sh to produce a dotplot of the contigs for each haplotype arranged to the reference chromosome. Your task, as the human, will be to view the two dotplots per chromosome, side-by-side, and decide which contigs need to be relocated from one haplotype to the other, and which contigs are scrap duplicates. These revisions will ned to be made manually to the file ${CHR_NAME}-${hap}-contigs-revised-2.txt, which provides a list of corrected contigs to 8-yahs.sh for scaffolding. With 10 chromosomes and 2 haplotypes, there will, therefore, be 20 files to be edited prior to advancing. 

This process is repeated after 14-per-chr-dotplot.sh, only in this case the edits are made directly to the ${CHR_NAME}-${hap}-contigs-revised-2.txt files. 

The remainder should be fairly self-explanatory. It is an iterative process that requires a lot of squinting at dotplots. However, if you have ultra-long libraries to start with, it is more-or-less straightforward to see which are the good contigs and which are the noise scraps. 

The result from this pipeline will be a small number of scaffolds per chromosome, sometimes as few as two, but sometimes as many as six or eight. To condense them into pseudomolecules, we arranged and concatenated them manually in Geneious Prime.



