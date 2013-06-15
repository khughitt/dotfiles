#!/bin/sh

# monitor
external=$(xrandr -q | awk '/HDMI1/ {print $2}')
if [ "$external" = "connected" ]; then
    xrandr --output HDMI1 --auto
fi

# compositing
compton -cGb

# enable restart X
setxkbmap -option terminate:ctrl_alt_bksp

# load Xresources
xrdb -merge ~/.Xresources

# Awesome
exec awesome >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr
