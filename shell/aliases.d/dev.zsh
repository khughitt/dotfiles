# Development aliases.

# claude code
alias cl='claude --dangerously-skip-permissions'
alias clr='claude --dangerously-skip-permissions --resume'
alias clp='claude --dangerously-skip-permissions --plugin-dir ~/d/proto/science'

# codex
# --no-daemon: Codex 0.160+ otherwise runs hooks under its shared background server,
# which has no terminal, so familiar can't tell which window a hook belongs to.
alias co='codex --no-daemon --dangerously-bypass-approvals-and-sandbox'
alias cor='codex --no-daemon --dangerously-bypass-approvals-and-sandbox resume'

# conda/mamba
alias cde='micromamba deactivate'
alias cs='micromamba search'
alias mamba='micromamba'

# crush
alias cr='crush -y'

# docker
alias doc='docker'
alias docc='docker compose'
alias upv='docker --debug compose up --build'
alias dps='docker ps -a --format="table {{.ID}}\t\t{{.Names}}\t{{.Image}}\t{{.Status}}"'
alias docl='docker logs -f'
alias dkill='docker kill $(docker ps -q)'

# ghci
alias ghci='ghci-color'

# jupyter
alias jl='jupyter lab'

# lit-walk
alias lw='cd $PROJ/lit-explore/lit-walk poetry run lit-walk'
alias lwd="cd $PROJ/lit-explore/lit-walk poetry run lit-walk --config='~/.config/lit/config-dev.yml'"

# neovim
alias vi=nvim
alias vim=nvim
alias vm='kitty @ set-window-title nvim README.*md && nvim README.*md'
alias vl="nvim -c \"normal '0\""                         # open most recently edited file / position
alias vv='x=$(fc -l -1); x=${x##* }; vim ${x/\~/$HOME}'  # open last argument of last command in vim

# npm
alias ndev="npm run dev"

# python
alias ipy=ipython

# pytest
alias pyt="uv run pytest --no-cov 2>&1 | tee pytest.txt"
alias pyj="uv run pytest . --json-report --json-report-file=pytest.json"

# rg
alias rgl='rg -l'
alias rgd='rg -d'
alias rgu='rg -uuu --no-ignore-files'

# r
alias R='R --quiet --no-save'
alias r=radian

# rust
alias rc=rustc

# science
alias s='uv run science --color=always'

# snakemake
alias snek="snakemake"

# tasks
alias ta='TASKS_FORMAT=pretty tasks --color=always'
alias tag='TASKS_FORMAT=pretty tasks list | grep -i'
taj() {
  (( $# )) || { print -u2 'usage: taj PATTERN [tasks list options]'; return 2; }
  setopt localoptions pipefail
  local pattern=$1
  shift
  tasks list --json "$@" | jq --arg pattern "$pattern" '.tasks |= map(select(any(.. | strings; test($pattern; "i"))))'
}
alias tal='ta list'
alias tan='ta next'
alias tap='ta projects'
alias tals='ta list --sort updated'
alias taps='ta projects --sort activity'

# The terminal's colors as a TASKS_PALETTE value. tasks queries the terminal itself only
# when stdout is a terminal, so a pipeline into a pager has to ask first, before the
# pager starts reading the same terminal.
_tasks_palette() {
  local saved buf= ch
  saved=$(stty -g </dev/tty 2>/dev/null) || return 1
  stty -echo -icanon </dev/tty
  # fg, bg, palette slots 5 (magenta) and 6 (cyan), then DA1 as a fence: every terminal
  # answers it, after the color replies.
  print -rn $'\e]10;?\e\\\e]11;?\e\\\e]4;5;?\e\\\e]4;6;?\e\\\e[c' >/dev/tty
  while read -rsk 1 -t 0.5 ch </dev/tty; do
    buf+=$ch
    [[ $buf == *$'\e[?'*c ]] && break
  done
  stty $saved </dev/tty
  _tasks_palette_parse $buf
}

# Replies look like ESC ] 10 ; rgb:rrrr/gggg/bbbb ST; the top two hex digits of each
# channel make the #rrggbb.
_tasks_palette_parse() {
  local buf=$1 key query out=() h='[0-9a-fA-F]'
  for key query in fg 10 bg 11 magenta 4\;5 cyan 4\;6; do
    [[ $buf =~ $'\e]'"$query;rgb:($h$h)$h*/($h$h)$h*/($h$h)" ]] || return 1
    out+=("$key=#$match[1]$match[2]$match[3]")
  done
  print -r -- "${(j: :)out}"
}

# show task in a pager; COLUMNS makes tasks wrap prose itself, which it skips when piped
tas() {
  local palette
  # No reply leaves TASKS_PALETTE as inherited: unset, tasks warns rather than going plain.
  if palette=$(_tasks_palette); then
    local -x TASKS_PALETTE=$palette
  fi
  COLUMNS=$COLUMNS ta show "$@" | moor --terminal-fg --no-linenumbers
}

alias Tal='ta list --all-projects'
alias Tals='ta list --sort updated'
alias Tag='TASKS_FORMAT=pretty tasks list --all-projects | grep -i'
alias lil='Tal  --process direct --size xs'
alias smol='Tal  --process direct --size s'
alias chore='git add tasks && git commit "chore: task updates"'

alias tuia='tui --all'

# tmux
alias x=xumt

# translate
alias tze="trans zh-TW:en"  # to english
alias tez="trans en:zh-TW"  # to chinese

# uv
alias u="uv run"
alias uvi="uv run ipython"

# virtual env
alias dea=deactivate

# visidata
alias vp="vd -f pandas"
