# Introducion

Hello,

Here, you may find the code used to make diploid Cannabis assemblies from ultra-long ONT R9 libraries, as described in our preprint: (citation).

In re: HMW DNA, our samples were prepared from isolated nuclei, and then size-selected above 50kb on the Blue Pippin. You should also use the Blue Pippin. If you don't have access to one, there are selective precipitation kits that eliminate some short fragments. But the Blue Pippin is much more effective. 

The contigs are created with PECAT, which does haplotype-aware error correction, apparently not as well as HERRO, but without needing GPU. (If you have GPU, you should probably use HERRO first.) We include a sample config file which has comments on the optimized parameters. You will need to remove the #comment lines prior from the .cfg prior to using it. 

Once you have diploid contigs, the tricky bit is phasing them with Hi-C libraries. Here, we begin by binning psuedohaploid contigs among chromosome using a reference, and then assembling them to pseudomolecules with HapHiC. Next, dual contigs are binned among the pseudohaps to create 10 piles of contigs. Each pile is then phased, frequently to chromosome scale, with GreenHill. Greenhill advances the theory of Falcon-Phase, and also incorporates the long reads. It is also able to incorporate a typical paired-end library, but we have not done so. The paper is worth reading: https://genomebiology.biomedcentral.com/articles/10.1186/s13059-023-03006-8

However: Greenhill does not always orient contigs correctly, and also necessarily trims homologous contigs to equal length as part of its process. Therefore, the dual GreenHill scaffolds are used to again bin each chromosome's pile of dual contigs into Haplotype 1 and Haplotype 2. 

The most labor-intensive part of this process is the manually purging and reassingment of contigs, in cases where both haplotigs map to one GreenHill scaffold, or in cases where the coverage of the reference is more than 2. This process probably can and should be automated, based on some simple heuristics, but we have not yet done so. 

Next, the phased contigs are scaffolded, typically to the scale of chromosome arms, with YaHS, which appears to do a much better job of orienting contigs, and discarding duplicates, than HapHiC, 3D-DNA, or any of the other programs we tried. There is a second round of manual purging to discard scrap haplo-scaffolds.

Lastly, the YaHS scaffolds are aligned to the reference, which permits discarding scrap haplotigs, and then you must manually reverse-complement as necessary and fuse them together to make pseudomolecules.

This pipeline is not straightforward to use and I apologize for that. If you have R10 reads you're probably better off using Hifiasm or Verkko. But if you want to make dual assemblies from old R9 reads this one does work pretty good. 

# Software required

## Conda packages (recommend each in its own environment):

PECAT (https://github.com/lemene/PECAT)

Clair3 (https://github.com/HKU-BAL/Clair3)

ntEdit (https://github.com/bcgsc/ntEdit)

HapHiC (https://github.com/zengxiaofei/HapHiC)

Greenhill (https://github.com/ShunOuchi/GreenHill)


## Others:

paf2dotplot (https://github.com/moold/paf2dotplot)

YaHS (https://github.com/c-zhou/yahs)



