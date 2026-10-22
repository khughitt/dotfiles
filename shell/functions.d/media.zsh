# Media and terminal presentation helpers.

# kitty theme switcher
function kit {
  local themedir="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/themes"
  local theme
  theme=$(/bin/ls "$themedir" | grep -v README | sed 's/.conf//' | grep --color='none' "$1" | fzf -1 --exact)
  kitten @ set-colors "$themedir/$theme.conf"
}

# kitty icat, as a function rather than an alias: zsh completes an alias as its
# expansion, which handed `icat <TAB>` to kitty's completer. That one filters by
# prefix itself and refuses matcher-list's substring matchers, so `icat den<TAB>`
# found nothing. Completing image files here lets matcher-list apply; zshrc
# registers _icat after compinit.
function icat {
  kitty +kitten icat "$@"
}

function _icat {
  _files -g '*.(#i)(png|apng|jpg|jpeg|gif|webp|avif|heic|heif|jxl|bmp|ico|tif|tiff|tga|psd|ppm|pgm|pbm|pnm|svg)(-.)'
}

# pandoc + mermaid
function merp {
  pandoc -t html --mathjax -F mermaid-filter -o "${1/.md/.html}" "$1"
}

# glslviewer
# note: may want to remove --headless option when working more on animated shaders..
function gls2png {
  local outfile="output/${1/.frag/.png}"

  glslviewer "$1" \
    -w 1080 \
    -h 1080 \
    -s 1 \
    --headless \
    -o "$outfile"

  icat "$outfile"
}
