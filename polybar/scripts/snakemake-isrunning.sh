#!/usr/bin/env sh
#
# Polybar snakemake status helper script
#
# to ensure that snake glyph is available, make sure NotoEmoji Nerd Font is loaded
# in the polybar config, e.g.:
#
# font-4 = "NotoEmoji Nerd Font:style=Book"
#
# For recent versions of Snakemake (5.9.0+), a command-line "--log-handler-script"
# switch is now also available which could be used for more precise control, however,
# the simple logic below may be enough.
#

# snakemake log directory to monitor
# LOGDIR=~/d/r/nih/p3/pipeline/.snakemake/log
LOGDIR=~/d/r/nih/fgsea/.snakemake/log
#LOGDIR=/data/inc/biowulf/snakemake-logs

# pgrep snakemake >/dev/null

# check if snakemake is currently running
# if so, retrieve the current status from the most recently changed log
# log=$LOGDIR/$(ls -Art $LOGDIR/*.log | tail -n 1)
log=$(ls -Art $LOGDIR/*.log | tail -n 1)

# number of steps / % complete
# status=$(grep --color=never "done$" $log | tail -n 1 | sed 's/of/\//' | sed -E 's/(steps | done)//g')

# number of steps only
status=$(grep --color=never "done$" $log | tail -n 1 | sed 's/of/\//' | cut -d\( -f1 | sed 's/ steps //')

if [ "$status" = "" ]; then
    status="Initializing..."
fi

echo "%{u#8FFFA6}🐍[$status]"
