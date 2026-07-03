#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

"${repo_root}/bin/dotfiles-check"

zsh -fc '
  source "$1/shell/aliases"
  source "$1/shell/functions"

  alias dropbox_ignore | rg -q "attr -s com.dropbox.ignored -V 1"
  alias dropbox_ignore | rg -vq "sudo"
  alias vi | rg -q "nvim"
  type pyf >/dev/null
  type yank >/dev/null
  type csvpeek >/dev/null
  type vite_proj >/dev/null
' zsh "$repo_root"

print -- "dotfiles check test passed"
