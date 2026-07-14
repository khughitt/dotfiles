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

# claude-code writes a spinner into the window title once a second while it works, which
# overwrites familiar's ⟨familiar:sNN:state⟩ marker -- the string niri's window rules match on
# for the identity border. The border therefore failed precisely while the agent was busy, and
# looked fine whenever you checked it at rest. familiar owns the title; claude-code does not.
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1

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

# remap caps-lock in sway
# export XKB_DEFAULT_OPTIONS=caps:escape

# perl
PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;

# pre-commit
export PRE_COMMIT_HOME=$HOME/.cache/pre-commit

# pytest: drop tmp_path dirs after passing runs so they don't pile up. On Linux,
# systemd (>=256) sets a per-user usrquota on the /tmp + /dev/shm tmpfs, and
# leaked pytest temp data can exhaust it; failed sessions are still kept (last 3).
export PYTEST_ADDOPTS="-o tmp_path_retention_policy=failed"

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
