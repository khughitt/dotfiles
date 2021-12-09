#!/bin/sh

# X11
if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# detect displays;
# note: $() subshell syntax not supported in sh
xrandrq=`xrandr -q`

dp1=`echo "$xrandrq" | awk '/^DP-1/ {print $2}'`
edp1=`echo "$xrandrq" | awk '/^eDP-?1/ {print $2}'`
dvi1=`echo "$xrandrq" | awk '/^DVI-D-1/ {print $2}'`
hdmi0=`echo "$xrandrq" | awk '/^HDMI-?0/ {print $2}'`
hdmi1=`echo "$xrandrq" | awk '/^HDMI-?1/ {print $2}'`

# large cursor
if [ "$HOSTNAME" = "titan" ]; then
    xsetroot -xcf /usr/share/icons/whiteglass/cursors/left_ptr 64
fi 

# laptop + monitor
if [ "$edp1" = "connected" ]; then
    # eDP1 / eDP-1
    edp1_id=`xrandr -q | awk '/^eDP-?1/ {print $1}'`

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

# siji font support
xset +fp /home/keith/.fonts
xset fp rehash

# load Xresources
xrdb -merge ~/.Xresources

# java tiling window manager fix
export _JAVA_AWT_WM_NONREPARENTING=1

# map caps to escape
if [ -s ~/.Xmodmap ]; then
    xmodmap ~/.Xmodmap
fi

# sync clipboard buffers
#autocutsel -fork &

# sync primary/clipboard
autocutsel -fork &
autocutsel -fork -s PRIMARY &

# fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# fcitx (kitty support)
export GLFW_IM_MODULE=ibus

# pywal
wal -R

# sway
#exec sway >> ~/.cache/sway/stdout 2>> ~/.cache/sway/stderr

# ssh-agent
eval `pkill ssh-agent && ssh-agent`

# gnome
#exec gnome-session

# i3
exec i3 >> ~/.cache/i3/stdout 2>> ~/.cache/i3/stderr
