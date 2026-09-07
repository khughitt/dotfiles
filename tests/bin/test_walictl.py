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
    sys.modules["walictl"] = module
    loader.exec_module(module)
    return module


@pytest.fixture
def walictl() -> ModuleType:
    return load_walictl()


@pytest.fixture
def env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> dict[str, Path]:
    tmp_path = tmp_path.resolve()
    config_home, state_home = tmp_path / "config", tmp_path / "state"
    wallpapers, archive, favorites = tmp_path / "3440", tmp_path / "archive", tmp_path / "favorites.json"
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
    return {"config_home": config_home, "state_home": state_home, "wallpapers": wallpapers, "archive": archive, "favorites": favorites}


class FakeNoctalia:
    def __init__(self, default: Path | None, *, reject_set: str | None = None) -> None:
        self.default, self.reject_set = default, reject_set
        self.calls: list[list[str]] = []

    def run(self, args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(list(args))
        assert args[:2] == ["noctalia", "msg"], args
        if args[2] == "wallpaper-get":
            return subprocess.CompletedProcess(args, 0, stdout=f"{self.default}\n" if self.default else "\n", stderr="")
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
        except SystemExit as exc:
            code = exc.code if isinstance(exc.code, int) else 1
    return code, stdout.getvalue(), stderr.getvalue()


def test_load_config_reads_required_and_optional_keys(walictl: ModuleType, env: dict[str, Path]) -> None:
    config = walictl.load_config(walictl.config_path())
    assert config.wallpaper_dir == env["wallpapers"]
    assert config.favorites_file == env["favorites"]
    assert config.archive_root == env["archive"]
    assert config.variants_dir is None
    assert config.sampling == walictl.Sampling(exclude_recent=200, favorite_boost=1.0, period_boost=3.0)


def test_load_config_expands_tilde_and_reads_sampling(walictl: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    tmp_path = tmp_path.resolve()
    monkeypatch.setenv("HOME", str(tmp_path))
    path = tmp_path / "config.toml"
    path.write_text('wallpaper_dir = "~/w"\nfavorites_file = "~/f.json"\nvariants_dir = "~/v"\n[sampling]\nexclude_recent = 5\nfavorite_boost = 0.5\nperiod_boost = 0\n')
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


@pytest.mark.parametrize("key,value", [("exclude_recent", "0.5"), ("exclude_recent", "-1"), ("exclude_recent", "true"), ("exclude_recent", '"2"'), ("favorite_boost", "-1"), ("favorite_boost", "true"), ("favorite_boost", '"oops"'), ("favorite_boost", "nan"), ("favorite_boost", "inf"), ("favorite_boost", "-inf"), ("period_boost", "-1"), ("period_boost", "false"), ("period_boost", '"oops"'), ("period_boost", "nan"), ("period_boost", "inf")])
def test_invalid_sampling_values_report_config_error(walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, key: str, value: str) -> None:
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


def test_every_command_fails_without_config(walictl: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "empty"))
    code, stdout, stderr = run_cli(walictl, ["current", "--json"])
    assert (code, stdout) == (1, "")
    assert stderr.startswith("config not found:")


def test_main_flattens_expected_runtime_error(walictl: ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    def fail(path: Path) -> Any:
        raise OSError("bad\nconfig")
    monkeypatch.setattr(walictl, "load_config", fail)
    assert run_cli(walictl, ["current", "--json"]) == (1, "", "bad config\n")


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


def test_find_by_stem_matches_literal_bracketed_stem(walictl: ModuleType, tmp_path: Path) -> None:
    literal = tmp_path / "photo[1].png"
    literal.touch()
    (tmp_path / "photo1.jpg").touch()
    assert walictl.find_by_stem(tmp_path, "photo[1]") == literal


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


@pytest.mark.parametrize("version", [True, 1.0])
def test_favorites_rejects_non_integer_version(walictl: ModuleType, tmp_path: Path, version: object) -> None:
    path = tmp_path / "favorites.json"
    path.write_text(json.dumps({"version": version, "favorites": {}}))
    with pytest.raises(walictl.WalictlError, match="unsupported favorites version"):
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
    assert path.read_text().startswith('{"version": 1')


@pytest.mark.parametrize(
    "payload,error",
    [
        ({"version": True, "cursor": -1, "entries": []}, "unsupported history version"),
        ({"version": 1.0, "cursor": -1, "entries": []}, "unsupported history version"),
        ({"version": 1, "cursor": True, "entries": []}, "history file is malformed"),
        ({"version": 1, "cursor": -1, "entries": {}}, "history file is malformed"),
    ],
)
def test_history_rejects_malformed_state(
    walictl: ModuleType, tmp_path: Path, payload: dict[str, object], error: str
) -> None:
    path = tmp_path / "history.json"
    path.write_text(json.dumps(payload))
    with pytest.raises(walictl.WalictlError, match=error):
        walictl.History.load(path)


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
