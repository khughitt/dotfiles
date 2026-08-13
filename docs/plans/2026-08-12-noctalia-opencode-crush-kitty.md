# Noctalia OpenCode Glass and Crush Transparency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a wallpaper-derived OpenCode 1.18.16 theme in the existing
atomic Noctalia glass generation, safely refresh only signal-aware OpenCode
processes, move OpenCode runtime state out of the synced repo, and make Crush's
supported transparent base reproducible.

**Architecture:** `bin/noctalia-glass-sync` remains the only palette consumer
and atomically publishes Nvim, Kitty, and OpenCode artifacts through one
`current` symlink. OpenCode configuration moves to a machine-local backing
directory with three managed links; a preflighted Python stdlib migrator refuses
all divergent collisions before changing either tree. Crush receives only its
native tracked transparency default because version 0.88.0 has no custom-theme
interface.

**Tech Stack:** Python 3 standard library, Bash/Zsh, JSON, Linux `/proc`, Kitty,
OpenCode 1.18.16, Crush 0.88.0, Noctalia.

**Spec:** `docs/specs/2026-08-12-noctalia-opencode-crush-kitty-design.md`

## Global Constraints

- Before Task 1, use `superpowers:using-git-worktrees`; all paths below are
  relative to the isolated worktree root.
- Conventional commits only; no AI attribution or `Co-Authored-By` trailers.
- `docs/` is gitignored, so tracked plan/spec changes require `git add -f`.
- Preserve unrelated worktree changes.
- No new dependency and no second Noctalia template. Use Python's standard
  library and the existing palette candidate.
- Production palette paths remain literal
  `~/.cache/noctalia/nvim-glass/current/`; `NOCTALIA_GLASS_DIR` remains
  tests-only.
- The `current` symlink rename remains the commit point. All three files are
  staged before it; every signal occurs after it.
- Kitty keeps exactly seven registered RGB backgrounds. OpenCode structural
  surfaces must reuse `chrome`, `tab_off`, `cursorline`, `raised`,
  `diff_added`, or `diff_removed`; no eighth color is introduced.
- Signal order is Kitty `SIGUSR1`, Nvim `SIGUSR1`, then capable OpenCode
  processes `SIGUSR2`. Never use `pkill -SIGUSR2 -x opencode`.
- OpenCode process discovery is Linux-only and capability-based: exact process
  name, current real UID, and the `SIGUSR2` bit present in `/proc/<pid>/status`
  `SigCgt`. A vanished PID is ignored; other errors fail post-commit.
- OpenCode theme JSON is dark-only and contains all 52 supported color keys
  used in OpenCode 1.18.16, including explicit `selectedListItemText` and
  `backgroundMenu`; it does not use alpha colors. The optional numeric
  `thinkingOpacity` setting is deliberately omitted so OpenCode keeps its 0.6
  default.
- `backgroundMenu` is `glass.raised`, ordinary `border` is `outline`, and the
  checker must require `border != backgroundMenu`.
- OpenCode's selected semantic controls and hard-coded modal dimmers remain
  opaque. Do not patch OpenCode, fork Crush, or alter Niri.
- OpenCode runtime migration must inventory both complete trees and report all
  conflicts before mutation. Identical files/symlinks may be cleaned only after
  the config-link commit point; divergent data is never chosen or discarded.
- Setup tests set `DOTFILES_OPENCODE_RUNTIME_SOURCE` to a temporary directory so
  they cannot migrate ignored runtime files from the real checkout. Production
  leaves it unset, making the runtime source the tracked `opencode/` directory.
- Managed-link comparisons use canonical resolved paths, accepting the same
  repo reached through `~/d/` or its physical Dropbox path.
- The generated OpenCode theme link may dangle before the first render; health
  checks validate its intended target without requiring the target to exist.
- `crush/crushrc` gains exactly one supported rendering change:
  `option ui transparent true`. Machine/workspace state may override it.
- No GitHub write is part of this plan. If a later follow-up writes with `gh`,
  verify `gh api user --jq .login` is `khughitt` (not `keith-cainex`) and
  restore any temporarily changed active account on success and failure.
- Every behavior change is test-first: run the focused test RED for the stated
  reason, implement the minimum change, then run it GREEN.

---

### Task 1: Generate the complete OpenCode theme atomically

**Files:**
- Modify: `nvim/tests/noctalia/glass_sync_test.sh:57-114`
- Modify: `bin/noctalia-glass-sync:35-173`

**Interfaces:**
- Consumes: the already validated palette object accepted by `validate(raw)`.
- Produces: `build_opencode_theme(raw: dict) -> dict` and staged
  `opencode-theme.json` beside `nvim-palette.json` and `kitty-glass.conf`.
- Contract: the mapping below is the complete 52-key OpenCode 1.18.16 dark
  color contract; the JSON top level is exactly `$schema` plus `theme`.
  `thinkingOpacity` is not a color and remains at OpenCode's 0.6 default.

- [ ] **Step 1: Extend the success and rejection tests first**

In the first success case, require the third file and validate its exact keys
and palette mapping:

```bash
[[ -f "$CUR/nvim-palette.json" && -f "$CUR/kitty-glass.conf" && \
   -f "$CUR/opencode-theme.json" ]] || {
  echo "FAIL: staged files missing"
  exit 1
}
python3 - "$CUR/nvim-palette.json" "$CUR/opencode-theme.json" <<'PY'
import json, sys

palette = json.load(open(sys.argv[1]))
theme = json.load(open(sys.argv[2]))
mapping = {
    "primary": ("primary",),
    "secondary": ("secondary",),
    "accent": ("tertiary",),
    "error": ("error",),
    "warning": ("tertiary_fixed_dim",),
    "success": ("secondary_fixed_dim",),
    "info": ("primary_fixed_dim",),
    "text": ("on_surface",),
    "textMuted": ("on_surface_variant",),
    "selectedListItemText": ("on_primary",),
    "background": ("glass", "chrome"),
    "backgroundPanel": ("glass", "tab_off"),
    "backgroundElement": ("glass", "cursorline"),
    "backgroundMenu": ("glass", "raised"),
    "border": ("outline",),
    "borderActive": ("primary",),
    "borderSubtle": ("outline_variant",),
    "diffAdded": ("secondary_fixed_dim",),
    "diffRemoved": ("error",),
    "diffContext": ("on_surface_variant",),
    "diffHunkHeader": ("tertiary",),
    "diffHighlightAdded": ("secondary",),
    "diffHighlightRemoved": ("error",),
    "diffAddedBg": ("glass", "diff_added"),
    "diffRemovedBg": ("glass", "diff_removed"),
    "diffContextBg": ("glass", "chrome"),
    "diffLineNumber": ("outline",),
    "diffAddedLineNumberBg": ("glass", "diff_added"),
    "diffRemovedLineNumberBg": ("glass", "diff_removed"),
    "markdownText": ("on_surface",),
    "markdownHeading": ("tertiary",),
    "markdownLink": ("primary",),
    "markdownLinkText": ("secondary",),
    "markdownCode": ("secondary_fixed_dim",),
    "markdownBlockQuote": ("outline",),
    "markdownEmph": ("tertiary_fixed_dim",),
    "markdownStrong": ("primary_fixed_dim",),
    "markdownHorizontalRule": ("outline_variant",),
    "markdownListItem": ("primary",),
    "markdownListEnumeration": ("secondary",),
    "markdownImage": ("tertiary",),
    "markdownImageText": ("on_surface",),
    "markdownCodeBlock": ("on_surface",),
    "syntaxComment": ("outline",),
    "syntaxKeyword": ("tertiary",),
    "syntaxFunction": ("primary",),
    "syntaxVariable": ("error",),
    "syntaxString": ("secondary_fixed_dim",),
    "syntaxNumber": ("primary_fixed_dim",),
    "syntaxType": ("secondary",),
    "syntaxOperator": ("tertiary_fixed_dim",),
    "syntaxPunctuation": ("on_surface_variant",),
}

assert set(theme) == {"$schema", "theme"}
assert theme["$schema"] == "https://opencode.ai/theme.json"
assert set(theme["theme"]) == set(mapping)
for key, path in mapping.items():
    value = palette
    for part in path:
        value = value[part]
    assert theme["theme"][key] == value.lower(), (key, theme["theme"][key], value)
assert theme["theme"]["border"] != theme["theme"]["backgroundMenu"]
PY
```

After the second successful promotion, retain a copy of the complete generation
before a rejected candidate and prove all three visible files remain unchanged:

```bash
cp "$CUR/opencode-theme.json" "$TMP/opencode-before-reject.json"
good_candidate
sed -i 's/"primary": "#82aaff"/"primary": "broken"/' "$CANDIDATE"
expect_reject "invalid primary before OpenCode construction"
cmp "$TMP/opencode-before-reject.json" "$CUR/opencode-theme.json" || {
  echo "FAIL: rejected candidate changed OpenCode theme"
  exit 1
}

good_candidate
sed -i 's/"outline": "#636da6"/"outline": "#3b4261"/' "$CANDIDATE"
expect_reject "OpenCode border collision"

# Restore the pre-existing missing-candidate case's actual precondition.
rm -f "$CANDIDATE"
```

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
nvim/tests/noctalia/glass_sync_test.sh
```

Expected: `FAIL: staged files missing` because the version directory has no
`opencode-theme.json`.

- [ ] **Step 3: Add the pure mapping and stage its JSON before the commit point**

Add this constant beside `OPACITY` (the insertion order is the emitted order):

```python
OPENCODE_MAP = {
    'primary': ('primary',),
    'secondary': ('secondary',),
    'accent': ('tertiary',),
    'error': ('error',),
    'warning': ('tertiary_fixed_dim',),
    'success': ('secondary_fixed_dim',),
    'info': ('primary_fixed_dim',),
    'text': ('on_surface',),
    'textMuted': ('on_surface_variant',),
    'selectedListItemText': ('on_primary',),
    'background': ('glass', 'chrome'),
    'backgroundPanel': ('glass', 'tab_off'),
    'backgroundElement': ('glass', 'cursorline'),
    'backgroundMenu': ('glass', 'raised'),
    'border': ('outline',),
    'borderActive': ('primary',),
    'borderSubtle': ('outline_variant',),
    'diffAdded': ('secondary_fixed_dim',),
    'diffRemoved': ('error',),
    'diffContext': ('on_surface_variant',),
    'diffHunkHeader': ('tertiary',),
    'diffHighlightAdded': ('secondary',),
    'diffHighlightRemoved': ('error',),
    'diffAddedBg': ('glass', 'diff_added'),
    'diffRemovedBg': ('glass', 'diff_removed'),
    'diffContextBg': ('glass', 'chrome'),
    'diffLineNumber': ('outline',),
    'diffAddedLineNumberBg': ('glass', 'diff_added'),
    'diffRemovedLineNumberBg': ('glass', 'diff_removed'),
    'markdownText': ('on_surface',),
    'markdownHeading': ('tertiary',),
    'markdownLink': ('primary',),
    'markdownLinkText': ('secondary',),
    'markdownCode': ('secondary_fixed_dim',),
    'markdownBlockQuote': ('outline',),
    'markdownEmph': ('tertiary_fixed_dim',),
    'markdownStrong': ('primary_fixed_dim',),
    'markdownHorizontalRule': ('outline_variant',),
    'markdownListItem': ('primary',),
    'markdownListEnumeration': ('secondary',),
    'markdownImage': ('tertiary',),
    'markdownImageText': ('on_surface',),
    'markdownCodeBlock': ('on_surface',),
    'syntaxComment': ('outline',),
    'syntaxKeyword': ('tertiary',),
    'syntaxFunction': ('primary',),
    'syntaxVariable': ('error',),
    'syntaxString': ('secondary_fixed_dim',),
    'syntaxNumber': ('primary_fixed_dim',),
    'syntaxType': ('secondary',),
    'syntaxOperator': ('tertiary_fixed_dim',),
    'syntaxPunctuation': ('on_surface_variant',),
}
```

Add the pure constructor after `validate`:

```python
def build_opencode_theme(raw: dict) -> dict:
    colors = {}
    for key, path in OPENCODE_MAP.items():
        value = raw
        for part in path:
            value = value[part]
        colors[key] = value.lower()
    return {'$schema': 'https://opencode.ai/theme.json', 'theme': colors}
```

Keep construction pure by rejecting the invisible pairing in `validate`, after
the other glass invariants:

```python
    if glass['raised'].lower() == raw['outline'].lower():
        fail('OpenCode border collides with backgroundMenu')
```

Construct once after `validate(raw)`:

```python
    opencode_theme = build_opencode_theme(raw)
```

Stage it immediately after the Kitty file and before creating `tmplink`:

```python
        (vdir / 'opencode-theme.json').write_text(
            json.dumps(opencode_theme, indent=2) + '\n')
```

Update the module docstring to name all three artifacts and add the new design
spec beside the existing Nvim spec reference.

- [ ] **Step 4: Run the focused test and confirm GREEN**

```bash
nvim/tests/noctalia/glass_sync_test.sh
```

Expected: `OK glass_sync`.

- [ ] **Step 5: Commit**

```bash
git add bin/noctalia-glass-sync nvim/tests/noctalia/glass_sync_test.sh
git diff --cached --check
git commit -m "feat(noctalia): generate opencode glass theme"
```

---

### Task 2: Make the checker enforce the three-consumer generation

**Files:**
- Modify: `nvim/tests/noctalia/glass_check_test.sh:12-137`
- Modify: `bin/noctalia-glass-check:1-119`

**Interfaces:**
- Consumes: Task 1's `opencode-theme.json` and the same `OPENCODE_MAP` contract.
- Produces: clean `FAIL: noctalia-glass-check:` errors for an old generation,
  malformed JSON, incomplete keys, exact mapping drift, or invisible menu
  borders.

- [ ] **Step 1: Write the failing checker cases**

After the healthy case, add a reset helper and these cases:

```bash
promote() {
  cp nvim/tests/noctalia/fixtures/raw_palette.json \
    "$TMP/nvim-palette.candidate.json"
  "$SYNC" --no-signal
}

# Old two-consumer generation: FAIL with the migration remedy.
rm "$TMP/nvim-glass/current/opencode-theme.json"
if out=$("$CHECK" 2>&1); then
  echo "FAIL: old generation must fail"
  exit 1
fi
[[ "$out" == FAIL:*"format changed"*"re-render"* ]] || {
  echo "FAIL: missing old-generation remedy: $out"
  exit 1
}

# Malformed OpenCode JSON: clean FAIL, no traceback.
promote
echo '{ broken' > "$TMP/nvim-glass/current/opencode-theme.json"
if out=$("$CHECK" 2>&1); then
  echo "FAIL: malformed OpenCode theme must fail"
  exit 1
fi
[[ "$out" == FAIL:* && "$out" != *Traceback* ]] || {
  echo "FAIL: malformed theme did not use clean failure: $out"
  exit 1
}

# Complete-key and exact-background contracts.
promote
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['theme']['syntaxOperator']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: incomplete OpenCode theme must fail"
  exit 1
fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL line: $out"; exit 1; }

# A missing mapped non-glass palette key must cleanly FAIL, never traceback.
promote
python3 - "$TMP/nvim-glass/current/nvim-palette.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['primary']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: missing mapped palette key must fail"
  exit 1
fi
[[ "$out" == FAIL:* && "$out" != *Traceback* ]] || {
  echo "FAIL: mapped-key failure was not clean: $out"
  exit 1
}

promote
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['theme']['backgroundPanel'] = '#111111'
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: OpenCode background drift must fail"
  exit 1
fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL line: $out"; exit 1; }

promote
sed -i 's/"outline": "#636da6"/"outline": "#3b4261"/' \
  "$TMP/nvim-glass/current/nvim-palette.json"
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['theme']['border'] = d['theme']['backgroundMenu']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: invisible OpenCode menu border must fail"
  exit 1
fi
[[ "$out" == FAIL:*"border is invisible on backgroundMenu"* ]] || {
  echo "FAIL: wrong invisible-border failure: $out"
  exit 1
}
```

Replace repeated two-line candidate/sync resets in the remainder of the test
with `promote`; do not change their assertions.

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
nvim/tests/noctalia/glass_check_test.sh
```

Expected: the old-generation case incorrectly passes because the checker does
not require `opencode-theme.json`.

- [ ] **Step 3: Validate the third file and its exact mapping**

Mirror Task 1's `OPENCODE_MAP` beside `OPACITY`; keep the comment stating that
the two copies are intentionally mirrored producer/validator contracts.

After the Kitty file declaration, add:

```python
    opencode_file = CURRENT / 'opencode-theme.json'
```

After the Kitty missing check, add the old-generation failure with its remedy:

```python
    if not opencode_file.is_file():
        fail(
            f'{opencode_file} missing: the generation format changed; '
            're-render the current Noctalia wallpaper palette')
```

After validating `kitty-glass.conf`, parse and validate the OpenCode theme:

```python
    try:
        opencode = json.loads(opencode_file.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f'{opencode_file} unreadable: {exc}')
    if not isinstance(opencode, dict) or set(opencode) != {'$schema', 'theme'}:
        fail(f'{opencode_file} has the wrong top-level shape')
    if opencode['$schema'] != 'https://opencode.ai/theme.json':
        fail(f'{opencode_file} has the wrong schema')
    theme = opencode.get('theme')
    if not isinstance(theme, dict) or set(theme) != set(OPENCODE_MAP):
        fail(f'{opencode_file} has an incomplete theme key set')
    for key, path in OPENCODE_MAP.items():
        expected = data
        for part in path:
            if not isinstance(expected, dict) or part not in expected:
                fail(f'{palette_file} mapped path {".".join(path)} missing/malformed')
            expected = expected[part]
        if not isinstance(expected, str) or not HEX.fullmatch(expected):
            fail(f'{palette_file} mapped path {".".join(path)} missing/malformed')
        if theme.get(key) != expected.lower():
            fail(
                f'{opencode_file} {key} desynced: '
                f'{theme.get(key)!r} != {expected.lower()!r}')
    if theme['border'] == theme['backgroundMenu']:
        fail(f'{opencode_file} border is invisible on backgroundMenu')
```

Update the docstring from “both promoted files” to “all three promoted files.”

- [ ] **Step 4: Run the focused test and confirm GREEN**

```bash
nvim/tests/noctalia/glass_check_test.sh
```

Expected: `OK glass_check`.

- [ ] **Step 5: Commit**

```bash
git add bin/noctalia-glass-check nvim/tests/noctalia/glass_check_test.sh
git diff --cached --check
git commit -m "test(noctalia): validate opencode glass artifact"
```

---

### Task 3: Signal only OpenCode processes that catch `SIGUSR2`

**Files:**
- Create: `nvim/tests/noctalia/glass_signal_test.py`
- Modify: `nvim/tests/noctalia/run.sh:16-22`
- Modify: `bin/noctalia-glass-sync:22-27,168-173`

**Interfaces:**
- Produces: `signal_opencode(proc_root: Path = Path('/proc')) -> None` and
  `signal_programs() -> None`.
- `signal_opencode` sends `signal.SIGUSR2` only for status records whose `Name`
  is exactly `opencode`, real UID equals `os.getuid()`, and `SigCgt` contains
  bit `1 << (SIGUSR2 - 1)`.
- `signal_programs` preserves Kitty, Nvim, OpenCode ordering and existing
  post-commit failure semantics.

- [ ] **Step 1: Write the process-mask and ordering unit test**

Create `glass_signal_test.py`:

```python
#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import signal
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
loader = importlib.machinery.SourceFileLoader(
    "noctalia_glass_sync", str(ROOT / "bin/noctalia-glass-sync"))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
sync = importlib.util.module_from_spec(spec)
loader.exec_module(sync)


def status(root, pid, name="opencode", uid=None, caught=0):
    uid = os.getuid() if uid is None else uid
    path = root / str(pid)
    path.mkdir()
    (path / "status").write_text(
        f"Name:\t{name}\nUid:\t{uid}\t{uid}\t{uid}\t{uid}\n"
        f"SigCgt:\t{caught:016x}\n"
    )


with tempfile.TemporaryDirectory() as tmp:
    proc = Path(tmp)
    usr2 = 1 << (signal.SIGUSR2 - 1)
    status(proc, 101, caught=usr2)  # interactive TUI
    status(proc, 102, caught=usr2 | 1)  # run --interactive footer
    status(proc, 103, caught=0)  # serve: SIGUSR2 default action, must live
    status(proc, 104, name="not-opencode", caught=usr2)
    status(proc, 105, uid=os.getuid() + 1, caught=usr2)

    calls = []
    original_kill = sync.os.kill
    sync.os.kill = lambda pid, sig: calls.append((pid, sig))
    try:
        sync.signal_opencode(proc)
    finally:
        sync.os.kill = original_kill
    assert calls == [(101, signal.SIGUSR2), (102, signal.SIGUSR2)], calls

events = []
original_run = sync.subprocess.run
original_signal = sync.signal_opencode
sync.subprocess.run = lambda argv, check=False: type("R", (), {"returncode": 0})()
sync.signal_opencode = lambda: events.append("opencode")
try:
    def record_run(argv, check=False):
        events.append(argv[-1])
        return type("R", (), {"returncode": 0})()
    sync.subprocess.run = record_run
    sync.signal_programs()
finally:
    sync.subprocess.run = original_run
    sync.signal_opencode = original_signal
assert events == ["kitty", "nvim", "opencode"], events

events = []
sync.subprocess.run = lambda argv, check=False: type("R", (), {"returncode": 2})()
sync.signal_opencode = lambda: events.append("opencode")
try:
    try:
        sync.signal_programs()
    except SystemExit:
        pass
finally:
    sync.subprocess.run = original_run
    sync.signal_opencode = original_signal
assert events == [], "OpenCode signalled after Kitty reconciliation failed"

print("OK glass_signal")
```

Add this loop between the Lua and shell loops in `run.sh`:

```bash
for test in nvim/tests/noctalia/*_test.py; do
  python3 "$test"
done
```

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
python3 nvim/tests/noctalia/glass_signal_test.py
nvim/tests/noctalia/glass_sync_test.sh
```

Expected: Python fails because `signal_opencode` does not exist; the existing
shell test remains green.

- [ ] **Step 3: Implement capability discovery and ordered signalling**

Import `signal` beside the existing imports. Add:

```python
def signal_opencode(proc_root: Path = Path('/proc')) -> None:
    caught_bit = 1 << (signal.SIGUSR2 - 1)
    for process in sorted(proc_root.glob('[0-9]*'), key=lambda p: int(p.name)):
        try:
            fields = {}
            for line in (process / 'status').read_text().splitlines():
                key, separator, value = line.partition(':')
                if separator:
                    fields[key] = value.strip()
            if fields.get('Name') != 'opencode':
                continue
            if int(fields['Uid'].split()[0]) != os.getuid():
                continue
            if not int(fields['SigCgt'], 16) & caught_bit:
                continue
            os.kill(int(process.name), signal.SIGUSR2)
        except FileNotFoundError:
            continue
        except ProcessLookupError:
            continue


def signal_programs() -> None:
    for process in ('kitty', 'nvim'):
        result = subprocess.run(
            ['pkill', '-SIGUSR1', '-x', process], check=False)
        if result.returncode not in (0, 1):
            fail(f'pkill {process} failed with exit {result.returncode}')
    signal_opencode()
```

Rename `main()`'s existing local boolean:

```python
    should_signal = '--no-signal' not in sys.argv[1:]
```

Then replace the inline post-commit `for process in ('kitty', 'nvim')` block
with:

```python
    if should_signal:
        signal_programs()
```

Do not catch `PermissionError`, malformed readable status fields, or other
`OSError`s. They flow to the existing top-level clean failure after promotion.

- [ ] **Step 4: Prove a disappearing PID is ignored and other errors surface**

Extend `glass_signal_test.py` before its final print:

```python
with tempfile.TemporaryDirectory() as tmp:
    proc = Path(tmp)
    status(proc, 201, caught=1 << (signal.SIGUSR2 - 1))
    original_kill = sync.os.kill
    sync.os.kill = lambda pid, sig: (_ for _ in ()).throw(ProcessLookupError())
    try:
        sync.signal_opencode(proc)  # vanished is success
    finally:
        sync.os.kill = original_kill
```

The narrower exec/PID-reuse race remains documented, not “fixed” with command
line parsing or sleeps.

- [ ] **Step 5: Run the focused and aggregate Noctalia tests**

```bash
python3 nvim/tests/noctalia/glass_signal_test.py
nvim/tests/noctalia/glass_sync_test.sh
nvim/tests/noctalia/run.sh
```

Expected: `OK glass_signal`, `OK glass_sync`, and `OK noctalia suite`.

- [ ] **Step 6: Commit**

```bash
git add bin/noctalia-glass-sync \
  nvim/tests/noctalia/glass_signal_test.py \
  nvim/tests/noctalia/run.sh
git diff --cached --check
git commit -m "feat(noctalia): refresh signal-aware opencode processes"
```

---

### Task 4: Make the OpenCode and Crush tracked configuration reproducible

**Files:**
- Modify: `tests/noctalia_agent_themes_test.py:42-83`
- Modify: `opencode/opencode.json:1-15`
- Modify: `opencode/tui.json:1-14`
- Modify: `crush/crushrc:6-12`
- Modify: `.gitignore:63-68`

**Interfaces:**
- Produces: top-level `opencode/tui.json.theme = "noctalia"`, no legacy
  `opencode/opencode.json.tui`, and exact Crush default
  `option ui transparent true`.
- Removes: the obsolete repo-level ignore for
  `opencode/themes/noctalia.json`; Task 5 removes the actual ignored legacy
  file after migration activation.

- [ ] **Step 1: Write the failing tracked-config assertions**

Add before the final print in `noctalia_agent_themes_test.py`:

```python
opencode_server = json.loads((ROOT / "opencode/opencode.json").read_text())
opencode_tui = json.loads((ROOT / "opencode/tui.json").read_text())
assert "tui" not in opencode_server
assert opencode_tui["theme"] == "noctalia"

crush_lines = (ROOT / "crush/crushrc").read_text().splitlines()
assert crush_lines.count("option ui transparent true") == 1

root_ignore = (ROOT / ".gitignore").read_text().splitlines()
assert "opencode/themes/noctalia.json" not in root_ignore
```

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
python3 tests/noctalia_agent_themes_test.py
```

Expected: failure at `assert "tui" not in opencode_server`.

- [ ] **Step 3: Move the theme key, add the Crush default, and retire the ignore**

Delete this object from `opencode/opencode.json`:

```json
  "tui": {
    "theme": "noctalia"
  },
```

Add the top-level setting in `opencode/tui.json` immediately after `$schema`:

```json
  "theme": "noctalia",
```

Fix that file's existing indentation while editing it; do not reorder its
keybinds or plugins.

Add to `crush/crushrc` immediately before `option ui compact true`:

```text
option ui transparent true
```

Delete only this line from the root `.gitignore`:

```text
opencode/themes/noctalia.json
```

- [ ] **Step 4: Run the focused test and confirm GREEN**

```bash
python3 tests/noctalia_agent_themes_test.py
```

Expected: `OK noctalia agent themes`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore crush/crushrc opencode/opencode.json opencode/tui.json \
  tests/noctalia_agent_themes_test.py
git diff --cached --check
git commit -m "feat(agents): track opencode and crush theme defaults"
```

---

### Task 5: Migrate OpenCode runtime state to a machine-local config directory

**Files:**
- Create: `bin/opencode-config-migrate`
- Create: `tests/opencode_config_migrate_test.py`
- Modify: `lib/dotfiles-setup-data.bash:5`
- Modify: `setup.sh:398-405`
- Modify: `bin/dotfiles-health:73-101,134-145`
- Modify: `tests/setup_and_health.zsh:273-529`
- Modify: `bin/dotfiles-check:1-75`

**Interfaces:**
- `bin/opencode-config-migrate TRACKED_SOURCE RUNTIME_SOURCE CONFIG_LINK LOCAL_DIR THEME_TARGET`
  performs one preflight, lists every conflict, exits nonzero without mutation
  on any conflict, otherwise copies source-only runtime entries, installs the
  three managed links, atomically commits `CONFIG_LINK -> LOCAL_DIR`, then
  removes copied/identical runtime entries from `RUNTIME_SOURCE`.
- `TRACKED_SOURCE/opencode.json` and `TRACKED_SOURCE/tui.json` are immutable
  managed targets. In production `RUNTIME_SOURCE == TRACKED_SOURCE`; tests use
  a separate temporary runtime source. `RUNTIME_SOURCE/themes/noctalia.json`
  is obsolete generated state and is discarded only after activation.
- Every other ignored runtime entry is migrated, including `opencode/.gitignore`.
- Health treats OpenCode as a special layout instead of a common repo-directory
  link.

- [ ] **Step 1: Write the focused migration test first**

Create `tests/opencode_config_migrate_test.py`:

```python
#!/usr/bin/env python3
import hashlib
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIGRATE = ROOT / "bin/opencode-config-migrate"


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def snapshot(root):
    result = {}
    if not os.path.lexists(root):
        return result
    if root.is_symlink():
        return {".": ("link", os.readlink(root))}
    for path in [root, *sorted(root.rglob("*"))]:
        rel = "." if path == root else str(path.relative_to(root))
        if path.is_symlink():
            result[rel] = ("link", os.readlink(path))
        elif path.is_dir():
            result[rel] = ("dir",)
        else:
            result[rel] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
    return result


with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    source = base / "physical/dotfiles/opencode"
    alias_root = base / "home/d"
    local = base / "home/.config/opencode.local"
    config = base / "home/.config/opencode"
    theme = base / "home/.cache/noctalia/nvim-glass/current/opencode-theme.json"
    source.mkdir(parents=True)
    alias_root.parent.mkdir(parents=True)
    alias_root.symlink_to(base / "physical/dotfiles", target_is_directory=True)
    config.parent.mkdir(parents=True)
    config.symlink_to(alias_root / "opencode", target_is_directory=True)
    write(source / "opencode.json", "{}\n")
    write(source / "tui.json", "{}\n")
    write(source / "package.json", "same\n")
    write(source / ".gitignore", "runtime ignore\n")
    write(source / "node_modules/pkg/index.js", "runtime\n")
    write(source / "themes/noctalia.json", "obsolete\n")
    write(local / "package.json", "same\n")
    write(local / "destination-only", "keep\n")

    subprocess.run(
        [MIGRATE, source, source, config, local, theme], check=True, text=True)
    assert config.is_symlink() and config.resolve() == local.resolve()
    assert (local / "opencode.json").resolve() == (source / "opencode.json").resolve()
    assert (local / "tui.json").resolve() == (source / "tui.json").resolve()
    assert os.readlink(local / "themes/noctalia.json") == str(theme)
    assert (local / "node_modules/pkg/index.js").read_text() == "runtime\n"
    assert (local / ".gitignore").read_text() == "runtime ignore\n"
    assert (local / "destination-only").read_text() == "keep\n"
    assert not (source / "package.json").exists()
    assert not (source / ".gitignore").exists()
    assert not (source / "node_modules").exists()
    assert not (source / "themes/noctalia.json").exists()
    assert (source / "opencode.json").is_file()
    assert (source / "tui.json").is_file()

    # Reruns accept the already-active layout.
    subprocess.run(
        [MIGRATE, source, source, config, local, theme], check=True, text=True)

with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    source = base / "repo/opencode"
    local = base / "home/.config/opencode.local"
    config = base / "home/.config/opencode"
    theme = base / "home/.cache/noctalia/nvim-glass/current/opencode-theme.json"
    write(source / "opencode.json", "{}\n")
    write(source / "tui.json", "{}\n")
    write(source / "one", "source one\n")
    write(source / "two", "source two\n")
    write(local / "one", "destination one\n")
    write(local / "two", "destination two\n")
    config.parent.mkdir(parents=True, exist_ok=True)
    config.symlink_to(source, target_is_directory=True)
    before_source = snapshot(source)
    before_local = snapshot(local)
    before_config = snapshot(config)
    result = subprocess.run(
        [MIGRATE, source, source, config, local, theme], text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode != 0
    assert "one" in result.stdout and "two" in result.stdout, result.stdout
    assert snapshot(source) == before_source
    assert snapshot(local) == before_local
    assert snapshot(config) == before_config

print("OK opencode config migration")
```

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
python3 tests/opencode_config_migrate_test.py
```

Expected: `FileNotFoundError` for `bin/opencode-config-migrate`.

- [ ] **Step 3: Implement the preflighted stdlib migrator**

Create executable `bin/opencode-config-migrate`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import filecmp
import os
import shutil
import sys
from pathlib import Path, PurePath

MANAGED = {
    PurePath('opencode.json'),
    PurePath('tui.json'),
    PurePath('themes/noctalia.json'),
}


def lexists(path: Path) -> bool:
    return os.path.lexists(path)


def canonical(path: Path) -> Path:
    return Path(os.path.realpath(path))


def kind(path: Path) -> str:
    if path.is_symlink():
        return 'link'
    if path.is_dir():
        return 'dir'
    if path.is_file():
        return 'file'
    return 'other'


def inventory(root: Path) -> dict[PurePath, Path]:
    if not root.is_dir():
        return {}
    return {
        PurePath(path.relative_to(root)): path
        for path in sorted(root.rglob('*'))
        if PurePath(path.relative_to(root)) not in MANAGED
    }


def same(left: Path, right: Path) -> bool:
    left_kind = kind(left)
    if left_kind != kind(right):
        return False
    if left_kind == 'dir':
        return True
    if left_kind == 'link':
        return os.readlink(left) == os.readlink(right)
    if left_kind == 'file':
        return filecmp.cmp(left, right, shallow=False)
    return False


def copy_node(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        destination.symlink_to(os.readlink(source), target_is_directory=source.is_dir())
    elif source.is_dir():
        destination.mkdir(exist_ok=True)
    else:
        shutil.copy2(source, destination)


def remove_runtime(entries: dict[PurePath, Path]) -> None:
    for path in sorted(entries.values(), key=lambda p: len(p.parts), reverse=True):
        if path.is_symlink() or path.is_file():
            path.unlink()
        elif path.is_dir():
            try:
                path.rmdir()
            except OSError:
                pass


def install_link(destination: Path, target: Path) -> None:
    if destination.is_symlink() and canonical(destination) == canonical(target):
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.symlink_to(target, target_is_directory=target.is_dir())


def main() -> None:
    if len(sys.argv) != 6:
        raise SystemExit(
            'usage: opencode-config-migrate TRACKED_SOURCE RUNTIME_SOURCE '
            'CONFIG_LINK LOCAL_DIR THEME_TARGET')
    tracked, runtime, config, local, theme = map(Path, sys.argv[1:])
    tracked = canonical(tracked)
    runtime = canonical(runtime)
    local = Path(os.path.abspath(local))
    config = Path(os.path.abspath(config))
    theme = Path(os.path.abspath(theme))
    conflicts = []

    if lexists(config):
        if not config.is_symlink() or canonical(config) not in {
                tracked, canonical(local)}:
            conflicts.append(str(config))
    if lexists(local) and (not local.is_dir() or local.is_symlink()):
        conflicts.append(str(local))

    links = {
        local / 'opencode.json': tracked / 'opencode.json',
        local / 'tui.json': tracked / 'tui.json',
        local / 'themes/noctalia.json': theme,
    }
    for tracked_file in (tracked / 'opencode.json', tracked / 'tui.json'):
        if not tracked_file.is_file():
            conflicts.append(str(tracked_file))
    for destination, target in links.items():
        if lexists(destination) and (
                not destination.is_symlink()
                or canonical(destination) != canonical(target)):
            conflicts.append(str(destination))

    source_entries = inventory(runtime)
    destination_entries = inventory(local)
    for relative in sorted(source_entries.keys() & destination_entries.keys()):
        if not same(source_entries[relative], destination_entries[relative]):
            conflicts.append(str(relative))

    if conflicts:
        print('opencode-config-migrate: conflicts:', file=sys.stderr)
        for conflict in sorted(set(conflicts)):
            print(f'  {conflict}', file=sys.stderr)
        raise SystemExit(1)

    local.mkdir(parents=True, exist_ok=True)
    missing = set(source_entries) - set(destination_entries)
    for relative in sorted(missing, key=lambda p: len(p.parts)):
        copy_node(runtime / relative, local / relative)
    for destination, target in links.items():
        install_link(destination, target)

    temporary = config.with_name(f'.{config.name}.tmp-{os.getpid()}')
    temporary.symlink_to(local, target_is_directory=True)
    os.replace(temporary, config)  # migration commit point

    remove_runtime(source_entries)
    obsolete_theme = runtime / 'themes/noctalia.json'
    if lexists(obsolete_theme):
        remove_runtime({PurePath('themes/noctalia.json'): obsolete_theme})
    try:
        (runtime / 'themes').rmdir()
    except OSError:
        pass


if __name__ == '__main__':
    try:
        main()
    except OSError as exc:
        print(f'opencode-config-migrate: {exc}', file=sys.stderr)
        raise SystemExit(1)
```

Make it executable:

```bash
chmod +x bin/opencode-config-migrate
```

- [ ] **Step 4: Run the focused test and confirm GREEN**

```bash
python3 tests/opencode_config_migrate_test.py
```

Expected: `OK opencode config migration`.

- [ ] **Step 5: Replace the generic OpenCode link with the special setup layout**

Remove `opencode` from `DOTFILES_COMMON_CONFIGS` in
`lib/dotfiles-setup-data.bash`.

At the end of `setup_common_config_links`, after the ordinary loop, invoke the
migrator through the existing dry-run-aware `run` function:

```bash
    run "${DOTS_HOME}/bin/opencode-config-migrate" \
        "${DOTS_HOME}/opencode" \
        "${DOTFILES_OPENCODE_RUNTIME_SOURCE:-${DOTS_HOME}/opencode}" \
        "${XDG_CONFIG_HOME}/opencode" \
        "${XDG_CONFIG_HOME}/opencode.local" \
        "${HOME}/.cache/noctalia/nvim-glass/current/opencode-theme.json"
```

The tracked target intentionally uses the worktree's `DOTS_HOME`; canonical
comparison makes an existing `~/d/dotfiles/opencode` link equivalent after
integration. `DOTFILES_OPENCODE_RUNTIME_SOURCE` is tests-only and is never set
by production configuration.

- [ ] **Step 6: Add special-layout health checks**

Add a link check that permits a dangling target after `check_link`:

```bash
check_link_target() {
    local dest="$1"
    local expected="$2"
    if [[ ! -L "$dest" ]]; then
        fail "not a symlink: $dest"
    elif [[ "$(realpath -m "$dest")" == "$(realpath -m "$expected")" ]]; then
        pass "link target: $dest -> $(readlink "$dest")"
    else
        fail "wrong link target: $dest -> $(readlink "$dest"), expected $expected"
    fi
}
```

After the common-config loop, add:

```bash
opencode_local="${XDG_CONFIG_HOME}/opencode.local"
check_link "${XDG_CONFIG_HOME}/opencode" "$opencode_local"
check_link "$opencode_local/opencode.json" "${DOTS_HOME}/opencode/opencode.json"
check_link "$opencode_local/tui.json" "${DOTS_HOME}/opencode/tui.json"
check_link_target \
    "$opencode_local/themes/noctalia.json" \
    "${HOME}/.cache/noctalia/nvim-glass/current/opencode-theme.json"
unset opencode_local
```

- [ ] **Step 7: Extend setup/health integration tests**

In the existing `run_setup` helper, add the isolated runtime source before the
`bash` invocation:

```zsh
  DOTFILES_OPENCODE_RUNTIME_SOURCE="${tmp}/opencode-runtime-source" \
```

In `test_setup_link_only_creates_expected_links_without_external_clones`, add:

```zsh
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
```

Add a health regression before the test invocation list:

```zsh
test_dotfiles_health_fails_wrong_opencode_theme_link() {
  local tmp output exit_status theme_link
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"
  run_setup "$tmp" --link-only --headless >/dev/null
  theme_link="${tmp}/config/opencode.local/themes/noctalia.json"
  rm "$theme_link"
  ln -s "${tmp}/wrong-theme.json" "$theme_link"
  set +e
  output=$(HOME="${tmp}/home" XDG_CONFIG_HOME="${tmp}/config" \
    XDG_DATA_HOME="${tmp}/data" \
    "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1)
  exit_status=$?
  set -e
  [[ "$exit_status" -ne 0 ]] || fail "health accepted wrong OpenCode theme link"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "health did not explain wrong OpenCode theme link"
  rm -rf "$tmp"
}
```

Invoke it before the final success print:

```zsh
test_dotfiles_health_fails_wrong_opencode_theme_link
```

- [ ] **Step 8: Add migration coverage to the aggregate gate and run GREEN**

Do not add the Python migrator to `bash_files`. Add this direct test immediately
before `tests/noctalia_agent_themes_test.py`:

```bash
python3 tests/opencode_config_migrate_test.py
```

Run:

```bash
python3 tests/opencode_config_migrate_test.py
zsh tests/setup_and_health.zsh
bash -euo pipefail -c '
d=$(mktemp -d)
cp nvim/tests/noctalia/fixtures/raw_palette.json \
  "$d/nvim-palette.candidate.json"
NOCTALIA_GLASS_DIR="$d" bin/noctalia-glass-sync --no-signal
test -L "$d/nvim-glass/current"
test -f "$d/nvim-glass/current/opencode-theme.json"
NOCTALIA_GLASS_DIR="$d" \
  PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache bin/dotfiles-check
rm -rf "$d"
'
```

Expected: `OK opencode config migration`, `setup and health tests passed`, and
`dotfiles checks passed`.

- [ ] **Step 9: Commit**

```bash
git add -f bin/opencode-config-migrate
git add bin/dotfiles-check \
  bin/dotfiles-health lib/dotfiles-setup-data.bash setup.sh \
  tests/opencode_config_migrate_test.py tests/setup_and_health.zsh
git diff --cached --check
git commit -m "feat(opencode): move runtime config out of dotfiles"
```

---

### Task 6: Lock down OpenCode's fresh-machine fallback

**Files:**
- Create: `tests/opencode_theme_fallback_test.py`
- Modify: `bin/dotfiles-check:65-75`

**Interfaces:**
- Consumes: isolated XDG directories and, when available, installed `opencode`
  exactly version `1.18.16` plus `tmux`.
- Produces: a bounded end-to-end test that starts the real TUI with either a
  dangling or malformed `noctalia.json` and requires the built-in home screen
  to render instead of the process exiting.
- A machine without OpenCode or tmux prints one explicit `SKIP` line and passes;
  an installed OpenCode at any version other than 1.18.16 fails loudly.
- Uses a unique tmux server because tmux answers OpenCode's terminal capability
  queries; a raw EOF-only PTY liveness check is insufficient.

- [ ] **Step 1: Write the installed-binary fallback test**

Create `tests/opencode_theme_fallback_test.py`:

```python
#!/usr/bin/env python3
import shlex
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

binary = shutil.which("opencode")
if not binary:
    print("SKIP opencode theme fallback: opencode is not installed")
    raise SystemExit(0)
version = subprocess.run(
    [binary, "--version"], check=True, text=True,
    stdout=subprocess.PIPE).stdout.strip()
assert version == "1.18.16", f"expected OpenCode 1.18.16, got {version}"

tmux = shutil.which("tmux")
if not tmux:
    print("SKIP opencode theme fallback: tmux is not installed")
    raise SystemExit(0)


def probe(malformed):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        home = root / "home"
        config = home / ".config/opencode"
        themes = config / "themes"
        project = root / "project"
        themes.mkdir(parents=True)
        project.mkdir()
        (config / "tui.json").write_text('{"theme":"noctalia"}\n')
        theme = themes / "noctalia.json"
        if malformed:
            theme.write_text('{ broken\n')
        else:
            theme.symlink_to(root / "missing-theme.json")

        socket = "opencode-theme-test-" + uuid.uuid4().hex
        isolated = {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_STATE_HOME": str(home / ".local/state"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "TERM": "tmux-256color",
        }
        command = shlex.join(
            ["env", *(f"{key}={value}" for key, value in isolated.items()),
             binary, "--pure", str(project)])
        subprocess.run(
            [tmux, "-L", socket, "new-session", "-d", "-x", "100",
             "-y", "30", command], check=True, timeout=3,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 8
            capture = ""
            while time.monotonic() < deadline:
                result = subprocess.run(
                    [tmux, "-L", socket, "capture-pane", "-p", "-e"],
                    text=True, timeout=2, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE)
                capture = result.stdout
                if ("Ask anything" in capture
                        and "\x1b[48;2;10;10;10m" in capture):
                    break
                time.sleep(0.2)
            assert ("Ask anything" in capture
                    and "\x1b[48;2;10;10;10m" in capture), (
                f"OpenCode did not render built-in fallback for "
                f"{'malformed' if malformed else 'dangling'} theme: {capture!r}")
        finally:
            subprocess.run(
                [tmux, "-L", socket, "kill-server"], check=False, timeout=2,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


probe(malformed=False)
probe(malformed=True)
print("OK opencode theme fallback")
```

- [ ] **Step 2: Run the focused test and confirm GREEN against 1.18.16**

```bash
python3 tests/opencode_theme_fallback_test.py
```

Expected: `OK opencode theme fallback`. The `#0a0a0a` SGR background is the
installed built-in `opencode` theme's dark root. Temporarily replace that escape
with `"not present"`, confirm RED after the bounded timeout, then restore it.
Do not commit the mutation.

- [ ] **Step 3: Add the smoke test to the aggregate gate**

After the migration test in `bin/dotfiles-check`, add:

```bash
python3 tests/opencode_theme_fallback_test.py
```

- [ ] **Step 4: Run the focused and aggregate tests**

```bash
python3 tests/opencode_theme_fallback_test.py
bash -euo pipefail -c '
d=$(mktemp -d)
cp nvim/tests/noctalia/fixtures/raw_palette.json \
  "$d/nvim-palette.candidate.json"
NOCTALIA_GLASS_DIR="$d" bin/noctalia-glass-sync --no-signal
test -L "$d/nvim-glass/current"
test -f "$d/nvim-glass/current/opencode-theme.json"
NOCTALIA_GLASS_DIR="$d" \
  PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache bin/dotfiles-check
rm -rf "$d"
'
```

Expected: `OK opencode theme fallback` and `dotfiles checks passed`. If the
installed version has changed, inspect that release's source and behavior and
update the design instead of weakening the assertion.

- [ ] **Step 5: Commit**

```bash
git add bin/dotfiles-check tests/opencode_theme_fallback_test.py
git diff --cached --check
git commit -m "test(opencode): cover custom theme fallback"
```

---

### Task 7: Document, verify, and activate the completed design

**Files:**
- Modify: `noctalia/noctalia.md:13-59`
- Modify: `docs/specs/2026-08-12-noctalia-opencode-crush-kitty-design.md:1-2`

**Interfaces:**
- Consumes: Tasks 1-6 as an integrated, clean implementation branch.
- Produces: user-facing configuration/limitations and an ancestor-checkable
  inclusive implementation range in the design status.

- [ ] **Step 1: Update the user documentation**

Change the Nvim pipeline paragraph to say the hook validates and atomically
writes Nvim, Kitty, and OpenCode artifacts before signalling Kitty, Nvim, then
signal-aware OpenCode processes.

Append this OpenCode/Crush subsection to `## Agent themes`:

````markdown
### OpenCode and Crush

`setup.sh` keeps OpenCode's tracked configuration and generated theme separate:

```text
~/.config/opencode -> ~/.config/opencode.local
~/.config/opencode/opencode.json -> ~/d/dotfiles/opencode/opencode.json
~/.config/opencode/tui.json -> ~/d/dotfiles/opencode/tui.json
~/.config/opencode/themes/noctalia.json
  -> ~/.cache/noctalia/nvim-glass/current/opencode-theme.json
```

The Noctalia Nvim template hook generates the OpenCode theme in the same atomic
generation as Nvim and Kitty. OpenCode 1.18.16 reloads a running interactive
TUI or `run` footer after a wallpaper switch; non-TUI modes such as `serve` are
not signalled. Before the first render, the dangling theme link is ignored and
OpenCode uses its built-in theme.

OpenCode's root, panel, element, menu, context, and diff backgrounds reuse
Kitty's registered Noctalia glass colors. Small selected semantic controls and
hard-coded modal dimmers remain opaque because OpenCode exposes no independent
theme roles that Kitty can make translucent without sacrificing foreground
readability.

`crush/crushrc` sets `option ui transparent true` as the reproducible default.
Crush's saved global or workspace preference may override it. Crush 0.88.0 has
no custom-theme interface, so its application-painted blocks remain opaque.
````

- [ ] **Step 2: Run a complete isolated verification generation**

Use one Bash process so cleanup and failure semantics do not depend on the
ambient interactive Zsh:

```bash
bash -euo pipefail -c '
d=$(mktemp -d)
cp nvim/tests/noctalia/fixtures/raw_palette.json \
  "$d/nvim-palette.candidate.json"
NOCTALIA_GLASS_DIR="$d" bin/noctalia-glass-sync --no-signal
test -L "$d/nvim-glass/current"
test -f "$d/nvim-glass/current/opencode-theme.json"
NOCTALIA_GLASS_DIR="$d" env \
  PYTHONPYCACHEPREFIX=/tmp/noctalia-glass-pycache bin/dotfiles-check
rm -rf "$d"
'
nvim/tests/noctalia/run.sh
zsh tests/setup_and_health.zsh
python3 tests/noctalia_agent_themes_test.py
python3 tests/opencode_config_migrate_test.py
python3 tests/opencode_theme_fallback_test.py
git diff --check
```

Expected: every command exits 0. The explicit symlink and artifact assertions
prevent `noctalia-glass-check`'s valid fresh-machine no-op from making the
isolated verification vacuous.

- [ ] **Step 3: Record the inclusive implementation range and commit docs**

Resolve the first implementation commit by its unique subject and the last
code/test commit at current `HEAD`:

```bash
first=$(git log -1 --format=%H \
  --grep='^feat(noctalia): generate opencode glass theme$')
last=$(git rev-parse HEAD)
test -n "$first"
git merge-base --is-ancestor "$first" "$last"
python3 - "$first" "$last" <<'PY'
from pathlib import Path
import sys

path = Path('docs/specs/2026-08-12-noctalia-opencode-crush-kitty-design.md')
text = path.read_text()
old = '**Status:** Proposed.'
new = f'**Status:** Implemented (`{sys.argv[1][:7]}^..{sys.argv[2][:7]}`).'
assert text.count(old) == 1
path.write_text(text.replace(old, new))
PY
git add noctalia/noctalia.md
git add -f docs/specs/2026-08-12-noctalia-opencode-crush-kitty-design.md
git diff --cached --check
git commit -m "docs: record opencode and crush glass support"
```

The caret makes the Git range base-inclusive, so the first theme-generation
commit is not omitted.

- [ ] **Step 4: Integrate, run setup, and immediately render production**

Run this step only after `superpowers:finishing-a-development-branch` integrates
the implementation. Then run:

```bash
bash setup.sh --link-only --headless --only common-config
qs -c noctalia-shell ipc call wallpaper refresh
```

Do not run production `bin/dotfiles-check` between integration and the refresh:
the old two-file `current` generation is intentionally invalid under the new
checker. The setup migration fails before mutation if runtime copies diverge;
inspect and resolve the listed paths rather than deleting either side.

- [ ] **Step 5: Verify production state and live rendering**

```bash
bin/noctalia-glass-check
python3 - <<'PY'
import json
from pathlib import Path

theme = json.loads(Path.home().joinpath(
    '.cache/noctalia/nvim-glass/current/opencode-theme.json').read_text())
assert theme['theme']['background']
assert theme['theme']['diffAddedBg'] == '#022800'
assert theme['theme']['diffRemovedBg'] == '#3d0100'
assert theme['theme']['border'] != theme['theme']['backgroundMenu']
PY
realpath ~/.config/opencode
realpath ~/.config/opencode/opencode.json
realpath ~/.config/opencode/tui.json
readlink ~/.config/opencode/themes/noctalia.json
bin/dotfiles-health --skip-systemd
```

Expected: the checker and assertions pass; the config resolves to
`~/.config/opencode.local`, the two tracked files resolve into
`~/d/dotfiles/opencode/`, the theme link names the atomic cache artifact, and
health passes.

Start OpenCode in Kitty and verify the root, sidebar, input surface, menus, and
diffs reveal Niri-blurred wallpaper through their Noctalia colors. Switch one
wallpaper and verify the running TUI repaints without restart. Confirm attachment
badge text remains visible, selected semantic controls remain readable/opaque,
and the documented modal backdrop remains opaque.

For Crush, isolate both writable preference layers while retaining the tracked
global `crushrc`:

```bash
CRUSH_GLOBAL_DATA=$(mktemp -d) crush --data-dir "$(mktemp -d)"
```

Confirm wallpaper is visible between blocks, while application-painted blocks
remain opaque. Toggle transparency off and confirm the saved preference wins on
restart; this is the intended state-over-default precedence.
