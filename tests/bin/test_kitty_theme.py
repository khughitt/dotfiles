from __future__ import annotations

import contextlib
import io
import runpy
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any, cast

import pytest


def kitty_theme_script_path() -> Path:
    return Path(__file__).resolve().parents[2] / "bin" / "kitty-theme"


def load_kitty_theme_module() -> dict[str, Any]:
    return runpy.run_path(str(kitty_theme_script_path()), run_name="kitty_theme_test")


def run_kitty_theme(argv: list[str], monkeypatch: pytest.MonkeyPatch) -> tuple[int, str, str]:
    script_path = kitty_theme_script_path()
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


def test_registry_parses_existing_project_roots(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_project_registry = cast(Callable[[Path], list[Path]], module["parse_project_registry"])

    project_a = tmp_path / "workspace" / "project-a"
    project_b = tmp_path / "workspace" / "project-b"
    project_a.mkdir(parents=True)
    project_b.mkdir()

    registry = tmp_path / "semantic-projects.txt"
    registry.write_text(
        f"\n# comment\n{project_a.parent / 'project-a'}\n\n{project_b}\n{project_a}\n",
        encoding="utf-8",
    )

    assert parse_project_registry(registry) == [project_a.resolve(), project_b.resolve()]


def test_registry_rejects_nonexistent_project_root(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_project_registry = cast(Callable[[Path], list[Path]], module["parse_project_registry"])
    registry_error = cast(type[Exception], module["ProjectRegistryError"])

    missing_project = tmp_path / "missing-project"
    registry = tmp_path / "semantic-projects.txt"
    registry.write_text(f"{missing_project}\n", encoding="utf-8")

    with pytest.raises(registry_error, match="configured project root does not exist"):
        parse_project_registry(registry)


def test_projects_validate_accepts_valid_registry(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project_root = tmp_path / "project"
    project_root.mkdir()

    registry = tmp_path / "semantic-projects.txt"
    registry.write_text(f"{project_root}\n", encoding="utf-8")

    exit_code, stdout, stderr = run_kitty_theme(
        ["projects", "validate", "--registry", str(registry)],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"validated 1 project root from {registry.resolve()}\n"
