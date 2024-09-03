#!/bin/zsh
#
# rofi notes launcher
# kh (march 2020)
#
NOTES_DIR="$HOME/notes"

cd $NOTES_DIR

if [ -z $@ ]; then
    fd -t f md
else
    target=`fd -t f md | grep --color='none' "$@"`

    if [ -f "$target" ]; then
        coproc termite -e "nvim $target" > /dev/null
    fi
fi
