#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"
source "${repo_root}/shell/functions"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  [[ "$actual" == "$expected" ]] || fail "${label}: expected ${(qqq)expected}, got ${(qqq)actual}"
}

make_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/dropbox-ignore-flux.XXXXXX"
}

test_candidates_keep_only_top_level_matches() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"

  mkdir -p \
    "${tmp}/project/node_modules/pkg/node_modules" \
    "${tmp}/project/.venv/lib/python3.12/site-packages/pkg/node_modules" \
    "${tmp}/project/src/__pycache__" \
    "${tmp}/project/src/not_node_modules"

  local actual
  actual=$(_dropbox_ignore_flux_candidates "$tmp" node_modules .venv __pycache__)

  local expected
  expected="${tmp}/project/.venv
${tmp}/project/node_modules
${tmp}/project/src/__pycache__"

  assert_eq "$expected" "$actual" "top-level candidate filtering"
  rm -rf "$tmp"
}

test_dropbox_ignore_flux_sets_only_missing_attrs_without_sudo() {
  local tmp mockbin attr_log sudo_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mockbin="${tmp}/bin"
  attr_log="${tmp}/attr.log"
  sudo_log="${tmp}/sudo.log"

  mkdir -p \
    "$mockbin" \
    "${tmp}/already/node_modules" \
    "${tmp}/missing/.venv" \
    "${tmp}/missing/.venv/lib/python3.12/site-packages/pkg/node_modules"

  cat > "${mockbin}/attr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$ATTR_LOG"

if [[ "$1" == "-q" && "$2" == "-g" && "$3" == "com.dropbox.ignored" ]]; then
  path="${@: -1}"
  if [[ "$path" == */already/* ]]; then
    printf '1\n'
    exit 0
  fi
  exit 1
fi

if [[ "$1" == "-s" && "$2" == "com.dropbox.ignored" && "$3" == "-V" && "$4" == "1" ]]; then
  exit 0
fi

exit 64
EOF
  chmod +x "${mockbin}/attr"

  cat > "${mockbin}/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SUDO_LOG"
exit 99
EOF
  chmod +x "${mockbin}/sudo"

  ATTR_LOG="$attr_log" SUDO_LOG="$sudo_log" PATH="${mockbin}:$PATH" \
    dropbox_ignore_flux --root "$tmp" --quiet

  [[ ! -s "$sudo_log" ]] || fail "dropbox_ignore_flux should not call sudo"

  local log
  log=$(<"$attr_log")
  [[ "$log" == *"-q -g com.dropbox.ignored ${tmp}/already/node_modules"* ]] || \
    fail "expected attr check for already ignored node_modules"
  [[ "$log" == *"-q -g com.dropbox.ignored ${tmp}/missing/.venv"* ]] || \
    fail "expected attr check for missing .venv"
  [[ "$log" == *"-s com.dropbox.ignored -V 1 ${tmp}/missing/.venv"* ]] || \
    fail "expected attr set for missing .venv"
  [[ "$log" != *"-s com.dropbox.ignored -V 1 ${tmp}/already/node_modules"* ]] || \
    fail "should not set attr for already ignored node_modules"
  [[ "$log" != *"${tmp}/missing/.venv/lib/python3.12/site-packages/pkg/node_modules"* ]] || \
    fail "should not inspect nested matches under ignored parents"

  rm -rf "$tmp"
}

test_fu_finds_functions_d_modules() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  ln -s "${repo_root}/shell" "${tmp}/.shell"

  HOME="$tmp" zsh -fc 'source "$HOME/.shell/functions"; fu dropbox_ignore_flux | rg -q "dropbox_ignore_flux"'

  rm -rf "$tmp"
}

test_candidates_keep_only_top_level_matches
test_dropbox_ignore_flux_sets_only_missing_attrs_without_sudo
test_fu_finds_functions_d_modules

print -- "dropbox_ignore_flux tests passed"
