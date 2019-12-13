#!/bin/env sh
#
# Polybar snakemake status helper script
#
# to ensure that snake glyph is available, make sure NotoEmoji Nerd Font is loaded
# in the polybar config, e.g.:
#
# font-4 = "NotoEmoji Nerd Font:style=Book"
#

# snakemake log directory to monitor
LOGDIR=~/d/r/nih/p3/pipeline/.snakemake/log

pgrep snakemake >/dev/null

# check if snakemake is currently running
if [[ $? -eq 0 ]]; then
    # if so, retrieve the current status from the most recently changed log
    log=$LOGDIR/$(ls -Art $LOGDIR| tail -n 1)

    # including % complete
    # status=$(grep --color=never "done$" $log | tail -n 1 | sed 's/of/\//' | sed -E 's/(steps | done)//g')

    # number of steps only
    status=$(grep --color=never "done$" $log | tail -n 1 | sed 's/of/\//' | cut -d\( -f1 | sed 's/ steps //')

    if [ "$status" = "" ]; then
        status="Initializing..."
    fi

    echo "%{u#8FFFA6}🐍[$status]"
else
    echo "%{u#ffa58f}🐍[Down]"
fi
