# Wali Noctalia Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a local Noctalia bar plugin that previews the current wallpaper and exposes `save` and `edit` actions through a reusable `walictl` helper.

**Architecture:** Keep wallpaper discovery and actions in a standalone helper CLI and keep the Noctalia plugin as a thin UI layer. Store only the plugin subtree in the dotfiles repo and symlink that subtree into `~/.config/noctalia/plugins/` so Noctalia can discover it without taking ownership of all Noctalia config.

**Tech Stack:** Noctalia QML plugin, Quickshell process execution, Python helper script with `uv`, `pytest`, `ruff`, and `pyright`.

---

### Task 1: Scaffold the helper and test harness

**Files:**
- Create: `pyproject.toml`
- Create: `bin/walictl`
- Create: `tests/bin/test_walictl.py`

**Step 1: Write the failing test**

Create `tests/bin/test_walictl.py` with a first test that executes `bin/walictl current --json` under mocked subprocess responses and expects structured JSON:

```python
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


def test_current_returns_source_metadata(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ...
```

Cover at least:

- `qs ... wallpaper get all` returns a current wallpaper path with `PXL_20240520_023703962.jpg`
- `BACKGROUND_IMG_DIR` points at a temp archive root
- JSON output contains `ok`, `source_wallpaper_path`, and `display_date == "May 20, 2024"`

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: FAIL because `bin/walictl` and project metadata do not exist yet.

**Step 3: Write minimal implementation**

Create `pyproject.toml` with a minimal project and dev dependencies:

```toml
[project]
name = "dotfiles-wali-tools"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[dependency-groups]
dev = ["pytest>=8.0", "ruff>=0.11.0", "pyright>=1.1.0"]

[tool.pyright]
include = ["bin/walictl", "tests/bin/test_walictl.py"]

[tool.ruff]
line-length = 120
include = ["bin/walictl", "tests/**/*.py"]
```

Create `bin/walictl` as an executable Python script that:

- parses subcommands with `argparse`
- supports `current --json`
- runs `qs -c noctalia-shell ipc call wallpaper get all`
- normalizes the returned path
- parses the date from the filename
- derives the source image path from `BACKGROUND_IMG_DIR`
- prints JSON to stdout

Start with only the logic needed for the first test.

**Step 4: Run test to verify it passes**

Run:

```bash
uv sync
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: PASS for the first metadata test.

**Step 5: Commit**

```bash
git add pyproject.toml bin/walictl tests/bin/test_walictl.py
git commit -m "feat: scaffold walictl helper"
```

### Task 2: Harden `walictl current` failure modes

**Files:**
- Modify: `bin/walictl`
- Modify: `tests/bin/test_walictl.py`

**Step 1: Write the failing tests**

Add tests for:

- wallpaper query returns empty output
- filename does not contain a parseable date
- source path does not exist or cannot be derived

Example:

```python
def test_current_fails_when_wallpaper_query_is_empty(...) -> None:
    result = run_walictl(...)
    assert result.returncode != 0
    assert "could not determine current wallpaper" in result.stderr


def test_current_returns_null_date_for_unparseable_filename(...) -> None:
    payload = json.loads(run_walictl_ok(...).stdout)
    assert payload["parsed_date"] is None
    assert payload["display_date"] is None
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: FAIL on the new edge cases.

**Step 3: Write minimal implementation**

Update `bin/walictl` so that:

- query failures raise a specific error
- date parsing returns `None` instead of guessing
- source path derivation validates required env vars and path segments
- stderr messages are concise and explicit

Suggested internal helpers:

```python
def get_current_wallpaper_path() -> Path: ...
def parse_pixel_date(filename: str) -> date | None: ...
def derive_source_path(current_path: Path, archive_root: Path) -> Path: ...
```

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: PASS for success and failure cases.

**Step 5: Commit**

```bash
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat: harden walictl current resolution"
```

### Task 3: Add `save-current` and `edit-current`

**Files:**
- Modify: `bin/walictl`
- Modify: `tests/bin/test_walictl.py`

**Step 1: Write the failing tests**

Add tests for:

- `save-current` appends the resolved source path to `$WALI_DIR/favorites.txt`
- `edit-current` launches `gimp <resolved-source-path>`

Example:

```python
def test_save_current_appends_source_path(...) -> None:
    ...


def test_edit_current_launches_gimp(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: FAIL because the subcommands are not implemented yet.

**Step 3: Write minimal implementation**

Extend `bin/walictl` with:

- `save-current`
- `edit-current`

Implementation rules:

- resolve the current source path through the same code path as `current`
- append exactly one newline-terminated entry to `favorites.txt`
- launch `gimp` via `subprocess.run([...], check=True)`
- emit success to stdout only when the action succeeds

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
```

Expected: PASS for metadata, save, and edit behavior.

**Step 5: Commit**

```bash
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat: add walictl save and edit commands"
```

### Task 4: Add the Noctalia plugin files

**Files:**
- Create: `noctalia/plugins/wali-panel/manifest.json`
- Create: `noctalia/plugins/wali-panel/BarWidget.qml`
- Create: `noctalia/plugins/wali-panel/Panel.qml`

**Step 1: Write the failing test**

Because QML is the integration layer here, use a failing manual validation target instead of a unit test:

```text
Open Noctalia plugin settings and confirm the plugin is not yet discoverable.
```

**Step 2: Run test to verify it fails**

Manual verification:

- No plugin named `wali-panel` is visible in Noctalia
- No bar widget exists yet

**Step 3: Write minimal implementation**

Create `manifest.json`:

```json
{
  "id": "wali-panel",
  "name": "Wali Panel",
  "version": "0.1.0",
  "author": "Keith",
  "description": "Current wallpaper preview and actions for Wali.",
  "entryPoints": {
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml"
  },
  "metadata": {
    "icon": "wallpaper-selector",
    "iconColor": "none"
  }
}
```

Create `BarWidget.qml` to:

- accept `screen` and `pluginApi`
- render an `NIconButton`
- call `pluginApi.togglePanel(screen, root)` on click

Create `Panel.qml` to:

- expose the anchor properties expected by `PluginPanelSlot`
- spawn `Process` commands for `walictl current --json`, `walictl save-current`, and `walictl edit-current`
- parse JSON into panel state
- render preview, date, path, and action buttons
- show explicit error text when the helper fails

Use the helper via an absolute path or `["sh", "-lc", "walictl current --json"]` only if PATH resolution is reliable on your system. Prefer an explicit path if uncertain.

**Step 4: Run test to verify it passes**

Manual verification:

- Noctalia discovers the plugin from disk
- enabling it adds the widget to the bar
- clicking the widget opens the panel

**Step 5: Commit**

```bash
git add noctalia/plugins/wali-panel
git commit -m "feat: add wali noctalia plugin"
```

### Task 5: Wire dotfiles installation and local docs

**Files:**
- Modify: `setup.sh`
- Modify: `noctalia.md`

**Step 1: Write the failing test**

Use a failing manual install check:

```text
Run setup.sh in a disposable environment or inspect the target paths; confirm there is no symlink at ~/.config/noctalia/plugins/wali-panel.
```

**Step 2: Run test to verify it fails**

Manual verification:

- plugin symlink does not exist
- `noctalia.md` does not explain the plugin install/enable flow

**Step 3: Write minimal implementation**

Update `setup.sh` so the graphical install path also:

- creates `~/.config/noctalia/plugins`
- symlinks `${DOTS_HOME}/noctalia/plugins/wali-panel` to `~/.config/noctalia/plugins/wali-panel`

Add a short section to `noctalia.md` documenting:

- the plugin path
- that Noctalia will discover it as a local plugin
- that the user should enable `wali-panel` in the Plugins settings if it is not already enabled

**Step 4: Run test to verify it passes**

Manual verification:

- symlink exists after setup
- plugin is discoverable from the symlinked location
- docs describe the enablement step

**Step 5: Commit**

```bash
git add setup.sh noctalia.md
git commit -m "feat: install wali noctalia plugin"
```

### Task 6: Full verification

**Files:**
- Verify: `bin/walictl`
- Verify: `tests/bin/test_walictl.py`
- Verify: `noctalia/plugins/wali-panel/BarWidget.qml`
- Verify: `noctalia/plugins/wali-panel/Panel.qml`
- Verify: `setup.sh`
- Verify: `noctalia.md`

**Step 1: Run automated verification**

Run:

```bash
uv run --frozen pytest tests/bin/test_walictl.py -q
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py
uv run --frozen pyright
```

Expected: PASS for all helper tests and static checks.

**Step 2: Run manual verification**

Check:

- `walictl current --json`
- `walictl save-current`
- `walictl edit-current`
- Noctalia plugin discovery
- panel render and preview load
- save action success
- GIMP launch action success
- visible error state when the helper is forced to fail

**Step 3: Commit**

```bash
git add pyproject.toml bin/walictl tests/bin/test_walictl.py noctalia/plugins/wali-panel setup.sh noctalia.md
git commit -m "feat: complete wali wallpaper panel workflow"
```
