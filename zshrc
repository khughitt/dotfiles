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

# Additional shell settings (aliases, exports)
for file in ~/.shell/{aliases,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

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
[ -z "$plugins" ] && plugins=(archlinux git systemd web-search)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Autojump tab completion support
#autoload -U compinit && compinit -u

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

