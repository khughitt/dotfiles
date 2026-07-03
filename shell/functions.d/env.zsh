# Environment launcher helpers.

# mamba env launcher
function ma {
  local wd target
  wd=$(pwd)

  cd "$MAMBA_ROOT_PREFIX/envs/"
  target=$(/bin/ls -t | grep --color='none' "$1" | fzf -1 --exact)

  if [ ! -z "$target" ]; then
    micromamba activate "$target"
  fi

  cd "$wd"
}

# copy kitty terminfo to conda envs
function mamba_kitty {
  local x
  for x in "${MAMBA_ROOT_PREFIX}"/envs/*/share/terminfo/x; do
    echo "$x";
    cp /usr/share/terminfo/x/xterm-kitty "$x";
  done
}

# quick hop to a specific data dir (limit to project data to speed things up..)
function data_dir {
    cd /data/proj

    local target

    target=$(fd -t d | grep --color='none' "$1" | fzf -1 --exact)

    if [ ! -z "$target" ]; then
        cd "/data/proj/$target"
    fi
}

# virtual env launcher
function venv {
  local wd target
  wd=$(pwd)

  cd ~/venv/
  target=$(/bin/ls -t | grep --color='none' "$1" | fzf -1 --exact)

  if [ ! -z "$target" ]; then
    source ~/venv/$target/bin/activate
  fi

  cd "$wd"
}
alias ven=venv
