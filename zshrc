#
# Z shell Settings
#
# start profiling zshrc
# zmodload zsh/zprof 

# dotfiles home
export DOTFILES=$(dirname `readlink -f "${(%):-%x}"`)

# stop here in non-interactive mode
[ -z "$PS1" ] && return

# load zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# local settings (early)
if [ -e ~/.zsh_local_early ]; then
   source ~/.zsh_local_early
fi

# tmux
source ~/.shell/tmux

#
# history
# 
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

# 
# general
#
unsetopt correct_all          # disable auto correction
setopt extended_glob          # extended globstring support
setopt autocd                 # enter directories by name only
setopt interactivecomments    # recognize comments

zstyle ':completion:*' menu select=4                # tab completion menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # use smart-case completion
zstyle ':completion:*' matcher-list 'r:|=*' 'l:|=* r:|=*'  # complete from middle of path

# nnn
# for file in $DOTFILES/nnn/*.zsh; do
#     [ -r "$file" ] && source "$file"
# done
# unset file

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# disable scroll lock
stty -ixon

# fix keybindings
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

bindkey "^[[H" beginning-of-line
bindkey "^A"   beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^E"   end-of-line
bindkey "^[[1;3D" backward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5C" forward-word
bindkey "^[^?" backward-kill-word 

#
# zinit
#

# nvm
zinit ice wait lucid
zinit light lukechilds/zsh-nvm

zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/systemd/systemd.plugin.zsh
zinit snippet OMZ::plugins/taskwarrior/taskwarrior.plugin.zsh
zinit snippet OMZ::plugins/pip

# fzf history search
zinit ice lucid wait'0'
zinit light joshskidmore/zsh-fzf-history-search

# vi mode improvement
#zinit snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh

# emacs mode improvements
zinit snippet OMZ::lib/key-bindings.zsh

# prompt
zinit ice pick"async.zsh" src"pure.zsh"; zinit light sindresorhus/pure

# fasd-fzf integration
zinit light "khughitt/fzf-fasd"

# ls colors 
# zinit ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
# zinit load trapd00r/LS_COLORS

# alias reminders
zinit light "djui/alias-tips"

# cntl-z <-> fg
zinit light "mdumitru/fancy-ctrl-z"

# pure prompt
fpath+=$HOME/.zsh/pure

# tab completion
autoload -Uz compinit && compinit
zinit cdreplay -q 

# snakemake tab completion support
compdef _gnu_generic snakemake

# dec24: functionality recently added to bat; waiting for version in arch repos to update..
# https://github.com/sharkdp/bat/pull/3126
# source <(bat completion zsh)

# host-specific settings
if [ -e $DOTFILES/shell/local/$HOST.zsh ]; then
    . $DOTFILES/shell/local/$HOST.zsh
fi

# remaining zinit plugins
zinit wait lucid for \
 atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions

# set fast-syntax-highlighting theme
fast-theme q-jmnemonic &> /dev/null

# directory-specific command history
# https://github.com/natethinks/jog
function zshaddhistory() {
	echo "${1%%$'\n'}|${PWD}   " >> ~/.zsh_history_ext
}

# mamba
export MAMBA_EXE="$HOME/.local/bin/micromamba";
export MAMBA_ROOT_PREFIX="$HOME/micromamba";

__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"
fi
unset __mamba_setup

# Load a few important annexes, without Turbo
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# additional shell settings (aliases, exports, etc.); keep near end to prioritize
for file in ~/.shell/{aliases,audio,exports,fasd,functions,fzf,nodes,private/*,vconsole,video,wali}; do
    [ -r "$file" ] && source "$file"
done

# local settings (late)
if [ -e ~/.zsh_local_late ]; then
   source ~/.zsh_local_late
fi

# print greeting
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

# stop profiling zshrc
# zprof 
