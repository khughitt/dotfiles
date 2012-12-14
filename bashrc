#
# Bash configuration
#

# PATH
export PATH=$HOME/bin:$PATH

# If not running interactively, don't do anything
# [] is an "if" statement
# -z returns True if the length of the string is zero
[ -z "$PS1" ] && return

# Terminal
#export TERM=rxvt-unicode

# Bash
shopt -s histappend checkwinsize autocd globstar checkjobs dirspell

# History
HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups:ignorespace
HISTSIZE=1000
HISTFILESIZE=2000

# Prompt
PS1='\[\033[00;36m\]\u@\h \[\033[01;36m\]\W \$ \[\033[00m\]'
PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ] || [ -x /bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

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

# Autojump
source /etc/profile

# Banner
figlet `hostname` | lolcat

