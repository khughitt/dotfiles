#!/usr/bin/env bash
IGV_VERSION="3.0_beta"
TRITRYPDB_VERSION="25"

export JAVA_FONTS=/usr/share/fonts/TTF
export _JAVA_AWT_WM_NONREPARENTING=1
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

java -Xmx12096m -Djava.net.preferIPv4Stack=true \
    -jar ${HOME}/software/IGV_${IGV_VERSION}/igv.jar \
    -g ${REF}/lmajor_friedlin/genome/TriTrypDB-${TRITRYPDB_VERSION}_LmajorFriedlin_Genome.fasta \
       ${REF}/lmajor_friedlin/annotation/TriTrypDB-${TRITRYPDB_VERSION}_LmajorFriedlin_plus_unannotated_orfs.gff,$*
#       ${REF}/lmajor_friedlin/annotation/TriTrypDB-7.0_LmajorFriedlin_genes.gff,${HOME}/Dropbox/research/data/coverage_lmajor.tdf,$*
