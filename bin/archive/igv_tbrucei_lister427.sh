#!/usr/bin/env bash
IGV_VERSION="2.3.47"
TRITRYPDB_VERSION="9.0"

export JAVA_FONTS=/usr/share/fonts/TTF
export _JAVA_AWT_WM_NONREPARENTING=1
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

export SPECIES='TbruceiLister427'

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/tbrucei_lister427/genome/TriTrypDB-${TRITRYPDB_VERSION}_${SPECIES}_Genome.fasta \
       ${REF}/tbrucei_lister427/annotation/TriTrypDB-${TRITRYPDB_VERSION}_${SPECIES}_genes.gff,$*
