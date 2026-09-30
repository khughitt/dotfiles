#!/usr/bin/env zsh
set -e

repo_root=${0:A:h:h}

tasks() {
  [[ "$*" == 'list --json --status todo' ]] || return 42
  print -r -- '{"tasks":[{"id":"a","title":"Alpha"},{"id":"b","body":"second ALPHA note"},{"id":"c","title":"Gamma"}],"warnings":["sample"]}'
}

source "$repo_root/shell/aliases.d/dev.zsh"

result=$(taj alpha --status todo)
[[ $(print -r -- "$result" | jq -c '[.tasks[].id]') == '["a","b"]' ]]
[[ $(print -r -- "$result" | jq -c '.warnings') == '["sample"]' ]]
[[ $(taj title --status todo | jq -c '.tasks') == '[]' ]]

if taj >/dev/null 2>&1; then
  print -u2 'taj should require a search pattern'
  exit 1
fi

if taj alpha --status doing >/dev/null 2>&1; then
  print -u2 'taj should report tasks list failures'
  exit 1
fi
