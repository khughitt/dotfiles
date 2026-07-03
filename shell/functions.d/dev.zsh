# Development workflow helpers.

# docker
function dty {
    docker exec -it $1 /bin/bash
}

function up {
  # detect Ubuntu and set compose file args
  local compose_args=()
  if [ -f /etc/lsb-release ] && grep -q Ubuntu /etc/lsb-release; then
    compose_args=(-f compose.deploy.yml)
  fi

  # if container specified, just build it
  if [ $# -gt 0 ]; then
    docker compose "${compose_args[@]}" up --build "$@"
  else
    # otherwise build everything
    docker compose "${compose_args[@]}" up --build
  fi
}

function down {
  # detect Ubuntu and set compose file args
  local compose_args=()
  if [ -f /etc/lsb-release ] && grep -q Ubuntu /etc/lsb-release; then
    compose_args=(-f compose.deploy.yml)
  fi

  docker compose "${compose_args[@]}" down --remove-orphans
}

# fzf confs
function C {
    target=`fd . "$DOTFILES" -t f \
            --no-ignore-vcs \
            --exclude "tpm" --exclude "tmp" --exclude "tmux-*" --exclude "Extracted" \
            --exclude "*.xml" --exclude "*.png" --exclude "*.desktop" \
            --exclude "plugged" --exclude "black"`

    target=`echo $target |\
            grep --color='none' "$1" |\
            fzf -1 --exact`

    if [ ! -z "$target" ]; then
        kitty @ set-window-title vim $target
        vim $target
    fi
}

# cheatsheets
function c {
    target=`/bin/ls $DOTFILES/cheatsheets/ |\
            grep --color='none' "$1" |\
            fzf -1 --exact --preview 'bat $DOTFILES/cheatsheets/{}' --preview-window up`

    if [ ! -z "$target" ]; then
        kitty @ set-window-title vim $DOTFILES/cheatsheets/$target
        vim $DOTFILES/cheatsheets/$target
    fi
}

# vim + rg
function vr {
    local files=($(rg -l "$1"))
    [ ${#files[@]} -gt 0 ] && $EDITOR "${files[@]}"
}
function vru {
    local files=($(rg -uuu --no-ignore-files -l "$1"))
    [ ${#files[@]} -gt 0 ] && $EDITOR "${files[@]}"
}

# vim + fzf
function vI {
    target=`fd -t f \
            --exclude "*.svg" --exclude "*.png"`

    target=`echo $target |\
            grep --color='none' "$1" |\
            fzf -1 --exact`

    if [ ! -z "$target" ]; then
        kitty @ set-window-title vim $target
        vim $target
    fi
}

# pytest
function pyf {
  uv run pytest --no-cov $(fd $1)
}

# create new vite + react proj
function vite_proj {
  export projname="$1"
  npm create vite@latest "$projname"  -- --template react-ts

  cd "$projname"
  npm i

  # eslint
  sed -i "s/bundler/Node/" tsconfig.json

  npm install eslint eslint-plugin-react --save-dev

  # r3f & friends
  npm install three @types/three @react-three/fiber @react-three/drei

  # feb25; use r3f rc compat for now to support react 19
  # npm install three @types/three @react-three/fiber@rc \
  #   @react-three/drei@rc
    #@react-three/postprocessing leva

  # .glsl support
  npm i vite-plugin-glsl --save-dev
  sed -i "1 i import glsl from 'vite-plugin-glsl';" vite.config.ts
  sed -i "s/react()/react(), glsl()/" vite.config.ts
  sed -i '/compilerOptions/a \ \ \ \ "types": ["vite-plugin-glsl/ext"],' tsconfig.json

  echo "Finished!.."
  echo "---"
  echo "Manual step:"
  echo "dropbox_ignore node_modules"
}
