#!/usr/bin/env bash
IGV_VERSION="2.3.32"

ANNOTATIONS="${REF}/hsapiens/annotation/ensembl/release-75/Homo_sapiens.GRCh37.75.compat.sorted.gtf,${HOME}/Dropbox/research/data/coverage_human.tdf"

if [ $# -gt 0 ]; then
    ANNOTATIONS="${ANNOTATIONS},$*"
fi

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/hsapiens/genome/hg19/hg19.fasta  \
    $ANNOTATIONS
