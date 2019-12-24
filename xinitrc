#!/bin/sh

# X11
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# detect displays
dp1=$(xrandr -q | awk '/^DP-1/ {print $2}')
edp1=$(xrandr -q | awk '/^eDP-?1/ {print $2}')
dvi1=$(xrandr -q | awk '/^DVI-D-1/ {print $2}')

# hdmi0=$(xrandr -q | awk '/^HDMI-?0/ {print $2}')
# hdmi1=$(xrandr -q | awk '/^HDMI-?1/ {print $2}')

# titan
if [ "$hdmi0" = "connected" && "$dp1" = "connected" ]; then
  xrandr --output DP-1 --auto --left-of HDMI-0
fi

# laptop + monitor
if [ "$edp1" = "connected" ]; then
    # eDP1 / eDP-1
    edp1_id=$(xrandr -q | awk '/^eDP-?1/ {print $1}')

    if [ "$hdmi1" = "connected" ]; then
        xrandr --output HDMI1 --auto --same-as $edp1_id
        xrandr --output $edp1_id --off
    elif [ "$dp1" = "connected" ]; then
        xrandr --output DP-1 --auto --same-as $edp1_id
        xrandr --output $edp1_id --off
    fi
fi

# two monitors (HDMI/DVI)
if [ "$dvi1" = "connected" ]; then
  xrandr --output DVI-D-1 --auto --left-of HDMI-A-0
fi

# enable restart X
setxkbmap -option terminate:ctrl_alt_bksp

# fonts
#xset +fp /usr/share/fonts/local
#xset fp rehash

# load Xresources
xrdb -merge ~/.Xresources

# java tiling window manager fix
export _JAVA_AWT_WM_NONREPARENTING=1

if [ -s ~/.xmodmaprc ]; then
    xmodmap ~/.xmodmaprc
fi

# sync clipboard buffers
autocutsel -fork &

# awesome
#exec awesome >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr

# gnome
#exec gnome-session

# sway
#exec sway >> ~/.cache/sway/stdout 2>> ~/.cache/sway/stderr

# pywal
wal -R

# ssh-agent
eval $(ssh-agent)

# i3
exec i3 >> ~/.cache/i3/stdout 2>> ~/.cache/i3/stderr
