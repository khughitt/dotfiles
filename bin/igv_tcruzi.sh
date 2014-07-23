#!/usr/bin/env bash
IGV_VERSION="2.3.34"

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/tcruzi_clbrener/genome/tc_esmer/TriTrypDB-7.0_TcruziCLBrenerEsmeraldo-like_Genome.fasta \
       ${REF}/tcruzi_clbrener/annotation/tc_esmer/TriTrypDB-7.0_TcruziCLBrenerEsmeraldo-like_genes.gff,$*
