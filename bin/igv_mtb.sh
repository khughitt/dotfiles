#!/usr/bin/env bash
IGV_VERSION="2.3.36"

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/mtuberculosis/genome/mycobacterium_tuberculosis_h37rv_2_supercontigs.fasta \
       ${REF}/mtuberculosis/annotation/mycobacterium_tuberculosis_h37rv_2.gff,$*
