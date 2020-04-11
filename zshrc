#
# Z shell Settings
#
# start profiling zshrc
# zmodload zsh/zprof 

# stop here in non-interactive mode
[ -z "$PS1" ] && return

# load zplugin
source ~/.zplugin/bin/zplugin.zsh

# local settings (early)
if [ -e ~/.zsh_local_early ]; then
   source ~/.zsh_local_early
fi

# tmux
source ~/.shell/tmux

# check if in virtual console
if [ "$TERM" = "linux" ]; then
    export vconsole=true
else
    export vconsole=false
fi

# use Xresrouces to set TTY colors for virtual console sessions
if $vconsole; then
    COLORFILE=$(grep --color='never' -o "/.*termcolors/[a-z1-9\-]*" $HOME/.Xresources)
    _SEDCMD='s/.*\*color\([0-9]\{1,\}\).*#\([0-9a-fA-F]\{6\}\).*/\1 \2/p'
    for i in $(sed -n "$_SEDCMD" $COLORFILE | \
               awk '$1 < 16 {printf "\\e]P%X%s", $1, $2}'); do
        echo -en "$i"
    done
    clear
fi

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

# tab completion menu
zstyle ':completion:*' menu select=4

# use smart-case completion
# zstyle ':completion:*' matcher-list 'l:|=* r:|=*' 
zstyle ':completion:*'  matcher-list 'm:{a-z}={A-Z}'

# snakemake tab completion support
#compdef _gnu_generic snakemake

# additional shell settings (aliases, exports, etc.)
for file in ~/.shell/{aliases,functions,private,exports}; do
    [ -r "$file" ] && source "$file"
done
unset file

# fasd
export _FASD_SHELL='dash'

fasd_cache="$HOME/.fasd-init-zsh"
if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache" ]; then
  fasd --init auto >| "$fasd_cache"
fi
source "$fasd_cache"
unset fasd_cache

alias o='a -e xdg-open'
alias j='fasd_cd -d' 
alias v='f -e nvim'

# git -> hub
#eval "$(hub alias -s)"

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# disable scroll lock
stty -ixon

# urxvt keybindings
if [[ "${TERM}" == rxvt-* ]]
then
    source ~/.shell/urxvt
fi

# termite dynamic titles
if [[ $TERM == xterm-termite ]]; then
  . /etc/profile.d/vte.sh
  __vte_osc7
fi

# dir colors
#eval $(dircolors -b ~/.dir_colors)

# conda
__conda_setup="$("$HOME/conda/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
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

# local settings (late)
if [ -e ~/.zsh_local_late ]; then
   source ~/.zsh_local_late
fi

# enable vi-mode
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

# fix keybindings
bindkey "^[[H" beginning-of-line
bindkey "^A"   beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^E"   end-of-line
bindkey "^[[1;3D" backward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5C" forward-word
bindkey "^[^?" backward-kill-word 

#bindkey '^[[Z' reverse-menu-complete

#
# zplugin
#

# nvm
zplugin light lukechilds/zsh-nvm

zplugin snippet OMZ::lib/completion.zsh
zplugin snippet OMZ::lib/directories.zsh
zplugin snippet OMZ::lib/git.zsh
zplugin snippet OMZ::plugins/git/git.plugin.zsh
zplugin snippet OMZ::plugins/systemd/systemd.plugin.zsh

# vi mode improvement
#zplugin snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh

# emacs mode improvements
zplugin snippet OMZ::lib/key-bindings.zsh

# prompt
zplugin ice pick"async.zsh" src"pure.zsh"; zplugin light sindresorhus/pure

# fasd-fzf integration
zplugin light "khughitt/fzf-fasd"

# zsh autosuggestions
#zplugin light zsh-users/zsh-autosuggestions

# ls colors 
# zplugin ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
# zplugin load trapd00r/LS_COLORS

# syntax highlighting
zplugin light "zdharma/fast-syntax-highlighting"

# alias reminders
zplugin light "djui/alias-tips"

# cntl-z -> fg
zplugin light "mdumitru/fancy-ctrl-z"

# completions
if is-at-least 5.3; then
  zplugin ice lucid wait'0a' blockf
else
  zplugin ice blockf
fi
zplugin light "zsh-users/zsh-completions"

# fzf-marks
export FZF_MARKS_JUMP="^b"
zplugin light "urbainvaes/fzf-marks"

# fzf
export FZF_DEFAULT_COMMAND="fd --type file --color=never"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [[ ! "$DISABLE_FZF_AUTO_COMPLETION" == "true" ]]; then
    [[ $- == *i* ]] && source "~/.fzf/shell/completion.zsh" 2> /dev/null
fi

# navi
#source <(navi widget zsh)

# greenclip
fzf-clipboard() { echo -n "$(greenclip print | fzf -e -i)" | xclip -selection clipboard ;}
cfg-greenclip() { killall greenclip ; $EDITOR ~/.config/greenclip.cfg && nohup greenclip daemon > /dev/null 2>&1 & }
rld-greenclip() { killall greenclip ; nohup greenclip daemon > /dev/null 2>&1 & }
derez-greenclip() { killall greenclip ; rm ~/.cache/greenclip.history && nohup greenclip daemon > /dev/null 2>&1 & }

# kitty completion
#kitty + complete setup zsh | source /dev/stdin

# location of additional zsh completions
fpath+=$HOME/.dotfiles/zsh/

# tab completion
autoload -Uz compinit
compinit
zplugin cdreplay -q 

# pywal
#(/bin/cat ~/.cache/wal/sequences &)
#source ~/.cache/wal/colors-tty.sh

# host-specific settings
if [ -e ~/.dotfiles/zsh/$HOST.zsh ]; then
    . ~/.dotfiles/zsh/$HOST.zsh
fi

# print greeting
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

### End of Zinit's installer chunk
