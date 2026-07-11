# Development aliases.

# claude code
alias cl='claude --dangerously-skip-permissions'
alias clp='claude --dangerously-skip-permissions --plugin-dir /mnt/ssd/Dropbox/science'

# codex (linux symlink work-around)
# alias codex='codex -C `pwd`'

# conda/mamba
alias cde='micromamba deactivate'
alias cs='micromamba search'
alias mamba='micromamba'

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
