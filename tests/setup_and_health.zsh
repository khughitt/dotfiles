#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

make_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX"
}

test_tmp_cleanup_is_centralized() {
  local output exit_status

  set +e
  output=$(
    rg -n '^[[:space:]]*trap([[:space:]]|$)' \
      "${repo_root}/tests/setup_and_health.zsh" \
      "${repo_root}/tests/dropbox_ignore_flux.zsh" 2>&1
  )
  exit_status=$?
  set -e

  if (( exit_status == 0 )); then
    fail "test harnesses should not install traps:
${output}"
  fi
  (( exit_status == 1 )) || fail "failed to scan test harness traps: ${output}"
}

test_tmp_cleanup_runs_only_at_process_exit() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"

  set +e
  output=$(
    zsh -fc '
      set -euo pipefail
      source "$1"

      exercise_cleanup() {
        local tmp="$1"
        register_tmp_cleanup "$tmp"
        [[ -d "$tmp" ]] || {
          print -u2 -- "temporary directory removed during registration"
          exit 91
        }
        print -- registered > "${tmp}/after-register"
        exit 17
      }

      exercise_cleanup "$2"
    ' zsh "${repo_root}/tests/tmp_cleanup.zsh" "$tmp" 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 17 ]] || \
    fail "cleanup subprocess should preserve status 17, got ${exit_status}: ${output}"
  [[ ! -e "$tmp" ]] || fail "cleanup subprocess should remove its registered directory"
  [[ "$output" != *"parameter not set"* ]] || \
    fail "cleanup subprocess referenced an expired local variable: ${output}"
  [[ -z "$output" ]] || fail "cleanup subprocess wrote unexpected output: ${output}"
}

run_setup() {
  local tmp="$1"
  shift

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    bash "${repo_root}/setup.sh" "$@"
}

test_bash_config_is_native_and_minimal() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home"

  if ! env -i \
      HOME="${tmp}/home" \
      HISTFILE="${tmp}/home/.bash_history" \
      PATH=/usr/bin:/bin \
      TERM=xterm-256color \
      bash --noprofile --rcfile "${repo_root}/bashrc" -i -c '
        set -euo pipefail

        [[ "$PATH" == "$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/usr/bin:/bin" ]]
        [[ "$EDITOR" == nvim ]]
        [[ "$PAGER" == less ]]
        [[ "$HISTCONTROL" == ignoreboth:erasedups ]]
        [[ "$HISTSIZE" == 10000 ]]
        [[ "$HISTFILESIZE" == 100000 ]]
        [[ "$PROMPT_COMMAND" == "history -a; history -n" ]]
        shopt -q histappend
        shopt -q checkwinsize
        [[ "$PS1" == "$1" ]]

        backward=$(bind -q history-search-backward)
        forward=$(bind -q history-search-forward)
        [[ "$backward" == *"$2"* && "$backward" == *"$3"* ]]
        [[ "$forward" == *"$4"* && "$forward" == *"$5"* ]]
      ' bash '\u@\h:\w\$ ' '\eOA' '\e[A' '\eOB' '\e[B' \
      2>/dev/null; then
    fail "bashrc should configure the native interactive environment"
  fi

  if ! env -i HOME="${tmp}/home" PATH=/usr/bin:/bin \
      bash --noprofile --norc -c '
        source "$1"
        [[ "$PATH" == /usr/bin:/bin ]]
        [[ -z "${EDITOR+x}" ]]
        [[ -z "${PAGER+x}" ]]
      ' bash "${repo_root}/bashrc"; then
    fail "bashrc should leave non-interactive shells unchanged"
  fi

  rm -rf "$tmp"
}

test_setup_dry_run_link_only_does_not_write_home() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless)

  [[ "$output" == *"[DRY-RUN]"* ]] || fail "expected dry-run output"
  [[ "$output" == *"==> Shell links"* ]] || fail "expected shell links phase"
  [[ "$output" == *"==> Systemd user units"* ]] || fail "expected systemd user units phase"
  [[ "$output" == *"==> Package installation"* ]] || fail "expected package installation phase"
  [[ ! -e "${tmp}/home/.bashrc" ]] || fail "dry-run should not create ~/.bashrc"
  [[ ! -e "${tmp}/home/.bash_profile" ]] || fail "dry-run should not create ~/.bash_profile"
  [[ ! -e "${tmp}/home/.zshrc" ]] || fail "dry-run should not create ~/.zshrc"
  [[ ! -e "${tmp}/home/.shell" ]] || fail "dry-run should not create ~/.shell"
  [[ ! -e "${tmp}/config/systemd/user/dropbox-ignore-flux.timer" ]] || \
    fail "dry-run should not link systemd user timer"
  [[ ! -e "${tmp}/data/zinit" ]] || fail "link-only dry-run should not clone zinit"

  rm -rf "$tmp"
}

test_setup_link_only_creates_expected_links_without_external_clones() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  [[ -L "${tmp}/home/.bashrc" ]] || fail "expected ~/.bashrc symlink"
  [[ "$(readlink "${tmp}/home/.bashrc")" == "${repo_root}/bashrc" ]] || \
    fail "expected ~/.bashrc to point at repo bashrc"
  [[ -L "${tmp}/home/.bash_profile" ]] || fail "expected ~/.bash_profile symlink"
  [[ "$(readlink "${tmp}/home/.bash_profile")" == "${repo_root}/bash_profile" ]] || \
    fail "expected ~/.bash_profile to point at repo bash_profile"
  [[ -L "${tmp}/home/.zshrc" ]] || fail "expected ~/.zshrc symlink"
  [[ "$(readlink "${tmp}/home/.zshrc")" == "${repo_root}/zshrc" ]] || \
    fail "expected ~/.zshrc to point at repo zshrc"
  [[ -L "${tmp}/home/.shell" ]] || fail "expected ~/.shell symlink"
  [[ -L "${tmp}/config/systemd/user/dropbox-ignore-flux.timer" ]] || \
    fail "expected linked Dropbox ignore timer"
  [[ ! -e "${tmp}/data/zinit" ]] || fail "link-only should not clone zinit"
  [[ ! -e "${tmp}/home/.tmux/plugins/tpm" ]] || fail "link-only should not clone tpm"

  rm -rf "$tmp"
}

test_setup_dry_run_can_enable_user_timers() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --enable-user-timers)

  [[ "$output" == *"systemctl --user daemon-reload"* ]] || \
    fail "expected dry-run daemon-reload command"
  [[ "$output" == *"systemctl --user enable --now dropbox-ignore-flux.timer"* ]] || \
    fail "expected dry-run timer enable command"

  rm -rf "$tmp"
}

test_setup_only_runs_selected_phase() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --only shell)

  [[ "$output" == *"Only phases: shell"* ]] || fail "expected selected phase summary"
  [[ "$output" == *"==> Shell links"* ]] || fail "expected selected shell phase"
  [[ "$output" != *"==> Common config links"* ]] || fail "should skip unselected common config phase"
  [[ "$output" != *"==> Systemd user units"* ]] || fail "should skip unselected systemd phase"
  [[ "$output" != *"==> Package installation"* ]] || fail "should skip unselected package phase"

  rm -rf "$tmp"
}

test_setup_only_accepts_multiple_phases() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(run_setup "$tmp" --dry-run --link-only --headless --only shell,systemd)

  [[ "$output" == *"Only phases: shell systemd"* ]] || fail "expected multiple selected phases"
  [[ "$output" == *"==> Shell links"* ]] || fail "expected shell phase"
  [[ "$output" == *"==> Systemd user units"* ]] || fail "expected systemd phase"
  [[ "$output" != *"==> Common config links"* ]] || fail "should skip common config phase"

  rm -rf "$tmp"
}

test_setup_only_rejects_unknown_phase() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  set +e
  output=$(run_setup "$tmp" --dry-run --link-only --headless --only missing 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "setup should reject unknown phases"
  [[ "$output" == *"Unknown setup phase: missing"* ]] || fail "expected unknown phase message"

  rm -rf "$tmp"
}

test_setup_and_health_share_managed_link_metadata() {
  local metadata="${repo_root}/lib/dotfiles-setup-data.bash"

  [[ -f "$metadata" ]] || fail "expected shared setup metadata file"
  bash -n "$metadata"

  bash -c '
    set -euo pipefail
    source "$1"
    [[ "${DOTFILES_COMMON_CONFIGS[*]}" == *"kitty"* ]]
    [[ "${DOTFILES_COMMON_CONFIGS[*]}" == *"nvim"* ]]
    [[ "${DOTFILES_COMMON_CONFIGS[*]}" == *"fcitx"* ]]
    [[ "${DOTFILES_MACOS_EXCLUDED_COMMON_CONFIGS[*]}" == *"mimeapps.list"* ]]
    [[ "${DOTFILES_COMMON_DOTFILES[*]}" == *"tmux.conf"* ]]
  ' bash "$metadata"

  rg -q 'dotfiles-setup-data.bash' "${repo_root}/setup.sh" || \
    fail "setup.sh should source shared setup metadata"
  rg -q 'dotfiles-setup-data.bash' "${repo_root}/bin/dotfiles-health" || \
    fail "dotfiles-health should source shared setup metadata"
  ! rg -q -F 'COMMON_CONFIGS=("fcitx"' "${repo_root}/setup.sh" || \
    fail "setup.sh should not hardcode common config links"
  ! rg -q -F 'COMMON_CONFIGS=("git"' "${repo_root}/setup.sh" || \
    fail "setup.sh should not hardcode common config links"
  ! rg -q -F 'managed_config_links=(git' "${repo_root}/bin/dotfiles-health" || \
    fail "dotfiles-health should not hardcode managed config links"
  ! rg -q -F 'managed_config_links=("git"' "${repo_root}/bin/dotfiles-health" || \
    fail "dotfiles-health should not hardcode managed config links"
}

test_dotfiles_health_passes_after_link_only_setup() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    "${repo_root}/bin/dotfiles-health" --skip-systemd >/dev/null

  rm -rf "$tmp"
}

test_dotfiles_health_fails_stale_removed_config_links() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
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
}

test_dotfiles_health_ignores_brave_runtime_symlinks() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
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
}

test_dotfiles_health_ignores_unmanaged_config_symlinks() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
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
}

test_dotfiles_health_fails_broken_managed_config_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
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
}

test_dotfiles_health_checks_enabled_user_timer() {
  local tmp mockbin systemctl_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
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
}

test_setup_graphical_app_config_links_memory_alert() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --only app-config >/dev/null

  local plugin_link="${tmp}/config/noctalia/plugins/memory-pressure-alert"
  [[ -L "$plugin_link" ]] || fail "expected linked memory pressure alert plugin"
  [[ "$(readlink "$plugin_link")" == \
      "${repo_root}/noctalia/plugins/memory-pressure-alert" ]] || \
    fail "expected memory alert plugin to point into the repository"

  rm -rf "$tmp"
}

test_dotfiles_health_fails_wrong_memory_alert_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  run_setup "$tmp" --link-only --only app-config >/dev/null
  rm "${tmp}/config/noctalia/plugins/memory-pressure-alert"
  ln -s "${repo_root}/noctalia/plugins/wali-panel" \
    "${tmp}/config/noctalia/plugins/memory-pressure-alert"

  set +e
  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health should reject the wrong memory alert link"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "expected wrong memory alert link failure"

  rm -rf "$tmp"
}

test_tmp_cleanup_runs_only_at_process_exit
test_tmp_cleanup_is_centralized
test_bash_config_is_native_and_minimal
test_setup_dry_run_link_only_does_not_write_home
test_setup_link_only_creates_expected_links_without_external_clones
test_setup_dry_run_can_enable_user_timers
test_setup_only_runs_selected_phase
test_setup_only_accepts_multiple_phases
test_setup_only_rejects_unknown_phase
test_setup_and_health_share_managed_link_metadata
test_dotfiles_health_passes_after_link_only_setup
test_dotfiles_health_fails_stale_removed_config_links
test_dotfiles_health_ignores_brave_runtime_symlinks
test_dotfiles_health_ignores_unmanaged_config_symlinks
test_dotfiles_health_fails_broken_managed_config_link
test_dotfiles_health_checks_enabled_user_timer
test_setup_graphical_app_config_links_memory_alert
test_dotfiles_health_fails_wrong_memory_alert_link

print -- "setup and health tests passed"
