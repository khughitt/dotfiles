#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

# A scratch repository that mirrors the one shape the check guards against:
# a tracked symlink whose target is an absolute path into this machine.
make_repo() {
  local repo
  repo=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-layout.XXXXXX")
  register_tmp_cleanup "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  print -- "$repo"
}

run_check() {
  set +e
  output=$("${repo_root}/bin/dotfiles-layout-check" "$1" 2>&1)
  exit_status=$?
  set -e
}

repo=$(make_repo)
mkdir -p "${repo}/bin"
# Relative targets are fine even when dangling: a worktree checkout has no
# sibling projects, and the check must not depend on the target existing.
ln -s ../../elsewhere/bin/tool "${repo}/bin/relative"
print -r -- '# no machine paths here' > "${repo}/note.md"
git -C "$repo" add -A
git -C "$repo" commit -qm 'clean'
run_check "$repo"
(( exit_status == 0 )) || fail "clean repository should pass: $output"

ln -s /mnt/somewhere/bin/tool "${repo}/bin/absolute"
git -C "$repo" add -A
run_check "$repo"
(( exit_status == 1 )) || fail "absolute symlink target should fail with 1, got $exit_status"
[[ "$output" == *'bin/absolute -> /mnt/somewhere/bin/tool'* ]] || \
  fail "failure should name the link and its target: $output"

# Staged but uncommitted links count: the check runs before the commit lands.
git -C "$repo" rm -q --cached bin/absolute
rm "${repo}/bin/absolute"
run_check "$repo"
(( exit_status == 0 )) || fail "removing the absolute link should pass again: $output"

# The live tree must satisfy its own guard.
run_check "$repo_root"
(( exit_status == 0 )) || fail "dotfiles tree has machine-specific symlink targets: $output"

print -- 'layout-check tests passed'
