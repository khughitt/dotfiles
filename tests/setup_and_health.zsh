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
  [[ "$output" == *"==> Shell links"* ]] || fail "expected shell links phase"
  [[ "$output" == *"==> Systemd user units"* ]] || fail "expected systemd user units phase"
  [[ "$output" == *"==> Package installation"* ]] || fail "expected package installation phase"
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

test_setup_only_runs_selected_phase() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --only shell)

  [[ "$output" == *"Only phases: shell"* ]] || fail "expected selected phase summary"
  [[ "$output" == *"==> Shell links"* ]] || fail "expected selected shell phase"
  [[ "$output" != *"==> Common config links"* ]] || fail "should skip unselected common config phase"
  [[ "$output" != *"==> Systemd user units"* ]] || fail "should skip unselected systemd phase"
  [[ "$output" != *"==> Package installation"* ]] || fail "should skip unselected package phase"

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_only_accepts_multiple_phases() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --only shell,systemd)

  [[ "$output" == *"Only phases: shell systemd"* ]] || fail "expected multiple selected phases"
  [[ "$output" == *"==> Shell links"* ]] || fail "expected shell phase"
  [[ "$output" == *"==> Systemd user units"* ]] || fail "expected systemd phase"
  [[ "$output" != *"==> Common config links"* ]] || fail "should skip common config phase"

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_only_rejects_unknown_phase() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  set +e
  output=$(run_setup "$tmp" --dry-run --link-only --headless --only missing 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "setup should reject unknown phases"
  [[ "$output" == *"Unknown setup phase: missing"* ]] || fail "expected unknown phase message"

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

test_dotfiles_health_fails_stale_removed_config_links() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${repo_root}/snakemake" "${tmp}/config/snakemake"

  set +e
  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health should fail for stale managed config links"
  [[ "$output" == *"stale managed config link"* ]] || \
    fail "expected stale managed config link failure"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_ignores_brave_runtime_symlinks() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config/BraveSoftware/Brave-Browser" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${tmp}/missing-SingletonLock" "${tmp}/config/BraveSoftware/Brave-Browser/SingletonLock"
  ln -s "${tmp}/missing-SingletonCookie" "${tmp}/config/BraveSoftware/Brave-Browser/SingletonCookie"

  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )

  [[ "$output" != *"SingletonLock"* ]] || fail "health should ignore Brave SingletonLock"
  [[ "$output" != *"SingletonCookie"* ]] || fail "health should ignore Brave SingletonCookie"
  [[ "$output" != *"[WARN] broken symlinks under"* ]] || fail "health should not warn for ignored Brave symlinks"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_ignores_unmanaged_config_symlinks() {
  local tmp output
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config/unmanaged-app" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${tmp}/missing-runtime-link" "${tmp}/config/unmanaged-app/runtime-link"

  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )

  [[ "$output" != *"unmanaged-app"* ]] || fail "health should ignore unmanaged config symlinks"
  [[ "$output" != *"[WARN] broken symlinks under"* ]] || fail "health should not scan all config symlinks"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_fails_broken_managed_config_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  rm "${tmp}/config/kitty"
  ln -s "${tmp}/missing-kitty" "${tmp}/config/kitty"

  set +e
  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health should fail for broken managed config links"
  [[ "$output" == *"wrong link target"* || "$output" == *"broken link"* ]] || \
    fail "expected broken managed config link failure"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_checks_enabled_user_timer() {
  local tmp mockbin systemctl_log
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mockbin="${tmp}/bin"
  systemctl_log="${tmp}/systemctl.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "$mockbin"

  run_setup "$tmp" --link-only --headless >/dev/null

  cat > "${mockbin}/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"

if [[ "$*" == "--user is-enabled dropbox-ignore-flux.timer" ]]; then
  printf 'enabled\n'
  exit 0
fi

if [[ "$*" == "--user list-timers dropbox-ignore-flux.timer --no-pager" ]]; then
  printf 'NEXT LEFT LAST PASSED UNIT ACTIVATES\n'
  exit 0
fi

exit 64
EOF
  chmod +x "${mockbin}/systemctl"

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    SYSTEMCTL_LOG="$systemctl_log" \
    PATH="${mockbin}:$PATH" \
    "${repo_root}/bin/dotfiles-health" >/dev/null

  rg -q -- '--user is-enabled dropbox-ignore-flux.timer' "$systemctl_log" || \
    fail "expected health to query timer enabled state"
  rg -q -- '--user list-timers dropbox-ignore-flux.timer --no-pager' "$systemctl_log" || \
    fail "expected health to query timer schedule"

  rm -rf "$tmp"
  trap - EXIT
}

test_setup_dry_run_link_only_does_not_write_home
test_setup_link_only_creates_expected_links_without_external_clones
test_setup_dry_run_can_enable_user_timers
test_setup_only_runs_selected_phase
test_setup_only_accepts_multiple_phases
test_setup_only_rejects_unknown_phase
test_dotfiles_health_passes_after_link_only_setup
test_dotfiles_health_fails_stale_removed_config_links
test_dotfiles_health_ignores_brave_runtime_symlinks
test_dotfiles_health_ignores_unmanaged_config_symlinks
test_dotfiles_health_fails_broken_managed_config_link
test_dotfiles_health_checks_enabled_user_timer

print -- "setup and health tests passed"
