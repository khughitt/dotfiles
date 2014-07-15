#
# Z shell Settings
#

# Tmux on SSH
if [[ "$TERM" != "screen" ]] && [ ! -z "$SSH_CLIENT" ]; then
    # Fix DISPLAY variable
    # http://yubinkim.com/?p=203
    for name in `tmux ls -F '#{session_name}'`; do
        tmux setenv -g -t $name DISPLAY $DISPLAY #set display for all sessions
    done

    # Attempt to discover a detached session and attach 
    # it, else create a new session
    WHOAMI=$(whoami)

    if tmux has-session -t $WHOAMI 2>/dev/null; then
        tmux -2 attach-session -t $WHOAMI
    else
        tmux -2 new-session -s $WHOAMI
    fi

    # Exit on unattach
    exit
fi

# PATH
PATH=~/bin:~/.cabal/bin:$PATH

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

# R-vim tweaks
if [[ "x$DISPLAY" != "x" ]]; then
    alias vim='vim --servername VIM'
    if [[ "x$TERM" = "xrxvt-256-color" ]] || [[ "x$TERM" == "xxterm-256color" ]]
    then
        function tvim(){
            tmux -2 new-session "TERM=xterm-256color vim --servername VIM $@" ;
        }
    else
        function tvim(){
            tmux new-session "vim --servername VIM $@" ;
        }
    fi
else
    if [[ "x$TERM" == "xrxvt-256color" ]] || [[ "x$TERM" == "xxterm-256color" ]]
    then
        function tvim(){
            tmux -2 new-session "TERM=xterm-256color vim $@" ;
        }
    else
        function tvim(){
            tmux new-session "vim $@" ;
        }
    fi
fi

# Use Xresrouces to set TTY colors
if $vconsole; then
    COLORFILE=$(grep --color='never' -o "/.*termcolors/[a-z1-9\-]*" $HOME/.Xresources)
    _SEDCMD='s/.*\*color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $COLORFILE | \
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
[ -z "$plugins" ] && plugins=(\
    archlinux colored-man git systemd web-search)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Additional shell settings (aliases, exports)
for file in ~/.shell/{aliases,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# Fasd
eval "$(fasd --init auto)"
alias v='f -t -e vim -b viminfo'
alias m='f -e mplayer'
alias o='a -e xdg-open'
alias j='fasd_cd -d' 

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
    artist=$(soxi $1 | grep --color=never "Artist=" | sed s/Artist=//)
    track=$(soxi $1 | grep --color=never "Title=" | sed s/Title=//)
    year=$(soxi $1 | grep --color=never "Year=" | sed s/Year=//)

    bpm=$(sox $1 -t raw -r 44100 -e float -c 1 - 2> /dev/null | bpm)

    printf "%s - %s (%s) bpm: %s\n" $artist $track $year $bpm

    spectrogram=$(echo $1 | sed s/.mp3/_spectrogram.png/)
    sox $1 -n remix 1 spectrogram -l -t "${artist} - ${title} (${bpm})" -x 1920 -o $spectrogram
}

# Generates simplified gff files
function gff_genes() {
    # exclude any fasta sections at end of file
    last_line=$(expr $(grep --color='never' -nr "##FASTA" $1 |\
                awk '{print $1}' FS=":") - 1)
    outfile=$(basename $1 .gff)"_genes.gff"

    # grab first few comment fields
    head -n 3 $1 > $outfile

    # grab all gene fields
    head -n $last_line $1 | grep --color='never' 'gene' >> $outfile
}

# dir colors
eval $(dircolors -b ~/.dir_colors)

# Hostname
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 16
fi

