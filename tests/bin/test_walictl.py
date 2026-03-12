from __future__ import annotations

import contextlib
import io
import json
import runpy
import subprocess
import sys
from pathlib import Path

import pytest


def walictl_script_path() -> Path:
    return Path(__file__).resolve().parents[2] / "bin" / "walictl"


def run_walictl(argv: list[str], monkeypatch: pytest.MonkeyPatch) -> tuple[int, str, str]:
    script_path = walictl_script_path()
    monkeypatch.setattr(sys, "argv", [str(script_path), *argv])

    stdout = io.StringIO()
    stderr = io.StringIO()
    exit_code = 0

    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        try:
            runpy.run_path(str(script_path), run_name="__main__")
        except SystemExit as exc:
            exit_code = exc.code if isinstance(exc.code, int) else 1

    return exit_code, stdout.getvalue(), stderr.getvalue()


def test_current_returns_source_metadata(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    archive_root = tmp_path / "backgrounds"
    expected_source = archive_root / "2024" / "05" / "PXL_20240520_023703962.jpg"
    expected_source.parent.mkdir(parents=True)
    expected_source.touch()

    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setattr(subprocess, "run", fake_run)
    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)
    payload = json.loads(stdout)

    assert exit_code == 0
    assert stderr == ""
    assert payload["ok"] is True
    assert payload["source_wallpaper_path"] == str(expected_source)
    assert payload["display_date"] == "May 20, 2024"


def test_current_requires_json_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    def fail_if_called(*args: object, **kwargs: object) -> subprocess.CompletedProcess[str]:
        pytest.fail(f"subprocess.run should not be called: {args!r} {kwargs!r}")

    monkeypatch.setattr(subprocess, "run", fail_if_called)
    exit_code, stdout, stderr = run_walictl(["current"], monkeypatch)

    assert exit_code == 2
    assert stdout == ""
    assert "required" in stderr
    assert "--json" in stderr


def test_current_fails_when_wallpaper_query_is_empty(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    archive_root = tmp_path / "backgrounds"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout="\n \n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "could not determine current wallpaper\n"


def test_current_fails_when_qs_command_is_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        raise FileNotFoundError("qs")

    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "qs command not found\n"


def test_current_fails_when_wallpaper_query_command_fails(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        raise subprocess.CalledProcessError(returncode=1, cmd=args)

    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "wallpaper query failed\n"


def test_current_returns_null_metadata_for_unparseable_filename(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    current_wallpaper = tmp_path / "current" / "wallpaper.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.delenv("BACKGROUND_IMG_DIR", raising=False)
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)
    payload = json.loads(stdout)

    assert exit_code == 0
    assert stderr == ""
    assert payload["current_wallpaper_path"] == str(current_wallpaper)
    assert payload["source_wallpaper_path"] is None
    assert payload["parsed_date"] is None
    assert payload["display_date"] is None


def test_current_returns_null_metadata_for_noncanonical_filename(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    current_wallpaper = tmp_path / "current" / "IMG_PXL_20240520.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.delenv("BACKGROUND_IMG_DIR", raising=False)
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)
    payload = json.loads(stdout)

    assert exit_code == 0
    assert stderr == ""
    assert payload["current_wallpaper_path"] == str(current_wallpaper)
    assert payload["source_wallpaper_path"] is None
    assert payload["parsed_date"] is None
    assert payload["display_date"] is None


def test_current_fails_when_source_wallpaper_path_cannot_be_derived(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    archive_root = tmp_path / "backgrounds"
    current_wallpaper = tmp_path / "current" / "PXL_20240520.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "could not derive source wallpaper path\n"


def test_current_reports_derivation_error_before_missing_archive_env(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    current_wallpaper = tmp_path / "current" / "PXL_20240520.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.delenv("BACKGROUND_IMG_DIR", raising=False)
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "could not derive source wallpaper path\n"


def test_current_fails_when_source_wallpaper_is_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    archive_root = tmp_path / "backgrounds"
    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "source wallpaper not found\n"


def test_current_fails_when_background_img_dir_is_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"

    def fake_run(
        args: list[str], *, check: bool, capture_output: bool, text: bool
    ) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert check is True
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.delenv("BACKGROUND_IMG_DIR", raising=False)
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["current", "--json"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "BACKGROUND_IMG_DIR is not set\n"


def test_save_current_appends_source_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    archive_root = tmp_path / "backgrounds"
    source_path = archive_root / "2024" / "05" / "PXL_20240520_023703962.jpg"
    source_path.parent.mkdir(parents=True)
    source_path.touch()

    wali_dir = tmp_path / "wali"
    wali_dir.mkdir()
    favorites_path = wali_dir / "favorites.txt"
    favorites_path.write_text("existing-entry\n")

    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert kwargs == {"check": True, "capture_output": True, "text": True}
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setenv("WALI_DIR", str(wali_dir))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["save-current"], monkeypatch)

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"saved {source_path}\n"
    assert favorites_path.read_text() == f"existing-entry\n{source_path}\n"


def test_save_current_fails_when_wali_favorites_directory_is_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    archive_root = tmp_path / "backgrounds"
    source_path = archive_root / "2024" / "05" / "PXL_20240520_023703962.jpg"
    source_path.parent.mkdir(parents=True)
    source_path.touch()

    missing_wali_dir = tmp_path / "missing-wali"
    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        assert args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]
        assert kwargs == {"check": True, "capture_output": True, "text": True}
        return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setenv("WALI_DIR", str(missing_wali_dir))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["save-current"], monkeypatch)

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "favorites directory not found\n"


def test_edit_current_launches_gimp(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    archive_root = tmp_path / "backgrounds"
    source_path = archive_root / "2024" / "05" / "PXL_20240520_023703962.jpg"
    source_path.parent.mkdir(parents=True)
    source_path.touch()

    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"
    calls: list[tuple[list[str], dict[str, object]]] = []

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        calls.append((args, kwargs))
        if args == ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"]:
            assert kwargs == {"check": True, "capture_output": True, "text": True}
            return subprocess.CompletedProcess(args=args, returncode=0, stdout=f"{current_wallpaper}\n", stderr="")

        assert args == ["gimp", str(source_path)]
        assert kwargs == {"check": True}
        return subprocess.CompletedProcess(args=args, returncode=0, stdout="", stderr="")

    monkeypatch.setenv("BACKGROUND_IMG_DIR", str(archive_root))
    monkeypatch.setattr(subprocess, "run", fake_run)

    exit_code, stdout, stderr = run_walictl(["edit-current"], monkeypatch)

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"opened {source_path}\n"
    assert calls == [
        (["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "get", "all"], {"check": True, "capture_output": True, "text": True}),
        (["gimp", str(source_path)], {"check": True}),
    ]
