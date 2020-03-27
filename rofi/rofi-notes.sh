#!/bin/zsh
#
# rofi notes launcher
# kh (march 2020)
#
NOTES_DIR="/home/keith/d/notes"

if [ -z $@ ]; then
    fd -t f md $NOTES_DIR
else
    target=`fd -t f md $NOTES_DIR | grep --color='none' "$@"`

    if [ -f "$target" ]; then
        coproc termite -e "nvim $target" > /dev/null
    fi
fi
