#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

make_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX"
}

run_setup() {
  local tmp="$1"
  shift

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    bash "${repo_root}/setup.sh" "$@"
}

test_setup_dry_run_link_only_does_not_write_home() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless)

  [[ "$output" == *"[DRY-RUN]"* ]] || fail "expected dry-run output"
  [[ ! -e "${tmp}/home/.zshrc" ]] || fail "dry-run should not create ~/.zshrc"
  [[ ! -e "${tmp}/home/.shell" ]] || fail "dry-run should not create ~/.shell"
  [[ ! -e "${tmp}/config/systemd/user/dropbox-ignore-flux.timer" ]] || \
    fail "dry-run should not link systemd user timer"
  [[ ! -e "${tmp}/data/zinit" ]] || fail "link-only dry-run should not clone zinit"

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_link_only_creates_expected_links_without_external_clones() {
  local tmp
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  [[ -L "${tmp}/home/.zshrc" ]] || fail "expected ~/.zshrc symlink"
  [[ "$(readlink "${tmp}/home/.zshrc")" == "${repo_root}/zshrc" ]] || \
    fail "expected ~/.zshrc to point at repo zshrc"
  [[ -L "${tmp}/home/.shell" ]] || fail "expected ~/.shell symlink"
  [[ -L "${tmp}/config/systemd/user/dropbox-ignore-flux.timer" ]] || \
    fail "expected linked Dropbox ignore timer"
  [[ ! -e "${tmp}/data/zinit" ]] || fail "link-only should not clone zinit"
  [[ ! -e "${tmp}/home/.tmux/plugins/tpm" ]] || fail "link-only should not clone tpm"

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_dry_run_can_enable_user_timers() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --enable-user-timers)

  [[ "$output" == *"systemctl --user daemon-reload"* ]] || \
    fail "expected dry-run daemon-reload command"
  [[ "$output" == *"systemctl --user enable --now dropbox-ignore-flux.timer"* ]] || \
    fail "expected dry-run timer enable command"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_passes_after_link_only_setup() {
  local tmp
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    "${repo_root}/bin/dotfiles-health" --skip-systemd >/dev/null

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_dry_run_link_only_does_not_write_home
test_setup_link_only_creates_expected_links_without_external_clones
test_setup_dry_run_can_enable_user_timers
test_dotfiles_health_passes_after_link_only_setup

print -- "setup and health tests passed"
