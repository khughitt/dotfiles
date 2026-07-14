# Desktop, terminal, and OS integration aliases.

# bluetoothctl
alias bt='bluetoothcontrol'
alias btc='bluetoothctl connect'
alias btC='bluetoothctl devices Connected'

# feh
alias feh='feh --scale-down --auto-zoom -C /usr/share/fonts/TTF/ -e DejaVuSans/13'
alias fehd='feh -g 640x480 -d -S filename .'
alias feh_edit='gimp $(cat ~/.fehbg | /bin/grep -Eo "[\/a-z0-9]+PXL.*.png")'

# glslviewer
alias gls='glslviewer -w 1720 -h 1413'

# htop
alias htop=btop

# kitty
alias icat='kitty +kitten icat'

# journalctl
alias journalctl='journalctl -e -n 10000'
alias errors='journalctl -b -p err|less'
alias vacuum='sudo journalctl --vacuum-size=50M'

# mimetypes
alias open='mimeopen'
alias -s doc=lowriter
alias -s pdf=zathura
alias -s html=firefox
alias -s org=firefox
alias -s com=firefox
alias -s Rmd=nvim

# netstat
alias netp="sudo netstat -plant"

# sync location from one term to another
alias xp='pwd | wl-copy -p'
alias px='cd "$(wl-paste -p)"'

# wayland session
alias sx="niri-session"

# suspend
alias zzz="systemctl suspend"

# wl-copy
alias wl="wl-copy"

# yabridge
alias ya="yabridgectl"
alias yas="yabridgectl status"

# yay
alias y="yay"
alias yd="yay -Syu --devel"
