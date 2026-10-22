#!/usr/bin/env zsh
# Drives an interactive zsh through zpty and checks that `icat <partial><TAB>`
# completes image names by substring, as matcher-list does for other commands.
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-icat-completion.XXXXXX")
register_tmp_cleanup "$tmp"

mkdir -p "$tmp/home" "$tmp/probe"
touch "$tmp/probe/forge-0e720e-"{abstract-states,channels,density,styles}.png
touch "$tmp/probe/forge-0e720e-density.txt"

zmodload zsh/zpty

zpty -b icatz env -i PATH="$PATH" HOME="$tmp/home" TERM=dumb zsh -f -i
trap 'zpty -d icatz 2>/dev/null' EXIT

send() { zpty -w -n icatz "$1"; }

# Reads the pty until a line matches the pattern, or fails after ~10 s.
expect() {
  local pattern=$1 out='' chunk
  local -i tries=0
  while (( tries++ < 100 )); do
    if zpty -r -t icatz chunk 2>/dev/null; then
      out+=$chunk
      [[ $out == *${~pattern}* ]] && { REPLY=$out; return 0; }
    else
      sleep 0.1
    fi
  done
  fail "timed out waiting for ${pattern}; got: ${(q)out}"
}

send $'PS1=\'READY> \'; unsetopt zle_bracketed_paste\n'
send "autoload -Uz compinit && compinit -u -d ${(q)tmp}/zcompdump"$'\n'
send $'zstyle \':completion:*\' matcher-list \'m:{[:lower:][:upper:]}={[:upper:][:lower:]}\' \'r:|=*\' \'l:|=* r:|=*\'\n'
send "source ${(q)repo_root}/shell/aliases.d/desktop.zsh"$'\n'
send "source ${(q)repo_root}/shell/functions.d/media.zsh"$'\n'
# Register the completer exactly as zshrc does.
registration=$(grep -E '^compdef _icat icat( |$)' "${repo_root}/zshrc") || \
  fail 'zshrc should register _icat for icat'
send "${registration}"$'\n'
send "cd ${(q)tmp}/probe"$'\n'
send $'dump-buffer() { print -r -- "<BUF:${BUFFER}:FUB>"; }; zle -N dump-buffer; bindkey \'^X^D\' dump-buffer\n'
send $'print SETUP-DONE\n'
expect 'SETUP-DONE*READY> '

check_completion() {
  local typed=$1 expected=$2
  send "${typed}"$'\t'
  sleep 0.5
  send $'\x18\x04'
  expect '<BUF:*:FUB>'
  local buffer=${${REPLY##*<BUF:}%%:FUB>*}
  [[ $buffer == "$expected" ]] || fail "'${typed}<TAB>' gave '${buffer}', expected '${expected}'"
  send $'\x15'
}

# Control: plain file completion matches a mid-name substring through matcher-list.
check_completion 'ls abs' 'ls forge-0e720e-abstract-states.png '
# A substring from the middle of the name completes, as `ls den<TAB>` does; the
# .txt with the same substring is not an image and is not offered.
check_completion 'icat den' 'icat forge-0e720e-density.png '
# A leading prefix still completes.
check_completion 'icat forge-0e720e-ch' 'icat forge-0e720e-channels.png '

print -- 'icat completion tests passed'
