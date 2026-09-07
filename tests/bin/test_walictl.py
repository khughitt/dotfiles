from __future__ import annotations

import importlib.machinery
import importlib.util
import fcntl
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


def test_noctalia_set_default_rejects_zero_status_non_ok_answer(
    walictl: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    def non_ok(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, 0, stdout="okay\n", stderr="")

    monkeypatch.setattr(subprocess, "run", non_ok)
    with pytest.raises(walictl.WalictlError, match="wallpaper-set rejected /w/b.jpg: okay"):
        walictl.Noctalia().set_default(Path("/w/b.jpg"))


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


def test_sample_rejects_non_finite_total(walictl: ModuleType) -> None:
    import random

    sampling = walictl.Sampling(favorite_boost=sys.float_info.max, period_boost=sys.float_info.max)
    weighted = walictl.weights(
        ["PXL_20210608_1"], favorites_of(walictl, "PXL_20210608_1"), set(), sampling
    )
    with pytest.raises(walictl.WalictlError, match="total weight must be finite"):
        walictl.sample(weighted, random.Random(1), lambda _: None)


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
    assert history.entries[1].id != "PXL_20210608_111152739"
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
    assert len(load_history(walictl).entries) == 2


def test_previous_at_front_fails(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    code, stdout, stderr = run_cli(walictl, ["previous"])
    assert (code, stdout, stderr) == (1, "", "already at the oldest wallpaper in history\n")
    assert load_history(walictl).cursor == 0


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
    noctalia.default = env["wallpapers"] / "PXL_20220402_162957459.jpg"
    assert run_cli(walictl, ["observe"])[1] == "recorded PXL_20220402_162957459\n"
    history = load_history(walictl)
    assert [(e.id, e.origin) for e in history.entries] == [
        ("PXL_20210608_111152739", "observed"),
        ("PXL_20220402_162957459", "observed"),
    ]
    assert noctalia.calls.count(["noctalia", "msg", "wallpaper-get"]) == 3


def test_stale_observe_after_previous_is_a_noop(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    run_cli(walictl, ["random", "--seed", "3"])
    run_cli(walictl, ["previous"])
    code, stdout, _ = run_cli(walictl, ["observe"])
    assert (code, stdout) == (0, "unchanged PXL_20210608_111152739\n")
    assert len(load_history(walictl).entries) == 2


def test_navigation_holds_the_history_lock(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia
) -> None:
    import threading

    release = threading.Event()
    taken = threading.Event()

    def holder() -> None:
        with walictl.locked(walictl.history_lock()):
            taken.set()
            release.wait(2)

    thread = threading.Thread(target=holder)
    thread.start()
    assert taken.wait(2)
    try:
        walictl_fast = load_walictl()
        normal_lock = walictl_fast.locked

        def short_lock(path: Path, timeout: float = 10.0) -> Any:
            return normal_lock(path, timeout=0.2)

        walictl_fast.locked = short_lock  # type: ignore[assignment]
        code, _, stderr = run_cli(walictl_fast, ["observe"])
        assert code == 1 and stderr.startswith("timed out waiting for")
    finally:
        release.set()
        thread.join(2)
    assert not thread.is_alive()


def test_navigation_keeps_lock_during_wallpaper_set(
    walictl: ModuleType, env: dict[str, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    fake = FakeNoctalia(env["wallpapers"] / "PXL_20210608_111152739.jpg")

    def check_lock(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        if args[2] == "wallpaper-set":
            with walictl.history_lock().open("a", encoding="utf-8") as handle:
                with pytest.raises(BlockingIOError):
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fake.run(args, **kwargs)

    monkeypatch.setattr(subprocess, "run", check_lock)
    assert run_cli(walictl, ["random", "--seed", "3"])[0] == 0


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
    config = env["config_home"] / "wali" / "config.toml"
    config.write_text(config.read_text() + f'variants_dir = "{variants}"\n')
    run_cli(walictl, ["random", "--seed", "3"])
    variant = variants / "PXL_20210608_111152739.png"
    variant.touch()
    code, stdout, _ = run_cli(walictl, ["previous"])
    assert (code, stdout) == (0, "previous: PXL_20210608_111152739\n")
    assert noctalia.default == variant.resolve()
    assert load_history(walictl).entries[0].path == str(variant.resolve())


def test_sampling_prefers_variant_file(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, tmp_path: Path
) -> None:
    variants = tmp_path / "edits"
    variants.mkdir()
    for stem in ("PXL_20210609_120000000", "PXL_20220402_162957459"):
        (variants / f"{stem}.png").touch()
    config = env["config_home"] / "wali" / "config.toml"
    config.write_text(config.read_text() + f'variants_dir = "{variants}"\n')
    run_cli(walictl, ["random", "--seed", "3"])
    picked = load_history(walictl).entries[1]
    assert Path(picked.path).parent == variants


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
    from concurrent.futures import ThreadPoolExecutor

    config = walictl.load_config(walictl.config_path())

    def add(photo: str) -> None:
        ctx = walictl.Context(config=config, noctalia=walictl.Noctalia(), out=io.StringIO(), err=io.StringIO())
        args = walictl.argparse.Namespace(photo_id=photo, add=True, remove=False)
        assert walictl.cmd_favorite(ctx, args) == 0

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(add, photo) for photo in ("PXL_20210608_111152739", "PXL_20210609_120000000")]
        for future in futures:
            future.result()
    assert walictl.Favorites.load(env["favorites"]).ids() == ["PXL_20210608_111152739", "PXL_20210609_120000000"]


def test_favorites_json_lists_paths_and_existence(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, tmp_path: Path
) -> None:
    store = walictl.Favorites(entries={})
    store.add("PXL_20210608_111152739", "T1")
    store.add("PXL_20210919_170859013", "T2")
    store.add("PXL_20210609_120000000", "T3")
    store.save(env["favorites"])
    variants = tmp_path / "edits"
    variants.mkdir()
    (variants / "PXL_20210609_120000000.png").touch()
    config = env["config_home"] / "wali" / "config.toml"
    config.write_text(config.read_text() + f'variants_dir = "{variants}"\n')
    code, stdout, _ = run_cli(walictl, ["favorites", "--json"])
    assert code == 0
    assert json.loads(stdout) == {
        "ok": True,
        "favorites": [
            {"id": "PXL_20210608_111152739", "added": "T1", "path": str(env["wallpapers"] / "PXL_20210608_111152739.jpg"), "source_path": str(env["archive"] / "2021" / "06" / "PXL_20210608_111152739.jpg"), "exists": True},
            {"id": "PXL_20210609_120000000", "added": "T3", "path": str((variants / "PXL_20210609_120000000.png").resolve()), "source_path": None, "exists": True},
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
    assert payload["after"][0] == {"id": "PXL_20220402_162957459", "date": "2022-04-02", "path": str(env["wallpapers"] / "PXL_20220402_162957459.jpg")}
    payload = json.loads(run_cli(walictl, ["neighbors", "--json"])[1])
    assert [n["id"] for n in payload["before"]] == ["PXL_20210531_235959000", "PXL_20210608_111152739"]
    payload = json.loads(run_cli(walictl, ["neighbors", "--json", "--count", "0"])[1])
    assert payload["before"] == [] and payload["after"] == []
    assert run_cli(walictl, ["neighbors", "--json", "--count", "-1"])[2] == "count must be non-negative\n"


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


def test_edit_reports_missing_gimp(
    walictl: ModuleType, env: dict[str, Path], noctalia: FakeNoctalia, monkeypatch: pytest.MonkeyPatch
) -> None:
    def missing(*args: Any, **kwargs: Any) -> None:
        raise FileNotFoundError("gimp")

    monkeypatch.setattr(subprocess, "Popen", missing)
    assert run_cli(walictl, ["edit"]) == (1, "", "gimp command not found\n")


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
        env["favorites"].write_text('{"version": 1, "favorites": {"other": {"added": "T"}}}')
        return real_locked(path, timeout=timeout)

    walictl.locked = locked_then_racer  # type: ignore[assignment]
    code, _, stderr = run_cli(walictl, ["import-favorites", str(source)])
    assert (code, stderr) == (1, f"favorites file already exists (use --force): {env['favorites']}\n")
    assert walictl.Favorites.load(env["favorites"]).ids() == ["other"]


def test_import_favorites_fails_on_missing_source(walictl: ModuleType, env: dict[str, Path], tmp_path: Path) -> None:
    code, _, stderr = run_cli(walictl, ["import-favorites", str(tmp_path / "nope.txt")])
    assert (code, stderr) == (1, f"favorites source not found: {tmp_path / 'nope.txt'}\n")
