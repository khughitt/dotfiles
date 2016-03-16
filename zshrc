#
# Z shell Settings
#

# Check to see if zprofile has been loaded yet
if [[ $ZSHRC_LOADED = true ]]; then
    return
fi

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
    # Fix DISPLAY variables
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

# vim-r tweaks
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

# Disable auto correction
unsetopt correct_all


# Plugins
[ -z "$plugins" ] && plugins=(\
    archlinux colored-man git systemd web-search)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{aliases,functions,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# Fasd
eval "$(fasd --init auto)"
alias v='f -t -e vim -b viminfo'
alias m='f -e mplayer'
alias o='a -e xdg-open'
alias j='fasd_cd -d' 

# Suffix aliases
alias -s doc=lowriter
alias -s pdf=evince
alias -s html=chromium
alias -s org=chromium
alias -s com=chromium
alias -s Rmd=vim

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

# edit command in vim
# http://unix.stackexchange.com/questions/6620/how-to-edit-command-line-in-full-screen-editor-in-zsh
#autoload edit-command-line;
#bindkey -M vicmd v edit-command-line
#zle -N edit-command-line

# resore Cntl-R searching
#bindkey \\C-R history-incremental-search-backward

#zle -N zle-line-init
#zle -N zle-keymap-select

# re-enable moving around words with control left/right
#bindkey '^[[1;5D' emacs-backward-word
#bindkey '^[[1;5C' emacs-forward-word

# same but with alt-left/right
#bindkey "\e\e[D" backward-word
#bindkey "\e\e[C" forward-word

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

# Virtualenvwrapper
source $(which virtualenvwrapper.sh)

# PATH
PATH=~/.cabal/bin:~/software/tabulator/bin:$PATH

ZSHRC_LOADED='true'
