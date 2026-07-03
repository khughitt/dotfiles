# Environment launcher helpers.

# mamba env launcher
function ma {
  wd=`pwd`

  cd "$MAMBA_ROOT_PREFIX/envs/"
  target=`/bin/ls -t | grep --color='none' "$1" | fzf -1 --exact`

  if [ ! -z "$target" ]; then
    micromamba activate "$target"
  fi

  cd "$wd"
}

# copy kitty terminfo to conda envs
function mamba_kitty {
  for x in $MAMBA_ROOT_PREFIX/envs/*/share/terminfo/x; do
    echo $x;
    cp /usr/share/terminfo/x/xterm-kitty $x;
  done
}

# quick hop to a specific data dir (limit to project data to speed things up..)
function data_dir {
    cd /data/proj

    # determine fd command to use
    fd_cmd="fd -t d"

    target=`eval $fd_cmd | grep --color='none' "$1" | fzf -1 --exact`

    if [ ! -z "$target" ]; then
        cd "/data/proj/$target"
    fi
}

# virtual env launcher
function venv {
  wd=`pwd`

  cd ~/venv/
  target=`/bin/ls -t | grep --color='none' "$1" | fzf -1 --exact`

  if [ ! -z "$target" ]; then
    source ~/venv/$target/bin/activate
  fi

  cd $wd
}
alias ven=venv
