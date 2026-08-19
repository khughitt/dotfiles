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

  mkdir -p "${tmp}/home/d/niri-glass" \
    "${tmp}/home/d/prism/integrations/noctalia-plugin" "${tmp}/bin"
  touch "${tmp}/home/d/niri-glass/shell.qml"
  cat > "${tmp}/bin/prism" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == doctor ]] || exit 64
if [[ -n "${PRISM_DOCTOR_LOG:-}" ]]; then
  printf '%s\n' "$*" >> "$PRISM_DOCTOR_LOG"
fi
if [[ "${PRISM_DOCTOR_STATUS:-0}" -ne 0 ]]; then
  printf '%s\n' "doctor: niri: generated file missing: prism.kdl" >&2
  exit "$PRISM_DOCTOR_STATUS"
fi
printf '%s\n' "doctor: ok"
EOF
  chmod +x "${tmp}/bin/prism"
  cat > "${tmp}/bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PRISM_TEST_HOSTNAME:-dotfiles-test-unconfigured}"
EOF
  chmod +x "${tmp}/bin/hostname"

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    XDG_STATE_HOME="${tmp}/home/.local/state" \
    DOTFILES_OPENCODE_RUNTIME_SOURCE="${tmp}/opencode-runtime-source" \
    PATH="${tmp}/bin:$PATH" \
    bash "${repo_root}/setup.sh" "$@"
}

run_health() {
  local tmp="$1"
  shift

  HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    XDG_STATE_HOME="${tmp}/home/.local/state" \
    PATH="${tmp}/bin:$PATH" \
    "${repo_root}/bin/dotfiles-health" "$@"
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
        [[ "$PAGER" == "less -R" ]]
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
      ' bash '\[\e[36m\]\w\[\e[33m\]\$\[\e[0m\] ' '\eOA' '\e[A' '\eOB' '\e[B' \
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

test_glow_theme_renders_color() {
  local tmp theme output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  theme="${tmp}/glow.json"

  noctalia theme --theme-json "${repo_root}/noctalia/palettes/Glow.json" --dark \
    -r "${repo_root}/noctalia/templates/glow.json:${theme}" >/dev/null 2>&1 || \
    fail "Noctalia should render the Glow stylesheet"
  output=$(print -- '# Heading' | env -u NO_COLOR CLICOLOR_FORCE=1 \
    glow --config /dev/null --style "$theme" - 2>&1) || \
    fail "Glow should load the Noctalia stylesheet: ${output}"
  [[ "$output" == *$'\e['* ]] || fail "Noctalia stylesheet should render ANSI color"

  rm -rf "$tmp"
}

test_noctalia_v5_config_contract() {
  local tmp output templates
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config/noctalia" \
    "${tmp}/cache" "${tmp}/state"
  ln -s "${repo_root}/noctalia/config.toml" \
    "${tmp}/config/noctalia/config.toml"
  ln -s "${repo_root}/noctalia/templates.toml" \
    "${tmp}/config/noctalia/templates.toml"
  ln -s "${repo_root}/noctalia/templates" \
    "${tmp}/config/noctalia/templates"

  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_CACHE_HOME="${tmp}/cache" XDG_STATE_HOME="${tmp}/state" \
    noctalia config validate "${tmp}/config/noctalia" 2>&1) || \
    fail "tracked Noctalia v5 config should validate: ${output}"
  [[ "$output" != *WARN* && "$output" != *ERROR* ]] || \
    fail "tracked Noctalia config emitted a warning or error: ${output}"

  templates=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_CACHE_HOME="${tmp}/cache" XDG_STATE_HOME="${tmp}/state" \
    noctalia theme --list-templates 2>/dev/null) || \
    fail "Noctalia should list the tracked template registry"
  for id in glow nvim claude codex ohai; do
    print -r -- "$templates" | \
      rg -q "^[[:space:]]+${id}[[:space:]]+user([[:space:]]|$)" || \
      fail "missing user template: ${id}"
  done

  python3 - "${repo_root}/noctalia/config.toml" \
    "${repo_root}/noctalia/templates.toml" <<'PY'
import sys, tomllib

config = tomllib.load(open(sys.argv[1], "rb"))
templates = tomllib.load(open(sys.argv[2], "rb"))["theme"]["templates"]
assert config["theme"] == {
    "mode": "dark", "source": "wallpaper", "wallpaper_scheme": "m3-tonal-spot"
}
assert config["wallpaper"]["automation"] == {
    "enabled": True, "interval_seconds": 900, "order": "alphabetical"
}
assert config["bar"]["default"]["start"] == ["workspaces", "cpu", "ram"]
assert config["bar"]["default"]["center"] == ["active_window"]
assert config["bar"]["default"]["end"] == [
    "tray", "battery", "notifications", "output_volume", "wallpaper", "clock"
]
assert templates["builtin_ids"] == [
    "hyprland", "gtk3", "gtk4", "qt", "niri", "ghostty", "btop"
]
assert templates["community_ids"] == ["zathura"]
assert set(templates["user"]) == {"glow", "nvim", "claude", "codex", "ohai"}
assert "kitty" not in templates["builtin_ids"]
PY
}

test_noctalia_template_hook_markers_are_reproducible() {
  [[ -f "${repo_root}/gtk-3.0/gtk.css" ]] || \
    fail "GTK 3 import stub must exist for clean setup"
  ! git -C "$repo_root" check-ignore -q --no-index gtk-3.0/gtk.css || \
    fail "GTK 3 import stub must not be ignored"
  rg -q -F '@import url("noctalia.css");' \
    "${repo_root}/gtk-3.0/gtk.css" || fail "missing GTK 3 Noctalia import"
  rg -q -F 'source = ~/.config/hypr/noctalia.conf' \
    "${repo_root}/hypr/hyprland.conf" || fail "missing v5 Hyprland source"
  ! rg -q -F 'source = ~/.config/hypr/noctalia/noctalia-colors.conf' \
    "${repo_root}/hypr/hyprland.conf" || fail "active Hyprland still sources v4 colors"
  git -C "$repo_root" check-ignore -q --no-index hypr/noctalia.conf || \
    fail "generated v5 Hyprland theme must be ignored"
}

test_compositors_use_noctalia_v5() {
  local niri="${repo_root}/niri/config.kdl"
  local hypr="${repo_root}/hypr/hyprland.conf"
  rg -q -F 'spawn-at-startup "noctalia"' "$niri" || fail "Niri does not start v5"
  rg -q -F 'spawn "noctalia" "msg" "panel-toggle" "launcher"' "$niri" || \
    fail "Niri launcher bind is not v5"
  rg -q -F 'match app-id="dev.noctalia.Noctalia"' "$niri" || \
    fail "Niri settings window is not floating"
  rg -q -F 'exec-once = noctalia' "$hypr" || fail "Hyprland does not start v5"
  rg -q -F '$ipc = noctalia msg' "$hypr" || fail "Hyprland IPC is not v5"
  ! rg -q 'noctalia-shell|qs.*noctalia' "$niri" "$hypr" || \
    fail "active compositor config still calls Noctalia v4"
}

test_noctalia_builtin_hooks_leave_managed_configs_unchanged() {
  local tmp config targets before after
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  config="${tmp}/home/.config"
  targets="${tmp}/targets"
  mkdir -p "$config" "$targets/niri" "$targets/hypr" \
    "$targets/ghostty" "$targets/gtk-3.0" "$targets/gtk-4.0" "${tmp}/bin"
  cp "${repo_root}/niri/config.kdl" "$targets/niri/config.kdl"
  cp "${repo_root}/hypr/hyprland.conf" "$targets/hypr/hyprland.conf"
  cp "${repo_root}/ghostty/config.ghostty" "$targets/ghostty/config.ghostty"
  cp "${repo_root}/gtk-3.0/gtk.css" "$targets/gtk-3.0/gtk.css"
  cp "${repo_root}/gtk-4.0/gtk.css" "$targets/gtk-4.0/gtk.css"

  ln -s "$targets/niri" "$config/niri"
  ln -s "$targets/hypr" "$config/hypr"
  mkdir -p "$config/ghostty" "$config/gtk-3.0" "$config/gtk-4.0"
  ln -s "$targets/ghostty/config.ghostty" "$config/ghostty/config.ghostty"
  ln -s "$targets/gtk-3.0/gtk.css" "$config/gtk-3.0/gtk.css"
  ln -s "$targets/gtk-4.0/gtk.css" "$config/gtk-4.0/gtk.css"
  touch "$config/gtk-3.0/noctalia.css" "$config/gtk-4.0/noctalia.css"

  for command in hyprctl gsettings dconf pgrep pkill; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "${tmp}/bin/${command}"
    chmod +x "${tmp}/bin/${command}"
  done

  before=$(find "$targets" -type f -print0 | sort -z | xargs -0 sha256sum)
  HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/niri/apply.sh apply
  HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/hyprland/apply.sh apply
  HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/ghostty/apply.sh
  HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/gtk/apply.sh dark
  after=$(find "$targets" -type f -print0 | sort -z | xargs -0 sha256sum)

  [[ "$after" == "$before" ]] || fail "a built-in hook edited a disposable target"
  [[ -L "$config/niri" && -L "$config/hypr" ]] || \
    fail "a compositor directory link was replaced"
  for managed_path in ghostty/config.ghostty gtk-3.0/gtk.css gtk-4.0/gtk.css; do
    [[ -L "$config/$managed_path" ]] || \
      fail "a managed file link was replaced: $managed_path"
  done
}

test_zsh_pager_is_ansi_aware() {
  env -i \
    HOME=/tmp \
    HOSTNAME=dotfiles-test \
    PATH=/usr/bin:/bin \
    zsh -f -c 'source "$1"; [[ "$PAGER" == "less -R" ]]' \
    zsh "${repo_root}/zshenv" || fail "zsh should configure an ANSI-aware pager"
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
  local tmp unit
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  local opencode_local="${tmp}/config/opencode.local"
  [[ "${tmp}/config/opencode" -ef "$opencode_local" ]] || \
    fail "expected OpenCode config to use machine-local backing"
  [[ "${opencode_local}/opencode.json" -ef \
      "${repo_root}/opencode/opencode.json" ]] || \
    fail "expected tracked OpenCode server config link"
  [[ "${opencode_local}/tui.json" -ef \
      "${repo_root}/opencode/tui.json" ]] || \
    fail "expected tracked OpenCode TUI config link"
  [[ -L "${opencode_local}/themes/noctalia.json" ]] || \
    fail "expected dangling-safe OpenCode theme link"

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
  [[ -L "${tmp}/config/systemd/user/niri.service.d/stop-timeout.conf" ]] || \
    fail "expected linked niri stop-timeout override"
  [[ "$(readlink "${tmp}/config/systemd/user/niri.service.d/stop-timeout.conf")" == \
      "${repo_root}/systemd/user/niri.service.d/stop-timeout.conf" ]] || \
    fail "expected niri stop-timeout override to point into the repository"
  for unit in familiar-reap.service familiar-reap.timer mindful-docker.service; do
    [[ -L "${tmp}/config/systemd/user/${unit}" ]] || \
      fail "expected linked ${unit}"
    [[ "$(readlink "${tmp}/config/systemd/user/${unit}")" == \
        "${repo_root}/systemd/user/${unit}" ]] || \
      fail "expected ${unit} to point into the repository"
  done
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

test_dotfiles_health_skips_prism_when_unconfigured() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null

  PRISM_DOCTOR_STATUS=1 run_health "$tmp" --skip-systemd >/dev/null

  rm -rf "$tmp"
}

test_dotfiles_health_fails_wrong_prism_link_without_running_doctor() {
  local tmp output exit_status doctor_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  doctor_log="${tmp}/doctor.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${repo_root}/prism/europa" "${tmp}/config/prism"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan PRISM_DOCTOR_LOG="$doctor_log" \
    run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health accepted the wrong Prism config link"
  [[ "$output" == *"wrong link target"* ]] || fail "health did not explain wrong Prism config link"
  [[ ! -e "$doctor_log" ]] || fail "health ran doctor after rejecting the Prism config link"

  rm -rf "$tmp"
}

test_dotfiles_health_fails_unknown_host_dangling_prism_marker_without_doctor() {
  local tmp output exit_status doctor_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  doctor_log="${tmp}/doctor.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${tmp}/missing-prism-config" "${tmp}/config/prism"

  set +e
  output=$(PRISM_DOCTOR_LOG="$doctor_log" run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health accepted a dangling Prism marker on an unknown host"
  [[ "$output" == *"broken link"* ]] || fail "health did not explain dangling Prism marker"
  [[ ! -e "$doctor_log" ]] || fail "health ran doctor after rejecting a dangling Prism marker"

  rm -rf "$tmp"
}

test_dotfiles_health_fails_unknown_host_wrong_prism_marker_without_doctor() {
  local tmp output exit_status doctor_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  doctor_log="${tmp}/doctor.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  ln -s "${repo_root}/prism/europa" "${tmp}/config/prism"

  set +e
  output=$(PRISM_DOCTOR_LOG="$doctor_log" run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health accepted a wrong Prism marker on an unknown host"
  [[ "$output" == *"wrong link target"* ]] || fail "health did not explain wrong Prism marker"
  [[ ! -e "$doctor_log" ]] || fail "health ran doctor after rejecting a wrong Prism marker"

  rm -rf "$tmp"
}

test_prism_launcher_link_survives_relocated_sibling_repos() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/repos/dotfiles/bin" "${tmp}/repos/prism/bin"
  cp -P "${repo_root}/bin/prism" "${tmp}/repos/dotfiles/bin/prism"
  touch "${tmp}/repos/prism/bin/prism"

  [[ "${tmp}/repos/dotfiles/bin/prism" -ef "${tmp}/repos/prism/bin/prism" ]] || \
    fail "Prism launcher link should resolve in relocated sibling repositories"

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
  output=$(run_health "$tmp" --skip-systemd 2>&1)
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

  output=$(run_health "$tmp" --skip-systemd 2>&1)

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

  output=$(run_health "$tmp" --skip-systemd 2>&1)

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
  output=$(run_health "$tmp" --skip-systemd 2>&1)
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

  SYSTEMCTL_LOG="$systemctl_log" \
    PATH="${mockbin}:$PATH" \
    run_health "$tmp" >/dev/null

  rg -q -- '--user is-enabled dropbox-ignore-flux.timer' "$systemctl_log" || \
    fail "expected health to query timer enabled state"
  rg -q -- '--user list-timers dropbox-ignore-flux.timer --no-pager' "$systemctl_log" || \
    fail "expected health to query timer schedule"

  rm -rf "$tmp"
}

test_noctalia_v5_config_is_installed_and_validated() {
  local tmp output templates
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/cache" "${tmp}/data" "${tmp}/state"

  run_setup "$tmp" --link-only --only app-config >/dev/null

  [[ -L "${tmp}/config/noctalia/config.toml" ]] || \
    fail "expected linked Noctalia config"
  [[ -L "${tmp}/config/noctalia/templates" ]] || \
    fail "expected linked Noctalia templates"
  [[ -L "${tmp}/config/noctalia/templates.toml" ]] || \
    fail "expected linked Noctalia template config"
  [[ -L "${tmp}/config/noctalia/palettes/Glow.json" ]] || \
    fail "expected linked Noctalia Glow palette"
  [[ ! -e "${tmp}/config/noctalia/plugins" ]] || \
    fail "setup should not create Noctalia v4 plugin links"

  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_CACHE_HOME="${tmp}/cache" XDG_STATE_HOME="${tmp}/state" \
    noctalia config validate "${tmp}/config/noctalia" 2>&1) || \
    fail "installed Noctalia v5 config should validate: ${output}"
  [[ "$output" != *WARN* && "$output" != *ERROR* ]] || \
    fail "installed Noctalia config emitted a warning or error: ${output}"

  templates=$(HOME="${tmp}/home" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_CACHE_HOME="${tmp}/cache" \
    XDG_STATE_HOME="${tmp}/state" \
    noctalia theme --list-templates 2>/dev/null) || \
    fail "Noctalia should load the installed template config"
  for id in glow nvim claude codex ohai; do
    print -r -- "$templates" | \
      rg -q "^[[:space:]]+${id}[[:space:]]+user([[:space:]]|$)" || \
      fail "Noctalia should register the ${id} user template"
  done

  rm -rf "$tmp"
}

test_setup_graphical_config_plans_niri_glass() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(PRISM_TEST_HOSTNAME=titan \
    run_setup "$tmp" --dry-run --link-only --only graphical-config)

  [[ "$output" == *"${tmp}/home/d/niri-glass"* ]] || \
    fail "graphical setup did not plan the niri-glass source"
  [[ "$output" == *"${tmp}/config/quickshell/niri-glass"* ]] || \
    fail "graphical setup did not plan the named Quickshell config"
  [[ "$output" == *"niri-glass.json"* ]] || \
    fail "graphical setup did not plan the generated config consumer"
  rg -q -F 'spawn-at-startup "qs" "-c" "niri-glass"' \
    "${repo_root}/niri/config.kdl" || \
    fail "niri does not launch the named niri-glass config"
}

configure_prism_glass_runtime() {
  local tmp="$1"
  mkdir -p "${tmp}/config/quickshell" "${tmp}/config/niri" \
    "${tmp}/home/d/niri-glass" "${tmp}/home/.local/state/prism/generated"
  touch "${tmp}/home/d/niri-glass/shell.qml"
  print -- '{}' > "${tmp}/home/.local/state/prism/generated/niri-glass.json"
  ln -s "${repo_root}/prism/titan" "${tmp}/config/prism"
  ln -s "${tmp}/home/d/niri-glass" "${tmp}/config/quickshell/niri-glass"
  ln -s "${tmp}/home/.local/state/prism/generated/niri-glass.json" \
    "${tmp}/config/niri/niri-glass.json"
}

test_dotfiles_health_accepts_prism_glass_runtime() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  configure_prism_glass_runtime "$tmp"

  PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd >/dev/null
}

test_dotfiles_health_fails_wrong_niri_glass_consumer() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  configure_prism_glass_runtime "$tmp"
  print -- '{}' > "${tmp}/wrong.json"
  rm "${tmp}/config/niri/niri-glass.json"
  ln -s "${tmp}/wrong.json" "${tmp}/config/niri/niri-glass.json"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted wrong niri-glass consumer"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "health did not explain wrong niri-glass consumer"
}

test_dotfiles_health_fails_wrong_named_niri_glass_config() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  configure_prism_glass_runtime "$tmp"
  mkdir "${tmp}/wrong-niri-glass"
  rm "${tmp}/config/quickshell/niri-glass"
  ln -s "${tmp}/wrong-niri-glass" "${tmp}/config/quickshell/niri-glass"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted wrong named niri-glass config"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "health did not explain wrong named niri-glass config"
}

test_dotfiles_health_rejects_root_quickshell_config() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  configure_prism_glass_runtime "$tmp"
  touch "${tmp}/config/quickshell/shell.qml"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted a root Quickshell config"
  [[ "$output" == *"disables named Quickshell configs"* ]] || \
    fail "health did not explain the named-config shadow"
}

test_dotfiles_health_fails_when_prism_doctor_fails() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  configure_prism_glass_runtime "$tmp"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan PRISM_DOCTOR_STATUS=1 run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health should fail when prism doctor fails"
  [[ "$output" == *"generated file missing: prism.kdl"* ]] || \
    fail "expected prism doctor failure details"

  rm -rf "$tmp"
}

test_dotfiles_health_rejects_noctalia_config_warning() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  run_setup "$tmp" --link-only --only app-config >/dev/null
  print -r -- '[config]' > "${tmp}/config/noctalia/obsolete.toml"
  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted a Noctalia config warning"
  [[ "$output" == *"Noctalia config warning or error"* ]] || \
    fail "health did not explain the validator warning: ${output}"
}

test_dotfiles_health_fails_wrong_opencode_theme_link() {
  local tmp output exit_status theme_link mockbin
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mockbin="${tmp}/bin"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "$mockbin"
  run_setup "$tmp" --link-only --headless >/dev/null
  theme_link="${tmp}/config/opencode.local/themes/noctalia.json"
  rm "$theme_link"
  ln -s "${tmp}/wrong-theme.json" "$theme_link"
  printf '#!/usr/bin/env bash\nexit 99\n' > "${mockbin}/realpath"
  chmod +x "${mockbin}/realpath"
  set +e
  output=$(PATH="${mockbin}:$PATH" run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted wrong OpenCode theme link"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "health did not explain wrong OpenCode theme link"
  rm -rf "$tmp"
}

test_dotfiles_health_rejects_symlinked_opencode_local() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  mv "${tmp}/config/opencode.local" "${tmp}/opencode-local-target"
  ln -s "${tmp}/opencode-local-target" "${tmp}/config/opencode.local"
  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted symlinked opencode.local"
  [[ "$output" == *"not a real directory"* ]] || \
    fail "health did not explain symlinked opencode.local"
}

test_tmp_cleanup_runs_only_at_process_exit
test_tmp_cleanup_is_centralized
test_bash_config_is_native_and_minimal
test_glow_theme_renders_color
test_noctalia_v5_config_contract
test_noctalia_template_hook_markers_are_reproducible
test_compositors_use_noctalia_v5
test_noctalia_builtin_hooks_leave_managed_configs_unchanged
test_zsh_pager_is_ansi_aware
test_setup_dry_run_link_only_does_not_write_home
test_setup_link_only_creates_expected_links_without_external_clones
test_setup_dry_run_can_enable_user_timers
test_setup_only_runs_selected_phase
test_setup_only_accepts_multiple_phases
test_setup_only_rejects_unknown_phase
test_setup_and_health_share_managed_link_metadata
test_dotfiles_health_skips_prism_when_unconfigured
test_prism_launcher_link_survives_relocated_sibling_repos
test_dotfiles_health_fails_unknown_host_wrong_prism_marker_without_doctor
test_dotfiles_health_fails_unknown_host_dangling_prism_marker_without_doctor
test_dotfiles_health_fails_wrong_prism_link_without_running_doctor
test_dotfiles_health_fails_stale_removed_config_links
test_dotfiles_health_ignores_brave_runtime_symlinks
test_dotfiles_health_ignores_unmanaged_config_symlinks
test_dotfiles_health_fails_broken_managed_config_link
test_dotfiles_health_checks_enabled_user_timer
test_noctalia_v5_config_is_installed_and_validated
test_setup_graphical_config_plans_niri_glass
test_dotfiles_health_accepts_prism_glass_runtime
test_dotfiles_health_fails_wrong_niri_glass_consumer
test_dotfiles_health_fails_wrong_named_niri_glass_config
test_dotfiles_health_rejects_root_quickshell_config
test_dotfiles_health_fails_when_prism_doctor_fails
test_dotfiles_health_rejects_noctalia_config_warning
test_dotfiles_health_fails_wrong_opencode_theme_link
test_dotfiles_health_rejects_symlinked_opencode_local

print -- "setup and health tests passed"
