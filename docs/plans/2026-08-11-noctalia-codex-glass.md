# Noctalia Codex Glass Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Codex translucent red/green diff backgrounds and a live-colored,
necessarily opaque Kitty selection while leaving its unsupported input box
unchanged.

**Architecture:** Codex's existing `.tmTheme` supplies the fixed diff cell
backgrounds already registered in Kitty. The atomic Noctalia promotion writes
the current `glass.selection_fg`/`glass.selection` pair beside Kitty's
seven-slot transparency directive, and Kitty includes that generated file last
so last-value-wins applies both live selection colors.

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
- `glass.selection@0.55` makes Claude's SGR-painted selection translucent.
  Kitty 0.48.2 forces its own selected cells to alpha `1.0`, so
  `selection_background` supplies live color only and remains opaque.
- `selection_foreground` is a normal Kitty color setting and consumes no
  `transparent_background_colors` slot.
- The Codex diff backgrounds are exactly `#022800` and `#3d0100`; they must
  match the fixed Kitty registrations and Claude theme.
- `kitty-glass.conf` contains exactly three directives, in this order:
  `transparent_background_colors ...`,
  `selection_foreground <glass.selection_fg>`, then
  `selection_background <glass.selection>`.
- The `current` symlink rename remains the commit point. Both generated files
  are staged before the flip; signals remain post-commit reconciliation.
- The hardcoded fresh-machine selection pair is foreground `#c8d3f5` and
  background `#003dbe`, matching `default_palette.lua` and the fixture; their
  WCAG contrast ratio is approximately 5.84:1.
- Codex 0.147.0's input box remains opaque. Do not add a restart loop, retain
  historical wallpaper tones, wrap Codex, or patch/build Codex.
- This is an intentional schema break with no compatibility reader. The live
  one-line generation is invalid after merge; do not start Neovim or run the
  production checker between merging and the immediate Noctalia re-render in
  Task 6.
- Noctalia's installed nvim template resolves through `~/.config/nvim` to the
  main checkout, so a worktree render cannot migrate production. Worktree
  verification must use `NOCTALIA_GLASS_DIR` with an isolated promoted fixture.
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

### Task 2: Add the selection foreground glass role

**Files:**
- Modify: `nvim/tests/noctalia/palette_test.lua:10-18`
- Modify: `nvim/tests/noctalia/template_test.lua:20-30`
- Modify: `nvim/tests/noctalia/glass_sync_test.sh:95-110`
- Modify: `nvim/lua/user/noctalia/palette-template.json:18-29`
- Modify: `nvim/lua/user/noctalia/palette.lua:44-56`
- Modify: `nvim/lua/user/noctalia/default_palette.lua:23-34`
- Modify: `nvim/tests/noctalia/fixtures/raw_palette.json:18-29`
- Modify: `bin/noctalia-glass-sync:94-105`

**Interfaces:**
- Produces: required non-registered glass role
  `glass.selection_fg: "#rrggbb"`, sourced from Noctalia's
  `colors.on_primary_container.default.hex`.
- Consumed by: Task 3's generated `selection_foreground`.

- [ ] **Step 1: Write the failing artifact-contract tests**

After the existing missing-`primary` case in `palette_test.lua`, add:

```lua
bad = read_json(fixture); bad.glass.selection_fg = nil
ok, err = p.validate(bad)
assert(not ok and err:match('selection_fg'),
  'missing selection foreground detected')
```

After the rendered-template validation in `template_test.lua`, add:

```lua
assert(tokens.on_primary_container,
  'template must request on_primary_container')
assert(raw.glass.selection_fg == tokens.on_primary_container,
  'selection foreground must use on_primary_container')
```

Add a sync rejection case after the existing missing-accent case in
`glass_sync_test.sh`:

```bash
# Missing selection foreground is a complete-artifact failure.
good_candidate
python3 - "$CANDIDATE" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['glass'].pop('selection_fg', None)
json.dump(d, open(p, 'w'))
EOF
expect_reject "missing selection foreground"
```

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
nvim --clean -l nvim/tests/noctalia/palette_test.lua
nvim --clean -l nvim/tests/noctalia/template_test.lua
nvim/tests/noctalia/glass_sync_test.sh
```

Expected: the Lua tests fail on missing `glass.selection_fg`; the sync test
reports `accepted missing selection foreground`.

- [ ] **Step 3: Extend every mirrored artifact definition**

Add this field immediately before `glass.selection` in the template:

```json
    "selection_fg": "{{colors.on_primary_container.default.hex}}",
```

Validate the role beside the existing non-registered `glass.float` check in
`palette.lua`:

```lua
  if not is_hex(raw.glass.selection_fg) then
    return nil, 'glass.selection_fg missing/invalid'
  end
```

Add the matching validation beside `glass.float` in `noctalia-glass-sync`:

```python
    if not is_hex(glass.get('selection_fg')):
        fail('glass.selection_fg missing/invalid')
```

Add the fallback role immediately before `glass.selection` in both
`raw_palette.json` and `default_palette.lua`:

```json
    "selection_fg": "#c8d3f5",
```

```lua
    selection_fg = '#c8d3f5',
```

- [ ] **Step 4: Run the focused tests and confirm GREEN**

```bash
nvim --clean -l nvim/tests/noctalia/palette_test.lua
nvim --clean -l nvim/tests/noctalia/template_test.lua
nvim/tests/noctalia/glass_sync_test.sh
```

Expected: `OK palette`, `OK template`, and `OK glass_sync`.

- [ ] **Step 5: Commit**

```bash
git add nvim/lua/user/noctalia/palette-template.json \
  nvim/lua/user/noctalia/palette.lua \
  nvim/lua/user/noctalia/default_palette.lua \
  nvim/tests/noctalia/fixtures/raw_palette.json \
  nvim/tests/noctalia/palette_test.lua \
  nvim/tests/noctalia/template_test.lua \
  nvim/tests/noctalia/glass_sync_test.sh \
  bin/noctalia-glass-sync
git diff --cached --check
git commit -m "feat(noctalia): add selection foreground glass role"
```

---

### Task 3: Promote and validate the live Kitty selection pair

**Files:**
- Modify: `nvim/tests/noctalia/glass_sync_test.sh:60-72`
- Modify: `nvim/tests/noctalia/glass_check_test.sh:14-38`
- Modify: `bin/noctalia-glass-sync:127-134`
- Modify: `bin/noctalia-glass-check:93-102`
- Modify: `nvim/tests/noctalia/mood_swatches_test.sh:12`

**Interfaces:**
- Consumes: validated `raw['glass']['selection_fg']` and
  `raw['glass']['selection']` from the candidate JSON.
- Produces: a three-line `kitty-glass.conf`; the checker accepts only those
  three directives and requires both selection colors to equal the promoted
  palette.

- [ ] **Step 1: Make the sync success case require all three directives**

Replace the current one-line count/assertion in
`glass_sync_test.sh` with:

```bash
[[ "$(wc -l < "$CUR/kitty-glass.conf")" == 3 ]] || {
  echo "FAIL: kitty conf must have three lines"
  cat "$CUR/kitty-glass.conf"
  exit 1
}
grep -qx 'transparent_background_colors #1e2030 #2f334d #272a3f #3b4261 #022800@0.72 #3d0100@0.72 #003dbe@0.55' \
  "$CUR/kitty-glass.conf" || { echo "FAIL: kitty transparent list wrong"; cat "$CUR/kitty-glass.conf"; exit 1; }
grep -qx 'selection_foreground #c8d3f5' "$CUR/kitty-glass.conf" || {
  echo "FAIL: kitty selection foreground wrong"
  cat "$CUR/kitty-glass.conf"
  exit 1
}
grep -qx 'selection_background #003dbe' "$CUR/kitty-glass.conf" || {
  echo "FAIL: kitty selection background wrong"
  cat "$CUR/kitty-glass.conf"
  exit 1
}
```

- [ ] **Step 2: Add a checker regression for selection drift**

Insert after the healthy promoted-state check in
`glass_check_test.sh`, then renumber later case comments:

```bash
# 3. generated selection foreground must equal the promoted palette: FAIL
sed -i 's/^selection_foreground .*/selection_foreground #111111/' \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: selection foreground desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

cp nvim/tests/noctalia/fixtures/raw_palette.json \
  "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal

# 4. generated selection background must equal the promoted palette: FAIL
sed -i 's/^selection_background .*/selection_background #111111/' \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: selection background desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }
```

Before the old partial-state case removes `nvim-palette.json`, reset the
generation so that case begins from healthy state like every other mutation:

```bash
cp nvim/tests/noctalia/fixtures/raw_palette.json \
  "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
```

- [ ] **Step 3: Run both focused tests and confirm RED**

Run:

```bash
nvim/tests/noctalia/glass_sync_test.sh
nvim/tests/noctalia/glass_check_test.sh
```

Expected: `glass_sync_test.sh` reports `kitty conf must have three lines`, and
`glass_check_test.sh` reports `selection foreground desync must fail`.

- [ ] **Step 4: Emit the selection in the staged generation**

Replace the `kitty-glass.conf` write in `noctalia-glass-sync` with:

```python
        (vdir / 'kitty-glass.conf').write_text(
            'transparent_background_colors ' + ' '.join(tones) + '\n'
            f"selection_foreground {raw['glass']['selection_fg'].lower()}\n"
            f"selection_background {raw['glass']['selection'].lower()}\n")
```

Do not change promotion order: both files must still be written before the
prepared symlink is renamed over `current`.

- [ ] **Step 5: Validate exactly three directives and both selection tones**

Replace the checker block beginning with `m = re.fullmatch(...)` with:

```python
    lines = kitty_text.splitlines()
    if len(lines) != 3:
        fail(f'{kitty_file} must contain exactly three directives')
    m = re.fullmatch(r'transparent_background_colors (.+)', lines[0])
    if not m:
        fail(f'{kitty_file} has no transparent_background_colors line')
    kitty_tones = m.group(1).split()
    if kitty_tones != palette_tones:
        fail(f'tones desynced: kitty={kitty_tones} palette={palette_tones}')
    selection_foreground = glass.get('selection_fg')
    if (not isinstance(selection_foreground, str)
            or not HEX.fullmatch(selection_foreground)):
        fail(f'{palette_file} glass.selection_fg missing/malformed')
    expected_foreground = f'selection_foreground {selection_foreground.lower()}'
    if lines[1] != expected_foreground:
        fail(f'selection foreground desynced: kitty={lines[1]!r} palette={expected_foreground!r}')
    expected_background = f"selection_background {glass['selection'].lower()}"
    if lines[2] != expected_background:
        fail(f'selection background desynced: kitty={lines[2]!r} palette={expected_background!r}')
```

This retains the existing duplicate-directive rejection because any fourth
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
git commit -m "feat(noctalia): generate kitty selection pair"
```

---

### Task 4: Make the generated selection pair win in Kitty

**Files:**
- Modify: `nvim/tests/noctalia/palette_test.lua:93-112`
- Modify: `kitty/kitty.conf:80-123`
- Modify: `noctalia/noctalia.md:30-58`

**Interfaces:**
- Consumes: the three-line generated include from Task 3.
- Produces: a fresh-machine foreground `#c8d3f5` / background `#003dbe`
  fallback pair and generated include precedence over every static include.

- [ ] **Step 1: Extend the fresh-machine invariant test**

Add after the existing fallback-tone loop in `palette_test.lua`:

```lua
local selection_foreground = conf:match('\nselection_foreground ([^\n]+)')
assert(selection_foreground == default.glass.selection_fg,
  'kitty selection foreground fallback must equal default glass.selection_fg')
local selection_background = conf:match('\nselection_background ([^\n]+)')
assert(selection_background == default.glass.selection,
  'kitty selection fallback must equal default glass.selection')
local os_include = assert(conf:find('include os-local.conf', 1, true),
  'os-local include missing')
local fallback_foreground = assert(conf:find(
  '\nselection_foreground #c8d3f5', 1, true),
  'selection foreground fallback missing')
local fallback_background = assert(conf:find(
  '\nselection_background #003dbe', 1, true),
  'selection background fallback missing')
local glass_include = assert(conf:find(
  'include ${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf', 1, true),
  'generated glass include missing')
assert(os_include < fallback_foreground and
  fallback_foreground < fallback_background and
  fallback_background < glass_include,
  'selection pair must follow other includes and precede generated glass')
assert(not conf:find('\ninclude ', glass_include + 1, true),
  'generated glass include must be the final include')
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
nvim --clean -l nvim/tests/noctalia/palette_test.lua
```

Expected: failure with `kitty selection foreground fallback must equal default
glass.selection_fg`.

- [ ] **Step 3: Add the fallback and move the generated include**

Delete the generated include from its current position above the tmux settings.
After `include os-local.conf`, make these the final settings in the file:

```conf
# Fixed selection fallback pair applies when no promoted generation exists.
selection_foreground #c8d3f5
selection_background #003dbe
# Generated Noctalia transparency and selection-pair override. This must be the
# final include because Kitty applies the last value for each setting.
include ${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf
```

This placement makes the fallback win over `themes/noctalia.conf` and
`current-theme.conf` when the generated include is missing, while a present
generated include wins over every static include.

Replace the final three lines of the seven-slot comment block with this pointer
to the separated fallback/override block:

```conf
# Three colored slots cover Claude/Codex added/removed diff cells and Claude's
# SGR-painted selection. The paired Kitty selection fallback/override lives
# after all static includes at the end of this file.
```

Do not edit the generated/gitignored `kitty/themes/noctalia.conf`.

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
backgrounds 72% opacity. The registered `primary_container` gives Claude's
painted selection 55% opacity. Kitty's own terminal selection uses the paired
live `glass.selection_fg` (`on_primary_container`) foreground and
`glass.selection` (`primary_container`) background but remains opaque because
Kitty forces selected cells to alpha 1. Codex's input box remains opaque
because Codex owns and caches that background and exposes no theme role for it.
```

- [ ] **Step 6: Run the complete automated verification**

Run from the worktree root:

```bash
env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache nvim/tests/noctalia/run.sh
env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache \
  python3 -m py_compile bin/noctalia-glass-sync bin/noctalia-glass-check \
  tests/noctalia_agent_themes_test.py
bash -euo pipefail -c '
  verify_glass_dir=$(mktemp -d)
  cp nvim/tests/noctalia/fixtures/raw_palette.json \
    "$verify_glass_dir/nvim-palette.candidate.json"
  NOCTALIA_GLASS_DIR="$verify_glass_dir" \
    bin/noctalia-glass-sync --no-signal
  test -L "$verify_glass_dir/nvim-glass/current" || {
    echo "isolated promote missing"
    exit 1
  }
  NOCTALIA_GLASS_DIR="$verify_glass_dir" \
    env PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache bin/dotfiles-check
  rm -rf "$verify_glass_dir"
'
git diff --check
test ! -e nvim.log
```

Expected: all commands exit 0; the Noctalia runner ends with `OK noctalia
suite`, the isolated promotion assertion succeeds, isolated `dotfiles-check`
ends with `dotfiles checks passed`, and no `nvim.log` exists. Do not run
production `bin/noctalia-glass-check` here: its one-line live generation is
intentionally old until Task 6 runs after merge.

- [ ] **Step 7: Commit**

```bash
git add kitty/kitty.conf nvim/tests/noctalia/palette_test.lua \
  noctalia/noctalia.md
git diff --cached --check
git commit -m "feat(noctalia): activate codex selection pair"
```

---

### Task 5: Record the implemented commit range in the spec

**Files:**
- Modify: `docs/specs/2026-08-09-noctalia-nvim-theme-design.md`

**Interfaces:**
- Consumes: the actual commit before Task 1 and the Task 4 commit ID.
- Produces: an ancestor-checkable implemented status and present-tense design.

- [ ] **Step 1: Resolve and verify the implementation range**

Run:

```bash
codex_first=$(git log --format=%h \
  --grep='^feat(noctalia): add codex diff backgrounds$' -1)
codex_base=$(git rev-parse --short "${codex_first}^")
codex_last=$(git log --format=%h \
  --grep='^feat(noctalia): activate codex selection pair$' -1)
test -n "$codex_base" && test -n "$codex_first" && test -n "$codex_last"
git merge-base --is-ancestor "$codex_base" "$codex_last"
git log --format='%h %s' "$codex_base..$codex_last"
printf 'range: %s..%s\n' "$codex_base" "$codex_last"
```

Expected: the log includes all four implementation commits, including
`feat(noctalia): add codex diff backgrounds`, followed by one base-exclusive
short-hash range and exit 0. Use that exact printed range in Step 2; do not
write shell variable names or placeholder text into the spec.

- [ ] **Step 2: Mark the approved behavior implemented**

Use `apply_patch` to replace the status's pending clause with
`Codex diff/selection refinement implemented (` followed by the exact range
from Step 1 and `).`

In the `[templates.nvim]` artifact description, replace the emitted-color
sentence with:

```markdown
  - Emits a JSON object of raw material colors — the 4 accents (+ fixed_dim
    variants), surfaces, outline, on_surface tones — plus a `glass` table of
    role → hex. `glass.selection_fg` maps `on_primary_container` beside the
    existing `glass.selection` → `primary_container` mapping.
```

In sync step 3, replace the one-line `kitty-glass.conf` parenthetical with:

```markdown
`kitty-glass.conf` (three lines: `transparent_background_colors`, paired
`selection_foreground`, and `selection_background`)
```

Replace the pending Kitty architecture bullet with:

```markdown
- `kitty.conf` keeps hardcoded `transparent_background_colors` and paired
  `selection_foreground`/`selection_background` fallbacks after all static
  includes, then includes
  `${HOME}/.cache/noctalia/nvim-glass/current/kitty-glass.conf` last. Kitty is
  last-value-wins, so the fixed pair wins when no generation exists and the
  generated pair wins when it does.
```

Replace the pending Codex subsection through its acceptance paragraph with:

```markdown
#### Codex refinement

Codex's custom `.tmTheme` has a narrower but useful UI contract. Its
`markup.inserted` and `markup.deleted` scope backgrounds override the native
diff backgrounds, so the Noctalia theme sets them to the same fixed green and
red already registered for Claude. Kitty owns terminal text selection; the
generated `selection_foreground`/`selection_background` pair uses
`glass.selection_fg`/`glass.selection` (Noctalia
`on_primary_container`/`primary_container`) and therefore updates live on
wallpaper changes. Kitty 0.48.2 forces selected cells to alpha 1 before
substituting those colors, so its own selection remains opaque. The registered
background still makes Claude's SGR-painted selection translucent at 55%
opacity.

Acceptance: in a newly started Codex session, added/deleted diff backgrounds
are colored and translucent; terminal text selection is Noctalia-colored,
opaque, and follows later wallpaper switches; the input box remains
Codex-owned and opaque.
```

Retain the following input-box rationale unchanged.

In Error handling's fresh-machine bullet, replace the fallback description
with:

```markdown
Kitty's hardcoded fallback carries the four matching tokyonight-moon chrome
tones, fixed agent diff colors, and the paired selection foreground/background
`#c8d3f5`/`#003dbe`, so glass and readable selection work before Noctalia has
ever run.
```

Replace the scripted checker bullet with:

```markdown
- Scripted: `bin/noctalia-glass-check` (run manually and from
  `dotfiles-check`) — passes on fresh machines (no `current` symlink), FAILS
  on partial state (symlink present but a file missing), when Kitty's seven
  color/opacity tokens differ from the palette's glass tones in role order, or
  when either generated selection directive differs from the promoted
  `glass.selection_fg`/`glass.selection` pair.
```

- [ ] **Step 3: Verify and commit the spec**

```bash
git diff --check
git add -f docs/specs/2026-08-09-noctalia-nvim-theme-design.md
git diff --cached --check
git commit -m "docs: record codex glass refinement"
```

---

### Task 6: Migrate production after merge and visually verify

**Files:** None.

**Interfaces:**
- Consumes: Tasks 1-5 integrated into the main checkout.
- Produces: the first three-line production generation and confirmation of the
  spec's visual acceptance criteria; no compatibility layer, recurring process
  restart, or new configuration.

- [ ] **Step 1: Merge, then immediately trigger one Noctalia render**

Run this task only after the implementation branch is integrated into main via
`superpowers:finishing-a-development-branch`. Before starting Neovim or running
production `dotfiles-check`, re-apply the current Noctalia color scheme once.
Do not wait for the next wallpaper rotation: the existing one-line production
generation is present-but-invalid under the merged schema. The template hook
must generate a fresh `current` version and signal Kitty; do not manually kill
Kitty terminals.

- [ ] **Step 2: Verify the promoted and rendered artifacts**

Run:

```bash
bin/noctalia-glass-check
rg -n '^selection_(foreground|background) ' \
  ~/.cache/noctalia/nvim-glass/current/kitty-glass.conf
nvim --headless \
  -c 'lua assert(require("user.noctalia.palette").load().glass.selection_fg)' \
  -c qa
python3 -c 'import plistlib,pathlib; p=plistlib.loads(pathlib.Path.home().joinpath(".codex/themes/noctalia.tmTheme").read_bytes()); s={e.get("scope"):e.get("settings",{}) for e in p["settings"]}; assert s["markup.inserted"]["background"]=="#022800"; assert s["markup.deleted"]["background"]=="#3d0100"'
```

Expected: the checker exits 0, both selection lines contain the promoted
`glass.selection_fg`/`glass.selection` pair, Neovim loads the migrated palette,
and the plist assertion exits 0.

- [ ] **Step 3: Start one new Codex session and inspect all four areas**

Confirm:

- Added diff cells are green and translucent.
- Removed diff cells are red and translucent.
- Terminal text selection is Noctalia-colored, opaque, and changes color after
  a later wallpaper switch.
- The input box remains Codex-owned and opaque, as explicitly deferred.

If any of the first three fail, capture a screenshot and the two generated
artifact commands from Step 2 before changing code.
