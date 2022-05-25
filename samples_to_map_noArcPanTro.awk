#!/bin/awk -f
#This script takes the output of bcftools query -l (i.e. a list of sample IDs) and
# outputs a 3-column map for bcftools +split -S to produce per-sample VCFs.
#The regex is just to exclude the archaics and PanTro from the map.
#We want this map to do per-sample phasing with whatshap.
BEGIN{
   OFS="\t";
}
!/^Altai|Denisova|Vindija|Chagyrskaya|pan_troglodytes/{
   print $1, "-", "chr"chrom"_"$1"_unphased";
}
