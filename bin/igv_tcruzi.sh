#!/usr/bin/env bash
IGV_VERSION="2.3.47"

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/tcruzi_clbrener_esmeraldo-like/genome/TriTrypDB-27_TcruziCLBrenerEsmeraldo-like_Genome.fasta \
       ${REF}/tcruzi_clbrener_esmeraldo-like/annotation/TriTrypDB-27_TcruziCLBrenerEsmeraldo-like.gff,$*
