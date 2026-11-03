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

nvim_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-nvim.XXXXXX")
register_tmp_cleanup "$nvim_home"
mkdir -p "$nvim_home/config" "$nvim_home/cache" "$nvim_home/state" "$nvim_home/runtime"
ln -s "${repo_root}/nvim" "$nvim_home/config/nvim"
nvim_env=(
  "PATH=$PATH" "HOME=$nvim_home" "USER=nvim-fixture" "TERM=dumb" "LANG=C.UTF-8"
  "XDG_CONFIG_HOME=$nvim_home/config" "XDG_CACHE_HOME=$nvim_home/cache"
  "XDG_STATE_HOME=$nvim_home/state" "XDG_RUNTIME_DIR=$nvim_home/runtime"
  "XDG_DATA_HOME=${XDG_DATA_HOME:-${HOME}/.local/share}"
  "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_NOSYSTEM=1" "PYTHONDONTWRITEBYTECODE=1"
)
if [[ -n "${EVIDENCE_DIR:-}" ]]; then
  nvim_env+=("EVIDENCE_DIR=$EVIDENCE_DIR")
fi

nvim_case() {
  env -i "${nvim_env[@]}" python3 "${repo_root}/tools/test-suite.py" phase "$@"
}

"${repo_root}/bin/dotfiles-check"

mindful_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-mindful-home.XXXXXX")
register_tmp_cleanup "$mindful_home"
mindful_release="${mindful_home}/.local/share/mindful/current"
mkdir -p "${mindful_release}/bin" "${mindful_release}/packages/mindful/dist"
print -r -- '#!/usr/bin/env bash
exec bash "$1" "${@:2}"' > "${mindful_release}/bin/node"
chmod +x "${mindful_release}/bin/node"
print -r -- '#!/usr/bin/env bash
quoted=()
for arg in "$@"; do quoted+=("\"$arg\""); done
IFS=,
printf "[%s]" "${quoted[*]}"' > \
  "${mindful_release}/packages/mindful/dist/bin.js"
mindful_output=$(HOME="$mindful_home" "${repo_root}/bin/mindful" --flag "two words" 2>&1) || \
  fail "mindful wrapper failed against the stubbed release: $mindful_output"
[[ "$mindful_output" == '["--flag","two words"]' ]] || \
  fail "mindful wrapper did not forward arguments: $mindful_output"

# bin/prism is a wrapper rather than a symlink so the tree carries no path to
# the prism checkout: `~/d` is the only layout the repository assumes, and a
# worktree checkout of dotfiles still resolves it.
[[ ! -L "${repo_root}/bin/prism" ]] || fail "bin/prism must be a wrapper, not a symlink"
prism_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-prism-home.XXXXXX")
register_tmp_cleanup "$prism_home"
mkdir -p "${prism_home}/d/prism/bin"
print -r -- '#!/usr/bin/env bash
printf "%s\n" "$@"' > "${prism_home}/d/prism/bin/prism"
chmod +x "${prism_home}/d/prism/bin/prism"
prism_output=$(HOME="$prism_home" "${repo_root}/bin/prism" apply "two words")
[[ "$prism_output" == $'apply\ntwo words' ]] || \
  fail "prism wrapper did not forward arguments: $prism_output"

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
  shell/zoxide
)

for file in "${modeline_files[@]}"; do
  output=$(
    nvim_case "modeline:${file}" nvim --headless -i NONE -u NONE \
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

nvim_case nvim-clipboard nvim --headless -i NONE -u "${repo_root}/nvim/init.lua" --cmd 'set noswapfile' \
  "+lua dofile('${repo_root}/nvim/tests/clipboard_test.lua')" '+qa!'

nvim_case nvim-theme nvim --headless -i NONE -u "${repo_root}/nvim/init.lua" --cmd 'set noswapfile' \
  -l "${repo_root}/nvim/tests/theme_test.lua"

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
