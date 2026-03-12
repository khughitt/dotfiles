from __future__ import annotations

import contextlib
import io
import json
import runpy
import subprocess
import sys
from pathlib import Path

import pytest


def test_current_returns_source_metadata(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    archive_root = tmp_path / "backgrounds"
    expected_source = archive_root / "2024" / "05" / "PXL_20240520_023703962.jpg"
    expected_source.parent.mkdir(parents=True)
    expected_source.touch()

    current_wallpaper = tmp_path / "current" / "PXL_20240520_023703962.jpg"
    script_path = Path(__file__).resolve().parents[2] / "bin" / "walictl"

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
    monkeypatch.setattr(sys, "argv", [str(script_path), "current", "--json"])

    stdout = io.StringIO()
    stderr = io.StringIO()
    exit_code = 0

    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        try:
            runpy.run_path(str(script_path), run_name="__main__")
        except SystemExit as exc:
            exit_code = exc.code if isinstance(exc.code, int) else 1

    payload = json.loads(stdout.getvalue())

    assert exit_code == 0
    assert stderr.getvalue() == ""
    assert payload["ok"] is True
    assert payload["source_wallpaper_path"] == str(expected_source)
    assert payload["display_date"] == "May 20, 2024"
