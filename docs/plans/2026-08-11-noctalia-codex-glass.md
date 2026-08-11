# Noctalia Codex Glass Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Codex translucent red/green diff backgrounds and a live
Noctalia-colored terminal selection while leaving its unsupported input box
unchanged.

**Architecture:** Codex's existing `.tmTheme` supplies the fixed diff cell
backgrounds already registered in Kitty. The atomic Noctalia promotion writes
the current `primary_container` as `selection_background` beside Kitty's
seven-slot transparency directive, and Kitty includes that generated file
after `current-theme.conf` so last-value-wins applies the live selection.

**Tech Stack:** XML plist (`.tmTheme`), Python 3 stdlib, Bash tests, Lua/Neovim
tests, Kitty configuration.

**Spec:** `docs/specs/2026-08-09-noctalia-nvim-theme-design.md`

## Global Constraints

- Before Task 1, use `superpowers:using-git-worktrees`; all paths below are
  relative to the isolated worktree root.
- Conventional commits only; no AI attribution trailers or `Co-Authored-By`.
- `docs/` is gitignored, so tracked plan/spec changes require `git add -f`.
- No new dependencies. Python code uses only the standard library.
- Production generated files remain pinned to literal
  `~/.cache/noctalia/nvim-glass/current/`; `NOCTALIA_GLASS_DIR` remains
  tests-only.
- Kitty keeps exactly seven registered transparency colors: four neutral
  chrome tones, `#022800@0.72`, `#3d0100@0.72`, and the current
  `glass.selection@0.55`.
- The Codex diff backgrounds are exactly `#022800` and `#3d0100`; they must
  match the fixed Kitty registrations and Claude theme.
- `kitty-glass.conf` contains exactly two directives, in this order:
  `transparent_background_colors ...`, then
  `selection_background <glass.selection>`.
- The `current` symlink rename remains the commit point. Both generated files
  are staged before the flip; signals remain post-commit reconciliation.
- The hardcoded fresh-machine selection fallback is `#003dbe`, matching
  `default_palette.lua` and the fixture.
- Codex 0.147.0's input box remains opaque. Do not add a restart loop, retain
  historical wallpaper tones, wrap Codex, or patch/build Codex.
- Behavior changes are test-first: run the focused test red for the stated
  reason, make the minimum implementation, then run it green.
- Do not touch unrelated worktree changes.

---

### Task 1: Add Codex diff backgrounds

**Files:**
- Modify: `tests/noctalia_agent_themes_test.py:68-76`
- Modify: `noctalia/templates/codex.tmTheme:138-159`

**Interfaces:**
- Consumes: Codex TextMate scopes `markup.inserted` and `markup.deleted`.
- Produces: rendered scope settings with fixed `background` values `#022800`
  and `#3d0100`; existing dynamic foregrounds remain unchanged.

- [ ] **Step 1: Write the failing assertions**

Add after the existing Codex syntax-scope assertions:

```python
codex_scopes = {
    entry["scope"]: entry["settings"]
    for entry in codex["settings"]
    if "scope" in entry
}
assert codex_scopes["markup.inserted"]["background"] == "#022800"
assert codex_scopes["markup.deleted"]["background"] == "#3d0100"
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
python3 tests/noctalia_agent_themes_test.py
```

Expected: failure with `KeyError: 'background'` for `markup.inserted`.

- [ ] **Step 3: Add only the two fixed background settings**

Change the `Inserted` settings dictionary to:

```xml
      <dict>
        <key>background</key>
        <string>#022800</string>
        <key>foreground</key>
        <string>{{colors.secondary_fixed_dim.default.hex}}</string>
      </dict>
```

Change the `Deleted` settings dictionary to:

```xml
      <dict>
        <key>background</key>
        <string>#3d0100</string>
        <key>foreground</key>
        <string>{{colors.error.default.hex}}</string>
      </dict>
```

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run:

```bash
python3 tests/noctalia_agent_themes_test.py
```

Expected: `OK noctalia agent themes`.

- [ ] **Step 5: Commit**

```bash
git add noctalia/templates/codex.tmTheme tests/noctalia_agent_themes_test.py
git diff --cached --check
git commit -m "feat(noctalia): add codex diff backgrounds"
```

---

### Task 2: Promote and validate the live Kitty selection

**Files:**
- Modify: `nvim/tests/noctalia/glass_sync_test.sh:60-72`
- Modify: `nvim/tests/noctalia/glass_check_test.sh:14-38`
- Modify: `bin/noctalia-glass-sync:127-134`
- Modify: `bin/noctalia-glass-check:93-102`
- Modify: `nvim/tests/noctalia/mood_swatches_test.sh:12`

**Interfaces:**
- Consumes: validated `raw['glass']['selection']` from the candidate JSON.
- Produces: a two-line `kitty-glass.conf`; the checker accepts only those two
  directives and requires the selection value to equal the promoted palette.

- [ ] **Step 1: Make the sync success case require both directives**

Replace the current one-line count/assertion in
`glass_sync_test.sh` with:

```bash
[[ "$(wc -l < "$CUR/kitty-glass.conf")" == 2 ]] || {
  echo "FAIL: kitty conf must have two lines"
  cat "$CUR/kitty-glass.conf"
  exit 1
}
grep -qx 'transparent_background_colors #1e2030 #2f334d #272a3f #3b4261 #022800@0.72 #3d0100@0.72 #003dbe@0.55' \
  "$CUR/kitty-glass.conf" || { echo "FAIL: kitty transparent list wrong"; cat "$CUR/kitty-glass.conf"; exit 1; }
grep -qx 'selection_background #003dbe' "$CUR/kitty-glass.conf" || {
  echo "FAIL: kitty selection wrong"
  cat "$CUR/kitty-glass.conf"
  exit 1
}
```

- [ ] **Step 2: Add a checker regression for selection drift**

Insert after the healthy promoted-state check in
`glass_check_test.sh`, then renumber later case comments:

```bash
# 3. generated selection must equal the promoted palette: FAIL
sed -i 's/^selection_background .*/selection_background #111111/' \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: selection desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }
```

- [ ] **Step 3: Run both focused tests and confirm RED**

Run:

```bash
nvim/tests/noctalia/glass_sync_test.sh
nvim/tests/noctalia/glass_check_test.sh
```

Expected: `glass_sync_test.sh` reports `kitty conf must have two lines`, and
`glass_check_test.sh` reports `selection desync must fail`.

- [ ] **Step 4: Emit the selection in the staged generation**

Replace the `kitty-glass.conf` write in `noctalia-glass-sync` with:

```python
        (vdir / 'kitty-glass.conf').write_text(
            'transparent_background_colors ' + ' '.join(tones) + '\n'
            f"selection_background {raw['glass']['selection'].lower()}\n")
```

Do not change promotion order: both files must still be written before the
prepared symlink is renamed over `current`.

- [ ] **Step 5: Validate exactly two directives and the selected tone**

Replace the checker block beginning with `m = re.fullmatch(...)` with:

```python
    lines = kitty_text.splitlines()
    if len(lines) != 2:
        fail(f'{kitty_file} must contain exactly two directives')
    m = re.fullmatch(r'transparent_background_colors (.+)', lines[0])
    if not m:
        fail(f'{kitty_file} has no transparent_background_colors line')
    kitty_tones = m.group(1).split()
    if kitty_tones != palette_tones:
        fail(f'tones desynced: kitty={kitty_tones} palette={palette_tones}')
    expected_selection = f"selection_background {glass['selection'].lower()}"
    if lines[1] != expected_selection:
        fail(f'selection desynced: kitty={lines[1]!r} palette={expected_selection!r}')
```

This retains the existing duplicate-directive rejection because any third
line fails the exact line-count check.

- [ ] **Step 6: Run both focused tests and confirm GREEN**

Run:

```bash
nvim/tests/noctalia/glass_sync_test.sh
nvim/tests/noctalia/glass_check_test.sh
```

Expected: `OK glass_sync` and `OK glass_check`.

- [ ] **Step 7: Make the mood-swatch test report consistently**

Append:

```bash
echo "OK mood_swatches"
```

Run:

```bash
nvim/tests/noctalia/mood_swatches_test.sh
```

Expected: `OK mood_swatches`.

- [ ] **Step 8: Commit**

```bash
git add bin/noctalia-glass-sync bin/noctalia-glass-check \
  nvim/tests/noctalia/glass_sync_test.sh \
  nvim/tests/noctalia/glass_check_test.sh \
  nvim/tests/noctalia/mood_swatches_test.sh
git diff --cached --check
git commit -m "feat(noctalia): generate kitty selection color"
```

---

### Task 3: Make the generated selection win in Kitty

**Files:**
- Modify: `nvim/tests/noctalia/palette_test.lua:93-112`
- Modify: `kitty/kitty.conf:80-123`
- Modify: `noctalia/noctalia.md:30-58`
- Modify: `docs/specs/2026-08-09-noctalia-nvim-theme-design.md`

**Interfaces:**
- Consumes: the two-line generated include from Task 2.
- Produces: a fresh-machine `selection_background #003dbe` fallback and
  generated include precedence over `current-theme.conf`.

- [ ] **Step 1: Extend the fresh-machine invariant test**

Add after the existing fallback-tone loop in `palette_test.lua`:

```lua
local selection = conf:match('\nselection_background ([^\n]+)')
assert(selection == default.glass.selection,
  'kitty selection fallback must equal default glass.selection')
local theme_include = assert(conf:find('include current-theme.conf', 1, true),
  'current-theme include missing')
local glass_include = assert(conf:find(
  'include ${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf', 1, true),
  'generated glass include missing')
assert(theme_include < glass_include,
  'generated glass include must follow current-theme.conf')
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
nvim --clean -l nvim/tests/noctalia/palette_test.lua
```

Expected: failure with `kitty selection fallback must equal default
glass.selection`.

- [ ] **Step 3: Add the fallback and move the generated include**

Immediately after the hardcoded seven-slot line in `kitty/kitty.conf`, add:

```conf
selection_background #003dbe
```

Delete the generated include from its current position above the tmux settings.
Immediately after the `# END_KITTY_THEME` line, add:

```conf
# Generated Noctalia transparency and selection override. This must follow
# current-theme.conf because Kitty applies the last value for each setting.
include ${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf
```

Update the nearby slot comment from Claude-only wording to shared Claude/Codex
diff and selection semantics. Do not edit the generated/gitignored
`kitty/themes/noctalia.conf`.

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run:

```bash
nvim --clean -l nvim/tests/noctalia/palette_test.lua
```

Expected: `OK palette`.

- [ ] **Step 5: Update the user documentation**

Replace the final Agent themes paragraph in `noctalia/noctalia.md` with:

```markdown
Claude Code reloads theme-file changes live. If its themes directory did not
exist when Claude started, restart once after the first render. Codex applies
its syntax theme in new sessions. Kitty gives Claude and Codex red/green diff
backgrounds 72% opacity and the current Noctalia `primary_container` terminal
selection 55% opacity; the selection updates on wallpaper changes. Codex's
input box remains opaque because Codex owns and caches that background and
exposes no theme role for it.
```

- [ ] **Step 6: Mark the approved spec behavior implemented**

Change the status line to:

```markdown
**Status:** Implemented; original pipeline commits `753305e..0485858`, Codex
diff/selection refinement completed 2026-08-11.
```

Replace the pending Kitty architecture bullet with:

```markdown
- `kitty.conf` keeps hardcoded `transparent_background_colors` and semantic
  `selection_background` fallbacks, then includes
  `${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf` after
  `current-theme.conf`. Kitty is last-value-wins, so the generated selection
  overrides Noctalia's built-in theme selection.
```

Replace the pending Codex subsection through its acceptance paragraph with:

```markdown
#### Codex refinement

Codex's custom `.tmTheme` has a narrower but useful UI contract. Its
`markup.inserted` and `markup.deleted` scope backgrounds override the native
diff backgrounds, so the Noctalia theme sets them to the same fixed green and
red already registered for Claude. Terminal text selection is owned by Kitty,
not Codex; the generated `selection_background` points it at the registered
`primary_container` tone and therefore updates live on wallpaper changes.
`kitty-glass.conf` contains both settings, and its include follows
`current-theme.conf` so the generated selection wins.

Acceptance: in a newly started Codex session, added/deleted diff backgrounds
and terminal text selection are colored and translucent before and after later
wallpaper switches; the input box remains Codex-owned and opaque.
```

Retain the following input-box rationale unchanged.

- [ ] **Step 7: Run the complete automated verification**

Run from the worktree root:

```bash
env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache nvim/tests/noctalia/run.sh
env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache bin/dotfiles-check
env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache \
  python3 -m py_compile bin/noctalia-glass-sync bin/noctalia-glass-check \
  tests/noctalia_agent_themes_test.py
git diff --check
test ! -e nvim.log
```

Expected: all commands exit 0; the Noctalia runner ends with `OK noctalia
suite`, `dotfiles-check` ends with `dotfiles checks passed`, and no `nvim.log`
exists.

- [ ] **Step 8: Commit**

```bash
git add kitty/kitty.conf nvim/tests/noctalia/palette_test.lua \
  noctalia/noctalia.md
git add -f docs/specs/2026-08-09-noctalia-nvim-theme-design.md
git diff --cached --check
git commit -m "feat(noctalia): activate codex glass refinement"
```

---

### Task 4: Activate and visually verify

**Files:** None.

**Interfaces:**
- Consumes: rendered Codex theme and promoted Kitty generation from Tasks 1-3.
- Produces: confirmation of the spec's visual acceptance criteria; no recurring
  process restart or new configuration.

- [ ] **Step 1: Trigger one Noctalia render**

Re-apply the current Noctalia color scheme once, or wait for the next wallpaper
change. The existing template hook must generate a fresh `current` version and
signal Kitty; do not manually kill Kitty terminals.

- [ ] **Step 2: Verify the promoted and rendered artifacts**

Run:

```bash
bin/noctalia-glass-check
rg -n '^selection_background ' \
  ~/.cache/noctalia/nvim-glass/current/kitty-glass.conf
python3 -c 'import plistlib,pathlib; p=plistlib.loads(pathlib.Path.home().joinpath(".codex/themes/noctalia.tmTheme").read_bytes()); s={e.get("scope"):e.get("settings",{}) for e in p["settings"]}; assert s["markup.inserted"]["background"]=="#022800"; assert s["markup.deleted"]["background"]=="#3d0100"'
```

Expected: the checker exits 0, the selection line contains the current promoted
`glass.selection`, and the plist assertion exits 0.

- [ ] **Step 3: Start one new Codex session and inspect all four areas**

Confirm:

- Added diff cells are green and translucent.
- Removed diff cells are red and translucent.
- Terminal text selection is Noctalia-colored and translucent, including after
  a later wallpaper switch.
- The input box remains Codex-owned and opaque, as explicitly deferred.

If any of the first three fail, capture a screenshot and the two generated
artifact commands from Step 2 before changing code.
