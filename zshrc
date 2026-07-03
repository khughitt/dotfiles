#
# Z shell settings
#
# start profiling zshrc
# zmodload zsh/zprof

# dotfiles home
export DOTFILES=${${(%):-%x}:A:h}

# stop here in non-interactive mode
[ -z "$PS1" ] && return

#
# Bootstrap
#

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -r "${ZINIT_HOME}/zinit.zsh" ]]; then
    print -u2 "zinit is not installed at ${ZINIT_HOME}; run setup.sh"
    return 1
fi
source "${ZINIT_HOME}/zinit.zsh"

if [[ -r "${HOME}/.zsh_local_early" ]]; then
   source "${HOME}/.zsh_local_early"
fi

source "${HOME}/.shell/tmux"

#
# History
#

[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"

HISTSIZE=100000
SAVEHIST=100000

setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_verify            # show command with history expansion to user before running it
unsetopt inc_append_history   # share_history already appends incrementally
setopt share_history          # share command history data

# directory-specific command history
# https://github.com/natethinks/jog
function zshaddhistory() {
    echo "${1%%$'\n'}|${PWD}   " >> "${HOME}/.zsh_history_ext"
}

#
# Shell behavior
#

unsetopt correct_all          # disable auto correction
setopt extended_glob          # extended globstring support
setopt autocd                 # enter directories by name only
setopt interactivecomments    # recognize comments

zstyle ':completion:*' menu select=4
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# less page colors to use for man pages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;38;5;74m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[38;5;204m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

[[ -t 0 ]] && stty -ixon

#
# Keybindings
#

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
# Zinit plugins
#

zinit ice wait lucid
zinit light lukechilds/zsh-nvm

zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/pip

[[ "$(uname)" != "Darwin" ]] && zinit snippet OMZ::plugins/systemd/systemd.plugin.zsh

# vi mode improvement
# zinit snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh

zinit snippet OMZ::lib/key-bindings.zsh

zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

zinit light "djui/alias-tips"
zinit light "mdumitru/fancy-ctrl-z"

zinit ice blockf
zinit light zsh-users/zsh-completions

fpath=("${HOME}/.local/share/zsh/site-functions" $fpath)

autoload -Uz compinit && compinit
autoload -Uz bashcompinit && bashcompinit
zinit cdreplay -q

compdef _gnu_generic snakemake
(( $+commands[xan] )) && eval "$(xan completions zsh)"

if [[ -r "${DOTFILES}/shell/local/${HOST}.zsh" ]]; then
    source "${DOTFILES}/shell/local/${HOST}.zsh"
fi

zinit wait lucid for \
    atload"fast-theme q-jmnemonic &>/dev/null" \
    zdharma-continuum/fast-syntax-highlighting

[[ -f /usr/bin/aws_zsh_completer.sh ]] && sched +0 source /usr/bin/aws_zsh_completer.sh

zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

#
# Environment managers
#

export MAMBA_EXE="$HOME/.local/bin/micromamba"
export MAMBA_ROOT_PREFIX="$HOME/micromamba"

if [[ -x "$MAMBA_EXE" ]]; then
    __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__mamba_setup"
    else
        alias micromamba="$MAMBA_EXE"
    fi
    unset __mamba_setup
fi

#
# Dotfile fragments
#

shell_fragments=(aliases audio functions fzf kitty macos ubuntu vconsole wali zoxide)
for file in "${shell_fragments[@]}"; do
    [[ -r "${HOME}/.shell/${file}" ]] && source "${HOME}/.shell/${file}"
done
unset file shell_fragments

if [[ -d "${HOME}/.shell/private" ]]; then
    for file in "${HOME}/.shell/private"/*; do
        [[ -r "$file" ]] && source "$file"
    done
    unset file
fi

if [[ -r "${HOME}/.zsh_local_late" ]]; then
   source "${HOME}/.zsh_local_late"
fi

#
# Greeting
#

if [[ -t 1 && "$vconsole" = false ]] && (( $+commands[figlet] )) && (( $+commands[lolcat] )); then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

# stop profiling zshrc
# zprof

# vi:syntax=zsh
