#!/bin/zsh
#
# rofi mindmap launcher
# kh (jan 2021)
#
MMDIR="$HOME/d/mindmaps"

cd $MMDIR

if [ -z $@ ]; then
    fd -e mm --exclude archive
else
    target=`fd -e mm | grep --color='none' "$@"`

    if [ -f "$target" ]; then
        target=`realpath $target`
        coproc freeplane $target > /dev/null
    fi
fi
