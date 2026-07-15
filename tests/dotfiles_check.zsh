#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_ignored() {
  git -C "$repo_root" check-ignore -q --no-index "$1" || \
    fail "expected ignored secret path: $1"
}

assert_not_ignored() {
  if git -C "$repo_root" check-ignore -q --no-index "$1"; then
    fail "expected allowed example path: $1"
  fi
}

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

for secret_path in \
  .env \
  .env.local \
  .env.production \
  host.pem \
  host.key \
  id_ed25519 \
  .netrc \
  .npmrc \
  kubeconfig \
  kubeconfig.work; do
  assert_ignored "$secret_path"
done

assert_not_ignored .env.example
assert_not_ignored .env.production.example

rg -q '^X-Auth-CouchDB-Token: xxx$' "${repo_root}/cheatsheets/curl" || \
  fail "expected CouchDB cheatsheet to use the non-secret fixture"

print -- "dotfiles check test passed"
