# update PATH
typeset -U PATH path
export PATH=$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.gem/ruby/2.7.0/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH

# environmental variables
export BROWSER=chromium
export EDITOR=nvim
export PDFVIEWER=zathura
export SYSTEMD_EDITOR=nvim
export XDG_CONFIG_HOME="$HOME/.config"

export PAGER=less

# use system colors for ls
export LS_COLORS="di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# if type "moar" > /dev/null; then
#     export PAGER=$(which moar)
# fi

# java
export JAVA_HOME=/usr/lib/jvm/default
export JAVA_FONTS=/usr/share/fonts/TTF
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'
export _JAVA_AWT_WM_NONREPARENTING=1

# let ncurces know where to find terminfo
export TERMINFO=~/.terminfo

# remap caps-lock in sway
export XKB_DEFAULT_OPTIONS=caps:escape

# lazy-load NVM
export NVM_LAZY_LOAD=true

# less page colors to use for man pages
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;204m'    # begin standout-mode - info/highlight
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[01;32m'       # begin underline

# CMFinder
#export PATH=$PATH:$HOME/software/cmfinder-0.4.1.9/bin
PATH=$PATH:$HOME/software/cmfinder-0.4.1.9/bin
export CMfinder=$HOME/software/cmfinder-0.4.1.9

# perl
PATH="/home/keith/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/keith/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/keith/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/keith/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/keith/perl5"; export PERL_MM_OPT;

# ibus
#export GTK_IM_MODULE=ibus
#export XMODIFIERS=@im=ibus
#export QT_IM_MODULE=ibus

