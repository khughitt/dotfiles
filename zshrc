#
# Z shell Settings
#

# Check to see if zprofile has been loaded yet
if [[ $ZSHRC_LOADED = true ]]; then
    return
fi
#echo `date` "| zshrc" >> ~/boot_order

# Stop here in non-interactive mode
[ -z "$PS1" ] && return

# Oh-my-zsh settings
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bira"
CASE_SENSITIVE="true"

# Local settings (early settings)
if [ -e ~/.zsh_local_early ]; then
    source ~/.zsh_local_early
fi

# tmux helper function
function xumt() {
    SESSION_NAME=$(whoami)
    if [ ! -z "$1" ]; then
        SESSION_NAME="${SESSION_NAME}_$1"
    fi

    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        tmux -2 attach-session -t $SESSION_NAME
    else
        tmux -2 new-session -s $SESSION_NAME
    fi
}

# Automatically launch tmux when connecting via SSH
if [[ "$TERM" != screen* ]] && [ ! -z "$SSH_CLIENT" ]; then
    # Fix DISPLAY variableda
    # http://yubinkim.com/?p=203
    #for name in `tmux ls -F '#{session_name}'`; do
    #    tmux setenv -g -t $name DISPLAY $DISPLAY #set display for all sessions
    #done

    # Attempt to discover a detached session and attach 
    # it, else create a new session
    xumt $TMUX_SESSION

    # Exit on unattach
    exit
fi

# Check if in virtual console
if [ "$TERM" = "linux" ]; then
    export vconsole=true
else
    export vconsole=false
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

# R-vim tweaks
if [[ $(vim --version | grep -o "+clientserver") == '+clientserver' ]]; then
    alias vim='vim --servername VIM'

    if [ "$DISPLAY" != "" ]; then
        function tvim() { tmux new-session "vim --servername VIM $@" ; }
    else
        function tvim() { tmux new-session "vim $@" ; }
    fi
fi

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

# vim key bindings
# http://dougblack.io/words/zsh-vi-mode.html
#bindkey -v

#bindkey '^P' up-history
#bindkey '^N' down-history
#bindkey '^?' backward-delete-char
#bindkey '^h' backward-delete-char
#bindkey '^w' backward-kill-word
#bindkey '^r' history-incremental-search-backward

#function zle-line-init zle-keymap-select {
#    VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]%  %{$reset_color%}"
#    RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/}$(git_custom_status) $EPS1"
#    zle reset-prompt
#}

#zle -N zle-line-init
#zle -N zle-keymap-select

# re-enable moving around words with control left/right
#bindkey '^[[1;5D' emacs-backward-word
#bindkey '^[[1;5C' emacs-forward-word

# same but with alt-left/right
#bindkey "\e\e[D" backward-word
#bindkey "\e\e[C" forward-word

#
# vim like history movements
#bindkey '^k' up-history
#bindkey '^j' down-history

# Reduce lag when switching between modes
#export KEYTIMEOUT=1

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

function strip_fasta() {
    # exclude any fasta sections at end of file
    last_line=$(expr $(grep --color='never' -nr "##FASTA" $1 |\
                awk '{print $1}' FS=":") - 1)

    # grab all fields after the FASTA entries
    head -n ${last_line} ${1} >> ${1}.tmp
    mv ${1}.tmp ${1}
}

# dir colors
eval $(dircolors -b ~/.dir_colors)

# Hostname
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 16
fi

# TEMP work-around for oh-my-zsh deprecated grep options
alias grep="grep ${GREP_OPTIONS}"
unset GREP_OPTIONS

# Local settings (late settings)
if [ -e ~/.zsh_local_late ]; then
    source ~/.zsh_local_late
fi

# PATH
PATH=~/.cabal/bin:$PATH

ZSHRC_LOADED='true'

# gifify
# https://gist.github.com/SlexAxton/4989674
gifify() {
  if [[ -n "$1" ]]; then
    if [[ $2 == '--good' ]]; then
      ffmpeg -i $1 -r 10 -vcodec png out-static-%05d.png
      time convert -verbose +dither -layers Optimize -resize 600x600\> out-static*.png  GIF:- | gifsicle --colors 128 --delay=5 --loop --optimize=3 --multifile - > $1.gif
      rm out-static*.png
    else
      ffmpeg -i $1 -s 600x400 -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=3 > $1.gif
    fi
  else
    echo "proper usage: gifify <input_movie.mov>. You DO need to include extension."
  fi
}

# hstr - improved history searching
export HISTFILE=~/.zsh_history  # ensure history file visibility
export HH_CONFIG=hicolor        # get more colors
bindkey -s "\C-r" "\eqhh\n"     # bind hh to Ctrl-r (for Vi mode check doc)

