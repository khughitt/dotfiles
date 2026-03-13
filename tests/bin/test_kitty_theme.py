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
        f"\n# comment\n{project_a.parent / 'nested' / '..' / 'project-a'}\n\n{project_b}\n{project_a}\n",
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


def test_registry_rejects_missing_registry_path(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_project_registry = cast(Callable[[Path], list[Path]], module["parse_project_registry"])
    registry_error = cast(type[Exception], module["ProjectRegistryError"])

    registry = tmp_path / "missing-semantic-projects.txt"

    with pytest.raises(registry_error, match="project registry not found"):
        parse_project_registry(registry)


def test_registry_resolves_relative_paths_from_registry_location(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_project_registry = cast(Callable[[Path], list[Path]], module["parse_project_registry"])

    project_root = tmp_path / "projects" / "project-a"
    project_root.mkdir(parents=True)

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text("../projects/project-a\n", encoding="utf-8")

    assert parse_project_registry(registry) == [project_root.resolve()]


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


def test_projects_validate_rejects_invalid_registry_encoding(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    registry = tmp_path / "semantic-projects.txt"
    registry.write_bytes(b"\xff\xfe/project\n")

    exit_code, stdout, stderr = run_kitty_theme(
        ["projects", "validate", "--registry", str(registry)],
        monkeypatch,
    )

    assert exit_code == 1
    assert stdout == ""
    assert stderr == f"failed to read project registry: {registry.resolve()}\n"


def test_build_project_corpus_includes_docs_metadata_and_sampled_code(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    build_project_corpus = cast(Callable[..., str], module["build_project_corpus"])

    project_root = tmp_path / "sample-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("Semantic project overview\n", encoding="utf-8")
    (project_root / "docs").mkdir()
    (project_root / "docs" / "guide.md").write_text("Guide details\n", encoding="utf-8")
    (project_root / "pyproject.toml").write_text(
        """
[project]
name = "sample-project"
description = "Semantic palette generator"
dependencies = ["rich>=13", "click>=8"]
""".strip()
        + "\n",
        encoding="utf-8",
    )
    (project_root / "package.json").write_text(
        """
{
  "name": "sample-ui",
  "scripts": {"build": "vite build"},
  "dependencies": {"react": "^18.0.0"}
}
""".strip()
        + "\n",
        encoding="utf-8",
    )
    (project_root / "uv.lock").write_text(
        """
[[package]]
name = "rich"
version = "13.0.0"

[[package]]
name = "click"
version = "8.1.0"
""".strip()
        + "\n",
        encoding="utf-8",
    )
    (project_root / "src").mkdir()
    (project_root / "src" / "app.py").write_text("def render_theme() -> str:\n    return 'nord'\n", encoding="utf-8")

    corpus = build_project_corpus(project_root)

    assert corpus.index("DOC README.md") < corpus.index("DOC docs/guide.md")
    assert "sample-project" in corpus
    assert "Semantic palette generator" in corpus
    assert "rich" in corpus
    assert "click" in corpus
    assert "sample-ui" in corpus
    assert "build" in corpus
    assert "react" in corpus
    assert "CODE src/app.py" in corpus
    assert "render_theme" in corpus


def test_discover_doc_files_uses_preferred_readme_and_doc_priority(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    discover_doc_files = cast(Callable[[Path], list[Path]], module["discover_doc_files"])

    project_root = tmp_path / "docs-project"
    project_root.mkdir()
    (project_root / "README").write_text("fallback readme\n", encoding="utf-8")
    (project_root / "README.md").write_text("preferred readme\n", encoding="utf-8")
    (project_root / "docs").mkdir()
    (project_root / "docs" / "guide.md").write_text("guide\n", encoding="utf-8")
    (project_root / "docs" / "index.md").write_text("index\n", encoding="utf-8")
    (project_root / "docs" / "reference.md").write_text("reference\n", encoding="utf-8")

    assert discover_doc_files(project_root) == [
        project_root / "README.md",
        project_root / "README",
        project_root / "docs" / "index.md",
        project_root / "docs" / "guide.md",
        project_root / "docs" / "reference.md",
    ]


def test_build_project_corpus_respects_code_file_count_and_byte_budget(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    build_project_corpus = cast(Callable[..., str], module["build_project_corpus"])

    project_root = tmp_path / "budget-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("Budget project\n", encoding="utf-8")
    (project_root / "src").mkdir()

    alpha = "def alpha() -> str:\n    return 'alpha'\n"
    beta = "def beta() -> str:\n    return 'beta'\n"
    gamma = "def gamma() -> str:\n    return 'gamma and extra bytes'\n"
    (project_root / "src" / "alpha.py").write_text(alpha, encoding="utf-8")
    (project_root / "src" / "beta.py").write_text(beta, encoding="utf-8")
    (project_root / "src" / "gamma.py").write_text(gamma, encoding="utf-8")

    corpus = build_project_corpus(project_root, max_code_files=2, max_code_bytes=len(alpha) + len(beta))

    assert "CODE src/alpha.py" in corpus
    assert "CODE src/beta.py" in corpus
    assert "CODE src/gamma.py" not in corpus


def test_build_project_corpus_reports_explicit_skips_for_unsupported_and_oversized_files(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    build_project_corpus = cast(Callable[..., str], module["build_project_corpus"])

    project_root = tmp_path / "skip-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("Skip project\n", encoding="utf-8")
    (project_root / "src").mkdir()
    (project_root / "src" / "huge.py").write_text("x" * 200, encoding="utf-8")
    (project_root / "src" / "logo.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    corpus = build_project_corpus(project_root, max_file_bytes=64)

    assert "SKIP src/huge.py oversized" in corpus
    assert "SKIP src/logo.png unsupported" in corpus
