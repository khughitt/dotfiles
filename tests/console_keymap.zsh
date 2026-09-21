#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

# `loadkeys -m` compiles a keymap to a C table without touching a console, so
# the map can be checked from any shell. The Alt column of each cursor key must
# point at a string entry (KT_FN, 0xf1xx), not at the plain keysym the stock
# map replicates there, and the strings must be the xterm modifier sequences
# tmux decodes as M-<key>.
table=$(loadkeys -m "${repo_root}/kbd/us-tmux.map") || fail "kbd/us-tmux.map does not compile"

alt_column() {
  local keycode="$1"
  print -r -- "$table" \
    | sed -n '/^static unsigned short alt_map\[NR_KEYS\] = {/,/^};/p' \
    | grep -o '0x[0-9a-f]\{4\}' \
    | sed -n "$((keycode + 1))p"
}

for entry in 103:Up 108:Down 106:Right 105:Left 104:PageUp 109:PageDown; do
  keycode=${entry%%:*}
  label=${entry#*:}
  value=$(alt_column "$keycode")
  [[ "$value" == 0xf1* ]] || fail "Alt+${label} (keycode ${keycode}) is ${value}, not a string entry"
done

# Each func_buf line is one string, e.g. '\033', '[', '1', ';', '3', 'A', 0,
strings=$(print -r -- "$table" | sed -n "/^char func_buf\[\] = {/,/^};/p" | tr -d " '")
for seq in '\033,[,1,;,3,A,0,' '\033,[,1,;,3,B,0,' '\033,[,1,;,3,C,0,' '\033,[,1,;,3,D,0,' \
           '\033,[,5,;,3,~,0,' '\033,[,6,;,3,~,0,'; do
  [[ "$strings" == *"$seq"* ]] || fail "missing string ${(q)seq} in compiled keymap"
done

print -- "console keymap tests passed"
