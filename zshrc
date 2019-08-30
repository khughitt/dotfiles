#
# Z shell Settings
#
# start profiling zshrc
# zmodload zsh/zprof 

# check to see if zprofile has been loaded yet
#if [[ $ZSHRC_LOADED = true ]]; then
#    return
#fi


# stop here in non-interactive mode
[ -z "$PS1" ] && return

# load zplugin
source ~/.zplugin/bin/zplugin.zsh

#export CASE_SENSITIVE="true"

# reduce amount of time zsh waits after escape characters
# https://www.johnhawthorn.com/2012/09/vi-escape-delays/
#export KEYTIMEOUT=1

#for dump in ~/.zcompdump(N.mh+24); do
#  compinit -u
#done

#compinit -C
#autoload -U compinit && compinit

# local settings (early)
#if [ -e ~/.zsh_local_early ]; then
#    source ~/.zsh_local_early
#fi

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

# automatically launch tmux when connecting via SSH
if [[ "$TERM" != (screen|tmux)-* ]] && [ ! -z "$SSH_CLIENT" ]; then
    # attempt to discover a detached session and attach it, else create a new session
    xumt $TMUX_SESSION
    exit
fi

# check if in virtual console
if [ "$TERM" = "linux" ]; then
    export vconsole=true
else
    export vconsole=false
fi

# use Xresrouces to set TTY colors for virtual console sessions
if $vconsole; then
    COLORFILE=$(grep --color='never' -o "/.*termcolors/[a-z1-9\-]*" $HOME/.Xresources)
    _SEDCMD='s/.*\*color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $COLORFILE | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

# history
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"

HISTSIZE=50000
SAVEHIST=10000

setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt inc_append_history     # add commands to HISTFILE as they are executed
setopt share_history          # share command history data

# disable auto correction
unsetopt correct_all

# extended globstring support
setopt extended_glob

# enter directories by name only
setopt autocd

# tab completion menu
zstyle ':completion:*' menu select=4

# lazy-load NVM
export NVM_LAZY_LOAD=true

# oh-my-zsh plugins
#[ -z "$plugins" ] && plugins=(archlinux git git-auto-status sudo systemd web-search biozsh zsh-nvm)

# snakemake tab completion support
#compdef _gnu_generic snakemake

# additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{aliases,functions,private,exports,biosyntax}; do
    [ -r "$file" ] && source "$file"
done
unset file

# fasd
export _FASD_SHELL='dash'
eval "$(fasd --init auto)"

alias o='a -e xdg-open'
alias j='fasd_cd -d' 
alias v='f -e nvim'

# git -> hub
eval "$(hub alias -s)"

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# disable scroll lock
stty -ixon

# urxvt keybindings
if [[ "${TERM}" == rxvt-* ]]
then
    source ~/.shell/urxvt
fi

# dir colors
#eval $(dircolors -b ~/.dir_colors)

# conda
__conda_setup="$("$HOME/conda/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/conda/etc/profile.d/conda.sh" ]; then
        . "$HOME/conda/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/conda/bin:$PATH"
    fi
fi
unset __conda_setup

# local settings (late)
#if [ -e ~/.zsh_local_late ]; then
#    source ~/.zsh_local_late
#fi

# map caps lock to <Esc>
#xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'

# marker;
# key bindings conflicts with fzf; disabling for now
#[[ -s "$HOME/.local/share/marker/marker.sh" ]] && source "$HOME/.local/share/marker/marker.sh"

# pyspark
#if type "pyspark" > /dev/null && [ ! -z "$CONDA_PREFIX" ]; then
#    #export SPARK_HOME="/opt/apache-spark"
#    #source ${SPARK_HOME}/conf/spark-env.sh 
#    export PYSPARK_PYTHON=${CONDA_PYTHON_EXE}
#    export PYSPARK_DRIVER_PYTHON=${CONDA_PREFIX}/bin/ipython
#    source ${CONDA_PREFIX}/lib/python3.7/site-packages/pyspark/bin/load-spark-env.sh 

#    # required for sparklyr local instances to work
#    #unset SPARK_HOME
#fi

# torch
#if [ -e ~/torch/install/bin/torch-activate ]; then
#    source ~/torch/install/bin/torch-activate
#fi

# unset lscolors (lsd handles)
#unset LSCOLORS
#unset LS_COLORS

# lscolors
#. /usr/share/LS_COLORS/dircolors.sh
#
# rvm
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# hide ruby version from ps1
function ruby_prompt_info() { echo '' }

# enable vi-mode
bindkey -v

bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

export KEYTIMEOUT=1

# fix keybindings
bindkey "^[[H" beginning-of-line
bindkey "^A"   beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^E"   end-of-line
bindkey "^[[1;3D" backward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5C" forward-word
bindkey "^[^?" backward-kill-word 

#bindkey '^[[Z' reverse-menu-complete

#
# oh-my-zsh plugins
#

# nvm
zplugin light lukechilds/zsh-nvm

zplugin snippet OMZ::lib/completion.zsh
zplugin snippet OMZ::lib/directories.zsh
zplugin snippet OMZ::lib/git.zsh
zplugin snippet OMZ::lib/grep.zsh
zplugin snippet OMZ::lib/key-bindings.zsh
zplugin snippet OMZ::lib/spectrum.zsh
zplugin snippet OMZ::lib/directories.zsh
zplugin snippet OMZ::plugins/archlinux/archlinux.plugin.zsh
zplugin snippet OMZ::plugins/git/git.plugin.zsh
zplugin snippet OMZ::plugins/rvm/rvm.plugin.zsh
zplugin snippet OMZ::plugins/sudo/sudo.plugin.zsh
zplugin snippet OMZ::plugins/systemd/systemd.plugin.zsh

# theme
zplugin ice pick"async.zsh" src"pure.zsh"; zplugin light sindresorhus/pure

# zsh autosuggestions
#zplugin light zsh-users/zsh-autosuggestions

# ls colors
zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
zplugin load trapd00r/LS_COLORS

# syntax highlighting
zplugin light zdharma/fast-syntax-highlighting
zplugin load trapd00r/zsh-syntax-highlighting-filetypes

# alias reminders
zplugin light "djui/alias-tips"

# cntl-z -> fg
zplugin light mdumitru/fancy-ctrl-z

# completions
if is-at-least 5.3; then
  zplugin ice lucid wait'0a' blockf
else
  zplugin ice blockf
fi
zplugin light zsh-users/zsh-completions

# zshmarks
zplugin light "urbainvaes/fzf-marks"

# fzf
export FZF_DEFAULT_COMMAND="fd --type file --color=always"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# location of additional zsh completions
fpath+=$HOME/d/dotfiles/zsh/

# tab completion
autoload -Uz compinit
compinit
zplugin cdreplay -q 

# print greeting
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

ZSHRC_LOADED='true'
