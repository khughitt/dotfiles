#
# Z shell Settings
#

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# PATH
PATH=$PATH:~/bin

# History
setopt HIST_IGNORE_DUPS

# Oh-my-zsh settings
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bira"
CASE_SENSITIVE="true"

# Plugins
plugins=(archlinux autojump git zsh-syntax-highlighting)

# Load Oh-my-zsh
source $ZSH/oh-my-zsh.sh

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

# Additional shell settings (aliases, exports)
for file in ~/.shell/{aliases,aliases_private,exports}; do
	[ -r "$file" ] && source "$file"
done
unset file

# Quick history searches (can also use ctrl + R)
function h {
    history | grep $1
}

# Banner
figlet `hostname` | lolcat

