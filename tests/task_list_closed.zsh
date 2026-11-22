#!/usr/bin/env zsh
set -e

repo_root=${0:A:h:h}

source "$repo_root/shell/aliases.d/dev.zsh"

# Replace ta after sourcing so the test never queries the terminal palette.
ta() { print -r -- "$*"; }

[[ $(tal) == 'list' ]]
[[ $(tal --sort updated) == 'list --sort updated' ]]
[[ $(tal --status done --sort created) == 'list --status done --sort created' ]]

all='--status idea --status todo --status doing --status blocked --status shelved --status done --status dropped --status moved'
[[ $(tal -c) == "list $all" ]]
[[ $(tal --closed --tag cli) == "list --tag cli $all" ]]

if tal -c --status done >/dev/null 2>&1; then
  print -u2 'tal --closed should reject an explicit --status'
  exit 1
fi
if tal --closed --status=done >/dev/null 2>&1; then
  print -u2 'tal --closed should reject --status=VALUE'
  exit 1
fi
