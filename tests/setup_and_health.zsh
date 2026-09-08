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

install_test_stubs() {
  local tmp="$1"
  mkdir -p "${tmp}/bin"

  if [[ ! -e "${tmp}/bin/noctalia" ]]; then
    cat > "${tmp}/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 4 && "$1" == msg && "$2" == plugins && "$3" == enable ]]; then
  if [[ -n "${NOCTALIA_TEST_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "$NOCTALIA_TEST_LOG"
  fi
  exit "${NOCTALIA_ENABLE_STATUS:-0}"
fi
if [[ $# -eq 3 && "$1" == msg && "$2" == plugins && "$3" == list ]]; then
  printf '%s\n' "${NOCTALIA_PLUGIN_LIST:-khughitt/wali-panel [local] 1.0.0 enabled requires walictl
khughitt/prism [local] 1.0.0 enabled requires prism, qs}"
  exit "${NOCTALIA_PLUGIN_LIST_STATUS:-0}"
fi
if [[ $# -ge 2 && "$1" == config && "$2" == validate ]]; then
  exec /usr/bin/noctalia "$@"
fi
if [[ $# -eq 3 && "$1" == config && "$2" == export && "$3" == merged ]]; then
  exec /usr/bin/noctalia "$@"
fi
if [[ $# -eq 2 && "$1" == theme && "$2" == --list-templates ]]; then
  exec /usr/bin/noctalia "$@"
fi
printf 'unexpected Noctalia test command:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 64
EOF
    chmod +x "${tmp}/bin/noctalia"
  fi

  if [[ ! -e "${tmp}/bin/prism" ]]; then
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
  fi
}

run_setup() {
  local tmp="$1"
  local setup_root="${SETUP_ROOT:-$repo_root}"
  shift

  mkdir -p "${tmp}/bin"
  if [[ "${PRISM_PLUGIN_SOURCE_PRESENT:-true}" == true ]]; then
    mkdir -p "${tmp}/home/d/prism/integrations/noctalia-plugin"
    touch "${tmp}/home/d/prism/integrations/noctalia-plugin/plugin.toml"
  fi
  install_test_stubs "$tmp"
  cat > "${tmp}/bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PRISM_TEST_HOSTNAME:-dotfiles-test-unconfigured}"
EOF
  chmod +x "${tmp}/bin/hostname"
  for command in xan crush codex; do
    [[ -x "${tmp}/bin/${command}" ]] && continue
    cat > "${tmp}/bin/${command}" <<'EOF'
#!/usr/bin/env bash
printf '#compdef %s\n' "$(basename "$0")"
EOF
    chmod +x "${tmp}/bin/${command}"
  done

  HOME="${tmp}/home" \
    XDG_CACHE_HOME="${tmp}/cache" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    XDG_STATE_HOME="${tmp}/home/.local/state" \
    DOTFILES_OPENCODE_RUNTIME_SOURCE="${tmp}/opencode-runtime-source" \
    PATH="${tmp}/bin:$PATH" \
    bash "${setup_root}/setup.sh" "$@"
}

run_health() {
  local tmp="$1"
  shift

  install_test_stubs "$tmp"

  HOME="${tmp}/home" \
    XDG_CACHE_HOME="${tmp}/cache" \
    XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    XDG_STATE_HOME="${tmp}/home/.local/state" \
    PATH="${tmp}/bin:$PATH" \
    "${repo_root}/bin/dotfiles-health" "$@"
}

prepare_health_fixture() {
  local tmp="$1"

  run_setup "$tmp" --link-only --headless >/dev/null
  run_setup "$tmp" --link-only --only app-config >/dev/null
  run_setup "$tmp" --link-only --only noctalia-plugins >/dev/null
}

test_setup_and_health_install_safe_noctalia_stubs() {
  local setup_tmp health_tmp log exit_status
  setup_tmp=$(make_tmpdir)
  health_tmp=$(make_tmpdir)
  register_tmp_cleanup "$setup_tmp"
  register_tmp_cleanup "$health_tmp"
  log="${setup_tmp}/noctalia.log"

  NOCTALIA_TEST_LOG="$log" run_setup "$setup_tmp" --help >/dev/null
  NOCTALIA_TEST_LOG="$log" PATH="${setup_tmp}/bin:$PATH" \
    noctalia msg plugins enable test/never-live
  [[ "$(<"$log")" == "msg plugins enable test/never-live" ]] || \
    fail "Noctalia enable stub did not capture the exact IPC call"

  if PATH="${setup_tmp}/bin:$PATH" noctalia msg plugins disable test/never-live; then
    exit_status=0
  else
    exit_status=$?
  fi
  (( exit_status == 64 )) || fail "Noctalia test stub forwarded an unknown mutating command"

  run_health "$health_tmp" --help >/dev/null
  [[ -x "${health_tmp}/bin/noctalia" ]] || \
    fail "run_health did not install its own Noctalia stub"
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

test_noctalia_lsd_theme_is_consumed() {
  local tmp output
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/config/lsd"

  noctalia theme --theme-json "${repo_root}/noctalia/palettes/Glow.json" --dark \
    -r "${repo_root}/noctalia/templates/lsd.yaml:${tmp}/config/lsd/colors.yaml" \
    >/dev/null 2>&1 || fail "Noctalia should render the LSD theme"

  output=$(env -u NO_COLOR HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    LS_COLORS= TERM=xterm-256color \
    lsd --config-file "${repo_root}/lsd/config.yaml" --color always --long \
    "${tmp}/config/lsd/colors.yaml" 2>&1) || \
    fail "LSD should load the rendered Noctalia theme: ${output}"
  [[ "$output" != *Warning* ]] || fail "LSD emitted a theme warning: ${output}"
  [[ "$output" == *$'\e[38;2;21;230;207m'* ]] || \
    fail "LSD did not use the rendered primary color"

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
  for id in glow nvim claude codex lsd fzf fastfetch ohai; do
    print -r -- "$templates" | \
      rg -q "^[[:space:]]+${id}[[:space:]]+user([[:space:]]|$)" || \
      fail "missing user template: ${id}"
  done

  python3 - "${repo_root}/noctalia/config.toml" \
    "${repo_root}/noctalia/templates.toml" \
    "${repo_root}/noctalia/plugins/wali-panel/plugin.toml" <<'PY'
import sys, tomllib

config = tomllib.load(open(sys.argv[1], "rb"))
templates = tomllib.load(open(sys.argv[2], "rb"))["theme"]["templates"]
wali = tomllib.load(open(sys.argv[3], "rb"))
assert config["accessibility"]["ui_scale"] == 1.05
assert "ui_scale" not in config["shell"]
assert config["theme"] == {
    "mode": "dark", "source": "wallpaper", "wallpaper_scheme": "m3-tonal-spot"
}
assert config["wallpaper"]["automation"] == {"enabled": False}
assert config["hooks"]["wallpaper_changed"] == [
    '~/bin/prism context wallpaper "$NOCTALIA_WALLPAPER_PATH"',
    "~/bin/walictl observe",
]
assert config["bar"]["default"]["start"] == ["workspaces", "cpu", "ram"]
assert config["bar"]["default"]["center"] == ["active_window"]
assert config["bar"]["default"]["end"] == [
    "tray", "battery", "notifications", "output_volume",
    "khughitt/prism:widget", "khughitt/wali-panel:widget", "clock",
]
assert "plugins" not in config
assert not any(name.startswith("khughitt/") for name in config.get("widget", {}))
assert templates["builtin_ids"] == [
    "hyprland", "gtk3", "gtk4", "qt", "niri", "ghostty", "kitty", "btop"
]
assert templates["community_ids"] == ["zathura", "bat", "yazi"]
assert set(templates["user"]) == {
    "glow", "nvim", "claude", "codex", "lsd", "fzf", "fastfetch", "ohai"
}
assert templates["user"]["lsd"] == {
    "input_path": "$XDG_CONFIG_HOME/noctalia/templates/lsd.yaml",
    "output_path": "$XDG_CONFIG_HOME/lsd/colors.yaml",
}
assert templates["user"]["fzf"] == {
    "input_path": "$XDG_CONFIG_HOME/noctalia/templates/fzf.conf",
    "output_path": "$XDG_CACHE_HOME/noctalia/fzf.conf",
}
assert templates["user"]["fastfetch"] == {
    "input_path": "$XDG_CONFIG_HOME/noctalia/templates/fastfetch.jsonc",
    "output_path": "$XDG_CONFIG_HOME/fastfetch/config.jsonc",
}
assert wali["id"] == "khughitt/wali-panel"
assert wali["plugin_api"] == 22
assert wali["plugin_api"] <= 23
assert wali["dependencies"] == ["walictl"]
assert wali["widget"] == [{"id": "widget", "entry": "widget.luau"}]
assert wali["panel"] == [{
    "id": "panel", "entry": "panel.luau", "width": 588, "height": 798,
    "placement": "attached", "position": "auto",
}]
assert "setting" not in wali
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

test_active_noctalia_code_has_no_v4_ipc() {
  local output exit_status files=(
    "${repo_root}/bin/walictl"
    "${repo_root}/shell/wali"
    "${repo_root}/niri/config.kdl"
    "${repo_root}/hypr/hyprland.conf"
    "${repo_root}/setup.sh"
    "${repo_root}/bin/dotfiles-health"
  )

  set +e
  output=$(rg -n 'noctalia-shell|qs.*ipc.*(wallpaper|launcher|controlCenter|settings|volume|brightness)' \
    "${files[@]}" 2>&1)
  exit_status=$?
  set -e

  case "$exit_status" in
    0) fail "active code still contains Noctalia v4 IPC: ${output}" ;;
    1) ;;
    *) fail "active Noctalia v4 scan failed: ${output}" ;;
  esac
}

test_active_noctalia_code_has_no_v4_ipc_fails_on_scan_error() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "$tmp/repo/bin" "$tmp/repo/shell" "$tmp/repo/niri" "$tmp/repo/hypr"
  cp "${repo_root}/bin/walictl" "$tmp/repo/bin/walictl"
  cp "${repo_root}/shell/wali" "$tmp/repo/shell/wali"
  cp "${repo_root}/niri/config.kdl" "$tmp/repo/niri/config.kdl"
  cp "${repo_root}/hypr/hyprland.conf" "$tmp/repo/hypr/hyprland.conf"
  cp "${repo_root}/setup.sh" "$tmp/repo/setup.sh"

  set +e
  output=$(repo_root="$tmp/repo" test_active_noctalia_code_has_no_v4_ipc 2>&1)
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "active Noctalia v4 scan should fail on a missing input"
  [[ "$output" == *"active Noctalia v4 scan failed"* ]] || \
    fail "active Noctalia v4 scan should report its scan error: ${output}"
}

test_noctalia_builtin_hooks_leave_managed_configs_unchanged() {
  local tmp config targets before after output hook_output=""
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  config="${tmp}/home/.config"
  targets="${tmp}/targets"
  mkdir -p "$config" "$targets/niri" "$targets/hypr" \
    "$targets/ghostty" "$targets/kitty/themes" "$targets/gtk-3.0" \
    "$targets/gtk-4.0" "${tmp}/bin"
  cp "${repo_root}/niri/config.kdl" "$targets/niri/config.kdl"
  cp "${repo_root}/hypr/hyprland.conf" "$targets/hypr/hyprland.conf"
  cp "${repo_root}/ghostty/config.ghostty" "$targets/ghostty/config.ghostty"
  cp "${repo_root}/kitty/kitty.conf" "$targets/kitty/kitty.conf"
  cp "${repo_root}/gtk-3.0/gtk.css" "$targets/gtk-3.0/gtk.css"
  cp "${repo_root}/gtk-4.0/gtk.css" "$targets/gtk-4.0/gtk.css"

  ln -s "$targets/niri" "$config/niri"
  ln -s "$targets/hypr" "$config/hypr"
  ln -s "$targets/kitty" "$config/kitty"
  mkdir -p "$config/ghostty" "$config/gtk-3.0" "$config/gtk-4.0"
  ln -s "$targets/ghostty/config.ghostty" "$config/ghostty/config.ghostty"
  ln -s "$targets/gtk-3.0/gtk.css" "$config/gtk-3.0/gtk.css"
  ln -s "$targets/gtk-4.0/gtk.css" "$config/gtk-4.0/gtk.css"
  touch "$config/gtk-3.0/noctalia.css" "$config/gtk-4.0/noctalia.css"
  touch "$config/kitty/themes/noctalia.conf"

  for command in hyprctl gsettings dconf pgrep pkill; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "${tmp}/bin/${command}"
    chmod +x "${tmp}/bin/${command}"
  done

  before=$(find "$targets" -type f -print0 | sort -z | xargs -0 sha256sum)
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/niri/apply.sh apply 2>&1) || \
    fail "Niri hook failed: ${output}"
  hook_output+="Niri: ${output}"$'\n'
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/hyprland/apply.sh apply 2>&1) || \
    fail "Hyprland hook failed: ${output}"
  hook_output+="Hyprland: ${output}"$'\n'
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/ghostty/apply.sh 2>&1) || \
    fail "Ghostty hook failed: ${output}"
  hook_output+="Ghostty: ${output}"$'\n'
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/kitty/apply.sh 2>&1) || \
    fail "Kitty hook failed: ${output}"
  hook_output+="Kitty: ${output}"$'\n'
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="$config" PATH="${tmp}/bin:$PATH" \
    bash /usr/share/noctalia/assets/templates/gtk/apply.sh dark 2>&1) || \
    fail "GTK hook failed: ${output}"
  hook_output+="GTK: ${output}"$'\n'
  after=$(find "$targets" -type f -print0 | sort -z | xargs -0 sha256sum)

  [[ "$after" == "$before" ]] || \
    fail "a built-in hook edited a disposable target: ${hook_output}"
  [[ -L "$config/niri" && -L "$config/hypr" && -L "$config/kitty" ]] || \
    fail "a managed directory link was replaced: ${hook_output}"
  for managed_path in ghostty/config.ghostty gtk-3.0/gtk.css gtk-4.0/gtk.css; do
    [[ -L "$config/$managed_path" ]] || \
      fail "a managed file link was replaced: ${managed_path}: ${hook_output}"
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
  [[ -d "${tmp}/config/lsd" && ! -L "${tmp}/config/lsd" ]] || \
    fail "expected a writable LSD config directory"
  [[ "${tmp}/config/lsd/config.yaml" -ef "${repo_root}/lsd/config.yaml" ]] || \
    fail "expected tracked LSD config link"
  [[ -d "${tmp}/config/yazi" && ! -L "${tmp}/config/yazi" ]] || \
    fail "expected a writable Yazi config directory"
  [[ "${tmp}/config/yazi/yazi.toml" -ef "${repo_root}/yazi/yazi.toml" ]] || \
    fail "expected tracked Yazi config link"
  [[ -L "${tmp}/config/systemd/user/dropbox-ignore-flux.timer" ]] || \
    fail "expected linked Dropbox ignore timer"
  [[ -L "${tmp}/config/systemd/user/niri.service.d/stop-timeout.conf" ]] || \
    fail "expected linked niri stop-timeout override"
  [[ "$(readlink "${tmp}/config/systemd/user/niri.service.d/stop-timeout.conf")" == \
      "${repo_root}/systemd/user/niri.service.d/stop-timeout.conf" ]] || \
    fail "expected niri stop-timeout override to point into the repository"
  for unit in familiar-reap.service familiar-reap.timer mindful-docker.service \
      wali-rotate.service wali-rotate.timer; do
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

test_setup_migrates_legacy_lsd_directory_link() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  ln -s "${repo_root}/lsd" "${tmp}/config/lsd"

  run_setup "$tmp" --link-only --headless --only common-config >/dev/null

  [[ -d "${tmp}/config/lsd" && ! -L "${tmp}/config/lsd" ]] || \
    fail "setup should replace the legacy LSD directory link"
  [[ "${tmp}/config/lsd/config.yaml" -ef "${repo_root}/lsd/config.yaml" ]] || \
    fail "setup should preserve the tracked LSD config"

  rm -rf "$tmp"
}

test_setup_shell_generates_static_zsh_completions() {
  local tmp command completion_dir
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless --only shell >/dev/null

  completion_dir="${tmp}/data/zsh/site-functions"
  for command in xan crush codex; do
    [[ "$(<"${completion_dir}/_${command}")" == "#compdef ${command}" ]] || \
      fail "shell setup should generate static ${command} completion"
  done

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
  [[ "$output" == *"systemctl --user enable --now wali-rotate.timer"* ]] || \
    fail "expected dry-run wali timer enable command"

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

test_noctalia_plugin_phase_links_and_enables_exact_ids() {
  local tmp log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  log="${tmp}/noctalia.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  NOCTALIA_TEST_LOG="$log" run_setup "$tmp" --link-only \
    --only noctalia-plugins >/dev/null

  [[ -L "${tmp}/data/noctalia/plugins/wali-panel" ]]
  [[ -L "${tmp}/data/noctalia/plugins/prism" ]]
  [[ -f "${tmp}/data/noctalia/plugins/wali-panel/plugin.toml" ]]
  [[ -f "${tmp}/data/noctalia/plugins/prism/plugin.toml" ]]
  [[ ! -e "${tmp}/data/noctalia/plugins/wali-panel/manifest.json" ]]
  [[ ! -e "${tmp}/data/noctalia/plugins/prism/manifest.json" ]]
  [[ "$(<"$log")" == $'msg plugins enable khughitt/wali-panel\nmsg plugins enable khughitt/prism' ]] || \
    fail "plugin phase did not issue the two exact enable calls"
}

test_default_setup_does_not_require_live_noctalia() {
  local tmp fixture output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  fixture="${tmp}/repo"
  cp -a "$repo_root" "$fixture"
  rm "${fixture}/bin/prism"
  cat > "${fixture}/bin/prism" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == "apply niri" || "$*" == "apply kitty" || "$*" == "apply debug-backdrop" ]] || exit 64
exit 0
EOF
  chmod +x "${fixture}/bin/prism"
  mkdir -p "${tmp}/bin"
  cat > "${tmp}/bin/niri" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "$1" == validate ]] || exit 64
EOF
  chmod +x "${tmp}/bin/niri"
  set +e
  output=$(NIRI_SOCKET= PRISM_TEST_HOSTNAME=titan NOCTALIA_ENABLE_STATUS=69 SETUP_ROOT="$fixture" \
    run_setup "$tmp" --link-only 2>&1)
  exit_status=$?
  set -e
  (( exit_status == 0 )) || fail "default setup required live Noctalia: ${output}"
}

test_noctalia_plugin_phase_fails_when_ipc_is_unavailable() {
  local tmp exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  set +e
  NOCTALIA_ENABLE_STATUS=69 run_setup "$tmp" --link-only \
    --only noctalia-plugins >/dev/null 2>&1
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "plugin setup accepted unavailable Noctalia IPC"
}

test_noctalia_plugin_phase_requires_prism_source() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  set +e
  output=$(PRISM_PLUGIN_SOURCE_PRESENT=false run_setup "$tmp" --link-only \
    --only noctalia-plugins 2>&1)
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "plugin setup accepted a missing Prism plugin source"
  [[ "$output" == *"Link source does not exist"* ]] || \
    fail "plugin setup did not explain the missing Prism plugin source"
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

  prepare_health_fixture "$tmp"

  PRISM_DOCTOR_STATUS=1 run_health "$tmp" --skip-systemd >/dev/null

  rm -rf "$tmp"
}

test_dotfiles_health_fails_missing_noctalia_config() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  run_setup "$tmp" --link-only --only noctalia-plugins >/dev/null

  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted missing Noctalia config"
  [[ "$output" == *"${tmp}/config/noctalia/config.toml"* ]] || \
    fail "health did not report the missing Noctalia config: ${output}"
}

test_dotfiles_health_fails_wrong_noctalia_plugin_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "${tmp}/wrong-wali"
  touch "${tmp}/wrong-wali/plugin.toml"
  prepare_health_fixture "$tmp"
  rm "${tmp}/data/noctalia/plugins/wali-panel"
  ln -s "${tmp}/wrong-wali" "${tmp}/data/noctalia/plugins/wali-panel"

  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted the wrong Wali plugin link"
  [[ "$output" == *"wrong link target"* && "$output" == *"wali-panel"* ]] || \
    fail "health did not identify the wrong Wali plugin link: ${output}"
}

test_dotfiles_health_fails_stale_noctalia_plugin_manifest() {
  local tmp output exit_status prism_source
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"
  prism_source="${tmp}/home/d/prism/integrations/noctalia-plugin"
  rm "${prism_source}/plugin.toml"
  touch "${prism_source}/manifest.json"

  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted a stale Prism v4 manifest"
  [[ "$output" == *"prism"* ]] || \
    fail "health did not identify the stale Prism manifest: ${output}"
}

test_dotfiles_health_fails_when_wali_plugin_is_not_enabled() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"

  set +e
  output=$(NOCTALIA_PLUGIN_LIST='khughitt/prism [local] 1.0.0 enabled' \
    run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted disabled Wali plugin state"
  [[ "$output" == *"wali-panel"* ]] || \
    fail "health did not identify the disabled Wali plugin: ${output}"
}

test_dotfiles_health_fails_when_prism_plugin_is_not_enabled() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"

  set +e
  output=$(NOCTALIA_PLUGIN_LIST='khughitt/wali-panel [local] 1.0.0 enabled' \
    run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted disabled Prism plugin state"
  [[ "$output" == *"prism"* ]] || \
    fail "health did not identify the disabled Prism plugin: ${output}"
}

test_dotfiles_health_fails_when_plugin_list_is_unavailable() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"

  set +e
  output=$(NOCTALIA_PLUGIN_LIST_STATUS=69 run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted unavailable Noctalia plugin IPC"
  [[ "$output" == *"Noctalia"* && "$output" == *"plugin"* ]] || \
    fail "health did not identify unavailable Noctalia plugin IPC: ${output}"
}

test_dotfiles_health_offline_flag_skips_only_plugin_ipc() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "${tmp}/wrong-wali"
  touch "${tmp}/wrong-wali/plugin.toml"
  prepare_health_fixture "$tmp"

  set +e
  output=$(NOCTALIA_PLUGIN_LIST='other/plugin [local] 1.0.0 disabled' \
    run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "live health accepted disabled plugin state"

  output=$(NOCTALIA_PLUGIN_LIST='other/plugin [local] 1.0.0 disabled' \
    run_health "$tmp" --skip-systemd --skip-noctalia-ipc 2>&1) || \
    fail "offline health rejected valid static plugin topology: ${output}"
  [[ "$output" == *"[OK]"* && "$output" == *"live Noctalia plugin check"* ]] || \
    fail "offline health did not report the explicit plugin IPC skip: ${output}"

  rm "${tmp}/data/noctalia/plugins/wali-panel"
  ln -s "${tmp}/wrong-wali" "${tmp}/data/noctalia/plugins/wali-panel"
  set +e
  output=$(run_health "$tmp" --skip-systemd --skip-noctalia-ipc 2>&1)
  exit_status=$?
  set -e
  (( exit_status != 0 )) || fail "offline health skipped the wrong Wali plugin link"
  [[ "$output" == *"wrong link target"* && "$output" == *"wali-panel"* ]] || \
    fail "offline health did not identify the wrong Wali plugin link: ${output}"
}

test_dotfiles_health_skips_noctalia_on_macos() {
  local tmp output exit_status noctalia_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  noctalia_log="${tmp}/noctalia.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --macos \
    --only shell,common-config,home,app-config >/dev/null
  printf '#!/usr/bin/env bash\nprintf "called\\n" >> "$NOCTALIA_LOG"\nexit 99\n' \
    > "${tmp}/bin/noctalia"
  printf '#!/usr/bin/env bash\nprintf "Darwin\\n"\n' > "${tmp}/bin/uname"
  chmod +x "${tmp}/bin/noctalia" "${tmp}/bin/uname"

  set +e
  output=$(NOCTALIA_LOG="$noctalia_log" run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status == 0 )) || \
    fail "health rejected a supported macOS headless setup: ${output}"
  [[ ! -e "$noctalia_log" ]] || fail "health ran Noctalia on macOS"
}

test_dotfiles_health_fails_wrong_prism_link_without_running_doctor() {
  local tmp output exit_status doctor_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  doctor_log="${tmp}/doctor.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  prepare_health_fixture "$tmp"
  mkdir -p "${tmp}/config/wali"
  ln -s "${repo_root}/wali/titan/config.toml" "${tmp}/config/wali/config.toml"
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

  prepare_health_fixture "$tmp"
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

  prepare_health_fixture "$tmp"
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

  prepare_health_fixture "$tmp"
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

  prepare_health_fixture "$tmp"
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

  prepare_health_fixture "$tmp"
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

  prepare_health_fixture "$tmp"
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

test_dotfiles_health_rejects_legacy_lsd_directory_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  prepare_health_fixture "$tmp"
  rm -rf "${tmp}/config/lsd"
  ln -s "${repo_root}/lsd" "${tmp}/config/lsd"

  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted the legacy LSD directory link"
  [[ "$output" == *"not a real directory"* ]] || \
    fail "health did not explain the legacy LSD layout: ${output}"

  rm -rf "$tmp"
}

test_dotfiles_health_rejects_legacy_yazi_directory_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  prepare_health_fixture "$tmp"
  rm -rf "${tmp}/config/yazi"
  ln -s "${repo_root}/yazi" "${tmp}/config/yazi"

  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted the legacy Yazi directory link"
  [[ "$output" == *"not a real directory"* ]] || \
    fail "health did not explain the legacy Yazi layout: ${output}"

  rm -rf "$tmp"
}

test_dotfiles_health_checks_enabled_user_timer() {
  local tmp mockbin systemctl_log
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mockbin="${tmp}/bin"
  systemctl_log="${tmp}/systemctl.log"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "$mockbin"

  prepare_health_fixture "$tmp"

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

if [[ "$*" == "--user is-enabled wali-rotate.timer" ]]; then
  printf 'enabled\n'
  exit 0
fi

if [[ "$*" == "--user list-timers wali-rotate.timer --no-pager" ]]; then
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
  rg -q -- '--user is-enabled wali-rotate.timer' "$systemctl_log" || \
    fail "expected health to query the wali timer enabled state"
  rg -q -- '--user list-timers wali-rotate.timer --no-pager' "$systemctl_log" || \
    fail "expected health to query the wali timer schedule"

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
  for id in glow nvim claude codex lsd fzf fastfetch ohai; do
    print -r -- "$templates" | \
      rg -q "^[[:space:]]+${id}[[:space:]]+user([[:space:]]|$)" || \
      fail "Noctalia should register the ${id} user template"
  done

  rm -rf "$tmp"
}

test_setup_graphical_config_hands_material_ownership_to_prism() {
  local tmp output config
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(PRISM_TEST_HOSTNAME=titan \
    run_setup "$tmp" --dry-run --link-only --only graphical-config)

  [[ "$output" != *"quickshell/niri-glass"* ]] || \
    fail "graphical setup still plans the named Quickshell consumer"
  [[ "$output" != *"niri-glass.json"* ]] || \
    fail "graphical setup still plans the generated JSON consumer"
  [[ "$output" == *"NIRI_CONFIG=${repo_root}/niri/config.kdl"* ]] || \
    fail "pre-link Prism apply does not name the tracked niri config"
  [[ "$output" == *"prism.kdl"* ]] || \
    fail "graphical setup no longer links the generated Prism config"
  [[ "$output" == *"apply debug-backdrop"* ]] || \
    fail "graphical setup does not apply the debug backdrop sink"

  config="${repo_root}/niri/config.kdl"
  ! rg -q -F 'spawn-at-startup "qs" "-c" "niri-glass"' "$config" || \
    fail "niri still autostarts the legacy glass runtime"
  rg -q -F 'include "./prism.kdl"' "$config" || fail "missing Prism include"
  rg -q -F 'spawn-at-startup "~/.config/niri/scripts/prism-debug-backdrop-startup"' "$config" || \
    fail "niri does not restore the persisted debug backdrop"
  ! rg -q -F 'include "./materials.kdl"' "$config" || \
    fail "niri still includes the static material Prism now generates"
  [[ ! -e "${repo_root}/niri/materials.kdl" ]] || \
    fail "the static material file survived the ownership handoff"
  ! rg -q -F 'niri/niri-glass.json' "${repo_root}/.gitignore" || \
    fail ".gitignore still names the retired generated consumer"
}

test_setup_graphical_config_links_wali_config_for_known_host() {
  local tmp output prism_fixture
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  output=$(PRISM_TEST_HOSTNAME=titan \
    run_setup "$tmp" --dry-run --link-only --only graphical-config)
  [[ "$output" == *"${repo_root}/wali/titan/config.toml"* ]] || \
    fail "graphical setup does not link the titan wali config"

  # Dry-run skips Prism directory creation; supply that prerequisite.
  prism_fixture=$(mktemp -d "${repo_root}/prism/wali-test.XXXXXX")
  register_tmp_cleanup "$prism_fixture"
  output=$(PRISM_TEST_HOSTNAME="${prism_fixture:t}" \
    run_setup "$tmp" --dry-run --link-only --only graphical-config)
  [[ "$output" == *"No wali config for ${prism_fixture:t}"* ]] || \
    fail "graphical setup does not explain a missing wali config"
  [[ "$output" != *"Link source does not exist"* ]] || \
    fail "graphical setup aborted on a host without a wali config"
}

test_clean_graphical_setup_creates_empty_hyprland_theme_stub() {
  local tmp fixture
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  fixture="${tmp}/repo"
  mkdir -p "$fixture/bin" "$fixture/lib" "$fixture/feh" "$fixture/hypr" "$fixture/niri" \
    "$fixture/zathura" "$fixture/prism/titan" "$fixture/kitty" \
    "${tmp}/config" "${tmp}/bin"
  cp "${repo_root}/setup.sh" "$fixture/setup.sh"
  cp "${repo_root}/lib/dotfiles-setup-data.bash" "$fixture/lib/"
  cp "${repo_root}/niri/host_specific.sh" "$fixture/niri/"
  cp "${repo_root}/hypr/host_specific.sh" "$fixture/hypr/"
  printf '// titan\n' > "$fixture/niri/host-titan.kdl"
  printf '# titan\n' > "$fixture/hypr/host-titan.conf"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/bin/prism"
  printf '#!/usr/bin/env bash\nprintf "titan\\n"\n' > "${tmp}/bin/hostname"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${tmp}/bin/niri"
  chmod +x "$fixture/setup.sh" "$fixture/bin/prism" \
    "$fixture/niri/host_specific.sh" "$fixture/hypr/host_specific.sh" \
    "${tmp}/bin/hostname" "${tmp}/bin/niri"

  HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_STATE_HOME="${tmp}/state" PATH="${tmp}/bin:$PATH" \
    bash "$fixture/setup.sh" --link-only --only graphical-config >/dev/null

  [[ -f "$fixture/hypr/noctalia.conf" ]] || \
    fail "clean graphical setup did not create the Hyprland theme stub"
  [[ ! -s "$fixture/hypr/noctalia.conf" ]] || \
    fail "clean graphical setup should leave the Hyprland theme stub empty"
  [[ -d "$fixture/prism/titan/contexts" ]] || \
    fail "clean graphical setup did not create the host contexts directory"
  [[ "$(readlink "${tmp}/state/niri/host.kdl")" == "$fixture/niri/host-titan.kdl" ]] || \
    fail "niri host selection did not land in per-machine state"
  [[ "$(readlink "${tmp}/state/hypr/host.conf")" == "$fixture/hypr/host-titan.conf" ]] || \
    fail "hyprland host selection did not land in per-machine state"
  [[ ! -e "$fixture/niri/host.kdl" && ! -e "$fixture/hypr/host.conf" ]] || \
    fail "host selection wrote a per-machine symlink into the shared tree"
  # -e follows the link, so a dangling one fails here
  [[ -e "$fixture/niri/prism.kdl" ]] || \
    fail "niri include points at a generated file that was never created"
  [[ -e "$fixture/kitty/prism-generated.conf" ]] || \
    fail "kitty include points at a generated file that was never created"
  printf 'glass.ior: 1.3\n' > "${tmp}/config/prism/contexts/pinned-write.yaml"
  [[ -f "$fixture/prism/titan/contexts/pinned-write.yaml" ]] || \
    fail "context writes do not reach the host directory"
}

test_setup_continues_past_a_failing_phase() {
  local tmp fixture output rc
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  fixture="${tmp}/repo"
  mkdir -p "$fixture/bin" "$fixture/lib" "$fixture/hypr" "$fixture/niri" \
    "$fixture/prism/titan" "$fixture/mime" "${tmp}/config" "${tmp}/bin"
  cp "${repo_root}/setup.sh" "$fixture/setup.sh"
  cp "${repo_root}/lib/dotfiles-setup-data.bash" "$fixture/lib/"
  cp "${repo_root}/niri/host_specific.sh" "$fixture/niri/"
  cp "${repo_root}/hypr/host_specific.sh" "$fixture/hypr/"
  printf '// titan\n' > "$fixture/niri/host-titan.kdl"
  printf '# titan\n' > "$fixture/hypr/host-titan.conf"
  printf '[Default Applications]\n' > "$fixture/mimeapps.list"
  # graphical-config fails here, and only here
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/bin/prism"
  printf '#!/usr/bin/env bash\nprintf "titan\\n"\n' > "${tmp}/bin/hostname"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${tmp}/bin/niri"
  chmod +x "$fixture/setup.sh" "$fixture/bin/prism" \
    "$fixture/niri/host_specific.sh" "$fixture/hypr/host_specific.sh" \
    "${tmp}/bin/hostname" "${tmp}/bin/niri"

  rc=0
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" XDG_STATE_HOME="${tmp}/state" \
    PATH="${tmp}/bin:$PATH" \
    bash "$fixture/setup.sh" --link-only --only graphical-config,mime 2>&1) || rc=$?

  [[ "$rc" -ne 0 ]] || \
    fail "setup exited zero despite a failing phase"
  [[ "$output" == *"MIME links"* ]] || \
    fail "a phase after the failing one never ran"
  [[ -L "${tmp}/config/mimeapps.list" ]] || \
    fail "the phase after the failing one did no work"
  [[ "$output" == *"FAILED  graphical-config"* ]] || \
    fail "the summary does not name the failed phase"
  [[ "$output" == *"ok      mime"* ]] || \
    fail "the summary does not name the phases that succeeded"
}

test_preflight_reports_every_unmet_prerequisite_without_mutating() {
  local tmp fixture output rc entries
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  fixture="${tmp}/repo"
  mkdir -p "$fixture/bin" "$fixture/lib" "$fixture/prismrepo/bin" \
    "${tmp}/config" "${tmp}/bin"
  cp "${repo_root}/setup.sh" "$fixture/setup.sh"
  cp "${repo_root}/lib/dotfiles-setup-data.bash" "$fixture/lib/"
  # a prism checkout with no node_modules: the tree that is never in git
  printf '{}\n' > "$fixture/prismrepo/package.json"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/prismrepo/bin/prism"
  chmod +x "$fixture/setup.sh" "$fixture/prismrepo/bin/prism"
  ln -s "../prismrepo/bin/prism" "$fixture/bin/prism"
  printf '#!/usr/bin/env bash\nprintf "titan\\n"\n' > "${tmp}/bin/hostname"
  chmod +x "${tmp}/bin/hostname"

  rc=0
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" XDG_STATE_HOME="${tmp}/state" \
    PATH="${tmp}/bin:$PATH" \
    bash "$fixture/setup.sh" --headless --link-only --check 2>&1) || rc=$?

  [[ "$rc" -ne 0 ]] || \
    fail "--check exited zero with unmet prerequisites"
  # both findings must appear in one run, not one crash at a time
  [[ "$output" == *"MISSING  prism node dependencies"* ]] || \
    fail "preflight did not report the missing prism node_modules"
  [[ "$output" == *"MISSING  tasks registry"* ]] || \
    fail "preflight did not report the unpopulated tasks registry"
  [[ "$output" == *"npm ci --prefix"* ]] || \
    fail "preflight reported a finding without naming its fix"

  [[ ! -d "$fixture/prismrepo/node_modules" ]] || \
    fail "preflight installed prism dependencies"
  entries=("${tmp}/config"/*(N))
  (( ${#entries} == 0 )) || \
    fail "preflight wrote into the config directory: ${entries}"

  # outside --check the same findings are reported but do not fail the phase
  rc=0
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" XDG_STATE_HOME="${tmp}/state" \
    PATH="${tmp}/bin:$PATH" \
    bash "$fixture/setup.sh" --headless --link-only --only preflight 2>&1) || rc=$?
  [[ "$rc" -eq 0 ]] || \
    fail "preflight findings failed a normal run: ${output}"
  [[ "$output" == *"MISSING  tasks registry"* ]] || \
    fail "a normal run did not report the preflight finding"
}

configure_prism_runtime() {
  local tmp="$1"
  mkdir -p "${tmp}/config/niri"
  ln -s "${repo_root}/prism/titan" "${tmp}/config/prism"
  mkdir -p "${tmp}/config/wali"
  ln -s "${repo_root}/wali/titan/config.toml" "${tmp}/config/wali/config.toml"
}

test_dotfiles_health_checks_wali_config_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "${tmp}/config/wali"
  prepare_health_fixture "$tmp"
  ln -s "${repo_root}/prism/titan" "${tmp}/config/prism"
  ln -s "${repo_root}/wali/europa/config.toml" "${tmp}/config/wali/config.toml"

  set +e
  output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted the wrong wali config link"
  [[ "$output" == *"wrong link target"*"wali/config.toml"* ]] || \
    fail "health did not explain the wrong wali config link"

  rm -f "${tmp}/config/wali/config.toml"
  ln -s "${repo_root}/wali/titan/config.toml" "${tmp}/config/wali/config.toml"
  output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1) || \
    fail "health rejected the correct wali config link: $output"
}

test_dotfiles_health_accepts_prism_runtime() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"
  configure_prism_runtime "$tmp"

  PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd >/dev/null
}

test_dotfiles_health_rejects_missing_or_external_prism_contexts() {
  local tmp fixture output exit_status context_state
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"
  fixture="${tmp}/repo"
  mkdir -p "$fixture/bin" "$fixture/lib" "$fixture/prism/titan" "${tmp}/external"
  cp "${repo_root}/bin/dotfiles-health" "$fixture/bin/"
  cp "${repo_root}/lib/dotfiles-setup-data.bash" "$fixture/lib/"
  ln -s "$fixture/prism/titan" "${tmp}/config/prism"
  local repo_root="$fixture"

  for context_state in missing external; do
    if [[ "$context_state" == external ]]; then
      ln -s "${tmp}/external" "$fixture/prism/titan/contexts"
    fi
    set +e
    output=$(PRISM_TEST_HOSTNAME=titan run_health "$tmp" --skip-systemd 2>&1)
    exit_status=$?
    set -e
    (( exit_status != 0 )) || fail "health accepted $context_state Prism contexts"
    [[ "$output" == *"[FAIL] not a real directory: ${tmp}/config/prism/contexts"* ]] || \
      fail "health did not identify $context_state Prism contexts"
  done
}

test_dotfiles_health_fails_when_prism_doctor_fails() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  prepare_health_fixture "$tmp"
  configure_prism_runtime "$tmp"

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

  prepare_health_fixture "$tmp"
  print -r -- '[templates]' > "${tmp}/config/noctalia/obsolete.toml"
  set +e
  output=$(run_health "$tmp" --skip-systemd 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted a Noctalia config warning"
  [[ "$output" == *"Noctalia config warning or error"* ]] || \
    fail "health did not explain the validator warning: ${output}"
}

test_dotfiles_health_rejects_noctalia_template_state_override() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  prepare_health_fixture "$tmp"
  mkdir -p "${tmp}/home/.local/state/noctalia"
  cat > "${tmp}/home/.local/state/noctalia/settings.toml" <<'EOF'
[theme.templates]
builtin_ids = ["btop", "kitty"]
community_ids = ["opencode", "zathura"]
EOF

  set +e
  output=$(run_health "$tmp" --skip-systemd --skip-noctalia-ipc 2>&1)
  exit_status=$?
  set -e

  (( exit_status != 0 )) || fail "health accepted a state-overridden template selection"
  [[ "$output" == *"merged Noctalia template selection differs"* ]] || \
    fail "health did not explain the template state override: ${output}"
}

test_dotfiles_health_fails_wrong_opencode_theme_link() {
  local tmp output exit_status theme_link mockbin
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mockbin="${tmp}/bin"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data" "$mockbin"
  prepare_health_fixture "$tmp"
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
  prepare_health_fixture "$tmp"
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
test_setup_and_health_install_safe_noctalia_stubs
test_bash_config_is_native_and_minimal
test_glow_theme_renders_color
test_noctalia_lsd_theme_is_consumed
test_noctalia_v5_config_contract
test_noctalia_template_hook_markers_are_reproducible
test_compositors_use_noctalia_v5
test_active_noctalia_code_has_no_v4_ipc
test_active_noctalia_code_has_no_v4_ipc_fails_on_scan_error
test_noctalia_builtin_hooks_leave_managed_configs_unchanged
test_zsh_pager_is_ansi_aware
test_setup_dry_run_link_only_does_not_write_home
test_setup_link_only_creates_expected_links_without_external_clones
test_setup_migrates_legacy_lsd_directory_link
test_setup_shell_generates_static_zsh_completions
test_setup_dry_run_can_enable_user_timers
test_setup_only_runs_selected_phase
test_setup_only_accepts_multiple_phases
test_setup_only_rejects_unknown_phase
test_noctalia_plugin_phase_links_and_enables_exact_ids
test_default_setup_does_not_require_live_noctalia
test_noctalia_plugin_phase_fails_when_ipc_is_unavailable
test_noctalia_plugin_phase_requires_prism_source
test_setup_and_health_share_managed_link_metadata
test_dotfiles_health_skips_prism_when_unconfigured
test_dotfiles_health_fails_missing_noctalia_config
test_dotfiles_health_fails_wrong_noctalia_plugin_link
test_dotfiles_health_fails_stale_noctalia_plugin_manifest
test_dotfiles_health_fails_when_wali_plugin_is_not_enabled
test_dotfiles_health_fails_when_prism_plugin_is_not_enabled
test_dotfiles_health_fails_when_plugin_list_is_unavailable
test_dotfiles_health_offline_flag_skips_only_plugin_ipc
test_dotfiles_health_skips_noctalia_on_macos
test_prism_launcher_link_survives_relocated_sibling_repos
test_dotfiles_health_fails_unknown_host_wrong_prism_marker_without_doctor
test_dotfiles_health_fails_unknown_host_dangling_prism_marker_without_doctor
test_dotfiles_health_fails_wrong_prism_link_without_running_doctor
test_dotfiles_health_fails_stale_removed_config_links
test_dotfiles_health_ignores_brave_runtime_symlinks
test_dotfiles_health_ignores_unmanaged_config_symlinks
test_dotfiles_health_fails_broken_managed_config_link
test_dotfiles_health_rejects_legacy_lsd_directory_link
test_dotfiles_health_rejects_legacy_yazi_directory_link
test_dotfiles_health_checks_enabled_user_timer
test_noctalia_v5_config_is_installed_and_validated
test_setup_graphical_config_hands_material_ownership_to_prism
test_setup_graphical_config_links_wali_config_for_known_host
test_clean_graphical_setup_creates_empty_hyprland_theme_stub
test_dotfiles_health_accepts_prism_runtime
test_dotfiles_health_checks_wali_config_link
test_dotfiles_health_rejects_missing_or_external_prism_contexts
test_dotfiles_health_fails_when_prism_doctor_fails
test_dotfiles_health_rejects_noctalia_config_warning
test_dotfiles_health_rejects_noctalia_template_state_override
test_dotfiles_health_fails_wrong_opencode_theme_link
test_dotfiles_health_rejects_symlinked_opencode_local
test_setup_continues_past_a_failing_phase
test_preflight_reports_every_unmet_prerequisite_without_mutating

print -- "setup and health tests passed"
