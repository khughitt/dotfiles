#
# Z shell Settings
#

# PATH
PATH=$HOME/bin:$PATH

# Stop here in non-interactive mode
[ -z "$PS1" ] && return

# Use Xresrouces to set TTY colors
if [ "$TERM" = "linux" ]; then
    _SEDCMD='s/.*\*\.color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $HOME/.Xresources | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

#Terminal
#TERM=rxvt-unicode

# Autojump
[[ -s ~/.autojump/etc/profile.d/autojump.sh ]] && . ~/.autojump/etc/profile.d/autojump.sh

# History
setopt HIST_IGNORE_DUPS

# Oh-my-zsh settings
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="cloud"
CASE_SENSITIVE="true"

# Plugins
plugins=(autojump git)

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

# Urxvt keybindings
if [[ "${TERM}" == "rxvt-unicode" ]]
then
    source ~/.shell/key_bindings
fi

# Quick history searches (can also use ctrl + R)
function h {
    history | grep $1
}

# Banner
figlet `hostname` | lolcat

#export PERL_LOCAL_LIB_ROOT="/home/keith/perl5";
#export PERL_MB_OPT="--install_base /home/keith/perl5";
#export PERL_MM_OPT="INSTALL_BASE=/home/keith/perl5";
#export PERL5LIB="/home/keith/perl5/lib/perl5/x86_64-linux-thread-multi:/home/keith/perl5/lib/perl5";
#export PATH="/home/keith/perl5/bin:$PATH";

