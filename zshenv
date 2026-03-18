# update PATH
# note: 'typeset -U' specifies that only the first occurence of any duplicates should be
#        kept in an array variable.
typeset -U PATH path

# Homebrew (Apple Silicon)
if [[ -d /opt/homebrew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export PATH=$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.gem/ruby/3.4.0/bin:$HOME/go/bin:$HOME/.yarn/bin:$PATH

export BROWSER=firefox
export EDITOR=nvim
export FONTCONFIG_PATH=/etc/fonts
export PAGER=less
export PDFVIEWER=zathura
export SYSTEMD_EDITOR=nvim
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"

# hostname (use existing if already set)
export HOSTNAME="${HOSTNAME:-$(hostname)}"

# anki font size fix
# https://changes.ankiweb.net/#/known-issues
export ANKI_NOHIGHDPI=1

# go
export GOPATH="$HOME/go"

# use system colors for ls
export LS_COLORS="di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# LS_COLORS
# export LS_COLORS="$(vivid generate one-dark)"

# java
if [[ "$(uname)" == "Darwin" ]]; then
    export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)
else
    export JAVA_HOME=/usr/lib/jvm/default
    export JAVA_FONTS=/usr/share/fonts/TTF
fi
if [[ "$(uname)" != "Darwin" ]]; then
    export _JAVA_AWT_WM_NONREPARENTING=1
    export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'
fi
export FREEPLANE_USE_UNSUPPORTED_JAVA_VERSION=1

# let ncurses know where to find terminfo
export TERMINFO=~/.terminfo

# remap caps-lock in sway
# export XKB_DEFAULT_OPTIONS=caps:escape

# less page colors to use for man pages
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;204m'    # begin standout-mode - info/highlight
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[01;32m'       # begin underline

# perl
PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;

# pre-commit
export PRE_COMMIT_HOME=$HOME/.cache/pre-commit

# ripgrep
export RIPGREP_CONFIG_PATH="$DOTFILES/ripgreprc"

# rofi x proj
export ROFI_PROJ_DIR="$DOTFILES/rofi/rofi-proj"

# uv
export UV_CONCURRENT_DOWNLOADS=3

# qt
export QT_SCALE_FACTOR=1

# Predictable SSH authentication socket location.
# https://unix.stackexchange.com/a/76256/39903
# SOCK="/tmp/ssh-agent-keith-screen"

# if test $SSH_AUTH_SOCK && [ $SSH_AUTH_SOCK != $SOCK ]; then
#     rm -f /tmp/ssh-agent-$USER-screen
#     ln -sf $SSH_AUTH_SOCK $SOCK
#     export SSH_AUTH_SOCK=$SOCK
# fi
