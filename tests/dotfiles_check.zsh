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

for manifest in install.toml install-linux.toml install-graphical.toml; do
  [[ -f "${repo_root}/${manifest}" ]] || fail "missing manifest: ${manifest}"
done
python3 -c 'import sys, tomllib; [tomllib.load(open(f, "rb")) for f in sys.argv[1:]]' \
  "${repo_root}/install.toml" \
  "${repo_root}/install-linux.toml" \
  "${repo_root}/install-graphical.toml" || fail "manifests failed to parse as TOML"

# bin/prism and bin/walictl are wrappers rather than symlinks so the tree
# carries no path to the target checkouts: registered project roots come from
# `tasks projects --paths --json`, falling back to `${WORKTREE_SCAN_ROOT:-$HOME/d}`.
[[ ! -L "${repo_root}/bin/prism" ]] || fail "bin/prism must be a wrapper, not a symlink"
[[ ! -L "${repo_root}/bin/walictl" ]] || fail "bin/walictl must be a wrapper, not a symlink"
prism_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-prism-home.XXXXXX")
register_tmp_cleanup "$prism_home"
relocated=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-relocated.XXXXXX")
register_tmp_cleanup "$relocated"
ext_cfg=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-ext-cfg.XXXXXX")
register_tmp_cleanup "$ext_cfg"
no_tasks_bin=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-no-tasks-bin.XXXXXX")
register_tmp_cleanup "$no_tasks_bin"
stub_bin=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stub-tasks.XXXXXX")
register_tmp_cleanup "$stub_bin"
ln -s "$(command -v python3)" "${no_tasks_bin}/python3"

mkdir -p "${prism_home}/d/prism/bin" "${prism_home}/d/wali/bin" \
  "${relocated}/prism/bin" "${relocated}/wali/bin" "${relocated}/alert"
print -r -- '#!/usr/bin/env bash
printf "%s\n" "$@"' > "${prism_home}/d/prism/bin/prism"
chmod +x "${prism_home}/d/prism/bin/prism"
print -r -- '#!/usr/bin/env bash
printf "fallback-wali:%s\n" "$*"' > "${prism_home}/d/wali/bin/walictl"
chmod +x "${prism_home}/d/wali/bin/walictl"
print -r -- '#!/usr/bin/env bash
printf "relocated-prism:%s\n" "$*"' > "${relocated}/prism/bin/prism"
chmod +x "${relocated}/prism/bin/prism"
print -r -- '#!/usr/bin/env bash
printf "relocated-wali:%s\n" "$*"' > "${relocated}/wali/bin/walictl"
chmod +x "${relocated}/wali/bin/walictl"

run_isolated() {
  local path_val="$1" cfg_val="$2"
  shift 2
  env -i \
    "PATH=$path_val" \
    "HOME=$prism_home" \
    "XDG_CONFIG_HOME=$cfg_val" \
    "WORKTREE_SCAN_ROOT=${prism_home}/d" \
    "GIT_CONFIG_GLOBAL=/dev/null" \
    "GIT_CONFIG_NOSYSTEM=1" \
    "LANG=C.UTF-8" \
    "TERM=dumb" \
    "$@"
}

no_tasks_path="${no_tasks_bin}:/usr/bin:/bin"
stub_tasks_path="${stub_bin}:${no_tasks_bin}:/usr/bin:/bin"

# Fallback when `tasks` is absent from PATH
prism_output=$(run_isolated "$no_tasks_path" "${prism_home}/.config" "${repo_root}/bin/prism" apply "two words")
[[ "$prism_output" == $'apply\ntwo words' ]] || \
  fail "prism wrapper did not forward arguments on fallback: $prism_output"
wali_output=$(run_isolated "$no_tasks_path" "${prism_home}/.config" "${repo_root}/bin/walictl" observe)
[[ "$wali_output" == "fallback-wali:observe" ]] || \
  fail "walictl wrapper did not fall back when tasks is absent: $wali_output"
pressure_root=$(run_isolated "$no_tasks_path" "${prism_home}/.config" bash -c 'source "$1/lib/dotfiles-setup-data.bash" && dotfiles_project_root pressure' bash "$repo_root")
[[ "$pressure_root" == "${prism_home}/d/noctalia-resource-alert" ]] || \
  fail "dotfiles_project_root did not fall back when tasks is absent: $pressure_root"

# Resolution via `tasks projects --paths --json` with external XDG_CONFIG_HOME
cat > "${stub_bin}/tasks" <<EOF
#!/usr/bin/env bash
if [[ "\$1 \$2 \$3" != "projects --paths --json" ]]; then
  echo "unexpected tasks args: \$*" >&2
  exit 1
fi
if [[ "\${XDG_CONFIG_HOME:-}" != "${ext_cfg}" ]]; then
  echo "expected XDG_CONFIG_HOME=${ext_cfg}, got \${XDG_CONFIG_HOME:-}" >&2
  exit 1
fi
case "\${TASKS_STUB_MODE:-registered}" in
  registered)
    printf '%s\n' '{"projects":[{"prefix":"prism","root":"${relocated}/prism"},{"prefix":"wali","root":"${relocated}/wali"},{"prefix":"pressure","root":"${relocated}/alert"}],"warnings":[]}'
    ;;
  empty)
    printf '%s\n' '{"projects":[],"warnings":[]}'
    ;;
  nonzero)
    echo "tasks registry failure" >&2
    exit 1
    ;;
  bad_json)
    printf '%s\n' '{not-json'
    ;;
  bare_list)
    printf '%s\n' '[{"prefix":"prism","root":"${relocated}/prism"}]'
    ;;
esac
EOF
chmod +x "${stub_bin}/tasks"

prism_relocated=$(run_isolated "$stub_tasks_path" "$ext_cfg" "${repo_root}/bin/prism" apply "two words")
[[ "$prism_relocated" == "relocated-prism:apply two words" ]] || \
  fail "bin/prism did not resolve relocated checkout via tasks: $prism_relocated"
wali_relocated=$(run_isolated "$stub_tasks_path" "$ext_cfg" "${repo_root}/bin/walictl" observe)
[[ "$wali_relocated" == "relocated-wali:observe" ]] || \
  fail "bin/walictl did not resolve relocated checkout via tasks: $wali_relocated"
pressure_relocated=$(run_isolated "$stub_tasks_path" "$ext_cfg" bash -c 'source "$1/lib/dotfiles-setup-data.bash" && dotfiles_project_root pressure' bash "$repo_root")
[[ "$pressure_relocated" == "${relocated}/alert" ]] || \
  fail "dotfiles_project_root did not resolve relocated checkout via tasks: $pressure_relocated"

# Fallback when valid `{"projects":[],"warnings":[]}` omits the queried prefix
prism_empty=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE=empty "${repo_root}/bin/prism" apply "two words")
[[ "$prism_empty" == $'apply\ntwo words' ]] || \
  fail "bin/prism did not fall back on empty projects list: $prism_empty"
wali_empty=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE=empty "${repo_root}/bin/walictl" observe)
[[ "$wali_empty" == "fallback-wali:observe" ]] || \
  fail "bin/walictl did not fall back on empty projects list: $wali_empty"
pressure_empty=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE=empty bash -c 'source "$1/lib/dotfiles-setup-data.bash" && dotfiles_project_root pressure' bash "$repo_root")
[[ "$pressure_empty" == "${prism_home}/d/noctalia-resource-alert" ]] || \
  fail "dotfiles_project_root did not fall back on empty projects list: $pressure_empty"

# Strict failure without fallback when tasks fails or outputs malformed/non-dict JSON
for mode in nonzero bad_json bare_list; do
  if err_out=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE="$mode" "${repo_root}/bin/prism" apply "two words" 2>&1); then
    fail "bin/prism unexpectedly succeeded under TASKS_STUB_MODE=${mode}: $err_out"
  fi
  [[ -n "$err_out" && "$err_out" != *$'apply\ntwo words'* ]] || \
    fail "bin/prism did not report error without fallback under ${mode}: $err_out"

  if err_out=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE="$mode" "${repo_root}/bin/walictl" observe 2>&1); then
    fail "bin/walictl unexpectedly succeeded under TASKS_STUB_MODE=${mode}: $err_out"
  fi
  [[ -n "$err_out" && "$err_out" != *"fallback-wali"* ]] || \
    fail "bin/walictl did not report error without fallback under ${mode}: $err_out"

  if err_out=$(run_isolated "$stub_tasks_path" "$ext_cfg" env TASKS_STUB_MODE="$mode" bash -c 'source "$1/lib/dotfiles-setup-data.bash" && dotfiles_project_root pressure' bash "$repo_root" 2>&1); then
    fail "dotfiles_project_root unexpectedly succeeded under TASKS_STUB_MODE=${mode}: $err_out"
  fi
  [[ -n "$err_out" && "$err_out" != *"${prism_home}/d"* ]] || \
    fail "dotfiles_project_root did not report error without fallback under ${mode}: $err_out"
done

# Per-file symlink root resolution in ~/bin
mkdir -p "${prism_home}/bin"
ln -s "${repo_root}/bin/dotfiles-check" "${prism_home}/bin/dotfiles-check"
run_isolated "$PATH" "${prism_home}/.config" "${prism_home}/bin/dotfiles-check" >/dev/null || \
  fail "per-file symlink ${prism_home}/bin/dotfiles-check failed to resolve repo_root"

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

[[ ! -e "${repo_root}/nvim/plugins/science-md.nvim" ]] || \
  fail "science-md.nvim must live in its standalone repository, not nvim/plugins"

nvim_case nvim-clipboard nvim --headless -i NONE -u "${repo_root}/nvim/init.lua" --cmd 'set noswapfile' \
  "+lua dofile('${repo_root}/nvim/tests/clipboard_test.lua')" '+qa!'

nvim_case nvim-science-md nvim --headless -i NONE -u "${repo_root}/nvim/init.lua" --cmd 'set noswapfile' \
  "+lua local p = assert(require('lazy.core.config').plugins['science-md.nvim'], 'missing science-md.nvim spec'); assert(not p._.is_local, 'science-md.nvim must be managed by lazy.nvim, not local dir'); local lock = require('lazy.manage.lock').get(p); assert(lock and lock.branch == 'main' and type(lock.commit) == 'string' and #lock.commit >= 7, 'missing science-md.nvim lock entry'); require('lazy').load({ plugins = { 'science-md.nvim' } }); assert(type(require('science-md').setup) == 'function')" '+qa!'

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
