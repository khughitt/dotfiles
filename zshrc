#
# Z shell Settings
#
# .zshrc config debugging switch
VERBOSE='false'

# start profiling zshrc
# zmodload zsh/zprof 

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:0

if [[ $ZSHRC_LOADED = true ]]; then
    return
fi

# check to see if zprofile has been loaded yet
if [[ $ZSHRC_LOADED = true ]]; then
    return
fi

# stop here in non-interactive mode
[ -z "$PS1" ] && return

# oh-my-zsh settings
export ZSH=$HOME/.oh-my-zsh
#export ZSH_THEME="bira"
#export DISABLE_LS_COLORS="true"
#
export CASE_SENSITIVE="true"

# additional zsh completions
fpath+=$HOME/d/dotfiles/zsh/

# reduce amount of time zsh waits after escape characters
# https://www.johnhawthorn.com/2012/09/vi-escape-delays/<Paste>
export KEYTIMEOUT=1

# load zplugin
source ~/.zplugin/bin/zplugin.zsh

# reduce frequency of zcompdump regeneration checks
# https://medium.com/@dannysmith/little-thing-2-speeding-up-zsh-f1860390f92
autoload -Uz compinit

for dump in ~/.zcompdump(N.mh+24); do
  compinit -u
done

compinit -C

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:1

# local settings (early)
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

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:2

# automatically launch tmux when connecting via SSH
if [[ "$TERM" != (screen|tmux)-* ]] && [ ! -z "$SSH_CLIENT" ]; then
    # attempt to discover a detached session and attach  it, else create a new session
    xumt $TMUX_SESSION
    exit
fi

# check if in virtual console
if [ "$TERM" = "linux" ]; then
    export vconsole=true
else
    export vconsole=false
fi

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:3

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
setopt HIST_IGNORE_DUPS

# disable auto correction
unsetopt correct_all

# extended globstring support
setopt extended_glob

# lazy-load NVM
export NVM_LAZY_LOAD=true

# oh-my-zsh plugins
[ -z "$plugins" ] && plugins=(fasd docker archlinux git git-auto-status sudo systemd web-search biozsh zsh-nvm)

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:4

# load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:5

# snakemake tab completion support
compdef _gnu_generic snakemake

# additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{aliases,functions,private,exports,biosyntax}; do
    [ -r "$file" ] && source "$file"
done
unset file

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:6

# fasd
export _FASD_SHELL='dash'

eval "$(fasd --init auto)"

alias o='a -e xdg-open'
alias j='fasd_cd -d' 
alias v='f -e nvim'

# git -> hub
eval "$(hub alias -s)"

#function v {
#    if [ -e" $1" ]; then
#       nvim $1
#    else
#       f -e nvim
#    fi
#}

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:7

# disable scroll lock
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

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:8

# local settings (late)
if [ -e ~/.zsh_local_late ]; then
    source ~/.zsh_local_late
fi

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:9

# map caps lock to <Esc>
#xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:10

# marker;
# key bindings conflicts with fzf; disabling for now
#[[ -s "$HOME/.local/share/marker/marker.sh" ]] && source "$HOME/.local/share/marker/marker.sh"

# pyspark
if type "pyspark" > /dev/null && [ ! -z "$CONDA_PREFIX" ]; then
    #export SPARK_HOME="/opt/apache-spark"
    #source ${SPARK_HOME}/conf/spark-env.sh 
    export PYSPARK_PYTHON=${CONDA_PYTHON_EXE}
    export PYSPARK_DRIVER_PYTHON=${CONDA_PREFIX}/bin/ipython
    source ${CONDA_PREFIX}/lib/python3.7/site-packages/pyspark/bin/load-spark-env.sh 

    # required for sparklyr local instances to work
    #unset SPARK_HOME
fi

# torch
#if [ -e ~/torch/install/bin/torch-activate ]; then
#    source ~/torch/install/bin/torch-activate
#fi

if [[ $VERBOSE = true ]] echo \[ $(date) \] .zshrc:11

# unset lscolors (lsd handles)
#unset LSCOLORS
#unset LS_COLORS

# lscolors
. /usr/share/LS_COLORS/dircolors.sh

ZSHRC_LOADED='true'

# stop profiling zshrc
#zprof

# zplugin
zplugin light zsh-users/zsh-autosuggestions
zplugin light zdharma/fast-syntax-highlighting
zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
zplugin load trapd00r/LS_COLORS
zplugin load trapd00r/zsh-syntax-highlighting-filetypes
zplugin ice pick"async.zsh" src"pure.zsh"; zplugin light sindresorhus/pure

# rvm
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# hide ruby version from ps1
function ruby_prompt_info() { echo '' }

# hostname
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi
