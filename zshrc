#
# Z shell settings
#
# start profiling zshrc
# zmodload zsh/zprof

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

source "${DOTFILES}/shell/history"

#
# Shell behavior
#

unsetopt correct_all          # disable auto correction
setopt extended_glob          # extended globstring support
setopt interactivecomments    # recognize comments
REPORTTIME=5

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
# Zinit plugins
#

zinit ice wait lucid
zinit light lukechilds/zsh-nvm

zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/pip

[[ "$OSTYPE" != darwin* ]] && zinit snippet OMZ::plugins/systemd/systemd.plugin.zsh

zinit snippet OMZ::lib/key-bindings.zsh

#
# Keybindings
#
#
bindkey '^G' edit-command-line
bindkey '^[[1;3D' backward-word  # Alt-Left
bindkey '^[[1;3C' forward-word   # Alt-Right

zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

zinit light "djui/alias-tips"
zinit light "mdumitru/fancy-ctrl-z"

zinit ice blockf
zinit light zsh-users/zsh-completions

fpath=("${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/site-functions" $fpath)

autoload -Uz compinit && compinit
zinit cdreplay -q

# zinit wait lucid for \
#     Aloxaf/fzf-tab
#     zsh-users/zsh-autosuggestions

compdef _gnu_generic snakemake

if [[ -r "${DOTFILES}/shell/local/${HOST}.zsh" ]]; then
    source "${DOTFILES}/shell/local/${HOST}.zsh"
fi

zinit wait lucid for \
    atload"fast-theme q-jmnemonic &>/dev/null" \
    zdharma-continuum/fast-syntax-highlighting

[[ -f /usr/bin/aws_zsh_completer.sh ]] && sched +0 source /usr/bin/aws_zsh_completer.sh

#
# Environment managers
#

export MAMBA_EXE="$HOME/.local/bin/micromamba"
export MAMBA_ROOT_PREFIX="$HOME/micromamba"

if [[ -x "$MAMBA_EXE" ]]; then
    __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX")" || return 1
    eval "$__mamba_setup"
    unset __mamba_setup
fi

#
# Dotfile fragments
#

shell_fragments=(aliases audio functions fzf macos ubuntu vconsole wali zoxide)
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

# vi:filetype=zsh
