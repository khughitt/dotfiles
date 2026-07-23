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

modeline_files=(
  zshrc
  shell/aliases
  shell/audio
  shell/functions
  shell/history
  shell/kitty
  shell/macos
  shell/tmux
  shell/ubuntu
  shell/vconsole
  shell/vi
  shell/wali
  shell/zoxide
)

for file in "${modeline_files[@]}"; do
  output=$(
    nvim --headless -i NONE -u NONE \
      --cmd 'set noswapfile' \
      --cmd 'filetype on' \
      --cmd 'syntax on' \
      "${repo_root}/${file}" \
      '+lua print("DOTFILES_FT:" .. vim.bo.filetype .. ":" .. vim.bo.syntax)' \
      '+qa!' 2>&1
  )

  [[ "$output" == "DOTFILES_FT:zsh:zsh" ]] || \
    fail "Neovim did not load ${file} cleanly as zsh: ${output}"
done

zsh -fc '
  source "$1/shell/aliases"
  source "$1/shell/functions"

  alias dropbox_ignore | rg -q "attr -s com.dropbox.ignored -V 1"
  alias dropbox_ignore | rg -vq "sudo"
  alias vi | rg -q "nvim"
  alias whatip | rg -Fq "curl --fail --silent --show-error https://api.ipify.org" \
    || exit 21
  if alias whatip | rg -Fq "http://"; then
    exit 22
  fi
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
