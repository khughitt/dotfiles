#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

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
  shell/macos
  shell/tmux
  shell/ubuntu
  shell/vconsole
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

nvim --headless -i NONE -u "${repo_root}/nvim/init.lua" --cmd 'set noswapfile' \
  "+lua dofile('${repo_root}/nvim/tests/clipboard_test.lua')" '+qa!'

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

zinit_data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
zdotdir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zdotdir.XXXXXX")
register_tmp_cleanup "$zdotdir"
mkdir -p "${zdotdir}/cache" "${zdotdir}/config" "${zdotdir}/state"
ln -s "${repo_root}/zshrc" "${zdotdir}/.zshrc"
ln -s "${repo_root}/shell" "${zdotdir}/.shell"
export DOTFILES="$repo_root"
export HOME="$zdotdir"
export XDG_CACHE_HOME="${zdotdir}/cache"
export XDG_CONFIG_HOME="${zdotdir}/config"
export XDG_DATA_HOME="$zinit_data_home"
export XDG_STATE_HOME="${zdotdir}/state"
export ZDOTDIR="$zdotdir"

zsh -ic '
  @zinit-scheduler burst
  [[ -o hist_find_no_dups ]] || exit 32
  [[ -o hist_save_no_dups ]] || exit 33
' || fail "interactive zsh enhancements are not loaded"

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
