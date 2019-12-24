#!/usr/bin/env sh
###############################################################################
#
# blast_bam_reads.sh
# Keith Hughitt
# 2015/12/08
#
# BLASTs a random subset of N reads from a .bam file (e.g. unmapped.bam).
#
# Usage: blash_bam_reads.sh <filepath.bam> <num_reads>
#
###############################################################################
INPUT_BAM="$1"
N="$2"

echo "Querying BLAST (nr) for $N randomly selected sequences."

samtools view ${INPUT_BAM} |\
    shuf -n ${N}      |\
    awk '{print $10}' |\
    sed 's/^/>\n/'    |\
    blastn -db nr -remote -out BLAST_results.txt

echo "Done! Saved results to BLAST_results.txt"
