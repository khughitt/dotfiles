#!/usr/bin/env bash
IGV_VERSION="2.3.32"

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/lmajor_friedlin/genome/TriTrypDB-7.0_LmajorFriedlin_Genome.fasta \
       ${REF}/lmajor_friedlin/annotation/TriTrypDB-7.0_LmajorFriedlin_genes.gff,${HOME}/Dropbox/research/data/coverage_lmajor.tdf,$*
