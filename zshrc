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
        tmux attach-session -t $SESSION_NAME
    else
        tmux new-session -s $SESSION_NAME
    fi
}

# Automatically launch tmux when connecting via SSH
if [[ "$TERM" != (screen|tmux)-* ]] && [ ! -z "$SSH_CLIENT" ]; then
    # Attempt to discover a detached session and attach  it, else create a new session
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

# Use Xresrouces to set TTY colors for virtual console sessions
if $vconsole; then
    COLORFILE=$(grep --color='never' -o "/.*termcolors/[a-z1-9\-]*" $HOME/.Xresources)
    _SEDCMD='s/.*\*color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $COLORFILE | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

# History
setopt HIST_IGNORE_DUPS

# Disable auto correction
unsetopt correct_all

# Extended globstring support
setopt extended_glob

# Plugins
[ -z "$plugins" ] && plugins=(\
    fasd archlinux colored-man git biozsh sudo systemd web-search)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{aliases,functions,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# Fasd
alias o='a -e xdg-open'
alias j='fasd_cd -d' 
alias v='f -e nvim'

# Suffix aliases
alias -s doc=lowriter
alias -s pdf=zathura
alias -s html=chromium
alias -s org=chromium
alias -s com=chromium
alias -s Rmd=vim

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Disable scroll lock
stty -ixon

# vi-mode key bindings
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

# urxvt keybindings
if [[ "${TERM}" == rxvt-* ]]
then
    source ~/.shell/urxvt
fi

# dir colors
eval $(dircolors -b ~/.dir_colors)

# hostname
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

# local settings (late settings)
if [ -e ~/.zsh_local_late ]; then
    source ~/.zsh_local_late
fi

function ztabview() {
    zcat $1 | tabview -
}

ZSHRC_LOADED='true'

# Anaconda
__conda_setup="$(CONDA_REPORT_ERRORS=false '$HOME/anaconda3/bin/conda' shell.bash hook 2> /dev/null)"
if [ $? -eq 0 ]; then
    \eval "$__conda_setup"
else
    if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/anaconda3/etc/profile.d/conda.sh"
        CONDA_CHANGEPS1=false conda activate base
    else
        \export PATH="$HOME/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup

# Map caps lock to <Esc>
xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'

# fzf
if [ -e /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
    source /usr/share/fzf/completion.zsh
fi

# Torch
#if [ -e ~/torch/install/bin/torch-activate ]; then
#    source ~/torch/install/bin/torch-activate
#fi

# sync primary / clipboard buffers
#autocutsel -fork &
#autocutsel -selection PRIMARY -fork &

