#!/usr/bin/env bash
IGV_VERSION="2.3.36"

export JAVA_FONTS=/usr/share/fonts/TTF
export _JAVA_AWT_WM_NONREPARENTING=1
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/mtuberculosis/genome/mycobacterium_tuberculosis_h37rv_2_supercontigs.fasta \
       ${REF}/mtuberculosis/annotation/mycobacterium_tuberculosis_h37rv_2.gff,$*
