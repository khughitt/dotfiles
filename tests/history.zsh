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

[[ ! -o hist_ignore_space ]] || fail 'HIST_IGNORE_SPACE should be disabled'

set +e
zshaddhistory $'echo visible\n'
normal_status=$?
set -e
(( normal_status == 1 )) || fail 'history hook should replace the original entry'

[[ -f "${HOME}/.zsh_history_ext" ]] || fail 'normal command should create extended history'
rg -q '^echo visible\|' "${HOME}/.zsh_history_ext" || \
  fail 'normal command missing from extended history'
[[ "$(stat -c '%a' "${HOME}/.zsh_history_ext")" == 600 ]] || \
  fail 'new extended history should use mode 600'

set +e
zshaddhistory $'   echo  spaced\n'
spaced_status=$?
set -e
(( spaced_status == 1 )) || fail 'leading-space hook should replace the original entry'
[[ "$(fc -ln "$HISTCMD")" == 'echo  spaced' ]] || \
  fail 'normal history should trim only leading whitespace'
rg -q '^echo  spaced\|' "${HOME}/.zsh_history_ext" || \
  fail 'extended history should trim only leading whitespace'

print -- 'history tests passed'
