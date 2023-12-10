#
# Z shell Settings
#
# start profiling zshrc
# zmodload zsh/zprof 
#

# dotfiles home
export DOTFILES=$(dirname `readlink -f "${(%):-%x}"`)

# stop here in non-interactive mode
[ -z "$PS1" ] && return

# load zinit
source ~/.zinit/bin/zinit.zsh

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

# additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{fasd,aliases,audio,functions,nodes,private/*,exports,vconsole,video}; do
    [ -r "$file" ] && source "$file"
done

# nnn
for file in $DOTFILES/nnn/*.zsh; do
    [ -r "$file" ] && source "$file"
done
unset file

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# disable scroll lock
stty -ixon

# termite dynamic titles
if [[ $TERM == xterm-termite ]]; then
  . /etc/profile.d/vte.sh
fi

# local settings (late)
if [ -e ~/.zsh_local_late ]; then
   source ~/.zsh_local_late
fi

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
zinit light lukechilds/zsh-nvm

zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/systemd/systemd.plugin.zsh
zinit snippet OMZ::plugins/taskwarrior/taskwarrior.plugin.zsh
zinit snippet OMZ::plugins/pip
zinit snippet OMZ::plugins/poetry

# vi mode improvement
#zinit snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh

# emacs mode improvements
zinit snippet OMZ::lib/key-bindings.zsh

# oh-my-zsh completions
zinit ice as"completion"
zinit snippet OMZ::plugins/fd/_fd
#zinit ice as"completion"
#zinit snippet OMZ::plugins/pip/_pip
zinit ice as"completion"
zinit snippet https://github.com/esc/conda-zsh-completion/blob/master/_conda 

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

# fzf
export FZF_DEFAULT_COMMAND="fd --type file --color=never"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [[ ! "$DISABLE_FZF_AUTO_COMPLETION" == "true" ]]; then
    [[ $- == *i* ]] && source "~/.fzf/shell/completion.zsh" 2> /dev/null
fi

# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# location of additional zsh completions
fpath+=$DOTFILES/zsh/

# pure prompt
fpath+=$HOME/.zsh/pure

# tab completion
autoload -Uz compinit && compinit
zinit cdreplay -q 

# snakemake tab completion support
compdef _gnu_generic snakemake mindful

# pywal
# (/bin/cat ~/.cache/wal/sequences &)
# if [ -e "${HOME}/.cache/wal/colors.sh" ]; then
#     source "${HOME}/.cache/wal/colors.sh"
# fi

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

# autocomplete commands with --help flags
#source <(cod init $$ zsh)

#
# custom zsh keybindings;
# should come near end of config to avoid being overwritten
# 
zle -N notes
bindkey "^N" notes

# directory-specific command history
# https://github.com/natethinks/jog
function zshaddhistory() {
	echo "${1%%$'\n'}|${PWD}   " >> ~/.zsh_history_ext
}

# print greeting
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/conda/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
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

if [ -f "/mnt/ssd2/conda/etc/profile.d/mamba.sh" ]; then
    . "/mnt/ssd2/conda/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
