#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

"${repo_root}/bin/dotfiles-check"

print -- "dotfiles check test passed"
