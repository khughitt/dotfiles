# Core shell helpers.

# alias lookup
function al {
  alias | grep "$1"
}

# function lookup
function fu {
  local query="$1"
  local line func def
  local function_files=(~/.shell/functions ~/.shell/functions.d/*.zsh(N))

  while IFS= read -r line; do
    # parse function name
    func="${${line#function }%% *}"

    # get function definition
    def=$(type -af "$func" 2>/dev/null) || continue

    if echo "$def" | grep -q "$query"; then
      echo "$def"
    fi
  done < <(rg --no-line-number --no-filename "^function " "${function_files[@]}")
}

# recursively count files in subdirs
function count_files {
  local x num_hidden

  # non-hidden folders
  for x in */; do
    echo "$x"
    fd -Luu . "$x" -t f | wc -l
  done

  # if hidden directories present, include them..
  num_hidden=$(/bin/ls -Ap | grep "^\..*/$" | wc -l)

  if [[ "$num_hidden" -ne 0 ]]; then
    for x in .*/; do
      echo "$x"
      fd -Luu . "$x" -t f | wc -l
    done
  fi
}

# copy full path
function cfp {
  realpath -s "$1" | xsel
}

# relative working directory
function wd {
  echo ${$(pwd)/$HOME\//}
}

# quick history searches
function h {
  history -df -100000 | grep "$1"
}

# mkdir & cd into it
function mdd {
  mkdir -p "$1"
  cd "$1"
}

# process management
function pg {
  ps -Af | grep "$1" | grep -v grep
}

# zcat | wc -l
function zcl {
  zcat "$1" | wc -l
}

# fahrenheit to celsius
function ftoc {
  local cel
  cel=$(echo "scale=4;(5/9)*($1-32)" | bc)  # scale determines precision
  echo "${cel%???}"                         # strip last few digits
}

# celsius to fahrenheit
function ctof {
  local far
  far=$(echo "scale=4;(9/5)*$1 + 32" | bc)
  echo "${far%???}"
}

# jq | less
function jql {
  cat "$1" | jq -C | /bin/less -R
}

# wl-copy
function yank {
  /bin/cat "$1" | wl-copy
}

# translate (中文 -> 英語)
function tt {
  sdcv -c "$1"
  echo "------------------------\n"
  trans zh-TW:en "$1"
}

# preview generated colormage palettes
function color_preview {
  local img base x

  for img in ~/d/colors/_inc/*-preview.jpg; do
    echo "$img"
    kitty +kitten icat "$img"

    base=${img/-preview.jpg/}

    for x in ${base}*.(png|jpg); do
      kitty +kitten icat "$x"
    done
  done
}
