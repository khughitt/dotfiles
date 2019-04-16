#!/bin/sh

# X11
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# detect monitors
edp1=$(xrandr -q | awk '/eDP1/ {print $2}')
hdmi1=$(xrandr -q | awk '/HDMI1/ {print $2}')
hdmi2=$(xrandr -q | awk '/HDMI2/ {print $2}')

# laptop + monitor
if [ "$edp1" = "connected" & "$hdmi1" = "connected" ]; then
  xrandr --output HDMI1 --auto --same-as eDP1
  xrandr --output eDP1 --off
fi

# two monitors
if [ "$hdmi2" = "connected" ]; then
  xrandr --output HDMI2 --auto --left-of HDMI1
fi

# compositing
# compton --config ~/.config/compton.conf -b

# enable restart X
setxkbmap -option terminate:ctrl_alt_bksp

# fonts
#xset +fp /usr/share/fonts/local
#xset fp rehash

# load Xresources
xrdb -merge ~/.Xresources

# map caps lock to escape
#setxkbmap -option caps:escape
#xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'
#xmodmap -e 'clear Lock' -e 'keycode 0x66 = Escape'

# java fix
export _JAVA_AWT_WM_NONREPARENTING=1

if [ -s ~/.xmodmaprc ]; then
    xmodmap ~/.xmodmaprc
fi

# sync primary/clipboard buffers
autocutsel -fork &
autocutsel -selection PRIMARY -fork &

# awesome
#exec awesome >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr

# gnome
#exec gnome-session

# i3
exec i3 >> ~/.cache/i3/stdout 2>> ~/.cache/i3/stderr

