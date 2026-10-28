#!/usr/bin/env zsh
# Drives an interactive zsh through zpty and checks that `glow <TAB>` offers the
# markdown files in the directory beside glow's subcommands, and that subcommands
# and flags still complete through glow's own completer.
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

command -v glow >/dev/null || fail 'glow is not installed (setup.sh installs it)'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-glow-completion.XXXXXX")
register_tmp_cleanup "$tmp"

mkdir -p "$tmp/home" "$tmp/probe"
touch "$tmp/probe/"{readme.md,readme.txt,notes.txt}

zmodload zsh/zpty

zpty -b glowz env -i PATH="$PATH" HOME="$tmp/home" TERM=dumb zsh -f -i
trap 'zpty -d glowz 2>/dev/null' EXIT

send() { zpty -w -n glowz "$1"; }

# Reads the pty until a line matches the pattern, or fails after ~10 s.
expect() {
  local pattern=$1 out='' chunk
  local -i tries=0
  while (( tries++ < 100 )); do
    if zpty -r -t glowz chunk 2>/dev/null; then
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
send "source ${(q)repo_root}/shell/functions.d/media.zsh"$'\n'
# Register the completer exactly as zshrc does.
registration=$(grep -E '^compdef _glow_markdown glow( |$)' "${repo_root}/zshrc") || \
  fail 'zshrc should register _glow_markdown for glow'
# Without interactive_comments, `#` starts no comment at an interactive prompt.
send "${registration%% \#*}"$'\n'
send "cd ${(q)tmp}/probe"$'\n'
send $'dump-buffer() { print -r -- "<BUF:${BUFFER}:FUB>"; }; zle -N dump-buffer; bindkey \'^X^D\' dump-buffer\n'
send $'print SETUP-DONE\n'
expect 'SETUP-DONE*READY> '

# Types the line and TAB, then dumps the buffer; REPLY keeps everything printed
# meanwhile, including any completion listing.
complete_line() {
  send "$1"$'\t'
  sleep 0.5
  send $'\x18\x04'
  expect '<BUF:*:FUB>'
  BUF=${${REPLY##*<BUF:}%%:FUB>*}
  send $'\x15'
}

check_completion() {
  local typed=$1 expected=$2
  complete_line "$typed"
  [[ $BUF == "$expected" ]] || fail "'${typed}<TAB>' gave '${BUF}', expected '${expected}'"
}

# An empty first argument lists the markdown files beside the subcommands, and
# leaves out files glow does not render.
complete_line 'glow '
listing=${REPLY%%<BUF:*}
[[ $listing == *readme.md* ]] || fail "'glow <TAB>' should list readme.md; got: ${(q)listing}"
[[ $listing == *config* ]] || fail "'glow <TAB>' should list the config subcommand; got: ${(q)listing}"
[[ $listing != *notes.txt* ]] || fail "'glow <TAB>' should not list notes.txt; got: ${(q)listing}"

# Only the markdown file is a candidate, so a shared stem completes it in full.
check_completion 'glow rea' 'glow readme.md '
# matcher-list's substring matching applies to the files.
check_completion 'glow adme' 'glow readme.md '
# After a subcommand, glow's own completer takes over.
check_completion 'glow completion z' 'glow completion zsh '
# Flags still complete through glow's completer.
check_completion 'glow --wi' 'glow --width '

print -- 'glow completion tests passed'
