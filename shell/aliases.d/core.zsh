# Core command aliases.

# bat
alias bat='bat --wrap=never --paging=never'

# cats
alias cats="$HOME/d/cats/.venv/bin/cats"

# cd
alias dl='cd ~/downloads'
alias dots='cd $DOTFILES'
alias cdd='cd $dlas'

# cheatsheets
alias crg='rg $DOTFILES/cheatsheets'

# cp
alias cpr='cp -r'

# diff
alias diff='diff --color=auto'

# dropbox
alias dropbox_ignore='attr -s com.dropbox.ignored -V 1 '

# du
alias dud='du -d 1 -h'
alias duf='du -sh *'
alias dus='du -sh'

# fd
alias Fd='fd -d 1'
alias fda='fd -Luu'
alias fdu='fd -u'
alias fdl='fd -l | sort -k6M -k7n'
alias fdr="fd -l --changed-within 5d | csvcut -d ' ' -S -c6-9 | csvlook -HI"

alias fdd="fd -t d"
alias fdf="fd -t f"

alias fd1='fd --changed-within 1h'
alias fd2='fd --changed-within 2h'
alias fd3='fd --changed-within 3h'
alias fd4='fd --changed-within 4h'
alias fd5='fd --changed-within 5h'
alias fd6='fd --changed-within 6h'
alias fd8='fd --changed-within 8h'
alias fd12='fd --changed-within 12h'
alias fd24='fd --changed-within 1d'
alias fd48='fd --changed-within 2d'

alias fda1='fd -Luu --changed-within 1h'
alias fda2='fd -Luu --changed-within 2h'
alias fda3='fd -Luu --changed-within 3h'
alias fda4='fd -Luu --changed-within 4h'
alias fda5='fd -Luu --changed-within 5h'
alias fda6='fd -Luu --changed-within 6h'
alias fda8='fd -Luu --changed-within 8h'
alias fda12='fd -Luu --changed-within 12h'
alias fda24='fd -Luu --changed-within 1d'
alias fda48='fd -Luu --changed-within 2d'

alias fd-1='fd --changed-before 1h'
alias fd-2='fd --changed-before 2h'
alias fd-24='fd --changed-before 1d'
alias fd-48='fd --changed-before 2d'

# grep
alias -g G='| grep -i'  # "-g" = global alias; can be substituted anywhere on the line
alias grep='grep --color=always'
alias zgrep='zgrep --color=always'

# less
if type "moor" > /dev/null; then
  alias less='moor'
fi

# ln
alias lns='ln -s'

# locate
alias locate=plocate

# ls
if type "lsd" > /dev/null; then
    alias ls='lsd --group-dirs=first'
fi

alias l='ls -l'
alias lt='ls --tree'
alias lr='ls -latr'
alias lrd='ls -latr doc/*.md'
alias lsr='ls -lSr'

# rm
alias rmf="rm -rf"

# sd
alias -g N='| sd "/\x1b\[[0-9;]*m/g" ""'   # strip ansi colors

# sleep
alias s1="sleep 60 &&"
alias s5="sleep 300 &&"
alias s10="sleep 600 &&"
alias s15="sleep 900 &&"
alias s20="sleep 1200 &&"
alias s25="sleep 1500 &&"
alias s30="sleep 1800 &&"
alias s60="sleep 3600 &&"
alias s120="sleep 7200 &&"

# sudo
alias sudo="sudo " # support aliases when using sudo
alias _='sudo'

# tar
alias taru="tar xavpf"
alias tarc="tar czvpf"

# termbin (ex. "echo foo | tb")
alias tb="nc termbin.com 9999"

# time zone
alias est="timedatectl set-timezone US/Eastern"
alias pst="timedatectl set-timezone US/Pacific"

# tree
alias tree="tree -C --gitignore"

# wc
alias wcl="wc -l"

# "whatip"; get external ip addr
alias whatip='curl --fail --silent --show-error https://api.ipify.org && echo'
