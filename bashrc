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
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    shopt -s histappend checkwinsize autocd globstar checkjobs dirspell
fi

# tmux helper function
function xumt() {
    SESSION_NAME=$(whoami)
    if [ ! -z "$1" ]; then
        SESSION_NAME="${SESSION_NAME}_$1"
    fi

    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        tmux -2 attach-session -t $SESSION_NAME
    else
        tmux -2 new-session -s $SESSION_NAME
    fi
}

# History
HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups:ignorespace
HISTSIZE=1000
HISTFILESIZE=2000

# Prompt
PS1='\[\e[0;32m\]\u@\h\[\e[m\] \[\e[1;34m\]\w\[\e[m\] \[\e[1;32m\]\$\[\e[m\]'
#PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ] || [ -x /bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Check if in virtual console
if [ "$TERM" = "linux" ]; then
    export vconsole=true
else
    export vconsole=false
fi

# For machines without dircolors support
# http://stackoverflow.com/questions/1550288/mac-os-x-terminal-colors
if [[ ! -e "$LSCOLORS" ]]; then
    alias ls='ls -Gp'
    export CLICOLOR=1
    export LSCOLORS=GxFxCxDxBxegedabagaced
fi

# Use Xresrouces to set TTY colors
if $vconsole; then
    COLORFILE=$(grep --color='never' -o "/.*termcolors/[a-z1-9\-]*" $HOME/.Xresources)
    _SEDCMD='s/.*\*color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $COLORFILE | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

# R-vim tweaks
alias vim='vim --servername VIM'

if [ "$DISPLAY" != "" ]; then
    function tvim() { tmux new-session "vim --servername VIM $@" ; }
else
    function tvim() { tmux new-session "vim $@" ; }
fi

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Additional shell settings (aliases, exports)
for file in ~/.shell/{aliases,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# Quick history searches (can also use ctrl + R)
function h {
    history | grep $1
}


# Disable scroll lock
stty -ixon

# Banner
if [[ $(type "figlet" &> /dev/null) ]]; then
# Hostname
    if [ "$vconsole" = false ]; then
        hostname | cut -d'.' -f1 | figlet | lolcat -S 16
    fi
fi

