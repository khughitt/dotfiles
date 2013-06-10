#!/bin/sh

# monitor
external=$(xrandr -q | awk '/HDMI1/ {print $2}')
if [ "$external" = "connected" ]; then
    xrandr --output HDMI1 --auto
fi

# load Xresources
xrdb -merge ~/.Xresources

# compositing
compton -cGb

