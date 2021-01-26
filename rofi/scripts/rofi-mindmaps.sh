#!/bin/zsh
#
# rofi mindmap launcher
# kh (jan 2021)
#
MMDIR="/home/keith/d/mindmaps"

cd $MMDIR

if [ -z $@ ]; then
    fd -e mm
else
    target=`fd -e mm | grep --color='none' "$@"`

    if [ -f "$target" ]; then
        coproc freeplane $target > /dev/null
    fi
fi
