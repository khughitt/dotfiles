# Wallpaper Management Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `walictl` the single owner of wallpaper selection, history, and favorites, driven by a systemd timer and a thin Noctalia panel, with Noctalia keeping display and color derivation.

**Architecture:** `bin/walictl` is rewritten as one Python file with sections for config, photo identity, favorites store, history store, Noctalia IPC, sampler, and commands. Every mutating command reconciles history against Noctalia's default wallpaper under a lock, calls `wallpaper-set`, and commits only after Noctalia answers ok. A systemd user timer runs `walictl next`; the `wallpaper_changed` hook runs `walictl observe`; the `wali-panel` Luau plugin renders `walictl current --json`.

**Tech Stack:** Python 3.11 standard library (argparse, tomllib, json, fcntl, random), pytest via `uv run --frozen pytest`, zsh tests, Lua 5.4 for the plugin test, systemd user units, Noctalia v5 Luau plugin API 22.

**Spec:** `docs/specs/2026-09-07-wallpaper-management-redesign-design.md`

## Global Constraints

- `bin/walictl` stays a single Python file, argparse, standard library only, `requires-python = ">=3.11"`.
- Photo id is the filename stem. Extension precedence when a stem has several files: `.jpg`, `.jpeg`, `.png`, `.webp`.
- Config file: `$XDG_CONFIG_HOME/wali/config.toml`; required keys `wallpaper_dir`, `favorites_file`; optional `archive_root`, `variants_dir`; `[sampling]` keys `exclude_recent` (200), `favorite_boost` (1.0), `period_boost` (3.0).
- Sampling config rejects booleans and strings: `exclude_recent` is a non-negative integer; boosts are non-negative finite numbers representable as floats. Invalid values raise `WalictlError`.
- State: `$XDG_STATE_HOME/wali/history.json`, `history.lock`, `favorites.lock`. History capped at 1000 entries. Lock wait bounded at 10 seconds.
- Favorite weight is `1 + favorite_boost`; month weight is `1 + period_boost * density`; recent ids (the `exclude_recent` entries at or before the cursor) weigh 0.
- Every failure exits non-zero with one line on stderr. Designed fallbacks only: Edit degrading to the display file, and uniform sampling when every weight is 0.
- History records selections Noctalia accepted, not confirmed displays. Only the default (all-monitor) wallpaper is tracked. `observe` takes no argument.
- Cursor moves (`previous`, and `next` while behind the end) do not create entries. `origin` is one of `next`, `random`, `observed`.
- Commit messages use conventional commits with no attribution trailer of any kind.
- The live system links to the main checkout, not this worktree. Nothing in tasks 1-16 changes what is running; task 17 is the cutover.
- Run the full suite with `just test` before every commit that touches Python, zsh, or Lua.

---

## File map

| Path | Responsibility |
|---|---|
| `bin/walictl` | The CLI. Rewritten in place. Sections in order: errors, config, photo identity and library, favorites, history, Noctalia IPC, sampler, commands, parser, main. |
| `tests/bin/test_walictl.py` | pytest suite. Rewritten in place; loads the script as a module for unit tests and runs it through `main()` for command tests. |
| `wali/titan/config.toml`, `wali/europa/config.toml` | Per-host config, linked to `$XDG_CONFIG_HOME/wali/config.toml`. |
| `systemd/user/wali-rotate.service`, `systemd/user/wali-rotate.timer` | Rotation trigger. |
| `setup.sh` | Links the config and the units. |
| `bin/dotfiles-health` | Checks the config link and the units. |
| `tests/setup_and_health.zsh` | Setup and health assertions. |
| `noctalia/config.toml` | Automation off, observe hook. |
| `noctalia/plugins/wali-panel/{logic,panel}.luau`, `plugin_test.lua`, `README.md` | Panel. |
| `shell/wali`, `tests/wali.zsh` | Shell trim. |
| `noctalia/noctalia-wallpaper-switcher.md`, `noctalia/noctalia.md` | Docs. |

## Test harness conventions (used by every Python task)

`tests/bin/test_walictl.py` starts with this preamble. Task 1 writes it; later tasks append to the file.

```python
from __future__ import annotations

import importlib.machinery
import importlib.util
import io
import json
import subprocess
import sys
from contextlib import redirect_stderr, redirect_stdout
from datetime import date, datetime
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "bin" / "walictl"


def load_walictl() -> ModuleType:
    loader = importlib.machinery.SourceFileLoader("walictl", str(SCRIPT))
    spec = importlib.util.spec_from_loader("walictl", loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["walictl"] = module  # dataclasses resolve postponed annotations through sys.modules
    loader.exec_module(module)
    return module


@pytest.fixture
def walictl() -> ModuleType:
    return load_walictl()


@pytest.fixture
def env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> dict[str, Path]:
    """XDG dirs, a config file, a wallpaper dir with dated photos, and an archive."""
    tmp_path = tmp_path.resolve()  # walictl realpaths what Noctalia reports
    config_home = tmp_path / "config"
    state_home = tmp_path / "state"
    wallpapers = tmp_path / "3440"
    archive = tmp_path / "archive"
    favorites = tmp_path / "favorites.json"
    wallpapers.mkdir()
    for stem in ("PXL_20210608_111152739", "PXL_20210609_120000000", "PXL_20220402_162957459"):
        (wallpapers / f"{stem}.jpg").touch()
    (archive / "2021" / "06").mkdir(parents=True)
    (archive / "2021" / "06" / "PXL_20210608_111152739.jpg").touch()
    (config_home / "wali").mkdir(parents=True)
    (config_home / "wali" / "config.toml").write_text(
        f'wallpaper_dir = "{wallpapers}"\n'
        f'favorites_file = "{favorites}"\n'
        f'archive_root = "{archive}"\n'
    )
    monkeypatch.setenv("XDG_CONFIG_HOME", str(config_home))
    monkeypatch.setenv("XDG_STATE_HOME", str(state_home))
    return {
        "config_home": config_home,
        "state_home": state_home,
        "wallpapers": wallpapers,
        "archive": archive,
        "favorites": favorites,
    }


class FakeNoctalia:
    """Stands in for `noctalia msg`. `default` is what wallpaper-get answers."""

    def __init__(self, default: Path | None, *, reject_set: str | None = None) -> None:
        self.default = default
        self.reject_set = reject_set
        self.calls: list[list[str]] = []

    def run(self, args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(list(args))
        assert args[:2] == ["noctalia", "msg"], args
        if args[2] == "wallpaper-get":
            out = f"{self.default}\n" if self.default else "\n"
            return subprocess.CompletedProcess(args, 0, stdout=out, stderr="")
        if args[2] == "wallpaper-set":
            if self.reject_set:
                return subprocess.CompletedProcess(args, 1, stdout=f"error: {self.reject_set}\n", stderr="")
            self.default = Path(args[3])
            return subprocess.CompletedProcess(args, 0, stdout="ok\n", stderr="")
        raise AssertionError(f"unexpected IPC call: {args}")


@pytest.fixture
def noctalia(env: dict[str, Path], monkeypatch: pytest.MonkeyPatch) -> FakeNoctalia:
    fake = FakeNoctalia(env["wallpapers"] / "PXL_20210608_111152739.jpg")
    monkeypatch.setattr(subprocess, "run", fake.run)
    return fake


def run_cli(walictl: ModuleType, argv: list[str]) -> tuple[int, str, str]:
    stdout, stderr = io.StringIO(), io.StringIO()
    with redirect_stdout(stdout), redirect_stderr(stderr):
        try:
            code = walictl.main(argv)
        except SystemExit as exc:  # argparse errors
            code = exc.code if isinstance(exc.code, int) else 1
    return code, stdout.getvalue(), stderr.getvalue()
```

`main(argv: list[str] | None = None) -> int` is the entry point every task's command tests call. Tests never touch the real shell.

Run the Python suite with:

```bash
uv run --frozen pytest -q tests/bin/test_walictl.py
```

---

### Task 1: Config loading and XDG paths

**Files:**
- Modify: `bin/walictl` (replace the whole file)
- Modify: `tests/bin/test_walictl.py` (replace the whole file with the preamble above plus these tests)

**Interfaces:**
- Produces: `class WalictlError(RuntimeError)`; `@dataclass(frozen=True) Sampling(exclude_recent: int = 200, favorite_boost: float = 1.0, period_boost: float = 3.0)`; `@dataclass(frozen=True) Config(wallpaper_dir: Path, favorites_file: Path, archive_root: Path | None, variants_dir: Path | None, sampling: Sampling)`; `config_path() -> Path`; `load_config(path: Path) -> Config`; `state_dir() -> Path`; `main(argv: list[str] | None = None) -> int`.

- [ ] **Step 1: Replace the test file with the preamble and these tests**

```python
def test_load_config_reads_required_and_optional_keys(walictl: ModuleType, env: dict[str, Path]) -> None:
    config = walictl.load_config(walictl.config_path())
    assert config.wallpaper_dir == env["wallpapers"]
    assert config.favorites_file == env["favorites"]
    assert config.archive_root == env["archive"]
    assert config.variants_dir is None
    assert config.sampling == walictl.Sampling(exclude_recent=200, favorite_boost=1.0, period_boost=3.0)


def test_load_config_expands_tilde_and_reads_sampling(
    walictl: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    tmp_path = tmp_path.resolve()
    monkeypatch.setenv("HOME", str(tmp_path))
    path = tmp_path / "config.toml"
    path.write_text(
        'wallpaper_dir = "~/w"\nfavorites_file = "~/f.json"\nvariants_dir = "~/v"\n'
        "[sampling]\nexclude_recent = 5\nfavorite_boost = 0.5\nperiod_boost = 0\n"
    )
    config = walictl.load_config(path)
    assert config.wallpaper_dir == tmp_path / "w"
    assert config.variants_dir == tmp_path / "v"
    assert config.sampling == walictl.Sampling(exclude_recent=5, favorite_boost=0.5, period_boost=0.0)


def test_load_config_resolves_symlinked_directories(walictl: ModuleType, tmp_path: Path) -> None:
    tmp_path = tmp_path.resolve()
    real = tmp_path / "real"
    real.mkdir()
    (tmp_path / "link").symlink_to(real)
    path = tmp_path / "config.toml"
    path.write_text(f'wallpaper_dir = "{tmp_path / "link"}"\nfavorites_file = "{tmp_path / "link" / "f.json"}"\n')
    config = walictl.load_config(path)
    assert config.wallpaper_dir == real
    assert config.favorites_file == real / "f.json"


@pytest.mark.parametrize("key,value", [
    ("exclude_recent", "0.5"),
    ("exclude_recent", "-1"),
    ("exclude_recent", "true"),
    ("exclude_recent", '"2"'),
    ("favorite_boost", "-1"),
    ("favorite_boost", "true"),
    ("favorite_boost", '"oops"'),
    ("favorite_boost", "nan"),
    ("favorite_boost", "inf"),
    ("favorite_boost", "-inf"),
    ("period_boost", "-1"),
    ("period_boost", "false"),
    ("period_boost", '"oops"'),
    ("period_boost", "nan"),
    ("period_boost", "inf"),
])
def test_invalid_sampling_values_report_config_error(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, key: str, value: str
) -> None:
    path = env["config_home"] / "wali" / "config.toml"
    path.write_text(path.read_text() + f"[sampling]\n{key} = {value}\n")
    code, stdout, stderr = run_cli(walictl, ["current", "--json"])
    assert (code, stdout) == (1, "")
    assert stderr.startswith(f"config key sampling.{key} ")
    assert len(stderr.splitlines()) == 1


def test_load_config_fails_when_file_is_missing(walictl: ModuleType, tmp_path: Path) -> None:
    with pytest.raises(walictl.WalictlError, match="config not found"):
        walictl.load_config(tmp_path / "missing.toml")


def test_load_config_fails_when_required_key_is_missing(walictl: ModuleType, tmp_path: Path) -> None:
    path = tmp_path / "config.toml"
    path.write_text('wallpaper_dir = "/w"\n')
    with pytest.raises(walictl.WalictlError, match="favorites_file"):
        walictl.load_config(path)


def test_config_and_state_paths_follow_xdg(walictl: ModuleType, env: dict[str, Path]) -> None:
    assert walictl.config_path() == env["config_home"] / "wali" / "config.toml"
    assert walictl.state_dir() == env["state_home"] / "wali"


def test_every_command_fails_without_config(
    walictl: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "empty"))
    code, stdout, stderr = run_cli(walictl, ["current", "--json"])
    assert (code, stdout) == (1, "")
    assert stderr.startswith("config not found:")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: FAIL (the old script has no `load_config`, `main`, or `Sampling`).

- [ ] **Step 3: Replace `bin/walictl` with the config section and a stub main**

```python
#!/usr/bin/env python3
"""walictl: wallpaper selection, history, and favorites on top of Noctalia v5."""
from __future__ import annotations

import argparse
import os
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path


class WalictlError(RuntimeError):
    """An expected failure: printed as one line on stderr, exit 1."""


# --- config -----------------------------------------------------------------


@dataclass(frozen=True)
class Sampling:
    exclude_recent: int = 200
    favorite_boost: float = 1.0
    period_boost: float = 3.0


@dataclass(frozen=True)
class Config:
    wallpaper_dir: Path
    favorites_file: Path
    archive_root: Path | None
    variants_dir: Path | None
    sampling: Sampling


def _xdg(var: str, default: str) -> Path:
    return Path(os.environ.get(var) or Path.home() / default)


def config_path() -> Path:
    return _xdg("XDG_CONFIG_HOME", ".config") / "wali" / "config.toml"


def state_dir() -> Path:
    return _xdg("XDG_STATE_HOME", ".local/state") / "wali"


def _expand(value: object, key: str) -> Path:
    if not isinstance(value, str) or not value:
        raise WalictlError(f"config key {key} must be a non-empty string")
    # Resolved so that stored paths compare equal to what Noctalia reports (it
    # realpaths too); the wallpaper dir on this host sits behind a symlink.
    return Path(value).expanduser().resolve()


def load_config(path: Path) -> Config:
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise WalictlError(f"config not found: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise WalictlError(f"config is not valid TOML: {path}: {exc}") from exc
    for key in ("wallpaper_dir", "favorites_file"):
        if key not in raw:
            raise WalictlError(f"config key {key} is required in {path}")
    sampling_raw = raw.get("sampling", {})
    if not isinstance(sampling_raw, dict):
        raise WalictlError("config table [sampling] must be a table")
    defaults = Sampling()
    exclude_recent = sampling_raw.get("exclude_recent", defaults.exclude_recent)
    if isinstance(exclude_recent, bool) or not isinstance(exclude_recent, int) or exclude_recent < 0:
        raise WalictlError("config key sampling.exclude_recent must be a non-negative integer")
    favorite_boost = sampling_raw.get("favorite_boost", defaults.favorite_boost)
    period_boost = sampling_raw.get("period_boost", defaults.period_boost)
    for key, value in (("favorite_boost", favorite_boost), ("period_boost", period_boost)):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0 <= value <= sys.float_info.max:
            raise WalictlError(f"config key sampling.{key} must be a non-negative finite float or integer")
    sampling = Sampling(
        exclude_recent=exclude_recent,
        favorite_boost=float(favorite_boost),
        period_boost=float(period_boost),
    )
    return Config(
        wallpaper_dir=_expand(raw["wallpaper_dir"], "wallpaper_dir"),
        favorites_file=_expand(raw["favorites_file"], "favorites_file"),
        archive_root=_expand(raw["archive_root"], "archive_root") if "archive_root" in raw else None,
        variants_dir=_expand(raw["variants_dir"], "variants_dir") if "variants_dir" in raw else None,
        sampling=sampling,
    )


# --- parser and main --------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="walictl")
    subparsers = parser.add_subparsers(dest="command", required=True)
    current = subparsers.add_parser("current")
    current.add_argument("--json", action="store_true", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        config = load_config(config_path())
        raise WalictlError(f"command not implemented: {args.command} ({config.wallpaper_dir})")
    except WalictlError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 22 passed.

- [ ] **Step 5: Lint and type-check, then commit**

Run: `uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright`
Expected: no errors.

```bash
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): load per-host TOML config from XDG paths"
```

---

### Task 2: Photo identity and library scan

**Files:**
- Modify: `bin/walictl` (add a section after config)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `Config`, `WalictlError`.
- Produces: `WALLPAPER_EXTENSIONS: tuple[str, ...] = (".jpg", ".jpeg", ".png", ".webp")`; `photo_id(path: Path) -> str`; `capture_date(photo_id: str) -> date | None`; `display_date(value: date | None) -> str | None`; `scan_library(directory: Path) -> dict[str, Path]` (id to chosen path, sorted keys); `find_by_stem(directory: Path, photo_id: str) -> Path | None`; `resolve_variant(config: Config, photo_id: str) -> Path | None`; `resolve_source(config: Config, photo_id: str) -> Path | None`; `display_path(config: Config, library: dict[str, Path], photo_id: str) -> Path`.

- [ ] **Step 1: Append the tests**

```python
def test_photo_id_and_capture_date(walictl: ModuleType) -> None:
    assert walictl.photo_id(Path("/x/PXL_20240520_023703962.jpg")) == "PXL_20240520_023703962"
    assert walictl.capture_date("PXL_20240520_023703962") == date(2024, 5, 20)
    assert walictl.capture_date("PXL_20240520") is None
    assert walictl.capture_date("IMG_20200525_124754") is None
    assert walictl.capture_date("PXL_20241399_000000000") is None
    assert walictl.display_date(date(2024, 5, 20)) == "May 20, 2024"
    assert walictl.display_date(None) is None


def test_scan_library_collapses_stems_by_extension_precedence(walictl: ModuleType, tmp_path: Path) -> None:
    for name in ("b.webp", "b.jpg", "a.png", "a.jpeg", "c.txt", "d.PNG"):
        (tmp_path / name).touch()
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "e.jpg").touch()
    library = walictl.scan_library(tmp_path)
    assert list(library) == ["a", "b", "d"]
    assert library["a"] == tmp_path / "a.jpeg"
    assert library["b"] == tmp_path / "b.jpg"
    assert library["d"] == tmp_path / "d.PNG"


def test_scan_library_fails_on_missing_directory(walictl: ModuleType, tmp_path: Path) -> None:
    with pytest.raises(walictl.WalictlError, match="wallpaper directory not found"):
        walictl.scan_library(tmp_path / "nope")


def test_resolve_variant_and_source(walictl: ModuleType, env: dict[str, Path], tmp_path: Path) -> None:
    config = walictl.load_config(walictl.config_path())
    assert walictl.resolve_variant(config, "PXL_20210608_111152739") is None
    variants = tmp_path / "edits"
    variants.mkdir()
    (variants / "PXL_20210608_111152739.png").touch()
    (variants / "PXL_20210608_111152739.jpg").touch()
    with_variants = walictl.Config(
        config.wallpaper_dir, config.favorites_file, config.archive_root, variants, config.sampling
    )
    assert walictl.resolve_variant(with_variants, "PXL_20210608_111152739") == variants / "PXL_20210608_111152739.jpg"
    assert walictl.resolve_source(config, "PXL_20210608_111152739") == env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"
    assert walictl.resolve_source(config, "PXL_20210609_120000000") is None
    assert walictl.resolve_source(config, "IMG_1") is None
    no_archive = walictl.Config(config.wallpaper_dir, config.favorites_file, None, None, config.sampling)
    assert walictl.resolve_source(no_archive, "PXL_20210608_111152739") is None


def test_display_path_prefers_variant_and_rejects_unknown_id(
    walictl: ModuleType, env: dict[str, Path], tmp_path: Path
) -> None:
    config = walictl.load_config(walictl.config_path())
    library = walictl.scan_library(config.wallpaper_dir)
    assert walictl.display_path(config, library, "PXL_20210609_120000000") == env["wallpapers"] / "PXL_20210609_120000000.jpg"
    variants = tmp_path / "edits"
    variants.mkdir()
    (variants / "PXL_20210609_120000000.webp").touch()
    with_variants = walictl.Config(
        config.wallpaper_dir, config.favorites_file, config.archive_root, variants, config.sampling
    )
    assert walictl.display_path(with_variants, library, "PXL_20210609_120000000") == variants / "PXL_20210609_120000000.webp"
    with pytest.raises(walictl.WalictlError, match="unknown photo id: nope"):
        walictl.display_path(config, library, "nope")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: the five new tests FAIL with `AttributeError`.

- [ ] **Step 3: Add the photo identity section to `bin/walictl` (after the config section; add `import re` and `from datetime import date, datetime` at the top)**

```python
# --- photo identity and library --------------------------------------------

WALLPAPER_EXTENSIONS: tuple[str, ...] = (".jpg", ".jpeg", ".png", ".webp")
_PXL_STEM = re.compile(r"PXL_(\d{8})_.+")


def photo_id(path: Path) -> str:
    return path.stem


def capture_date(photo_id: str) -> date | None:
    match = _PXL_STEM.fullmatch(photo_id)
    if match is None:
        return None
    try:
        return datetime.strptime(match.group(1), "%Y%m%d").date()
    except ValueError:
        return None


def display_date(value: date | None) -> str | None:
    return value.strftime("%B %-d, %Y") if value is not None else None


def _extension_rank(path: Path) -> int:
    return WALLPAPER_EXTENSIONS.index(path.suffix.lower())


def find_by_stem(directory: Path, photo_id: str) -> Path | None:
    candidates = [
        path
        for path in directory.glob(f"{photo_id}.*")
        if path.is_file() and path.suffix.lower() in WALLPAPER_EXTENSIONS
    ]
    if not candidates:
        return None
    return min(candidates, key=_extension_rank)


def scan_library(directory: Path) -> dict[str, Path]:
    if not directory.is_dir():
        raise WalictlError(f"wallpaper directory not found: {directory}")
    chosen: dict[str, Path] = {}
    for path in directory.iterdir():
        if not path.is_file() or path.suffix.lower() not in WALLPAPER_EXTENSIONS:
            continue
        stem = photo_id(path)
        if stem not in chosen or _extension_rank(path) < _extension_rank(chosen[stem]):
            chosen[stem] = path
    return dict(sorted(chosen.items()))


def resolve_variant(config: Config, photo_id: str) -> Path | None:
    if config.variants_dir is None or not config.variants_dir.is_dir():
        return None
    return find_by_stem(config.variants_dir, photo_id)


def resolve_source(config: Config, photo_id: str) -> Path | None:
    taken = capture_date(photo_id)
    if config.archive_root is None or taken is None:
        return None
    candidate = config.archive_root / taken.strftime("%Y") / taken.strftime("%m") / f"{photo_id}.jpg"
    return candidate if candidate.is_file() else None


def display_path(config: Config, library: dict[str, Path], photo_id: str) -> Path:
    variant = resolve_variant(config, photo_id)
    if variant is not None:
        return variant
    try:
        return library[photo_id]
    except KeyError as exc:
        raise WalictlError(f"unknown photo id: {photo_id}") from exc
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 27 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): key photos by stem and collapse the library by extension precedence"
```

---

### Task 3: Favorites store with a state-dir lock

**Files:**
- Modify: `bin/walictl` (add a section after photo identity)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `WalictlError`, `state_dir()`.
- Produces: `locked(lock_path: Path, timeout: float = 10.0)` context manager; `utc_now() -> str` (ISO 8601 seconds, `Z` suffix); `class Favorites` with `entries: dict[str, dict[str, str]]`, `load(path) -> Favorites` (classmethod), `save(path) -> None`, `__contains__(photo_id) -> bool`, `add(photo_id, now: str) -> bool` (True if new), `remove(photo_id) -> bool` (True if removed), `ids() -> list[str]` (sorted); `favorites_lock() -> Path`.

- [ ] **Step 1: Append the tests**

```python
def test_favorites_round_trip_and_idempotent_ops(walictl: ModuleType, tmp_path: Path) -> None:
    path = tmp_path / "favorites.json"
    store = walictl.Favorites.load(path)
    assert store.ids() == []
    assert store.add("b", "2026-09-07T00:00:00Z") is True
    assert store.add("b", "2026-09-07T00:00:01Z") is False
    assert store.add("a", "2026-09-07T00:00:02Z") is True
    store.save(path)
    loaded = walictl.Favorites.load(path)
    assert loaded.ids() == ["a", "b"]
    assert loaded.entries["b"] == {"added": "2026-09-07T00:00:00Z"}
    assert "b" in loaded and "zzz" not in loaded
    assert loaded.remove("b") is True
    assert loaded.remove("b") is False
    assert json.loads(path.read_text())["version"] == 1
    assert not list(tmp_path.glob("*.tmp"))


def test_favorites_rejects_corrupt_file(walictl: ModuleType, tmp_path: Path) -> None:
    path = tmp_path / "favorites.json"
    path.write_text("{not json")
    with pytest.raises(walictl.WalictlError, match="favorites file is not valid JSON"):
        walictl.Favorites.load(path)
    path.write_text('{"version": 9, "favorites": {}}')
    with pytest.raises(walictl.WalictlError, match="unsupported favorites version"):
        walictl.Favorites.load(path)
    path.write_text('{"version": 1, "favorites": {"a": null}}')
    with pytest.raises(walictl.WalictlError, match="malformed favorite entry: a"):
        walictl.Favorites.load(path)
    path.write_text('{"version": 1, "favorites": {"a": {"added": 5}}}')
    with pytest.raises(walictl.WalictlError, match="malformed favorite entry: a"):
        walictl.Favorites.load(path)


def test_locked_times_out_while_another_holder_exists(walictl: ModuleType, tmp_path: Path) -> None:
    import threading

    lock = tmp_path / "x.lock"
    acquired = threading.Event()
    release = threading.Event()

    def holder() -> None:
        with walictl.locked(lock):
            acquired.set()
            release.wait()

    thread = threading.Thread(target=holder)
    thread.start()
    acquired.wait()
    try:
        with pytest.raises(walictl.WalictlError, match="timed out waiting for"):
            with walictl.locked(lock, timeout=0.2):
                pass
    finally:
        release.set()
        thread.join()
    with walictl.locked(lock, timeout=0.2):
        pass


def test_utc_now_format(walictl: ModuleType) -> None:
    value = walictl.utc_now()
    assert value.endswith("Z") and len(value) == 20
    datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")


def test_favorites_lock_lives_in_state_dir(walictl: ModuleType, env: dict[str, Path]) -> None:
    assert walictl.favorites_lock() == env["state_home"] / "wali" / "favorites.lock"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: five new FAIL with `AttributeError`.

- [ ] **Step 3: Add the favorites section (add `import contextlib, fcntl, json, tempfile, time` and `from collections.abc import Iterator` at the top; also `from datetime import timezone`)**

```python
# --- shared helpers ---------------------------------------------------------


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


@contextlib.contextmanager
def locked(lock_path: Path, timeout: float = 10.0) -> Iterator[None]:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a", encoding="utf-8") as handle:
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError as exc:
                if time.monotonic() >= deadline:
                    raise WalictlError(f"timed out waiting for {lock_path}") from exc
                time.sleep(0.05)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def write_json_atomic(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(tmp_name, path)
    except BaseException:
        Path(tmp_name).unlink(missing_ok=True)
        raise


def read_json(path: Path, label: str) -> dict[str, object] | None:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise WalictlError(f"{label} is not valid JSON: {path}") from exc
    if not isinstance(payload, dict):
        raise WalictlError(f"{label} must be a JSON object: {path}")
    return payload


# --- favorites --------------------------------------------------------------

FAVORITES_VERSION = 1


def favorites_lock() -> Path:
    return state_dir() / "favorites.lock"


@dataclass
class Favorites:
    entries: dict[str, dict[str, str]]

    @classmethod
    def load(cls, path: Path) -> Favorites:
        payload = read_json(path, "favorites file")
        if payload is None:
            return cls(entries={})
        if payload.get("version") != FAVORITES_VERSION:
            raise WalictlError(f"unsupported favorites version in {path}: {payload.get('version')!r}")
        entries = payload.get("favorites")
        if not isinstance(entries, dict):
            raise WalictlError(f"favorites file has no favorites object: {path}")
        checked: dict[str, dict[str, str]] = {}
        for key, value in entries.items():
            if not isinstance(value, dict) or not isinstance(value.get("added"), str):
                raise WalictlError(f"malformed favorite entry: {key} in {path}")
            checked[str(key)] = {"added": value["added"]}
        return cls(entries=checked)

    def save(self, path: Path) -> None:
        write_json_atomic(path, {"version": FAVORITES_VERSION, "favorites": self.entries})

    def __contains__(self, photo_id: object) -> bool:
        return photo_id in self.entries

    def ids(self) -> list[str]:
        return sorted(self.entries)

    def add(self, photo_id: str, now: str) -> bool:
        if photo_id in self.entries:
            return False
        self.entries[photo_id] = {"added": now}
        return True

    def remove(self, photo_id: str) -> bool:
        return self.entries.pop(photo_id, None) is not None
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 32 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): favorites store keyed by photo id with a state-dir lock"
```

---

### Task 4: History store

**Files:**
- Modify: `bin/walictl` (add a section after favorites)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `read_json`, `write_json_atomic`, `state_dir`, `WalictlError`.
- Produces: `HISTORY_CAP = 1000`; `@dataclass HistoryEntry(ts: str, id: str, path: str, origin: str)`; `@dataclass History(entries: list[HistoryEntry], cursor: int)` with `load(path) -> History` (classmethod; missing file gives `History([], -1)`), `save(path)`, `current() -> HistoryEntry | None`, `at_end() -> bool`, `push(entry) -> None` (discard forward, append, cap, cursor to end), `recent_ids(count: int) -> set[str]` (ids of the `count` entries at or before the cursor); `history_path() -> Path`; `history_lock() -> Path`.

- [ ] **Step 1: Append the tests**

```python
def entry(walictl: ModuleType, photo: str, origin: str = "next") -> Any:
    return walictl.HistoryEntry(ts="2026-09-07T00:00:00Z", id=photo, path=f"/w/{photo}.jpg", origin=origin)


def test_history_missing_file_is_empty_state(walictl: ModuleType, tmp_path: Path) -> None:
    history = walictl.History.load(tmp_path / "missing" / "history.json")
    assert history.entries == [] and history.cursor == -1
    assert history.current() is None and history.at_end()


def test_history_corrupt_file_is_an_error(walictl: ModuleType, tmp_path: Path) -> None:
    path = tmp_path / "history.json"
    path.write_text("[]")
    with pytest.raises(walictl.WalictlError, match="must be a JSON object"):
        walictl.History.load(path)
    path.write_text('{"version": 2, "cursor": 0, "entries": []}')
    with pytest.raises(walictl.WalictlError, match="unsupported history version"):
        walictl.History.load(path)
    path.write_text('{"version": 1, "cursor": 3, "entries": []}')
    with pytest.raises(walictl.WalictlError, match="cursor out of range"):
        walictl.History.load(path)
    path.write_text('{"version": 1, "cursor": 0, "entries": [{"ts": "T", "id": "a", "origin": "next"}]}')
    with pytest.raises(walictl.WalictlError, match="malformed entry"):
        walictl.History.load(path)
    path.write_text('{"version": 1, "cursor": 0, "entries": [{"ts": "T", "id": 1, "path": "/p", "origin": "next"}]}')
    with pytest.raises(walictl.WalictlError, match="malformed entry"):
        walictl.History.load(path)
    assert path.read_text().startswith('{"version": 1')  # nothing overwrote it


def test_history_push_discards_forward_entries_and_round_trips(walictl: ModuleType, tmp_path: Path) -> None:
    path = tmp_path / "history.json"
    history = walictl.History.load(path)
    history.push(entry(walictl, "a", "observed"))
    history.push(entry(walictl, "b"))
    history.push(entry(walictl, "c", "random"))
    history.cursor = 0
    history.push(entry(walictl, "d"))
    assert [e.id for e in history.entries] == ["a", "d"]
    assert history.cursor == 1 and history.at_end()
    history.save(path)
    loaded = walictl.History.load(path)
    assert loaded == history
    assert json.loads(path.read_text())["version"] == 1


def test_history_cap_drops_oldest_and_shifts_cursor(walictl: ModuleType) -> None:
    history = walictl.History(entries=[], cursor=-1)
    for index in range(walictl.HISTORY_CAP + 5):
        history.push(entry(walictl, f"p{index}"))
    assert len(history.entries) == walictl.HISTORY_CAP
    assert history.entries[0].id == "p5"
    assert history.cursor == walictl.HISTORY_CAP - 1


def test_history_recent_ids_counts_back_from_cursor(walictl: ModuleType) -> None:
    history = walictl.History(entries=[entry(walictl, p) for p in "abcde"], cursor=2)
    assert history.recent_ids(2) == {"b", "c"}
    assert history.recent_ids(10) == {"a", "b", "c"}
    assert history.recent_ids(0) == set()
    assert history.current() is not None and history.current().id == "c"
    assert not history.at_end()


def test_history_paths_live_in_state_dir(walictl: ModuleType, env: dict[str, Path]) -> None:
    assert walictl.history_path() == env["state_home"] / "wali" / "history.json"
    assert walictl.history_lock() == env["state_home"] / "wali" / "history.lock"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: six new FAIL with `AttributeError`.

- [ ] **Step 3: Add the history section (add `from dataclasses import asdict, dataclass, field`)**

```python
# --- history ----------------------------------------------------------------

HISTORY_VERSION = 1
HISTORY_CAP = 1000
ORIGINS = ("next", "random", "observed")


def history_path() -> Path:
    return state_dir() / "history.json"


def history_lock() -> Path:
    return state_dir() / "history.lock"


@dataclass
class HistoryEntry:
    ts: str
    id: str
    path: str
    origin: str


@dataclass
class History:
    entries: list[HistoryEntry] = field(default_factory=list)
    cursor: int = -1

    @classmethod
    def load(cls, path: Path) -> History:
        payload = read_json(path, "history file")
        if payload is None:
            return cls()
        if payload.get("version") != HISTORY_VERSION:
            raise WalictlError(f"unsupported history version in {path}: {payload.get('version')!r}")
        raw_entries = payload.get("entries")
        cursor = payload.get("cursor")
        if not isinstance(raw_entries, list) or not isinstance(cursor, int):
            raise WalictlError(f"history file is malformed: {path}")
        entries: list[HistoryEntry] = []
        for raw in raw_entries:
            fields = ("ts", "id", "path", "origin")
            if (
                not isinstance(raw, dict)
                or any(not isinstance(raw.get(name), str) for name in fields)
                or raw["origin"] not in ORIGINS
            ):
                raise WalictlError(f"history file has a malformed entry: {path}")
            entries.append(HistoryEntry(raw["ts"], raw["id"], raw["path"], raw["origin"]))
        if not (-1 <= cursor < len(entries)) or (cursor == -1 and entries):
            raise WalictlError(f"history cursor out of range in {path}: {cursor}")
        return cls(entries=entries, cursor=cursor)

    def save(self, path: Path) -> None:
        write_json_atomic(
            path,
            {"version": HISTORY_VERSION, "cursor": self.cursor, "entries": [asdict(e) for e in self.entries]},
        )

    def current(self) -> HistoryEntry | None:
        return self.entries[self.cursor] if self.cursor >= 0 else None

    def at_end(self) -> bool:
        return self.cursor == len(self.entries) - 1

    def push(self, entry: HistoryEntry) -> None:
        del self.entries[self.cursor + 1 :]
        self.entries.append(entry)
        overflow = len(self.entries) - HISTORY_CAP
        if overflow > 0:
            del self.entries[:overflow]
        self.cursor = len(self.entries) - 1

    def recent_ids(self, count: int) -> set[str]:
        if count <= 0 or self.cursor < 0:
            return set()
        start = max(0, self.cursor + 1 - count)
        return {e.id for e in self.entries[start : self.cursor + 1]}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 38 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): browser-style history store with cursor, cap, and strict loading"
```

---

### Task 5: Noctalia IPC and reconcile

**Files:**
- Modify: `bin/walictl` (add a section after history)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `History`, `HistoryEntry`, `photo_id`, `utc_now`, `WalictlError`.
- Produces: `class Noctalia` with `get_default() -> Path` (real path of the bare `wallpaper-get` answer) and `set_default(path: Path) -> None` (raises on anything but `ok`); `reconcile(history: History, displayed: Path, now: str) -> bool` (True when an entry was appended).

- [ ] **Step 1: Append the tests**

```python
def test_noctalia_get_default_realpaths_the_answer(
    walictl: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    real = tmp_path / "real.jpg"
    real.touch()
    link = tmp_path / "link.jpg"
    link.symlink_to(real)
    fake = FakeNoctalia(link)
    monkeypatch.setattr(subprocess, "run", fake.run)
    assert walictl.Noctalia().get_default() == real.resolve()
    assert fake.calls == [["noctalia", "msg", "wallpaper-get"]]


def test_noctalia_get_default_fails_on_empty_answer(walictl: ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(subprocess, "run", FakeNoctalia(None).run)
    with pytest.raises(walictl.WalictlError, match="could not determine current wallpaper"):
        walictl.Noctalia().get_default()


def test_noctalia_errors_are_reported(walictl: ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    def missing(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError("noctalia")

    monkeypatch.setattr(subprocess, "run", missing)
    with pytest.raises(walictl.WalictlError, match="noctalia command not found"):
        walictl.Noctalia().get_default()
    fake = FakeNoctalia(Path("/w/a.jpg"), reject_set="path does not exist or is not a regular file")
    monkeypatch.setattr(subprocess, "run", fake.run)
    with pytest.raises(walictl.WalictlError, match="wallpaper-set rejected /w/b.jpg: error: path does not exist"):
        walictl.Noctalia().set_default(Path("/w/b.jpg"))
    assert fake.calls == [["noctalia", "msg", "wallpaper-set", "/w/b.jpg"]]


def test_reconcile_seeds_empty_history(walictl: ModuleType) -> None:
    history = walictl.History()
    assert walictl.reconcile(history, Path("/w/PXL_1.jpg"), "T") is True
    assert history.entries == [walictl.HistoryEntry("T", "PXL_1", "/w/PXL_1.jpg", "observed")]
    assert history.cursor == 0


def test_reconcile_is_a_noop_when_display_matches_cursor(walictl: ModuleType) -> None:
    history = walictl.History(entries=[entry(walictl, "a"), entry(walictl, "b")], cursor=0)
    assert walictl.reconcile(history, Path("/w/a.jpg"), "T") is False
    assert [e.id for e in history.entries] == ["a", "b"] and history.cursor == 0


def test_reconcile_records_external_change_and_discards_forward(walictl: ModuleType) -> None:
    history = walictl.History(entries=[entry(walictl, "a"), entry(walictl, "b")], cursor=0)
    assert walictl.reconcile(history, Path("/w/z.jpg"), "T") is True
    assert [(e.id, e.origin) for e in history.entries] == [("a", "next"), ("z", "observed")]
    assert history.cursor == 1
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: six new FAIL.

- [ ] **Step 3: Add the IPC and reconcile section (add `import subprocess`)**

```python
# --- noctalia ipc -----------------------------------------------------------


class Noctalia:
    def _msg(self, *args: str) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(["noctalia", "msg", *args], check=False, capture_output=True, text=True)
        except FileNotFoundError as exc:
            raise WalictlError("noctalia command not found") from exc

    def get_default(self) -> Path:
        result = self._msg("wallpaper-get")
        if result.returncode != 0:
            raise WalictlError(f"wallpaper-get failed: {(result.stderr or result.stdout).strip()}")
        line = next((text.strip() for text in result.stdout.splitlines() if text.strip()), "")
        if not line or line.startswith("error:"):
            raise WalictlError("could not determine current wallpaper")
        return Path(line).expanduser().resolve()

    def set_default(self, path: Path) -> None:
        result = self._msg("wallpaper-set", str(path))
        answer = (result.stdout or result.stderr).strip()
        if result.returncode != 0 or not answer.startswith("ok"):
            raise WalictlError(f"wallpaper-set rejected {path}: {answer or 'no answer'}")


def reconcile(history: History, displayed: Path, now: str) -> bool:
    current = history.current()
    if current is not None and Path(current.path) == displayed:
        return False
    history.push(HistoryEntry(ts=now, id=photo_id(displayed), path=str(displayed), origin="observed"))
    return True
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 44 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): noctalia ipc wrapper and history reconcile against the default wallpaper"
```

---

### Task 6: Weighted sampler

**Files:**
- Modify: `bin/walictl` (add a section after IPC)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `Sampling`, `capture_date`, `Favorites`.
- Produces: `weights(ids: list[str], favorites: Favorites, recent: set[str], sampling: Sampling) -> dict[str, float]`; `sample(weighted: dict[str, float], rng: random.Random, warn: Callable[[str], None]) -> str`.

- [ ] **Step 1: Append the tests**

```python
def favorites_of(walictl: ModuleType, *ids: str) -> Any:
    store = walictl.Favorites(entries={})
    for photo in ids:
        store.add(photo, "T")
    return store


def test_weights_zero_boosts_are_uniform_except_recent(walictl: ModuleType) -> None:
    ids = ["PXL_20210608_1", "PXL_20210609_1", "IMG_1"]
    sampling = walictl.Sampling(exclude_recent=1, favorite_boost=0.0, period_boost=0.0)
    result = walictl.weights(ids, favorites_of(walictl, "PXL_20210608_1"), {"IMG_1"}, sampling)
    assert result == {"PXL_20210608_1": 1.0, "PXL_20210609_1": 1.0, "IMG_1": 0.0}


def test_weights_apply_favorite_and_month_density(walictl: ModuleType) -> None:
    ids = ["PXL_20210608_1", "PXL_20210609_1", "PXL_20220402_1", "IMG_1"]
    sampling = walictl.Sampling(exclude_recent=0, favorite_boost=1.0, period_boost=3.0)
    result = walictl.weights(ids, favorites_of(walictl, "PXL_20210608_1"), set(), sampling)
    # June 2021 has 2 photos, 1 favorite: density 0.5, month factor 1 + 3 * 0.5 = 2.5
    assert result["PXL_20210608_1"] == pytest.approx(2.0 * 2.5)
    assert result["PXL_20210609_1"] == pytest.approx(2.5)
    assert result["PXL_20220402_1"] == pytest.approx(1.0)
    assert result["IMG_1"] == pytest.approx(1.0)


def test_sample_is_deterministic_and_honours_zero_weights(walictl: ModuleType) -> None:
    import random

    weighted = {"a": 0.0, "b": 1.0, "c": 3.0}
    warnings: list[str] = []
    picks = {walictl.sample(weighted, random.Random(seed), warnings.append) for seed in range(50)}
    assert picks == {"b", "c"}
    assert walictl.sample(weighted, random.Random(7), warnings.append) == walictl.sample(
        weighted, random.Random(7), warnings.append
    )
    assert warnings == []


def test_sample_falls_back_to_uniform_when_all_weights_are_zero(walictl: ModuleType) -> None:
    import random

    warnings: list[str] = []
    pick = walictl.sample({"a": 0.0, "b": 0.0}, random.Random(1), warnings.append)
    assert pick in {"a", "b"}
    assert warnings == ["every photo is excluded as recent; sampling uniformly"]


def test_sample_fails_on_empty_library(walictl: ModuleType) -> None:
    import random

    with pytest.raises(walictl.WalictlError, match="no wallpapers found"):
        walictl.sample({}, random.Random(1), lambda _: None)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: five new FAIL.

- [ ] **Step 3: Add the sampler section (add `import random`, `from collections import Counter`, `from collections.abc import Callable, Iterator`)**

```python
# --- sampler ----------------------------------------------------------------


def weights(ids: list[str], favorites: Favorites, recent: set[str], sampling: Sampling) -> dict[str, float]:
    months = {photo: capture_date(photo) for photo in ids}
    month_of = {photo: (d.year, d.month) for photo, d in months.items() if d is not None}
    photos_per_month = Counter(month_of.values())
    favorites_per_month = Counter(month for photo, month in month_of.items() if photo in favorites)
    result: dict[str, float] = {}
    for photo in ids:
        if photo in recent:
            result[photo] = 0.0
            continue
        weight = 1.0
        if photo in favorites:
            weight *= 1.0 + sampling.favorite_boost
        month = month_of.get(photo)
        if month is not None:
            density = favorites_per_month[month] / photos_per_month[month]
            weight *= 1.0 + sampling.period_boost * density
        result[photo] = weight
    return result


def sample(weighted: dict[str, float], rng: random.Random, warn: Callable[[str], None]) -> str:
    if not weighted:
        raise WalictlError("no wallpapers found")
    ids = list(weighted)
    values = [weighted[photo] for photo in ids]
    if sum(values) <= 0:
        warn("every photo is excluded as recent; sampling uniformly")
        return rng.choice(ids)
    return rng.choices(ids, weights=values, k=1)[0]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 49 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): weighted sampler with favorite and month-density boosts"
```

---

### Task 7: `current --json`

**Files:**
- Modify: `bin/walictl` (commands section, parser, main)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: everything above.
- Produces: `@dataclass Context(config: Config, noctalia: Noctalia, out: TextIO, err: TextIO)`; `describe(ctx: Context, displayed: Path, library: dict[str, Path], favorites: Favorites, history: History) -> dict[str, object]`; `cmd_current(ctx: Context, args: argparse.Namespace) -> int`; `main` dispatches through a `COMMANDS: dict[str, Callable[[Context, argparse.Namespace], int]]` table.

The JSON contract (spec "CLI"): `ok`, `id`, `date`, `display_date`, `path`, `source_path`, `variant_path`, `favorite`, `history: {cursor, length}`. `cursor` is `null` when history is empty.

- [ ] **Step 1: Append the tests**

```python
def test_current_json_contract(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    store = walictl.Favorites(entries={})
    store.add("PXL_20210608_111152739", "2026-09-07T00:00:00Z")
    store.save(env["favorites"])
    code, stdout, stderr = run_cli(walictl, ["current", "--json"])
    assert (code, stderr) == (0, "")
    payload = json.loads(stdout)
    assert payload == {
        "ok": True,
        "id": "PXL_20210608_111152739",
        "date": "2021-06-08",
        "display_date": "June 8, 2021",
        "path": str(env["wallpapers"] / "PXL_20210608_111152739.jpg"),
        "source_path": str(env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"),
        "variant_path": None,
        "favorite": True,
        "history": {"cursor": None, "length": 0},
    }


def test_current_json_nulls_for_undated_unfavorited_photo(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    undated = env["wallpapers"] / "IMG_20200525_124754.jpg"
    undated.touch()
    noctalia.default = undated
    code, stdout, _ = run_cli(walictl, ["current", "--json"])
    payload = json.loads(stdout)
    assert code == 0
    assert payload["id"] == "IMG_20200525_124754"
    assert payload["date"] is None and payload["display_date"] is None
    assert payload["source_path"] is None and payload["favorite"] is False


def test_current_reports_history_position(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    history = walictl.History()
    history.push(entry(walictl, "x", "observed"))
    history.push(entry(walictl, "y"))
    history.cursor = 0
    history.save(walictl.history_path())
    payload = json.loads(run_cli(walictl, ["current", "--json"])[1])
    assert payload["history"] == {"cursor": 0, "length": 2}


def test_current_requires_json_flag(walictl: ModuleType, env: dict[str, Path]) -> None:
    code, stdout, stderr = run_cli(walictl, ["current"])
    assert (code, stdout) == (2, "")
    assert "--json" in stderr


def test_script_runs_as_a_subprocess() -> None:
    result = subprocess.run([sys.executable, str(SCRIPT), "current"], capture_output=True, text=True, check=False)
    assert result.returncode == 2 and "--json" in result.stderr


def test_current_reports_ipc_failure(walictl: ModuleType, env: dict[str, Path], monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(subprocess, "run", FakeNoctalia(None).run)
    code, stdout, stderr = run_cli(walictl, ["current", "--json"])
    assert (code, stdout, stderr) == (1, "", "could not determine current wallpaper\n")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: six new FAIL (`command not implemented`; the smoke test fails on the stub's error path).

- [ ] **Step 3: Replace the parser/main section with the commands section, parser, and dispatch (add `from typing import TextIO`)**

```python
# --- commands ---------------------------------------------------------------


@dataclass
class Context:
    config: Config
    noctalia: Noctalia
    out: TextIO
    err: TextIO


def describe(
    ctx: Context, displayed: Path, library: dict[str, Path], favorites: Favorites, history: History
) -> dict[str, object]:
    photo = photo_id(displayed)
    taken = capture_date(photo)
    source = resolve_source(ctx.config, photo)
    variant = resolve_variant(ctx.config, photo)
    return {
        "ok": True,
        "id": photo,
        "date": taken.isoformat() if taken else None,
        "display_date": display_date(taken),
        "path": str(displayed),
        "source_path": str(source) if source else None,
        "variant_path": str(variant) if variant else None,
        "favorite": photo in favorites,
        "history": {"cursor": history.cursor if history.cursor >= 0 else None, "length": len(history.entries)},
    }


def cmd_current(ctx: Context, args: argparse.Namespace) -> int:
    displayed = ctx.noctalia.get_default()
    library = scan_library(ctx.config.wallpaper_dir)
    favorites = Favorites.load(ctx.config.favorites_file)
    history = History.load(history_path())
    json.dump(describe(ctx, displayed, library, favorites, history), ctx.out)
    ctx.out.write("\n")
    return 0


COMMANDS: dict[str, Callable[[Context, argparse.Namespace], int]] = {
    "current": cmd_current,
}


# --- parser and main --------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="walictl")
    subparsers = parser.add_subparsers(dest="command", required=True)
    current = subparsers.add_parser("current", help="describe the default wallpaper")
    current.add_argument("--json", action="store_true", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        ctx = Context(config=load_config(config_path()), noctalia=Noctalia(), out=sys.stdout, err=sys.stderr)
        return COMMANDS[args.command](ctx, args)
    except WalictlError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
```

The `__main__` guard must survive every later edit of this section; the smoke test below runs the script as a subprocess to prove it.

`library` is unused by `describe` in this task and is passed so that Task 9's `favorites --json` and Task 8's navigation share the signature; keep the parameter.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 55 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): current --json reports id, date, paths, favorite state, and history position"
```

---

### Task 8: `next`, `previous`, `random`, `observe`

**Files:**
- Modify: `bin/walictl` (commands, parser)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `locked`, `history_lock`, `reconcile`, `weights`, `sample`, `display_path`, `Noctalia`.
- Produces: `replay_path(config: Config, entry: HistoryEntry) -> Path` (a variant created since the entry was recorded wins over the stored path); `navigate(ctx: Context, action: str, rng: random.Random) -> str` (returns the id now selected; `action` in `next`, `previous`, `random`, `observe`); commands `cmd_next`, `cmd_previous`, `cmd_random`, `cmd_observe`; parser options `--seed INT` on `next` and `random`.

Output lines: `next: <id>`, `previous: <id>`, `random: <id>`, and for observe either `recorded <id>` or `unchanged <id>`.

- [ ] **Step 1: Append the tests**

```python
def load_history(walictl: ModuleType) -> Any:
    return walictl.History.load(walictl.history_path())


def test_random_seeds_history_then_samples_and_commits_after_ok(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    code, stdout, stderr = run_cli(walictl, ["random", "--seed", "3"])
    assert (code, stderr) == (0, "")
    history = load_history(walictl)
    assert [e.origin for e in history.entries] == ["observed", "random"]
    assert history.entries[0].id == "PXL_20210608_111152739"
    assert history.entries[1].id != "PXL_20210608_111152739"  # recent exclusion
    assert stdout == f"random: {history.entries[1].id}\n"
    assert noctalia.calls[-1] == ["noctalia", "msg", "wallpaper-set", history.entries[1].path]
    assert noctalia.default == Path(history.entries[1].path)


def test_previous_restores_the_seeded_wallpaper_and_next_moves_forward(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    run_cli(walictl, ["random", "--seed", "3"])
    picked = load_history(walictl).entries[1].id
    code, stdout, _ = run_cli(walictl, ["previous"])
    assert (code, stdout) == (0, "previous: PXL_20210608_111152739\n")
    assert noctalia.default == env["wallpapers"] / "PXL_20210608_111152739.jpg"
    assert load_history(walictl).cursor == 0
    code, stdout, _ = run_cli(walictl, ["next"])
    assert (code, stdout) == (0, f"next: {picked}\n")
    assert load_history(walictl).cursor == 1
    assert len(load_history(walictl).entries) == 2  # forward move, no new entry


def test_previous_at_front_fails(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    code, stdout, stderr = run_cli(walictl, ["previous"])
    assert (code, stdout, stderr) == (1, "", "already at the oldest wallpaper in history\n")
    assert load_history(walictl).cursor == 0  # reconcile still seeded


def test_next_at_end_samples(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    run_cli(walictl, ["next", "--seed", "1"])
    history = load_history(walictl)
    assert [e.origin for e in history.entries] == ["observed", "next"]
    assert history.cursor == 1


def test_random_mid_history_discards_forward_entries(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    run_cli(walictl, ["random", "--seed", "3"])
    run_cli(walictl, ["previous"])
    run_cli(walictl, ["random", "--seed", "5"])
    history = load_history(walictl)
    assert len(history.entries) == 2 and history.cursor == 1
    assert history.entries[1].origin == "random"


def test_rejected_set_leaves_history_as_reconcile_left_it(
    walictl: ModuleType, env: dict[str, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    fake = FakeNoctalia(env["wallpapers"] / "PXL_20210608_111152739.jpg", reject_set="boom")
    monkeypatch.setattr(subprocess, "run", fake.run)
    code, stdout, stderr = run_cli(walictl, ["random", "--seed", "3"])
    assert code == 1 and stdout == ""
    assert stderr.startswith("wallpaper-set rejected ")
    history = load_history(walictl)
    assert [e.origin for e in history.entries] == ["observed"] and history.cursor == 0


def test_observe_records_external_change_and_repeats_are_noops(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    assert run_cli(walictl, ["observe"])[1] == "recorded PXL_20210608_111152739\n"
    assert run_cli(walictl, ["observe"])[1] == "unchanged PXL_20210608_111152739\n"
    noctalia.default = env["wallpapers"] / "PXL_20220402_162957459.jpg"  # native panel change
    assert run_cli(walictl, ["observe"])[1] == "recorded PXL_20220402_162957459\n"
    history = load_history(walictl)
    assert [(e.id, e.origin) for e in history.entries] == [
        ("PXL_20210608_111152739", "observed"),
        ("PXL_20220402_162957459", "observed"),
    ]
    assert noctalia.calls.count(["noctalia", "msg", "wallpaper-get"]) == 3


def test_stale_observe_after_previous_is_a_noop(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    run_cli(walictl, ["random", "--seed", "3"])
    run_cli(walictl, ["previous"])
    # the hook for the random pick fires late; the display already shows the seeded wallpaper
    code, stdout, _ = run_cli(walictl, ["observe"])
    assert (code, stdout) == (0, "unchanged PXL_20210608_111152739\n")
    assert len(load_history(walictl).entries) == 2


def test_navigation_holds_the_history_lock(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    import threading

    release = threading.Event()
    taken = threading.Event()

    def holder() -> None:
        with walictl.locked(walictl.history_lock()):
            taken.set()
            release.wait()

    thread = threading.Thread(target=holder)
    thread.start()
    taken.wait()
    try:
        walictl_fast = load_walictl()
        monkey_timeout = walictl_fast.locked

        def short_lock(path: Path, timeout: float = 10.0) -> Any:
            return monkey_timeout(path, timeout=0.2)

        walictl_fast.locked = short_lock  # type: ignore[assignment]
        code, _, stderr = run_cli(walictl_fast, ["observe"])
        assert code == 1 and stderr.startswith("timed out waiting for")
    finally:
        release.set()
        thread.join()


def test_symlinked_wallpaper_dir_does_not_duplicate_history(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    link = env["wallpapers"].parent / "link"
    link.symlink_to(env["wallpapers"])
    config = env["config_home"] / "wali" / "config.toml"
    config.write_text(config.read_text().replace(str(env["wallpapers"]), str(link)))
    run_cli(walictl, ["random", "--seed", "3"])
    code, stdout, _ = run_cli(walictl, ["previous"])
    assert (code, stdout) == (0, "previous: PXL_20210608_111152739\n")
    history = load_history(walictl)
    assert [e.id for e in history.entries][0] == "PXL_20210608_111152739" and len(history.entries) == 2
    assert all(str(env["wallpapers"]) in e.path for e in history.entries)


def test_replay_prefers_a_variant_created_later(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, tmp_path: Path
) -> None:
    variants = tmp_path / "edits"
    variants.mkdir()
    (env["config_home"] / "wali" / "config.toml").write_text(
        (env["config_home"] / "wali" / "config.toml").read_text() + f'variants_dir = "{variants}"\n'
    )
    run_cli(walictl, ["random", "--seed", "3"])
    variant = variants / "PXL_20210608_111152739.png"
    variant.touch()
    code, stdout, _ = run_cli(walictl, ["previous"])
    assert (code, stdout) == (0, "previous: PXL_20210608_111152739\n")
    assert noctalia.default == variant.resolve()
    assert load_history(walictl).entries[0].path == str(variant.resolve())


def test_sampling_prefers_variant_file(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, tmp_path: Path) -> None:
    variants = tmp_path / "edits"
    variants.mkdir()
    for stem in ("PXL_20210609_120000000", "PXL_20220402_162957459"):
        (variants / f"{stem}.png").touch()
    (env["config_home"] / "wali" / "config.toml").write_text(
        (env["config_home"] / "wali" / "config.toml").read_text() + f'variants_dir = "{variants}"\n'
    )
    run_cli(walictl, ["random", "--seed", "3"])
    picked = load_history(walictl).entries[1]
    assert Path(picked.path).parent == variants
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: twelve new FAIL (argparse rejects unknown commands with exit 2, or `KeyError`).

- [ ] **Step 3: Add navigation to the commands section and register the commands**

```python
def replay_path(config: Config, entry: HistoryEntry) -> Path:
    """Where a history entry should be displayed now: a variant wins over the stored path."""
    return resolve_variant(config, entry.id) or Path(entry.path)


def navigate(ctx: Context, action: str, rng: random.Random) -> str:
    """Reconcile, navigate, commit. Runs entirely under the history lock."""
    with locked(history_lock()):
        history = History.load(history_path())
        displayed = ctx.noctalia.get_default()
        changed = reconcile(history, displayed, utc_now())
        if changed:
            history.save(history_path())
        current = history.current()
        assert current is not None
        if action == "observe":
            ctx.out.write(f"{'recorded' if changed else 'unchanged'} {current.id}\n")
            return current.id

        if action == "previous":
            if history.cursor == 0:
                raise WalictlError("already at the oldest wallpaper in history")
            target = history.entries[history.cursor - 1]
            path = replay_path(ctx.config, target)
            ctx.noctalia.set_default(path)
            target.path = str(path)  # keep reconcile matching what is now displayed
            history.cursor -= 1
        elif action == "next" and not history.at_end():
            target = history.entries[history.cursor + 1]
            path = replay_path(ctx.config, target)
            ctx.noctalia.set_default(path)
            target.path = str(path)
            history.cursor += 1
        else:
            library = scan_library(ctx.config.wallpaper_dir)
            favorites = Favorites.load(ctx.config.favorites_file)
            weighted = weights(list(library), favorites, history.recent_ids(ctx.config.sampling.exclude_recent), ctx.config.sampling)
            picked = sample(weighted, rng, lambda message: print(message, file=ctx.err))
            path = display_path(ctx.config, library, picked)
            ctx.noctalia.set_default(path)
            history.push(HistoryEntry(ts=utc_now(), id=picked, path=str(path), origin=action))
        history.save(history_path())
        selected = history.current()
        assert selected is not None
        ctx.out.write(f"{action}: {selected.id}\n")
        return selected.id


def _rng(args: argparse.Namespace) -> random.Random:
    seed = getattr(args, "seed", None)
    return random.Random(seed) if seed is not None else random.Random()


def cmd_next(ctx: Context, args: argparse.Namespace) -> int:
    navigate(ctx, "next", _rng(args))
    return 0


def cmd_previous(ctx: Context, args: argparse.Namespace) -> int:
    navigate(ctx, "previous", _rng(args))
    return 0


def cmd_random(ctx: Context, args: argparse.Namespace) -> int:
    navigate(ctx, "random", _rng(args))
    return 0


def cmd_observe(ctx: Context, args: argparse.Namespace) -> int:
    navigate(ctx, "observe", _rng(args))
    return 0
```

Register them:

```python
COMMANDS: dict[str, Callable[[Context, argparse.Namespace], int]] = {
    "current": cmd_current,
    "next": cmd_next,
    "previous": cmd_previous,
    "random": cmd_random,
    "observe": cmd_observe,
}
```

And extend `build_parser()`:

```python
    for name, help_text in (
        ("next", "forward in history, else a weighted sample"),
        ("random", "a weighted sample, discarding forward history"),
    ):
        sub = subparsers.add_parser(name, help=help_text)
        sub.add_argument("--seed", type=int, default=None, help="seed the sampler (tests)")
    subparsers.add_parser("previous", help="back one entry in history")
    subparsers.add_parser("observe", help="record a wallpaper change made outside walictl (hook entry point)")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 67 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): next, previous, random, and observe over reconciled history"
```

---

### Task 9: `favorite`, `favorites --json`, `neighbors --json`, `edit`

**Files:**
- Modify: `bin/walictl` (commands, parser)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `Favorites`, `favorites_lock`, `locked`, `scan_library`, `resolve_source`, `display_path`.
- Produces: `cmd_favorite` (`--add`/`--remove` mutually exclusive, optional positional `photo_id`; prints `favorited <id>` or `unfavorited <id>`); `cmd_favorites` (`--json`; `{"ok": true, "favorites": [{"id", "added", "path", "source_path", "exists"}]}` sorted by id); `cmd_neighbors` (`--json`, `--count N` default 3; `{"ok": true, "id", "before": [...], "after": [...]}` with `{"id", "date", "path"}` items ordered by capture date then id); `cmd_edit` (prints `opened <path>`; launches `gimp` detached via `subprocess.Popen(..., start_new_session=True)`).

- [ ] **Step 1: Append the tests**

```python
def test_favorite_toggles_current_and_explicit_ids(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    assert run_cli(walictl, ["favorite"])[1] == "favorited PXL_20210608_111152739\n"
    assert run_cli(walictl, ["favorite"])[1] == "unfavorited PXL_20210608_111152739\n"
    assert run_cli(walictl, ["favorite", "--add", "PXL_20220402_162957459"])[1] == "favorited PXL_20220402_162957459\n"
    assert run_cli(walictl, ["favorite", "--add", "PXL_20220402_162957459"])[1] == "favorited PXL_20220402_162957459\n"
    assert run_cli(walictl, ["favorite", "--remove", "PXL_20220402_162957459"])[1] == "unfavorited PXL_20220402_162957459\n"
    assert walictl.Favorites.load(env["favorites"]).ids() == []
    code, _, stderr = run_cli(walictl, ["favorite", "--add", "nope"])
    assert (code, stderr) == (1, "unknown photo id: nope\n")
    code, _, stderr = run_cli(walictl, ["favorite", "nope"])
    assert (code, stderr) == (1, "unknown photo id: nope\n")
    assert run_cli(walictl, ["favorite", "--add", "--remove", "x"])[0] == 2


def test_favorite_can_remove_an_id_whose_file_is_missing(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    store = walictl.Favorites(entries={})
    store.add("PXL_20210919_170859013", "T")
    store.save(env["favorites"])
    assert run_cli(walictl, ["favorite", "--remove", "PXL_20210919_170859013"])[1] == "unfavorited PXL_20210919_170859013\n"
    store.add("PXL_20210919_170859013", "T")
    store.save(env["favorites"])
    assert run_cli(walictl, ["favorite", "PXL_20210919_170859013"])[1] == "unfavorited PXL_20210919_170859013\n"
    assert walictl.Favorites.load(env["favorites"]).ids() == []


def test_favorite_concurrent_additions_both_land(walictl: ModuleType, env: dict[str, Path]) -> None:
    import threading

    def add(photo: str) -> None:
        run_cli(load_walictl(), ["favorite", "--add", photo])

    threads = [threading.Thread(target=add, args=(p,)) for p in ("PXL_20210608_111152739", "PXL_20210609_120000000")]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert walictl.Favorites.load(env["favorites"]).ids() == ["PXL_20210608_111152739", "PXL_20210609_120000000"]


def test_favorites_json_lists_paths_and_existence(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, tmp_path: Path
) -> None:
    store = walictl.Favorites(entries={})
    store.add("PXL_20210608_111152739", "T1")
    store.add("PXL_20210919_170859013", "T2")  # no display file
    store.add("PXL_20210609_120000000", "T3")  # has a variant
    store.save(env["favorites"])
    variants = tmp_path / "edits"
    variants.mkdir()
    (variants / "PXL_20210609_120000000.png").touch()
    (env["config_home"] / "wali" / "config.toml").write_text(
        (env["config_home"] / "wali" / "config.toml").read_text() + f'variants_dir = "{variants}"\n'
    )
    code, stdout, _ = run_cli(walictl, ["favorites", "--json"])
    assert code == 0
    assert json.loads(stdout) == {
        "ok": True,
        "favorites": [
            {
                "id": "PXL_20210608_111152739",
                "added": "T1",
                "path": str(env["wallpapers"] / "PXL_20210608_111152739.jpg"),
                "source_path": str(env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"),
                "exists": True,
            },
            {
                "id": "PXL_20210609_120000000",
                "added": "T3",
                "path": str((variants / "PXL_20210609_120000000.png").resolve()),
                "source_path": None,
                "exists": True,
            },
            {"id": "PXL_20210919_170859013", "added": "T2", "path": None, "source_path": None, "exists": False},
        ],
    }


def test_neighbors_json_orders_by_capture_date(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    (env["wallpapers"] / "PXL_20210531_235959000.jpg").touch()
    (env["wallpapers"] / "IMG_undated.jpg").touch()
    noctalia.default = env["wallpapers"] / "PXL_20210609_120000000.jpg"
    code, stdout, _ = run_cli(walictl, ["neighbors", "--json", "--count", "1"])
    assert code == 0
    payload = json.loads(stdout)
    assert payload["id"] == "PXL_20210609_120000000"
    assert [n["id"] for n in payload["before"]] == ["PXL_20210608_111152739"]
    assert [n["id"] for n in payload["after"]] == ["PXL_20220402_162957459"]
    assert payload["after"][0] == {
        "id": "PXL_20220402_162957459",
        "date": "2022-04-02",
        "path": str(env["wallpapers"] / "PXL_20220402_162957459.jpg"),
    }
    payload = json.loads(run_cli(walictl, ["neighbors", "--json"])[1])
    assert [n["id"] for n in payload["before"]] == ["PXL_20210531_235959000", "PXL_20210608_111152739"]


def test_neighbors_fails_for_undated_current(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia) -> None:
    undated = env["wallpapers"] / "IMG_1.jpg"
    undated.touch()
    noctalia.default = undated
    code, _, stderr = run_cli(walictl, ["neighbors", "--json"])
    assert (code, stderr) == (1, "current wallpaper has no capture date: IMG_1\n")


def test_edit_opens_source_when_present_else_display_file(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, monkeypatch: pytest.MonkeyPatch
) -> None:
    launched: list[tuple[list[str], dict[str, Any]]] = []

    class FakePopen:
        def __init__(self, args: list[str], **kwargs: Any) -> None:
            launched.append((list(args), kwargs))

    monkeypatch.setattr(subprocess, "Popen", FakePopen)
    source = env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"
    assert run_cli(walictl, ["edit"])[1] == f"opened {source}\n"
    noctalia.default = env["wallpapers"] / "PXL_20210609_120000000.jpg"
    assert run_cli(walictl, ["edit"])[1] == f"opened {noctalia.default}\n"
    assert [args for args, _ in launched] == [["gimp", str(source)], ["gimp", str(noctalia.default)]]
    assert all(kwargs == {"start_new_session": True} for _, kwargs in launched)


def test_edit_reports_missing_gimp(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, monkeypatch: pytest.MonkeyPatch) -> None:
    def missing(*args: Any, **kwargs: Any) -> None:
        raise FileNotFoundError("gimp")

    monkeypatch.setattr(subprocess, "Popen", missing)
    assert run_cli(walictl, ["edit"]) == (1, "", "gimp command not found\n")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: eight new FAIL.

- [ ] **Step 3: Add the commands**

```python
def _current_id(ctx: Context) -> str:
    return photo_id(ctx.noctalia.get_default())


def cmd_favorite(ctx: Context, args: argparse.Namespace) -> int:
    photo = args.photo_id or _current_id(ctx)
    with locked(favorites_lock()):
        store = Favorites.load(ctx.config.favorites_file)
        removing = args.remove or (not args.add and photo in store)
        if removing:
            # Removal never needs the file: an imported favorite whose photo is gone must stay removable.
            store.remove(photo)
            state = "unfavorited"
        else:
            if photo not in scan_library(ctx.config.wallpaper_dir):
                raise WalictlError(f"unknown photo id: {photo}")
            store.add(photo, utc_now())
            state = "favorited"
        store.save(ctx.config.favorites_file)
    ctx.out.write(f"{state} {photo}\n")
    return 0


def cmd_favorites(ctx: Context, args: argparse.Namespace) -> int:
    library = scan_library(ctx.config.wallpaper_dir)
    store = Favorites.load(ctx.config.favorites_file)
    items = []
    for photo in store.ids():
        path = resolve_variant(ctx.config, photo) or library.get(photo)
        source = resolve_source(ctx.config, photo)
        items.append({
            "id": photo,
            "added": store.entries[photo].get("added"),
            "path": str(path) if path else None,
            "source_path": str(source) if source else None,
            "exists": path is not None,
        })
    json.dump({"ok": True, "favorites": items}, ctx.out)
    ctx.out.write("\n")
    return 0


def cmd_neighbors(ctx: Context, args: argparse.Namespace) -> int:
    photo = _current_id(ctx)
    taken = capture_date(photo)
    if taken is None:
        raise WalictlError(f"current wallpaper has no capture date: {photo}")
    library = scan_library(ctx.config.wallpaper_dir)
    dated: list[tuple[date, str]] = []
    for candidate in library:
        candidate_date = capture_date(candidate)
        if candidate_date is not None:
            dated.append((candidate_date, candidate))
    dated.sort()
    ordered = [p for _, p in dated]
    if photo not in ordered:
        raise WalictlError(f"current wallpaper is not in the library: {photo}")
    index = ordered.index(photo)

    def item(p: str) -> dict[str, object]:
        d = capture_date(p)
        return {"id": p, "date": d.isoformat() if d else None, "path": str(library[p])}

    payload = {
        "ok": True,
        "id": photo,
        "before": [item(p) for p in ordered[max(0, index - args.count) : index]],
        "after": [item(p) for p in ordered[index + 1 : index + 1 + args.count]],
    }
    json.dump(payload, ctx.out)
    ctx.out.write("\n")
    return 0


def cmd_edit(ctx: Context, args: argparse.Namespace) -> int:
    displayed = ctx.noctalia.get_default()
    target = resolve_source(ctx.config, photo_id(displayed)) or displayed
    try:
        subprocess.Popen(["gimp", str(target)], start_new_session=True)
    except FileNotFoundError as exc:
        raise WalictlError("gimp command not found") from exc
    ctx.out.write(f"opened {target}\n")
    return 0
```

Register in `COMMANDS` (`"favorite": cmd_favorite, "favorites": cmd_favorites, "neighbors": cmd_neighbors, "edit": cmd_edit`) and extend `build_parser()`:

```python
    favorite = subparsers.add_parser("favorite", help="toggle (or --add/--remove) a favorite; default is the current photo")
    mode = favorite.add_mutually_exclusive_group()
    mode.add_argument("--add", action="store_true")
    mode.add_argument("--remove", action="store_true")
    favorite.add_argument("photo_id", nargs="?", default=None)
    favorites = subparsers.add_parser("favorites", help="list favorites")
    favorites.add_argument("--json", action="store_true", required=True)
    neighbors = subparsers.add_parser("neighbors", help="capture-time neighbours of the current photo")
    neighbors.add_argument("--json", action="store_true", required=True)
    neighbors.add_argument("--count", type=int, default=3)
    subparsers.add_parser("edit", help="open the original (or the display file) in GIMP")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 75 passed.

- [ ] **Step 5: Lint, type-check, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): favorite toggle, favorites and neighbors listings, detached edit"
```

---

### Task 10: `import-favorites`

**Files:**
- Modify: `bin/walictl` (commands, parser)
- Modify: `tests/bin/test_walictl.py` (append)

**Interfaces:**
- Consumes: `Favorites`, `favorites_lock`, `scan_library`.
- Produces: `cmd_import_favorites` (positional `source`, `--force`). Report on stdout, one item per line:

```
lines: 685
unique: 644
duplicate occurrences: 41
dangling paths: 2
  /mnt/.../PXL_x.jpg
missing display files: 1
  PXL_20210919_170859013
wrote <favorites_file>
```

- [ ] **Step 1: Append the tests**

```python
def test_import_favorites_dedupes_and_reports(walictl: ModuleType, env: dict[str, Path], tmp_path: Path) -> None:
    existing = env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"
    dangling = env["archive"] / "2021" / "06" / "PXL_20210630_000000000.jpg"
    source = tmp_path / "favorites.txt"
    source.write_text(f"{existing}\n{existing}\n\n{dangling}\n{env['wallpapers'] / 'PXL_20210609_120000000.jpg'}\n{existing}\n")
    code, stdout, stderr = run_cli(walictl, ["import-favorites", str(source)])
    assert (code, stderr) == (0, "")
    assert stdout == (
        "lines: 5\nunique: 3\nduplicate occurrences: 2\n"
        f"dangling paths: 1\n  {dangling}\n"
        "missing display files: 1\n  PXL_20210630_000000000\n"
        f"wrote {env['favorites']}\n"
    )
    store = walictl.Favorites.load(env["favorites"])
    assert store.ids() == ["PXL_20210608_111152739", "PXL_20210609_120000000", "PXL_20210630_000000000"]
    assert all(set(v) == {"added"} for v in store.entries.values())


def test_import_favorites_refuses_to_overwrite_without_force(
    walictl: ModuleType, env: dict[str, Path], tmp_path: Path
) -> None:
    env["favorites"].write_text('{"version": 1, "favorites": {}}')
    source = tmp_path / "favorites.txt"
    source.write_text("x.jpg\n")
    code, _, stderr = run_cli(walictl, ["import-favorites", str(source)])
    assert (code, stderr) == (1, f"favorites file already exists (use --force): {env['favorites']}\n")
    assert run_cli(walictl, ["import-favorites", "--force", str(source)])[0] == 0
    assert walictl.Favorites.load(env["favorites"]).ids() == ["x"]


def test_import_favorites_refuses_a_store_created_while_waiting_for_the_lock(
    walictl: ModuleType, env: dict[str, Path], tmp_path: Path
) -> None:
    source = tmp_path / "favorites.txt"
    source.write_text("x.jpg\n")
    real_locked = walictl.locked

    def locked_then_racer(path: Path, timeout: float = 10.0) -> Any:
        # Another command finished its write just before we acquired the lock.
        env["favorites"].write_text('{"version": 1, "favorites": {"other": {"added": "T"}}}')
        return real_locked(path, timeout=timeout)

    walictl.locked = locked_then_racer  # type: ignore[assignment]
    code, _, stderr = run_cli(walictl, ["import-favorites", str(source)])
    assert (code, stderr) == (1, f"favorites file already exists (use --force): {env['favorites']}\n")
    assert walictl.Favorites.load(env["favorites"]).ids() == ["other"]


def test_import_favorites_fails_on_missing_source(walictl: ModuleType, env: dict[str, Path], tmp_path: Path) -> None:
    code, _, stderr = run_cli(walictl, ["import-favorites", str(tmp_path / "nope.txt")])
    assert (code, stderr) == (1, f"favorites source not found: {tmp_path / 'nope.txt'}\n")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: four new FAIL.

- [ ] **Step 3: Add the command**

```python
def cmd_import_favorites(ctx: Context, args: argparse.Namespace) -> int:
    source = Path(args.source)
    try:
        lines = [line.strip() for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
    except FileNotFoundError as exc:
        raise WalictlError(f"favorites source not found: {source}") from exc
    library = scan_library(ctx.config.wallpaper_dir)
    ids = [photo_id(Path(line)) for line in lines]
    unique_ids = sorted(set(ids))
    dangling = sorted({line for line in lines if not Path(line).expanduser().exists()})
    missing = [photo for photo in unique_ids if photo not in library]
    now = utc_now()
    with locked(favorites_lock()):
        # Checked under the lock: a favorite written while we waited must not be replaced.
        if ctx.config.favorites_file.exists() and not args.force:
            raise WalictlError(f"favorites file already exists (use --force): {ctx.config.favorites_file}")
        store = Favorites(entries={})
        for photo in unique_ids:
            store.add(photo, now)
        store.save(ctx.config.favorites_file)
    ctx.out.write(f"lines: {len(lines)}\nunique: {len(unique_ids)}\n")
    ctx.out.write(f"duplicate occurrences: {len(ids) - len(unique_ids)}\n")
    ctx.out.write(f"dangling paths: {len(dangling)}\n")
    for line in dangling:
        ctx.out.write(f"  {line}\n")
    ctx.out.write(f"missing display files: {len(missing)}\n")
    for photo in missing:
        ctx.out.write(f"  {photo}\n")
    ctx.out.write(f"wrote {ctx.config.favorites_file}\n")
    return 0
```

Register `"import-favorites": cmd_import_favorites` and add to the parser:

```python
    importer = subparsers.add_parser("import-favorites", help="build favorites.json from the legacy favorites.txt")
    importer.add_argument("source")
    importer.add_argument("--force", action="store_true")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --frozen pytest -q tests/bin/test_walictl.py`
Expected: 79 passed.

- [ ] **Step 5: Lint, type-check, run the whole suite, commit**

```bash
uv run --frozen ruff check bin/walictl tests/bin/test_walictl.py && uv run --frozen pyright
just test
git add bin/walictl tests/bin/test_walictl.py
git commit -m "feat(walictl): import legacy favorites.txt with a dedupe and dangling report"
```

`just test` will fail at this point in `tests/wali.zsh` (it calls `wali_print`, untouched until Task 15) and in `plugin_test.lua` (old command names, Task 14). That is expected; confirm the pytest and setup/health parts pass and commit.

---

### Task 11: Per-host config files, setup link, health check

**Files:**
- Create: `wali/titan/config.toml`, `wali/europa/config.toml`
- Modify: `setup.sh` (`setup_graphical_config_links`, after the prism block around line 411)
- Modify: `bin/dotfiles-health` (after the prism block ending around line 344)
- Modify: `tests/setup_and_health.zsh` (new tests appended before the final `print`)

**Interfaces:**
- Produces: `$XDG_CONFIG_HOME/wali/config.toml` as a symlink to `${DOTS_HOME}/wali/$(hostname)/config.toml`.

- [ ] **Step 1: Write the failing setup test**

Append to `tests/setup_and_health.zsh` before the trailing `print -- "setup and health tests passed"` (register it in the call list at the bottom, next to `test_setup_graphical_config_hands_material_ownership_to_prism`):

```zsh
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
```

Update the existing titan health fixtures too. Append these lines to `configure_prism_runtime`, so its success and doctor-failure tests have the newly required Wali link:

```zsh
  mkdir -p "${tmp}/config/wali"
  ln -s "${repo_root}/wali/titan/config.toml" "${tmp}/config/wali/config.toml"
```

Add the same two lines after `prepare_health_fixture "$tmp"` in `test_dotfiles_health_fails_wrong_prism_link_without_running_doctor`, so that test still isolates the wrong Prism link. The new `test_dotfiles_health_checks_wali_config_link` above deliberately manages its own incorrect/correct Wali links.

Read `prepare_health_fixture` (around line 125) first: if the titan fixture path requires a real `${tmp}/config/prism/contexts` directory, create it in the test the same way `test_dotfiles_health_accepts_prism_runtime` does.

- [ ] **Step 2: Run the zsh test to verify it fails**

Run: `zsh tests/setup_and_health.zsh`
Expected: `FAIL: graphical setup does not link the titan wali config`.

- [ ] **Step 3: Add the config files**

`wali/titan/config.toml`:

```toml
# walictl configuration for titan. Linked to $XDG_CONFIG_HOME/wali/config.toml by setup.sh.
wallpaper_dir = "~/d/linux/backgrounds/3440"
favorites_file = "~/d/linux/backgrounds/favorites.json"
archive_root = "/mnt/storage/backgrounds"

[sampling]
exclude_recent = 200
favorite_boost = 1.0
period_boost = 3.0
```

`wali/europa/config.toml`:

```toml
# walictl configuration for europa. No photo archive on this host: Edit opens the display file.
wallpaper_dir = "~/d/linux/backgrounds/3440"
favorites_file = "~/d/linux/backgrounds/favorites.json"

[sampling]
exclude_recent = 200
favorite_boost = 1.0
period_boost = 3.0
```

- [ ] **Step 4: Link in `setup.sh`**

After the `ln_s "${DOTS_HOME}/prism/$(hostname)" "${XDG_CONFIG_HOME}/prism"` line inside `setup_graphical_config_links`:

```bash
    local wali_config="${DOTS_HOME}/wali/$(hostname)/config.toml"
    if [[ -f "$wali_config" ]]; then
        ln_s "$wali_config" "${XDG_CONFIG_HOME}/wali/config.toml"
    else
        echo "No wali config for $(hostname); skipping ${XDG_CONFIG_HOME}/wali/config.toml"
    fi
```

- [ ] **Step 5: Check in `bin/dotfiles-health`**

After the `unset prism_config prism_failures` line:

```bash
wali_config="${DOTS_HOME}/wali/$(hostname)/config.toml"
if [[ -f "$wali_config" || -L "${XDG_CONFIG_HOME}/wali/config.toml" ]]; then
    check_link "${XDG_CONFIG_HOME}/wali/config.toml" "$wali_config"
fi
unset wali_config
```

- [ ] **Step 6: Run the zsh test and the setup dry-run**

Run: `zsh tests/setup_and_health.zsh && just setup-dry-run`
Expected: `setup and health tests passed`; the dry run mentions `wali/titan/config.toml` or the skip message depending on the hostname stub.

- [ ] **Step 7: Commit**

```bash
git add wali setup.sh bin/dotfiles-health tests/setup_and_health.zsh
git commit -m "feat(wali): per-host walictl config linked and health-checked like prism"
```

---

### Task 12: systemd timer and service

**Files:**
- Create: `systemd/user/wali-rotate.service`, `systemd/user/wali-rotate.timer`
- Modify: `setup.sh` (`setup_systemd_user_units`)
- Modify: `bin/dotfiles-health` (systemd block around lines 296-324)
- Modify: `tests/setup_and_health.zsh` (extend `test_setup_link_only_creates_expected_links_without_external_clones` and the `--enable-user-timers` dry-run test; extend the `systemctl` stub in `test_dotfiles_health_checks_enabled_user_timer`)

- [ ] **Step 1: Extend the tests**

In `test_setup_link_only_creates_expected_links_without_external_clones`, add `wali-rotate.service wali-rotate.timer` to the `for unit in familiar-reap.service ...` loop. In the `--enable-user-timers` dry-run test (the one asserting `systemctl --user enable --now dropbox-ignore-flux.timer`), add:

```zsh
  [[ "$output" == *"systemctl --user enable --now wali-rotate.timer"* ]] || \
    fail "expected dry-run wali timer enable command"
```

In `test_dotfiles_health_checks_enabled_user_timer`, extend the stub so `--user is-enabled wali-rotate.timer` prints `enabled` and `--user list-timers wali-rotate.timer --no-pager` prints the header, and assert both were queried:

```zsh
  rg -q -- '--user is-enabled wali-rotate.timer' "$systemctl_log" || \
    fail "expected health to query the wali timer enabled state"
```

- [ ] **Step 2: Run the zsh test to verify it fails**

Run: `zsh tests/setup_and_health.zsh`
Expected: `FAIL: expected linked wali-rotate.service`.

- [ ] **Step 3: Add the units**

`systemd/user/wali-rotate.service`:

```ini
[Unit]
Description=Pick the next wallpaper with walictl

[Service]
Type=oneshot
ExecStart=%h/bin/walictl next
```

`systemd/user/wali-rotate.timer`:

```ini
[Unit]
Description=Rotate the wallpaper every 15 minutes

[Timer]
OnActiveSec=15min
OnUnitActiveSec=15min
AccuracySec=1min
Unit=wali-rotate.service

[Install]
WantedBy=timers.target
```

`OnActiveSec` gives the first trigger after the timer starts; `OnUnitActiveSec` alone is relative to the service's last run and never fires the first time. Not `Persistent`, so a missed tick does not fire on login.

- [ ] **Step 4: Link and enable in `setup.sh`**

In `setup_systemd_user_units`, after the kernel-gate-nudge links:

```bash
    ln_s "${DOTS_HOME}/systemd/user/wali-rotate.service" "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.service"
    ln_s "${DOTS_HOME}/systemd/user/wali-rotate.timer" "${XDG_CONFIG_HOME}/systemd/user/wali-rotate.timer"
```

and inside the `ENABLE_USER_TIMERS` block:

```bash
        run systemctl --user enable --now wali-rotate.timer
```

- [ ] **Step 5: Check in `bin/dotfiles-health`**

Next to the dropbox-ignore-flux checks, add `check_link` calls for both wali units, and inside the `SKIP_SYSTEMD != true` block repeat the `is-enabled` (fail) and `list-timers` (warn) checks for `wali-rotate.timer` with the same wording pattern.

- [ ] **Step 6: Run the tests**

Run: `zsh tests/setup_and_health.zsh`
Expected: `setup and health tests passed`.

- [ ] **Step 7: Commit**

```bash
git add systemd/user/wali-rotate.service systemd/user/wali-rotate.timer setup.sh bin/dotfiles-health tests/setup_and_health.zsh
git commit -m "feat(systemd): wali-rotate timer runs walictl next every 15 minutes"
```

---

### Task 13: Noctalia config: automation off, observe hook

**Files:**
- Modify: `noctalia/config.toml` (lines 12-15 and 48-50)
- Modify: `tests/setup_and_health.zsh` (the Python assertion block around line 338)

- [ ] **Step 1: Update the assertion first**

Replace

```python
assert config["wallpaper"]["automation"] == {
    "enabled": True, "interval_seconds": 900, "order": "alphabetical"
}
```

with

```python
assert config["wallpaper"]["automation"] == {"enabled": False}
assert config["hooks"]["wallpaper_changed"] == [
    '~/bin/prism context wallpaper "$NOCTALIA_WALLPAPER_PATH"',
    "~/bin/walictl observe",
]
```

- [ ] **Step 2: Run the zsh test to verify it fails**

Run: `zsh tests/setup_and_health.zsh`
Expected: an `AssertionError` from the Python block.

- [ ] **Step 3: Edit `noctalia/config.toml`**

```toml
[wallpaper.automation]
enabled = false
```

and

```toml
[hooks]
theme_mode_changed = ["~/d/familiar/bin/familiar-noctalia scheme-sync"]
wallpaper_changed = ["~/bin/prism context wallpaper \"$NOCTALIA_WALLPAPER_PATH\"", "~/bin/walictl observe"]
```

- [ ] **Step 4: Validate and test**

Run: `noctalia config validate noctalia/ 2>&1 | tail -3; zsh tests/setup_and_health.zsh`
Expected: validation reports no errors for `config.toml`; tests pass. If `noctalia config validate` needs the whole config dir, run it against `$XDG_CONFIG_HOME/noctalia` after Task 17 instead and note that here.

- [ ] **Step 5: Commit**

```bash
git add noctalia/config.toml tests/setup_and_health.zsh
git commit -m "feat(noctalia): hand rotation to walictl and record changes through observe"
```

---

### Task 14: Panel

**Files:**
- Modify: `noctalia/plugins/wali-panel/logic.luau`
- Modify: `noctalia/plugins/wali-panel/panel.luau`
- Modify: `noctalia/plugins/wali-panel/plugin_test.lua`
- Modify: `noctalia/plugins/wali-panel/README.md`

**Interfaces:**
- Consumes: `walictl current --json` payload from Task 7; commands `previous`, `next`, `random`, `favorite`, `edit`.
- Produces: `Logic.commandFor(action)` for `current`, `previous`, `next`, `random`, `favorite`, `edit`; `Logic.validateCurrent(payload)` requiring `ok == true`, string `id`, string `path`, boolean `favorite`, and nullable strings `date`, `display_date`, `source_path`, `variant_path`; `Logic.refreshAfter(action)` true for `previous`, `next`, `random`, `favorite`; `Logic.copyTarget(payload) -> string` (`source_path` if present else `path`); `Logic.favoriteGlyph(favorite) -> "heart-filled" | "heart"`.

- [ ] **Step 1: Rewrite `plugin_test.lua` expectations**

Replace the `commands` table and the payload with:

```lua
local commands = {
  current = { "walictl", "current", "--json" },
  previous = { "walictl", "previous" },
  next = { "walictl", "next" },
  random = { "walictl", "random" },
  favorite = { "walictl", "favorite" },
  edit = { "walictl", "edit" },
}

local payload = {
  ok = true,
  id = "PXL_20260820_000000000",
  date = "2026-08-20",
  display_date = "August 20, 2026",
  path = "/wall/current.jpg",
  source_path = "/wall/source.jpg",
  variant_path = nil,
  favorite = true,
  history = { cursor = 3, length = 4 },
}
```

Update the validation loop to the new nullable fields (`date`, `display_date`, `source_path`, `variant_path`) and add required-field checks:

```lua
for _, field in ipairs({ "id", "path" }) do
  local candidate = { ok = true, id = "x", path = "/p", favorite = false }
  candidate[field] = nil
  local invalid, invalidError = Logic.validateCurrent(candidate)
  assert(invalid == nil and type(invalidError) == "string" and invalidError:find(field, 1, true))
end
local invalidFavorite, favoriteError = Logic.validateCurrent({ ok = true, id = "x", path = "/p", favorite = "yes" })
assert(invalidFavorite == nil and favoriteError:find("favorite", 1, true))
```

Replace the `refreshAfter` assertions:

```lua
for _, action in ipairs({ "previous", "next", "random", "favorite" }) do
  assert(Logic.refreshAfter(action), action .. " must refresh current wallpaper metadata")
end
assert(not Logic.refreshAfter("current"))
assert(not Logic.refreshAfter("edit"))
equal(Logic.copyTarget({ path = "/p", source_path = "/s" }), "/s")
equal(Logic.copyTarget({ path = "/p" }), "/p")
equal(Logic.favoriteGlyph(true), "heart-filled")
equal(Logic.favoriteGlyph(false), "heart")
```

In the `noctalia.json.decode` stub, make `"without source"` return `{ ok = true, id = "n", path = "/wall/next.jpg", favorite = false }`. Replace the Copy assertions at the end: Copy is always enabled; after `"without source"` a click copies `/wall/next.jpg`. Replace `button(rendered, "Previous")` flow to use `commands.previous`, and add:

```lua
runs[3].callback(success("with source"))
local favorite = assert(button(rendered, "Favorite"))
equal(favorite.props.glyph, "heart-filled")
favorite.props.onClick()
equal(runs[#runs].command, Shell.command(commands.favorite))
runs[#runs].callback(success("favorited PXL_20260820_000000000"))
equal(runs[#runs].command, Shell.command(commands.current), "favorite did not refresh metadata")
runs[#runs].callback(success("without source"))
equal(assert(button(rendered, "Favorite")).props.glyph, "heart")
```

Run: `lua noctalia/plugins/wali-panel/plugin_test.lua`
Expected: an assertion error on `Logic.commandFor("previous")`.

- [ ] **Step 2: Rewrite `logic.luau`**

```lua
local M = {}

local commands = {
  current = { "walictl", "current", "--json" },
  previous = { "walictl", "previous" },
  next = { "walictl", "next" },
  random = { "walictl", "random" },
  favorite = { "walictl", "favorite" },
  edit = { "walictl", "edit" },
}

function M.commandFor(action)
  return assert(commands[action], "unknown walictl action: " .. tostring(action))
end

function M.validateCurrent(payload)
  if type(payload) ~= "table" then return nil, "walictl current did not return an object" end
  if payload.ok ~= true then return nil, "walictl current reported failure" end
  for _, field in ipairs({ "id", "path" }) do
    if type(payload[field]) ~= "string" then return nil, "walictl current returned an invalid " .. field .. " field" end
  end
  if type(payload.favorite) ~= "boolean" then return nil, "walictl current returned an invalid favorite field" end
  for _, field in ipairs({ "date", "display_date", "source_path", "variant_path" }) do
    if payload[field] ~= nil and type(payload[field]) ~= "string" then
      return nil, "walictl current returned an invalid " .. field .. " field"
    end
  end
  return payload
end

function M.decodeCurrent(text, decoder)
  local decoded, payload, decodeError = pcall(decoder, text)
  if not decoded then return nil, tostring(payload) end
  if payload == nil then return nil, tostring(decodeError or "walictl current returned invalid JSON") end
  return M.validateCurrent(payload)
end

function M.refreshAfter(action)
  return action == "previous" or action == "next" or action == "random" or action == "favorite"
end

function M.canStart(busy)
  return not busy
end

function M.copyTarget(payload)
  return payload.source_path or payload.path
end

function M.favoriteGlyph(favorite)
  return favorite and "heart-filled" or "heart"
end

return M
```

Check the glyph names exist in Noctalia's icon set: `grep -o '"heart[a-z-]*"' /usr/share/noctalia/assets/*.json | sort -u` (or the equivalent asset listing). If `heart-filled` is absent, use the filled name the set provides and update the test to match.

- [ ] **Step 3: Rewrite `panel.luau`**

Keep the structure; change state to hold `current` (the validated payload) instead of four fields, and render from it:

```lua
local Logic = require("./logic.luau")
local Shell = require("./shell.luau")

local state = { busy = false, loading = false, errorText = nil, current = nil }

local render
local refresh

local function trimmed(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function resultError(result, label)
  if result.timedOut then return label .. " timed out" end
  if result.exitCode ~= 0 then
    local stderr = trimmed(result.stderr)
    return stderr ~= "" and stderr or label .. " exited " .. tostring(result.exitCode)
  end
  return nil
end

local function run(argv, callback)
  return noctalia.runAsync(Shell.command(argv), callback, 10000)
end

local function finishCurrent(result)
  state.busy = false
  state.loading = false
  local message = resultError(result, "walictl current")
  local payload
  if not message then payload, message = Logic.decodeCurrent(result.stdout, noctalia.json.decode) end
  if message then
    state.current = nil
    state.errorText = message
  else
    state.current = payload
    state.errorText = nil
  end
  render()
end

refresh = function()
  if not Logic.canStart(state.busy) then return end
  state.busy = true
  state.loading = true
  state.errorText = nil
  render()
  if not run(Logic.commandFor("current"), finishCurrent) then
    state.busy = false
    state.loading = false
    state.errorText = "Failed to launch walictl current"
    render()
  end
end

local function finishAction(action, result)
  state.busy = false
  local message = resultError(result, "walictl " .. action)
  if message then
    state.errorText = message
    render()
    return
  end
  state.errorText = nil
  if Logic.refreshAfter(action) then
    refresh()
    return
  end
  if action == "edit" then noctalia.notify("Wali Panel", trimmed(result.stdout)) end
  render()
end

local function startAction(action)
  if not Logic.canStart(state.busy) then return end
  state.busy = true
  state.errorText = nil
  render()
  if not run(Logic.commandFor(action), function(result) finishAction(action, result) end) then
    state.busy = false
    state.errorText = "Failed to launch walictl " .. action
    render()
  end
end

local function copyPath()
  if not state.current then return end
  if noctalia.copyToClipboard(Logic.copyTarget(state.current), "text/plain") then
    state.errorText = nil
  else
    state.errorText = "Failed to copy the wallpaper path"
  end
  render()
end

local function preview()
  if state.current then
    return ui.image({ path = state.current.path, width = 520, height = 430, radius = 12, fit = "contain" })
  end
  return ui.box({ width = 520, height = 430, radius = 12, fill = "surface_variant" }, {
    ui.glyph({ name = state.loading and "loader" or "wallpaper", size = 56, color = "on_surface_variant" }),
  })
end

local function line(label, value)
  return ui.label({ text = label .. ": " .. (value or "Unavailable"), color = "on_surface_variant", maxLines = 2 })
end

render = function()
  local enabled = not state.busy
  local current = state.current
  local favorite = current ~= nil and current.favorite
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "Wali Panel", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = state.loading and "Loading…" or "", color = "on_surface_variant" }),
    }),
    preview(),
    ui.column({ gap = 4 }, {
      line("Taken", current and current.display_date),
      line("Favorite", current and (favorite and "yes" or "no")),
      line("Source", current and current.source_path),
      ui.label({ text = "Variant: " .. (current and current.variant_path or ""), color = "on_surface_variant",
        visible = current ~= nil and current.variant_path ~= nil, maxLines = 2 }),
      ui.label({ text = state.errorText or "", color = "error", visible = state.errorText ~= nil, maxLines = 3 }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Refresh", glyph = "refresh", enabled = enabled, onClick = function() refresh() end }),
      ui.button({ text = "Previous", glyph = "arrow-left", enabled = enabled, onClick = function() startAction("previous") end }),
      ui.button({ text = "Next", glyph = "arrow-right", enabled = enabled, onClick = function() startAction("next") end }),
      ui.button({ text = "Random", glyph = "dice", enabled = enabled, onClick = function() startAction("random") end }),
    }),
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ text = "Favorite", glyph = Logic.favoriteGlyph(favorite), enabled = enabled and current ~= nil,
        onClick = function() startAction("favorite") end }),
      ui.button({ text = "Edit", glyph = "photo-edit", enabled = enabled and current ~= nil,
        onClick = function() startAction("edit") end }),
      ui.button({ text = "Copy", glyph = "clipboard", enabled = current ~= nil, onClick = copyPath }),
    }),
  }))
end

function onOpen(_context)
  refresh()
end
```

- [ ] **Step 4: Run the plugin test and lint**

Run: `lua noctalia/plugins/wali-panel/plugin_test.lua && noctalia plugin lint noctalia/plugins/wali-panel`
Expected: `Wali plugin tests passed`; lint clean. If the `plugin lint` subcommand has a different name in v5.0.1, find it with `noctalia --help` and use that.

- [ ] **Step 5: Update the README**

Replace the Requirements section:

```markdown
## Requirements

- `walictl` on `PATH`, configured through `$XDG_CONFIG_HOME/wali/config.toml`.
- GIMP for the Edit button.

The panel holds no state and derives nothing from paths. Every button runs a
`walictl` command and re-reads `walictl current --json` afterwards.
```

- [ ] **Step 6: Commit**

```bash
git add noctalia/plugins/wali-panel
git commit -m "feat(wali-panel): favorite toggle with state, history navigation, edit and copy over walictl"
```

---

### Task 15: Trim `shell/wali`

**Files:**
- Modify: `shell/wali` (lines 39-45 alias block, 87-155 helpers, 324-361 `wali_rotate`)
- Modify: `tests/wali.zsh` (lines 111-127)

- [ ] **Step 1: Update the zsh test**

Replace the final zsh block so it exercises `wali_rotate` through a stubbed `walictl`:

```zsh
cat > "${tmp}/bin/walictl" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$NOCTALIA_LOG"
if [[ "$1" == current ]]; then
  printf '{"ok": true, "id": "PXL_20240520_023703962", "path": "%s", "source_path": "%s"}\n' \
    "$NOCTALIA_WALLPAPER" "$BACKGROUND_IMG_DIR/2024/05/PXL_20240520_023703962.jpg"
fi
EOF
chmod +x "${tmp}/bin/walictl"

HOME="${tmp}/home" WAYLAND_DISPLAY=wayland-1 \
  PATH="${tmp}/bin:$PATH" zsh -f -c '
    source "$1/shell/wali"
    [[ "$WALI_BACKEND" == noctalia ]]
    [[ "$(alias wali)" == *"walictl random"* ]]
    ! typeset -f wali_print >/dev/null
    ! typeset -f wali_save >/dev/null
    ! typeset -f wali_edit_fav >/dev/null
    wali_rotate r >/dev/null
  ' zsh "$repo_root"

rg -q -x 'current --json' "$NOCTALIA_LOG" || \
  fail 'wali_rotate did not read the wallpaper from walictl'
(( $(rg -c -x 'current --json' "$NOCTALIA_LOG") == 1 )) || \
  fail 'wali_rotate must read one payload, not one per field'
rg -q -F "msg wallpaper-set ${NOCTALIA_WALLPAPER}" "$NOCTALIA_LOG" || \
  fail 'wali rotate did not reset the v5 wallpaper'
! rg -q -F qs "$NOCTALIA_LOG" || fail 'wali called Quickshell IPC'
```

Keep the `noctalia` stub as is (it still answers `wallpaper-get`, harmless).

Run: `zsh tests/wali.zsh`
Expected: FAIL on the alias assertion.

- [ ] **Step 2: Edit `shell/wali`**

Replace the alias block:

```zsh
if [ "$WALI_BACKEND" = "noctalia" ]; then
  alias wali="walictl random"
```

Delete `wali_print`, `wali_edit_current`, `wali_save`, `wali_edit_fav`. Replace `wali_search`:

```zsh
# find an image by name and add it to the favorites
function wali_search {
  local target
  target=$(fd "$1" "$WALI_DIR/3440" | grep --color='none' "$1" | fzf -1 --exact --preview=$KITTY_PREVIEW_CMD)
  [ -n "$target" ] && walictl favorite --add "${${target:t}%.*}"
}
```

In `wali_rotate`, replace the block from `local current` through `echo "Source: $source"` with:

```zsh
  # one payload: two separate calls could straddle a rotation and pair one
  # photo's destination with another photo's original
  local payload current source
  payload=$(walictl current --json) || return 1
  current=$(jq -r '.path' <<< "$payload")
  source=$(jq -r '.source_path // empty' <<< "$payload")

  if [ -z "$source" ]; then
    echo "No source image for the current wallpaper; nothing to rotate" >&2
    return 1
  fi
  if [ ! -f "$source" ]; then
    echo "Source image not found: $source" >&2
    return 1
  fi

  echo "Source: $source"
```

`_wali_current_wallpaper` stays (used by the swww and feh branches and by nothing else on Noctalia); leave it.

- [ ] **Step 3: Run the zsh test and the full suite**

Run: `zsh tests/wali.zsh && just test`
Expected: `wali tests passed`; the full suite passes.

- [ ] **Step 4: Commit**

```bash
git add shell/wali tests/wali.zsh
git commit -m "refactor(wali): shell helpers defer to walictl for favorites, editing, and the current photo"
```

---

### Task 16: Docs and the spec status

**Files:**
- Modify: `noctalia/noctalia-wallpaper-switcher.md` (rewrite)
- Modify: `noctalia/noctalia.md` (paragraph starting at line 162)
- Modify: `docs/specs/2026-09-07-wallpaper-management-redesign-design.md` (status line)

- [ ] **Step 1: Rewrite the switcher doc**

```markdown
# Wallpaper selection with walictl

Noctalia v5 displays wallpapers and derives colors. `bin/walictl` decides which
photo is shown, remembers what was shown, and keeps favorites. The Wali Panel
plugin (`khughitt/wali-panel`) is a view over `walictl current --json`.

## Ownership

| Concern | Owner |
|---|---|
| Display, palette, templates, hooks | Noctalia |
| Next photo, history, favorites, config | `walictl` |
| Timed rotation | `systemd/user/wali-rotate.timer` running `walictl next` |
| Changes made in Noctalia's own panel | `wallpaper_changed` hook running `walictl observe` |
| Per-wallpaper glass deltas | prism |

## Files

| Path | Purpose |
|---|---|
| `$XDG_CONFIG_HOME/wali/config.toml` | Per-host config, linked from `wali/<hostname>/config.toml` |
| `<favorites_file>` | Favorites keyed by photo id, synced with the backgrounds dir |
| `$XDG_STATE_HOME/wali/history.json` | Per-host history with a cursor |
| `bin/walictl` | The CLI |
| `tests/bin/test_walictl.py` | Tests |

## Commands

```
walictl current --json      # id, date, path, source_path, variant_path, favorite, history
walictl next                # forward in history, else a weighted sample
walictl previous            # back in history
walictl random              # a weighted sample
walictl favorite            # toggle the current photo; --add/--remove [<id>]
walictl favorites --json
walictl neighbors --json    # capture-time neighbours, for mind6
walictl edit                # GIMP on the original, else on the display file
walictl observe             # hook entry point
walictl import-favorites <favorites.txt>
```

Sampling weights: favorites weigh `1 + favorite_boost`, months weigh
`1 + period_boost * favorite density`, and the last `exclude_recent` shown
photos weigh 0. History records selections Noctalia accepted; only the default
(all-monitor) wallpaper is tracked.

Design: `docs/specs/2026-09-07-wallpaper-management-redesign-design.md`.
```

- [ ] **Step 2: Update `noctalia/noctalia.md`**

Append to the paragraph that begins `The wallpaper_changed hook in noctalia/config.toml hands every wallpaper change to prism context wallpaper`:

```markdown
The same hook then runs `walictl observe`, which records a wallpaper chosen in
Noctalia's own panel into walictl's history. Noctalia's timed automation is
off; `wali-rotate.timer` runs `walictl next` instead.
```

Also change the sentence `Wali depends on walictl; Prism depends on prism alone.` to `Wali depends on walictl and its config link; Prism depends on prism alone.`

- [ ] **Step 3: Update the spec status line and the origin enum**

```markdown
**Status:** designed 2026-09-07; implemented on the `wallpaper-redesign`
branch (see `docs/plans/2026-09-07-wallpaper-management-redesign.md`).
Cutover on titan is recorded on task dots-59c279.
```

In the spec's History section, change

```
`origin` is one of `next`, `previous`, `random`, `observed`.
```

to

```
`origin` is one of `next`, `random`, `observed`. Cursor moves (`previous`,
and `next` while behind the end) create no entry.
```

- [ ] **Step 4: Commit**

```bash
git add -f noctalia/noctalia-wallpaper-switcher.md noctalia/noctalia.md docs/specs/2026-09-07-wallpaper-management-redesign-design.md
git commit -m "docs(wallpaper): describe walictl ownership and the observe hook"
```

---

### Task 17: Cutover on titan

This task runs against the live system after the branch is fast-forwarded into `main` (the live links point at the main checkout; see `superpowers:finishing-a-development-branch`). Record each result as a `tasks note dots-59c279` line.

- [ ] **Step 1: Merge and link**

```bash
cd ~/d/dotfiles && git merge --ff-only wallpaper-redesign
./setup.sh --link-only --only graphical-config
./setup.sh --link-only --only systemd --enable-user-timers
noctalia msg config-reload
bin/dotfiles-health --skip-systemd
```

Expected: `wali/config.toml` and both units linked; health passes; the timer is listed by `systemctl --user list-timers wali-rotate.timer`.

- [ ] **Step 2: Import favorites**

```bash
walictl import-favorites ~/d/linux/backgrounds/favorites.txt
```

Expected report: `lines: 685`, `unique: 644`, `duplicate occurrences: 41`, `dangling paths: 2`, `missing display files: 1` naming `PXL_20210919_170859013`. Any other numbers mean the file changed since the design; note the new numbers.

- [ ] **Step 3: Verify behaviour**

```bash
walictl current --json
walictl random && walictl previous && walictl current --json   # restores the wallpaper that was on screen
noctalia msg panel-toggle wallpaper   # pick a different photo in Noctalia's own panel, then:
python3 -c "import json;print(json.load(open('$HOME/.local/state/wali/history.json'))['entries'][-1])"
```

Expected: the last history entry has `origin: observed` and the id of the photo picked in the native panel. Open the Wali Panel from the bar: the heart is filled for a favorited photo and hollow otherwise, and toggling flips it.

- [ ] **Step 4: Confirm the timer fires**

```bash
systemctl --user list-timers wali-rotate.timer
journalctl --user -u wali-rotate.service -n 5
```

Expected: after 15 minutes the wallpaper changes and the journal shows `next: <id>`.

- [ ] **Step 5: Retire the old favorites file in its own commit**

Once the panel shows favorite state correctly:

```bash
rm ~/d/linux/backgrounds/favorites.txt
```

The file is outside the repo, so this is not a git change; record it with `tasks note dots-59c279`.

- [ ] **Step 6: Close the task**

```bash
tasks done dots-59c279 "walictl owns selection, favorites, and history; timer and observe hook live on titan; favorites imported (644 ids)"
```

Then update the spec status line to name the cutover date and commit it with the task file.

---

## Self-review

**Spec coverage.** Config (Task 1, 11), photo identity and stem collapse (2), favorites with lock (3, 9), history with missing-versus-corrupt and cap (4), IPC and reconcile including stale-hook and first-run seeding (5, 8), sampler and the uniform fallback (6), `current --json` contract (7), navigation with commit-after-ok under the lock (8), favorite/favorites/neighbors/edit (9), import with corrected counts (10), setup link and health (11), timer with `OnActiveSec` (12), Noctalia automation off and observe hook (13), panel (14), shell trim including `wali_rotate` (15), docs (16), migration and manual verification (17). The spec's "origin" list is reconciled to `next`, `random`, `observed` in Global Constraints because cursor moves create no entries; that correction is applied to the spec in Task 16's commit (edit the enum line in the History section).

**Placeholders.** None; every step carries code or an exact command.

**Type consistency.** `Context`, `History`, `HistoryEntry`, `Favorites`, `Noctalia`, `navigate`, `describe` names match across Tasks 5-10; the panel consumes the field names produced by Task 7's `describe`.
