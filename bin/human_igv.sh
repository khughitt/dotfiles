#!/usr/bin/env bash
IGV_VERSION="2.3.32"

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/hsapiens/genome/hg19.fasta  \
       ${REF}/hsapiens/annotation/ensembl/release-75/Homo_sapiens.GRCh37.75.compat.gtf,$*
