#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-history.XXXXXX")
register_tmp_cleanup "$tmp"
export HOME="$tmp"

source "${repo_root}/shell/history"

[[ -o hist_ignore_space ]] || fail 'HIST_IGNORE_SPACE should be enabled'

set +e
zshaddhistory $'echo visible\n'
normal_status=$?
set -e
(( normal_status == 0 )) || fail 'normal history hook path should return success'

[[ -f "${HOME}/.zsh_history_ext" ]] || fail 'normal command should create extended history'
rg -q '^echo visible\|' "${HOME}/.zsh_history_ext" || \
  fail 'normal command missing from extended history'
[[ "$(stat -c '%a' "${HOME}/.zsh_history_ext")" == 600 ]] || \
  fail 'new extended history should use mode 600'

set +e
zshaddhistory $' echo hidden\n'
hidden_status=$?
set -e
(( hidden_status == 0 )) || fail 'leading-space hook path should return success'
! rg -q 'echo hidden' "${HOME}/.zsh_history_ext" || \
  fail 'leading-space command should not enter extended history'

print -- 'history tests passed'
