# Noctalia v5 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the active Quickshell-based Noctalia v4 integration with the
native v5 shell while preserving the tracked wallpaper, theming, bar, idle,
compositor, and CLI behavior.

**Architecture:** Two tracked v5 TOML overlays own stable shell behavior and
template registration. Existing compositor and wallpaper entry points call the
native `noctalia` executable directly; setup installs individual managed files
without tracking GUI state, and health validates an isolated config scope plus
the complete user-template registry. V4 remains installed but inactive through
one validated login.

**Tech Stack:** TOML, Bash, Zsh, Python 3 standard library, pytest, Niri KDL,
Hyprland hyprlang, Noctalia v5 CLI.

**Spec:** `docs/specs/2026-08-19-noctalia-v5-migration-design.md`

## Global Constraints

- Work in the existing `.worktrees/noctalia-v5-migration` worktree on branch
  `docs/noctalia-v5-migration`; preserve unrelated changes in the main checkout.
- Conventional commits only; no AI-attribution trailers or footers.
- `docs/` is ignored, so plan/spec updates require `git add -f`.
- Do not add dependencies, a v4/v5 wrapper, runtime version detection, or a
  silent fallback to another wallpaper backend.
- Keep `noctalia-shell`, its JSON state, and v4 plugin source intact until one
  successful v5 login and separate explicit removal approval.
- Do not track `~/.local/state/noctalia`, current wallpaper state, credentials,
  history, location, avatar, or caches.
- Do not enable the built-in Kitty template. The existing
  `noctalia-glass-sync` pipeline remains the sole owner of Nvim, Kitty, and
  OpenCode colors.
- Enabled built-ins are exactly `hyprland`, `gtk3`, `gtk4`, `qt`, `niri`,
  `ghostty`, and `btop`; the community selection is exactly `zathura`.
- Generated `hypr/noctalia.conf`, `niri/noctalia.kdl`, and the existing v4
  `hypr/noctalia/noctalia-colors.conf` remain ignored.
- Every behavior change is test-first: run the focused test RED for the stated
  reason, implement the minimum change, then run it GREEN.
- Automated validation always passes an isolated config directory. Bare
  `noctalia config validate` is reserved for the live cutover because it also
  reads GUI-managed state.
- Never point a mutation-safety test at the worktree. Reproduce symlink topology
  with disposable copies.

## File Map

- `noctalia/config.toml`: curated v5 shell, wallpaper, bar, idle, and hook
  settings.
- `noctalia/templates.toml`: the only v5 template registry and selection list.
- `shell/wali`, `bin/walictl`: native v5 wallpaper IPC consumers.
- `niri/config.kdl`, `hypr/hyprland.conf`: v5 startup, keybindings, surfaces,
  and generated-theme includes.
- `setup.sh`, `bin/dotfiles-health`: install and validate tracked v5 inputs;
  stop managing v4 plugin links.
- `tests/setup_and_health.zsh`, `tests/wali.zsh`,
  `tests/bin/test_walictl.py`: executable migration contracts.
- `noctalia/noctalia.md`, `noctalia/noctalia-wallpaper-switcher.md`: user-facing
  v5 operation and rollback documentation.

---

### Task 1: Declare the curated v5 config and complete template registry

**Files:**
- Create: `noctalia/config.toml`
- Modify: `noctalia/templates.toml`
- Modify: `tests/setup_and_health.zsh`

**Interfaces:**
- Produces: two independently valid v5 TOML overlays consumed by Task 7.
- Produces user template IDs: `glow`, `nvim`, `claude`, `codex`, `ohai`.
- Preserves the existing Nvim post-hook
  `~/bin/noctalia-glass-sync` as the multi-consumer commit boundary.

- [ ] **Step 1: Add the failing config-contract test**

Add `test_noctalia_v5_config_contract` to `tests/setup_and_health.zsh`. It
creates an isolated XDG tree, links the repository's Noctalia files into it,
validates only that directory, checks the registry listing, then verifies the
semantic values with Python's `tomllib`:

```zsh
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
```

Call it immediately after `test_glow_theme_renders_color` at the bottom of the
test file.

- [ ] **Step 2: Run the focused suite and confirm RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: FAIL because `noctalia/config.toml` does not exist.

- [ ] **Step 3: Create the minimal curated config**

Create `noctalia/config.toml` with exactly these settings:

```toml
[theme]
mode = "dark"
source = "wallpaper"
wallpaper_scheme = "m3-tonal-spot"

[wallpaper]
directory = "~/d/linux/backgrounds/3440"
edge_smoothness = 0.05
transition = ["fade"]
transition_on_startup = true

[wallpaper.automation]
enabled = true
interval_seconds = 900
order = "alphabetical"

[backdrop]
enabled = false

[bar]
order = ["default"]

[bar.default]
background_opacity = 0.93
center = ["active_window"]
end = ["tray", "battery", "notifications", "output_volume", "wallpaper", "clock"]
start = ["workspaces", "cpu", "ram"]

[desktop_widgets]
enabled = false

[dock]
enabled = false

[notification]
position = "top_right"

[osd]
position = "top_right"
position_vertical = "top_right"

[shell]
ui_scale = 1.05

[shell.panel]
transparency_mode = "glass"

[hooks]
theme_mode_changed = ["~/d/familiar/bin/familiar-noctalia scheme-sync"]

[idle]
behavior_order = ["screen-off", "lock", "lock-and-suspend"]

[idle.behavior.screen-off]
action = "screen_off"
enabled = true
timeout = 600

[idle.behavior.lock]
action = "lock"
enabled = true
timeout = 3600

[idle.behavior.lock-and-suspend]
action = "lock_and_suspend"
enabled = true
timeout = 86400
```

Do not add v5 defaults such as `transition_duration` or
`wallpaper.automation.recursive`.

- [ ] **Step 4: Replace `noctalia/templates.toml` with the complete registry**

```toml
[theme.templates]
builtin_ids = ["hyprland", "gtk3", "gtk4", "qt", "niri", "ghostty", "btop"]
community_ids = ["zathura"]

[theme.templates.user.glow]
input_path = "$XDG_CONFIG_HOME/noctalia/templates/glow.json"
output_path = "$XDG_CACHE_HOME/noctalia/glow.json"

[theme.templates.user.nvim]
input_path = "$XDG_CONFIG_HOME/nvim/lua/user/noctalia/palette-template.json"
output_path = "$XDG_CACHE_HOME/noctalia/nvim-palette.candidate.json"
post_hook = "~/bin/noctalia-glass-sync"

[theme.templates.user.claude]
input_path = "$XDG_CONFIG_HOME/noctalia/templates/claude.json"
output_path = "~/.claude/themes/noctalia.json"

[theme.templates.user.codex]
input_path = "$XDG_CONFIG_HOME/noctalia/templates/codex.tmTheme"
output_path = "~/.codex/themes/noctalia.tmTheme"

[theme.templates.user.ohai]
input_path = "~/d/software/ohai/ohai/templates/noctalia/ohai-config.toml"
output_path = "$XDG_CONFIG_HOME/ohai/config.toml"
```

- [ ] **Step 5: Run GREEN and commit**

```bash
zsh tests/setup_and_health.zsh
git add noctalia/config.toml noctalia/templates.toml tests/setup_and_health.zsh
git diff --cached --check
git commit -m "feat(noctalia): declare v5 shell configuration"
```

Expected: `setup and health tests passed`.

---

### Task 2: Fix clean-checkout GTK and prepare the Hyprland include

**Files:**
- Modify: `.gitignore`
- Create: `gtk-3.0/gtk.css`
- Modify: `hypr/hyprland.conf`
- Modify: `tests/setup_and_health.zsh`

**Interfaces:**
- Produces the tracked GTK 3 source required by `setup.sh:ln_s`.
- Produces the exact Hyprland marker required to make the v5 built-in hook a
  no-op; Task 3 depends on this commit.

- [ ] **Step 1: Add the failing repository-invariant test**

```zsh
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
```

Call it after `test_noctalia_v5_config_contract`.

- [ ] **Step 2: Run RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: FAIL because `gtk-3.0/gtk.css` is ignored and untracked.

- [ ] **Step 3: Make the three minimal baseline edits**

- Remove only `gtk-3.0/gtk.css` from `.gitignore`.
- Add `hypr/noctalia.conf` to the generated Noctalia ignore block; retain the
  old `hypr/noctalia/noctalia-colors.conf` ignore for rollback state.
- Track `gtk-3.0/gtk.css`:

```css
/* Keep the built-in Noctalia import stable; its post-hook probes this marker. */
@import url("noctalia.css");
```

- Replace the one active Hyprland source line with:

```ini
source = ~/.config/hypr/noctalia.conf
```

- [ ] **Step 4: Run GREEN and prove the GTK phase works from the worktree**

```bash
zsh tests/setup_and_health.zsh
tmp=$(mktemp -d)
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" \
  bash setup.sh --link-only --only gtk
test -L "$tmp/config/gtk-3.0/gtk.css"
test -L "$tmp/config/gtk-4.0/gtk.css"
rm -rf "$tmp"
```

Expected: the suite passes and setup creates both GTK links without
`Link source does not exist`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore gtk-3.0/gtk.css hypr/hyprland.conf tests/setup_and_health.zsh
git diff --cached --check
git commit -m "fix(setup): restore clean-checkout GTK source"
```

---

### Task 3: Guard all enabled mutating template hooks

**Files:**
- Modify: `tests/setup_and_health.zsh`

**Interfaces:**
- Consumes the Hyprland source migration from Task 2.
- Protects the Niri directory link, Hyprland directory link, Ghostty file link,
  and GTK 3/4 file links without ever targeting the worktree.

- [ ] **Step 1: Add a disposable-topology helper and test**

Add a test that copies the five tracked targets under `${tmp}/targets`, then
recreates the live topology below `${tmp}/home/.config`: directory symlinks for
Niri and Hyprland, ordinary directories containing file symlinks for Ghostty
and GTK. Mock `hyprctl`, `gsettings`, and `dconf` so hooks cannot reach the live
desktop.

```zsh
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
  for path in ghostty/config.ghostty gtk-3.0/gtk.css gtk-4.0/gtk.css; do
    [[ -L "$config/$path" ]] || fail "a managed file link was replaced: $path"
  done
}
```

Call it after `test_noctalia_template_hook_markers_are_reproducible`.

- [ ] **Step 2: Run the characterization test**

```bash
zsh tests/setup_and_health.zsh
```

Expected: GREEN. Task 2 deliberately lands first; without its Hyprland source
migration this test changes the disposable `hyprland.conf` and fails the hash
comparison.

- [ ] **Step 3: Commit the regression guard**

```bash
git add tests/setup_and_health.zsh
git diff --cached --check
git commit -m "test(noctalia): guard built-in template hooks"
```

---

### Task 4: Move `walictl` to native v5 IPC

**Files:**
- Modify: `bin/walictl`
- Modify: `tests/bin/test_walictl.py`
- Modify: `justfile`
- Modify: `tests/justfile.zsh`

**Interfaces:**
- Produces `run_noctalia_msg(*args: str) -> str` as the single subprocess
  boundary.
- Exact commands: `wallpaper-get`, `wallpaper-set <path>`, and
  `wallpaper-random`.

- [ ] **Step 1: Update existing expectations and add navigation/random tests**

Replace every query expectation with:

```python
["noctalia", "msg", "wallpaper-get"]
```

Rename `test_current_fails_when_qs_command_is_missing` to
`test_current_fails_when_noctalia_command_is_missing` and expect
`noctalia command not found`. Retain the empty-output case; rename the failed
query case for Noctalia and expect `Noctalia IPC command failed`.
Add exact command tests:

```python
@pytest.mark.parametrize(
    ("command", "expected_name"),
    [("forward", "c.jpg"), ("backward", "a.jpg")],
)
def test_navigation_uses_v5_wallpaper_set(tmp_path, monkeypatch, command, expected_name):
    first = tmp_path / "a.jpg"
    current = tmp_path / "b.jpg"
    last = tmp_path / "c.jpg"
    for path in (first, current, last):
        path.touch()
    calls = []

    def fake_run(args, **kwargs):
        calls.append(args)
        stdout = f"{current}\n" if args[-1] == "wallpaper-get" else ""
        return subprocess.CompletedProcess(args, 0, stdout=stdout, stderr="")

    monkeypatch.setattr(subprocess, "run", fake_run)
    code, stdout, stderr = run_walictl([command], monkeypatch)
    assert (code, stderr) == (0, "")
    expected = tmp_path / expected_name
    assert calls == [
        ["noctalia", "msg", "wallpaper-get"],
        ["noctalia", "msg", "wallpaper-set", str(expected)],
    ]


def test_random_uses_v5_wallpaper_random(monkeypatch):
    calls = []

    def fake_run(args, **kwargs):
        calls.append(args)
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

    monkeypatch.setattr(subprocess, "run", fake_run)
    code, stdout, stderr = run_walictl(["random"], monkeypatch)
    assert (code, stdout, stderr) == (0, "randomized wallpaper\n", "")
    assert calls == [["noctalia", "msg", "wallpaper-random"]]
```

- [ ] **Step 2: Run RED**

```bash
uv run --frozen pytest -q tests/bin/test_walictl.py
zsh tests/justfile.zsh
```

Expected: existing code still invokes `qs -c noctalia-shell`; forward and
backward use the v4 wallpaper call, random uses the plugin call, and the
`justfile` test reports that pytest is absent from the complete gate.

- [ ] **Step 3: Replace both v4 IPC helpers with one v5 boundary**

```python
def run_noctalia_msg(*args: str) -> str:
    try:
        result = subprocess.run(
            ["noctalia", "msg", *args],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise WalictlError("noctalia command not found") from exc
    except subprocess.CalledProcessError as exc:
        raise WalictlError("Noctalia IPC command failed") from exc
    return result.stdout
```

Use `run_noctalia_msg("wallpaper-get")` in
`get_current_wallpaper_path`; preserve its empty-output
`WallpaperQueryError`. Use:

```python
run_noctalia_msg("wallpaper-set", str(new_path))
run_noctalia_msg("wallpaper-random")
```

Delete `ipc_call_noctalia`, `ipc_call_wallpaper`, and
`ipc_call_wali_panel`; do not retain compatibility aliases.

Add `uv run --frozen pytest -q` to the `test` recipe in `justfile`. Extend
`tests/justfile.zsh` with:

```zsh
assert_contains "$test_dry_run" "uv run --frozen pytest -q" \
  "expected test recipe to include Python tests"
```

- [ ] **Step 4: Run GREEN and commit**

```bash
uv run --frozen pytest -q tests/bin/test_walictl.py
zsh tests/justfile.zsh
git add bin/walictl tests/bin/test_walictl.py justfile tests/justfile.zsh
git diff --cached --check
git commit -m "feat(walictl): use Noctalia v5 IPC"
```

---

### Task 5: Route shell Wali wallpaper state through one helper

**Files:**
- Modify: `shell/wali`
- Modify: `tests/wali.zsh`

**Interfaces:**
- Produces `_wali_current_wallpaper`, shared by `wali_print` and `wali_rotate`.
- Backend selection is executable-based on Wayland: Noctalia, then swww, then
  feh. A stopped Noctalia shell fails its IPC call instead of changing backend.

- [ ] **Step 1: Extend the Zsh test with a mock Noctalia backend**

Add a `${tmp}/bin/noctalia` mock that logs every argument and prints
`${NOCTALIA_WALLPAPER}` for `msg wallpaper-get`. In a child Zsh process with a
nonempty `WAYLAND_DISPLAY`, no `.fehbg`, and temporary archive/current files,
append this case after the existing image-processing assertions:

```zsh
mkdir -p "${tmp}/home" "${tmp}/current" "${tmp}/archive/2024/05"
export NOCTALIA_LOG="${tmp}/noctalia.log"
export NOCTALIA_WALLPAPER="${tmp}/current/PXL_20240520_023703962.jpg"
export BACKGROUND_IMG_DIR="${tmp}/archive"
touch "$NOCTALIA_WALLPAPER" \
  "${BACKGROUND_IMG_DIR}/2024/05/PXL_20240520_023703962.jpg"

cat > "${tmp}/bin/noctalia" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$NOCTALIA_LOG"
if [[ "$*" == "msg wallpaper-get" ]]; then
  print -r -- "$NOCTALIA_WALLPAPER"
fi
EOF
chmod +x "${tmp}/bin/noctalia"

HOME="${tmp}/home" WAYLAND_DISPLAY=wayland-1 \
  PATH="${tmp}/bin:$PATH" zsh -f -c '
    source "$1/shell/wali"
    [[ "$WALI_BACKEND" == noctalia ]]
    [[ "$(_wali_current_wallpaper)" == "$NOCTALIA_WALLPAPER" ]]
    [[ "$(wali_print)" == \
      "$BACKGROUND_IMG_DIR/2024/05/PXL_20240520_023703962.jpg" ]]
    wali_rotate r >/dev/null
  ' zsh "$repo_root"

rg -q -x 'msg wallpaper-get' "$NOCTALIA_LOG" || \
  fail 'wali did not query the v5 wallpaper'
rg -q -F "msg wallpaper-set ${NOCTALIA_WALLPAPER}" "$NOCTALIA_LOG" || \
  fail 'wali rotate did not reset the v5 wallpaper'
! rg -q -F qs "$NOCTALIA_LOG" || fail 'wali called Quickshell IPC'
```

The missing `.fehbg` is the regression condition for both consumers.

- [ ] **Step 2: Run RED**

```bash
zsh tests/wali.zsh
```

Expected: backend detection falls through because no `noctalia-shell` process
exists, or the current path is read from missing `.fehbg`.

- [ ] **Step 3: Implement the single backend query**

Replace process-based detection with:

```zsh
if [[ -n "$WAYLAND_DISPLAY" ]] && command -v noctalia >/dev/null 2>&1; then
  WALI_BACKEND="noctalia"
elif [[ -n "$WAYLAND_DISPLAY" ]] && command -v swww >/dev/null 2>&1; then
  WALI_BACKEND="swww"
else
  WALI_BACKEND="feh"
fi
```

Use `noctalia msg wallpaper-random` for alias `wali`, and
`noctalia msg wallpaper-set "$img"` in `wali_set`. Add:

```zsh
function _wali_current_wallpaper {
  case "$WALI_BACKEND" in
    noctalia)
      noctalia msg wallpaper-get
      ;;
    swww)
      swww query | grep --color=never -oP 'image: \K.*' | head -n1
      ;;
    feh)
      /bin/cat ~/.fehbg | \
        /bin/grep --color=never -Eo "[\/a-z0-9]+PXL.*\.(jpg|png)"
      ;;
  esac
}
```

Replace both duplicated query blocks in `wali_print` and `wali_rotate` with
`file=$(_wali_current_wallpaper)` / `current=$(_wali_current_wallpaper)`.
Update the header comment from `noctalia-shell` to `Noctalia`.

- [ ] **Step 4: Run GREEN and commit**

```bash
zsh tests/wali.zsh
git add shell/wali tests/wali.zsh
git diff --cached --check
git commit -m "feat(wali): query Noctalia v5 wallpaper state"
```

---

### Task 6: Switch compositor startup, IPC, and surfaces to v5

**Files:**
- Modify: `niri/config.kdl`
- Modify: `hypr/hyprland.conf`
- Modify: `tests/setup_and_health.zsh`

**Interfaces:**
- Uses only `noctalia` and `noctalia msg`; no Quickshell IPC remains in active
  compositor config.
- Preserves Niri stationary wallpaper mode and current key choices.

- [ ] **Step 1: Add the failing static compositor contract**

```zsh
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
```

- [ ] **Step 2: Run RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: both compositors still start `qs -c noctalia-shell`.

- [ ] **Step 3: Migrate Niri directly**

- Replace startup with `spawn-at-startup "noctalia"`.
- Translate existing launcher, control-center, settings, volume, and brightness
  binds to argument-form `spawn "noctalia" "msg" ...` commands from the spec.
- Change the stationary match to `namespace="^noctalia-wallpaper"`.
- Replace the v4 blur namespace with:

```kdl
layer-rule {
    match namespace=r#"^noctalia-(bar-[^"]+|notification|dock|panel|attached-panel|osd)$"#
    background-effect { xray false }
}

layer-rule {
    match namespace="noctalia-window-switcher"
    background-effect {
        blur true
        xray false
    }
}
```

- Add the documented settings rule:

```kdl
window-rule {
    match app-id="dev.noctalia.Noctalia"
    open-floating true
    default-column-width { fixed 1080; }
    default-window-height { fixed 920; }
}
```

- [ ] **Step 4: Migrate Hyprland directly**

- Replace startup with `exec-once = noctalia`.
- Set `$ipc = noctalia msg` and translate the existing binds to
  `panel-toggle launcher`, `panel-toggle control-center`, `settings-toggle`,
  `volume-up`, `volume-down`, `volume-mute`, `brightness-up`, and
  `brightness-down`.
- Keep the `source = ~/.config/hypr/noctalia.conf` line from Task 2.
- Replace the v4 namespace with the documented v5 expression and disable
  compositor animation for Noctalia surfaces:

```ini
layerrule {
  name = noctalia
  match:namespace = ^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$
  no_anim = true
  ignore_alpha = 0.5
  blur = true
  blur_popups = true
}
```

- [ ] **Step 5: Validate GREEN and commit**

```bash
zsh tests/setup_and_health.zsh
niri validate -c niri/config.kdl
git add niri/config.kdl hypr/hyprland.conf tests/setup_and_health.zsh
git diff --cached --check
git commit -m "feat(noctalia): switch compositor integration to v5"
```

Do not reload either live compositor in this task.

---

### Task 7: Install and health-check v5 inputs; stop managing v4 plugins

**Files:**
- Modify: `setup.sh`
- Modify: `bin/dotfiles-health`
- Modify: `tests/setup_and_health.zsh`

**Interfaces:**
- Setup manages `config.toml`, `templates.toml`, `templates/`, and
  `palettes/Glow.json` as individual links.
- Health validates the explicit Noctalia config directory, fails warning-only
  output, and requires all five user template IDs.
- V4 plugin sources remain in place, but setup and health no longer link or
  require them.

- [ ] **Step 1: Replace plugin-link tests with v5 managed-input tests**

Delete these obsolete tests and calls:

- `test_setup_graphical_app_config_links_memory_alert`
- `test_setup_graphical_app_config_links_prism`
- `test_dotfiles_health_fails_wrong_memory_alert_link`

Expand `test_noctalia_glow_template_is_installed_and_rendered` into
`test_noctalia_v5_config_is_installed_and_validated`. After
`run_setup "$tmp" --link-only --only app-config`, assert the four managed links
and that `${tmp}/config/noctalia/plugins` was not created. Run the isolated
validator and template listing exactly as in Task 1.

Add a health rejection case:

```zsh
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
```

- [ ] **Step 2: Run RED**

```bash
zsh tests/setup_and_health.zsh
```

Expected: `config.toml` is not linked, plugin links still exist, and health
ignores the warning-only file.

- [ ] **Step 3: Make setup manage only v5 inputs**

Inside the graphical Noctalia block in `setup_application_config_links`:

- Remove `noctalia_plugin_dir`, `wali_panel_plugin`, `memory_alert_plugin`, and
  `prism_plugin` variables and all associated backup/link operations.
- Do not create `${XDG_CONFIG_HOME}/noctalia/plugins`.
- Add `noctalia_config="${XDG_CONFIG_HOME}/noctalia/config.toml"`.
- Link `${DOTS_HOME}/noctalia/config.toml` to that destination beside the
  existing palette, template directory, and template registry links.

Do not delete pre-existing live plugin links; rollback state is operator-owned.

- [ ] **Step 4: Make health validate the managed v5 contract**

Replace the memory-alert check with links for all four managed inputs. Then run:

```bash
if output=$(noctalia config validate "${XDG_CONFIG_HOME}/noctalia" 2>&1); then
    if grep -Eq '(^|[[:space:]])(WARN|ERROR)([[:space:]]|$)' <<<"$output"; then
        fail "Noctalia config warning or error: $output"
    else
        pass "Noctalia config validates without warnings"
    fi
else
    fail "Noctalia config validation failed: $output"
fi
```

Capture `noctalia theme --list-templates` and require lines for `glow`, `nvim`,
`claude`, `codex`, and `ohai` in the User templates section. A missing command,
failed validator, failed listing, warning, or missing ID is a health failure.

- [ ] **Step 5: Run GREEN and commit**

```bash
zsh tests/setup_and_health.zsh
git add setup.sh bin/dotfiles-health tests/setup_and_health.zsh
git diff --cached --check
git commit -m "feat(setup): install and validate Noctalia v5 config"
```

---

### Task 8: Remove active v4 references and document the cutover

**Files:**
- Modify: `tests/setup_and_health.zsh`
- Modify: `noctalia/noctalia.md`
- Modify: `noctalia/noctalia-wallpaper-switcher.md`
- Modify: `docs/specs/2026-08-19-noctalia-v5-migration-design.md`

**Interfaces:**
- Produces user-facing documentation matching the now-active code.
- Leaves package removal and destructive v4-state cleanup outside the commit.

- [ ] **Step 1: Add the final active-code scan**

```zsh
test_active_noctalia_code_has_no_v4_ipc() {
  local files=(
    "${repo_root}/bin/walictl"
    "${repo_root}/shell/wali"
    "${repo_root}/niri/config.kdl"
    "${repo_root}/hypr/hyprland.conf"
    "${repo_root}/setup.sh"
    "${repo_root}/bin/dotfiles-health"
  )
  ! rg -n 'noctalia-shell|qs.*ipc.*(wallpaper|launcher|controlCenter|settings|volume|brightness)' \
    "${files[@]}" || fail "active code still contains Noctalia v4 IPC"
}
```

Run `zsh tests/setup_and_health.zsh`; expected GREEN if Tasks 4–7 are complete.

- [ ] **Step 2: Rewrite the user-facing Noctalia docs for v5**

In `noctalia/noctalia.md`:

- Name `noctalia/config.toml` and `noctalia/templates.toml` as tracked inputs.
- Describe the five user templates and seven selected built-ins; explicitly say
  Kitty stays under `noctalia-glass-sync` ownership.
- Remove v4 `[templates.*]` examples and instructions to enable QML plugins.
- State that Wali Panel, Memory Pressure Alert, and Prism v4 plugin ports are
  deferred; their source is not active v5 code.
- Document `noctalia config validate` and `noctalia theme --list-templates`.

In `noctalia/noctalia-wallpaper-switcher.md`:

- Replace every `qs -c noctalia-shell` example with the native v5 command.
- State that `walictl random` uses `noctalia msg wallpaper-random` and
  forward/backward use `wallpaper-set`.
- Remove Wali Panel UI and plugin-install claims; the built-in wallpaper widget
  is the core picker, while source-photo CLI actions remain in `walictl`.

- [ ] **Step 3: Update design status accurately**

Change the design header to:

```markdown
**Status:** Implemented; live cutover validation pending.
```

Do not mark the live login or v4 package removal complete.

- [ ] **Step 4: Run the complete repository gate**

```bash
placeholder_pattern="T""BD|TO""DO|FIX""ME|PLACE""HOLDER"
! rg -n "$placeholder_pattern" \
  docs/specs/2026-08-19-noctalia-v5-migration-design.md \
  docs/plans/2026-08-19-noctalia-v5-migration.md \
  noctalia/noctalia.md noctalia/noctalia-wallpaper-switcher.md
forbidden_home="/home/"keith
forbidden_mount="/mnt/ssd/"Dropbox
! rg -n "$forbidden_home|$forbidden_mount" \
  docs/specs/2026-08-19-noctalia-v5-migration-design.md \
  docs/plans/2026-08-19-noctalia-v5-migration.md \
  noctalia/noctalia.md noctalia/noctalia-wallpaper-switcher.md
just test
git diff --check
```

Expected: the scan has no matches, every suite passes, and diff check is clean.

- [ ] **Step 5: Commit**

```bash
git add tests/setup_and_health.zsh noctalia/noctalia.md \
  noctalia/noctalia-wallpaper-switcher.md
git add -f docs/specs/2026-08-19-noctalia-v5-migration-design.md
git diff --cached --check
git commit -m "docs(noctalia): document v5 cutover"
```

## Live Cutover Checkpoint

After all implementation commits pass `just test`, stop before mutating the
live session. With the user present:

1. Confirm `noctalia-shell`, v4 JSON config, and v4 plugin directories remain.
2. Rename `~/.config/noctalia/user-templates.toml` to
   `~/.config/noctalia/user-templates.toml.v4-disabled`.
3. Run `bash setup.sh --link-only --only gtk,app-config`.
4. Run `noctalia config validate`; require no warnings or errors.
5. Stop v4, start `noctalia`, and exercise every compositor keybinding.
6. Exercise `walictl current --json`, forward, backward, and random.
7. Change wallpaper; confirm Glow, Nvim, Kitty, OpenCode, Claude Code, Codex,
   Ohai, and selected built-ins update while `git status --short` stays empty.
8. Reload Niri and complete one fresh login.
9. Ask separately before uninstalling `noctalia-shell` or archiving v4 state.

Rollback before step 9: stop v5, restore the original template registry name,
launch v4, and revert the cohesive migration commit if compositor autostart
must return to v4.
