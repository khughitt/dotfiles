# Media and terminal presentation helpers.

# kitty theme switcher
function kit {
  local themedir="$HOME/.config/kitty/themes"
  local theme
  theme=$(/bin/ls "$themedir" | grep -v README | sed 's/.conf//' | grep --color='none' "$1" | fzf -1 --exact)
  kitten @ set-colors "$themedir/$theme.conf"
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
