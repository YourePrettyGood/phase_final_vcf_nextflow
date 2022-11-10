#!/bin/awk -f
#This script takes the output of bcftools query -l (i.e. a list of sample IDs) and
# a file of sample ID to batch ID correspondencies in order to output
# a 3-column map for bcftools +split -G to produce per-sample VCFs.
#We want this map to do per-sample phasing with whatshap (though multiple
# samples per job, as they are processed independently).
BEGIN{
   FS="\t";
   OFS=FS;
   #Note that the chrom input variable is required
}
#First input file is the file mapping samples to batches
FNR==NR{
   batch[$1]=$2;
}
FNR<NR{
   print $1, "-", "chr"chrom"_"batch[$1]"_unphased";
}
