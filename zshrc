#
# Z shell Settings
#

# PATH
PATH=$PATH:~/bin

# Stop here in non-interactive mode
[ -z "$PS1" ] && return

# Oh-my-zsh settings
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bira-mod"
CASE_SENSITIVE="true"

# Local settings
[ -e ~/.zshlocal ] && source ~/.zshlocal

# Check if in virtual console
if [ "$TERM" = "linux" ]; then
    vconsole=true
else
    vconsole=false
fi

# Use Xresrouces to set TTY colors
if $vconsole; then
    _SEDCMD='s/.*\*\.color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $HOME/.Xresources | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

#Terminal
#TERM=rxvt-unicode-256color

# History
setopt HIST_IGNORE_DUPS

# Plugins
[ -z "$plugins" ] && plugins=(archlinux autojump git systemd web-search)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Disable auto correction
unsetopt correct_all

# Suffix aliases
alias -s doc=lowriter
alias -s pdf=evince
alias -s html=chromium
alias -s org=chromium
alias -s com=chromium

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Additional shell settings (aliases, exports)
for file in ~/.shell/{aliases,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# Disable scroll lock
stty -ixon

# Urxvt keybindings
if [[ "${TERM}" == rxvt-* ]]
then
    source ~/.shell/key_bindings
fi

# Quick history searches (can also use ctrl + R)
function h {
    history | grep $1
}

# Syntax highlighting with less
function src {
    /usr/bin/src-hilite-lesspipe.sh "$1" | less -R
}

# Audio info (TODO: move to separate functions file)
function ai {
    artist=$(soxi $1 | grep "Artist=" | sed s/Artist=//)
    track=$(soxi $1 | grep "Title=" | sed s/Title=//)
    year=$(soxi $1 | grep "Year=" | sed s/Year=//)

    bpm=$(sox $1 -t raw -r 44100 -e float -c 1 - 2> /dev/null | bpm)

    printf "%s - %s (%s) bpm: %s\n" $artist $track $year $bpm
}

# Hostname
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 26
fi

