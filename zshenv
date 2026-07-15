# update PATH
# note: 'typeset -U' specifies that only the first occurence of any duplicates should be
#        kept in an array variable.
typeset -U PATH path

# Resolve the dotfiles root from this file's own location so $DOTFILES is set even
# in a clean environment (e.g. a systemd unit), before anything below references it.
# %x = the file being sourced (this zshenv, possibly via the ~/.zshenv symlink);
# :A resolves symlinks to an absolute path, :h takes its directory.
: "${DOTFILES:=${${(%):-%x}:A:h}}"
export DOTFILES

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
export OPENCODE_DISABLE_TERMINAL_TITLE=1

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

# Keep tool caches OUT of ~/d (Dropbox): thousands of tiny churny cache files
# wedge the Dropbox sync engine. Redirect them to a host-local base dir, CACHE_DIR.
#
# CACHE_DIR defaults to XDG ~/.cache (already outside Dropbox, per host). To park
# caches elsewhere on a given machine (e.g. a separate data disk), export CACHE_DIR
# from shell/local/${HOST}.env.zsh — sourced here at zshenv time (not zshrc) so
# non-interactive tool runs (scripts, systemd, uv) see it too. No host currently
# overrides it; ~/.cache is an NVMe SSD with room, so the default is used.
#   - PYTHONPYCACHEPREFIX: writes all __pycache__/.pyc to a shadow tree, so none
#     appear next to source (Python >=3.8).
#   - RUFF_CACHE_DIR / MYPY_CACHE_DIR: single shared cache, safe across projects.
# pytest's .pytest_cache is intentionally NOT redirected here: cache_dir has no
# per-project env var, so a global one collides (lastfailed/nodeids) and races
# under parallel runs. It stays in-tree and is handled by dropbox-ignore-flux.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
[[ -n "$DOTFILES" && -r "${DOTFILES}/shell/local/${HOST}.env.zsh" ]] \
    && source "${DOTFILES}/shell/local/${HOST}.env.zsh"
export CACHE_DIR="${CACHE_DIR:-$XDG_CACHE_HOME}"
export PYTHONPYCACHEPREFIX="$CACHE_DIR/pycache"
export RUFF_CACHE_DIR="$CACHE_DIR/ruff"
export MYPY_CACHE_DIR="$CACHE_DIR/mypy"

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
