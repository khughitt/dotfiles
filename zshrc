#
# Z shell Settings
#
# start profiling zshrc
# zmodload zsh/zprof 

# stop here in non-interactive mode
[ -z "$PS1" ] && return

# load zinit
source ~/.zinit/bin/zinit.zsh

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

unalias a
unalias s
alias o='a -e xdg-open'
alias j='fasd_cd -d' 
alias v='f -e nvim'

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
  # __vte_osc7
fi

# dir colors
#eval $(dircolors -b ~/.dir_colors)

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
# zinit
#

# nvm
zinit light lukechilds/zsh-nvm

zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/directories.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit snippet OMZ::plugins/systemd/systemd.plugin.zsh

# vi mode improvement
#zinit snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh

# emacs mode improvements
zinit snippet OMZ::lib/key-bindings.zsh

# prompt
zinit ice pick"async.zsh" src"pure.zsh"; zinit light sindresorhus/pure

# fasd-fzf integration
zinit light "khughitt/fzf-fasd"

# zsh autosuggestions
#zinit light zsh-users/zsh-autosuggestions

# ls colors 
# zinit ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh"
# zinit load trapd00r/LS_COLORS

# syntax highlighting
zinit light "zdharma/fast-syntax-highlighting"

# alias reminders
zinit light "djui/alias-tips"

# cntl-z -> fg
zinit light "mdumitru/fancy-ctrl-z"

# completions
if is-at-least 5.3; then
  zinit ice lucid wait'0a' blockf
else
  zinit ice blockf
fi
zinit light "zsh-users/zsh-completions"

# fzf-marks
export FZF_MARKS_JUMP="^b"
zinit light "urbainvaes/fzf-marks"

# fzf
export FZF_DEFAULT_COMMAND="fd --type file --color=never"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [[ ! "$DISABLE_FZF_AUTO_COMPLETION" == "true" ]]; then
    [[ $- == *i* ]] && source "~/.fzf/shell/completion.zsh" 2> /dev/null
fi

# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# navi
#source <(navi widget zsh)

# kitty completion
#kitty + complete setup zsh | source /dev/stdin

# location of additional zsh completions
fpath+=$HOME/.dotfiles/zsh/

# tab completion
autoload -Uz compinit
compinit
zinit cdreplay -q 

# disable completion for "play" (wrong application)
# only need to do once..
#zinit cdisable play

# pywal
#(/bin/cat ~/.cache/wal/sequences &)
#source ~/.cache/wal/colors-tty.sh
if [ -e "${HOME}/.cache/wal/colors.sh" ]; then
    source "${HOME}/.cache/wal/colors.sh"
fi

# host-specific settings
if [ -e ~/.dotfiles/zsh/$HOST.zsh ]; then
    . ~/.dotfiles/zsh/$HOST.zsh
fi

# print greeting
if [ "$vconsole" = false ]; then
    hostname | cut -d'.' -f1 | figlet | lolcat -S 33
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/mnt/storage/conda/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/mnt/storage/conda/etc/profile.d/conda.sh" ]; then
        . "/mnt/storage/conda/etc/profile.d/conda.sh"
    else
        export PATH="/mnt/storage/conda/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
