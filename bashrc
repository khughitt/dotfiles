# shellcheck shell=bash

[[ $- == *i* ]] || return

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
export EDITOR=nvim
export PAGER='less -R'

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=100000
shopt -s histappend checkwinsize
PROMPT_COMMAND='history -a; history -n'

bind '"\e[A": history-search-backward'
bind '"\eOA": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOB": history-search-forward'

# ctrl-g -> edit command
bind '"\C-g": edit-and-execute-command'

[[ -t 0 ]] && stty -ixon

PS1='\[\e[36m\]\w\[\e[33m\]\$\[\e[0m\] '
