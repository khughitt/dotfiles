#!/bin/sh

# X11
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi


# monitor
external=$(xrandr -q | awk '/HDMI1/ {print $2}')
if [ "$external" = "connected" ]; then
    xrandr --output HDMI1 --auto --same-as eDP1
    xrandr --output eDP1 --off
fi

# compositing
# compton --config ~/.config/compton.conf -b

# enable restart X
setxkbmap -option terminate:ctrl_alt_bksp

# fonts
xset +fp /usr/share/fonts/local
xset fp rehash

# load Xresources
xrdb -merge ~/.Xresources

# map caps lock to escape
#setxkbmap -option caps:escape
#xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'
#xmodmap -e 'clear Lock' -e 'keycode 0x66 = Escape'

# Java fix
export _JAVA_AWT_WM_NONREPARENTING=1

if [ -s ~/.xmodmaprc ]; then
    xmodmap ~/.xmodmaprc
fi

# Awesome
exec awesome >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr
