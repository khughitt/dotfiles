from __future__ import annotations

import contextlib
import io
import json
import runpy
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any, cast

import pytest


SEMANTIC_BACKEND = "tfidf-svd-agglomerative-v1"


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


def build_semantic_fixture_inputs(
    tmp_path: Path, semantic_project_input: type[Any]
) -> tuple[list[Any], dict[str, Path]]:
    fixture_corpora = {
        "cli-terminal-a": (
            "terminal command palette shell prompt ansi console hotkey tmux cli terminal shell keybinding"
        ),
        "cli-terminal-b": "cli console prompt shell terminal escape sequence hotkey command pane terminal shell",
        "react-ui-a": "react component browser hooks jsx route frontend ui vite dashboard component react",
        "react-ui-b": "frontend react browser state component jsx router layout ui design react component",
        "data-analytics-a": "sql warehouse dbt analytics metrics model query dashboard pipeline sql dbt warehouse",
        "data-analytics-b": "analytics sql warehouse transformation metric dashboard dbt semantic model query sql",
        "nix-config-a": "nix flake derivation home-manager module package shell declarative nix flake module",
        "nix-config-b": "flake nix package overlay shell module declarative profile home-manager nix flake",
        "graphics-render-a": "shader vulkan opengl texture fragment vertex render gpu shader texture pipeline",
        "graphics-render-b": "opengl shader rendering texture gpu framebuffer vertex fragment shader render vulkan",
        "hybrid-workbench": "terminal command palette react component browser console dashboard workflow shell component",
    }

    project_inputs: list[Any] = []
    project_roots: dict[str, Path] = {}
    for project_name, corpus in fixture_corpora.items():
        project_root = (tmp_path / project_name).resolve()
        project_root.mkdir()
        project_roots[project_name] = project_root
        project_inputs.append(semantic_project_input(project_root=project_root, corpus=corpus))

    return project_inputs, project_roots


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


def test_discover_doc_files_is_deterministic_with_case_variant_names(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    discover_doc_files = cast(Callable[[Path], list[Path]], module["discover_doc_files"])

    project_root = tmp_path / "case-docs-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("upper preferred\n", encoding="utf-8")
    (project_root / "readme.md").write_text("lower preferred\n", encoding="utf-8")
    (project_root / "docs").mkdir()
    (project_root / "docs" / "Guide.md").write_text("guide upper\n", encoding="utf-8")
    (project_root / "docs" / "guide.md").write_text("guide lower\n", encoding="utf-8")

    assert discover_doc_files(project_root) == [
        project_root / "README.md",
        project_root / "readme.md",
        project_root / "docs" / "Guide.md",
        project_root / "docs" / "guide.md",
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


def test_semantic_embeddings_are_computed_for_each_fixture_project(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])

    project_inputs, _ = build_semantic_fixture_inputs(tmp_path, semantic_project_input)

    semantic_space = build_semantic_space(project_inputs)

    assert semantic_space.embeddings.shape[0] == len(project_inputs)
    assert semantic_space.embeddings.shape[1] >= 3
    assert semantic_space.similarity_matrix.shape == (len(project_inputs), len(project_inputs))
    assert set(semantic_space.project_roots) == {project_input.project_root for project_input in project_inputs}


def test_pairwise_similarity_output_is_symmetric_for_fixture_projects(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])

    project_inputs, project_roots = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    semantic_space = build_semantic_space(project_inputs)
    root_to_index = {
        project_root: index for index, project_root in enumerate(cast(list[Path], semantic_space.project_roots))
    }

    cli_a_index = root_to_index[project_roots["cli-terminal-a"]]
    cli_b_index = root_to_index[project_roots["cli-terminal-b"]]
    react_a_index = root_to_index[project_roots["react-ui-a"]]

    assert semantic_space.similarity_matrix[cli_a_index, cli_b_index] == pytest.approx(
        semantic_space.similarity_matrix[cli_b_index, cli_a_index]
    )
    assert semantic_space.similarity_matrix[cli_a_index, cli_a_index] == pytest.approx(1.0)
    assert semantic_space.similarity_matrix[cli_a_index, cli_b_index] > semantic_space.similarity_matrix[
        cli_a_index, react_a_index
    ]


def test_fixture_projects_cluster_into_deterministic_semantic_groups(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[[Any], Any], module["cluster_semantic_space"])

    project_inputs, _ = build_semantic_fixture_inputs(tmp_path, semantic_project_input)

    first_result = cluster_semantic_space(build_semantic_space(project_inputs))
    second_result = cluster_semantic_space(build_semantic_space(project_inputs))

    assert 4 <= len(first_result.cluster_terms) <= 6
    assert list(first_result.cluster_terms) == list(second_result.cluster_terms)
    assert first_result.project_labels == second_result.project_labels


def test_cluster_terms_are_discriminative_for_fixture_projects(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[[Any], Any], module["cluster_semantic_space"])

    project_inputs, project_roots = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    cluster_result = cluster_semantic_space(build_semantic_space(project_inputs))

    labels_by_project = {
        project_root: cluster_result.project_labels[project_root]
        for project_root in cast(list[Path], cluster_result.project_labels)
    }

    cli_terms = set(cluster_result.cluster_terms[labels_by_project[project_roots["cli-terminal-a"]]])
    data_terms = set(cluster_result.cluster_terms[labels_by_project[project_roots["data-analytics-a"]]])
    nix_terms = set(cluster_result.cluster_terms[labels_by_project[project_roots["nix-config-a"]]])

    assert {"terminal", "shell"} & cli_terms
    assert {"sql", "dbt", "warehouse"} & data_terms
    assert {"nix", "flake", "module"} & nix_terms


def test_low_confidence_projects_are_identified_for_fixture_projects(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[[Any], Any], module["cluster_semantic_space"])
    low_confidence_project_roots = cast(Callable[[Any], list[Path]], module["low_confidence_project_roots"])

    project_inputs, project_roots = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    cluster_result = cluster_semantic_space(build_semantic_space(project_inputs))

    assert low_confidence_project_roots(cluster_result) == [project_roots["hybrid-workbench"]]


def test_summarize_uv_lock_metadata_caps_package_lines_and_reports_totals(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    summarize_uv_lock_metadata = cast(Callable[[Path], list[str]], module["summarize_uv_lock_metadata"])

    metadata_path = tmp_path / "uv.lock"
    metadata_path.write_text(
        "\n".join(
            [
                "[[package]]",
                'name = "alpha"',
                'version = "1.0.0"',
                "",
                "[[package]]",
                'name = "beta"',
                'version = "1.0.0"',
                "",
                "[[package]]",
                'name = "charlie"',
                'version = "1.0.0"',
                "",
                "[[package]]",
                'name = "delta"',
                'version = "1.0.0"',
                "",
                "[[package]]",
                'name = "echo"',
                'version = "1.0.0"',
                "",
                "[[package]]",
                'name = "foxtrot"',
                'version = "1.0.0"',
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    summary_lines = summarize_uv_lock_metadata(metadata_path)

    assert "package_count: 6" in summary_lines
    assert any(line.startswith("package_remaining: ") for line in summary_lines)
    assert "package: alpha" in summary_lines
    assert "package: beta" in summary_lines
    assert "package: charlie" in summary_lines
    assert "package: delta" in summary_lines
    assert "package: echo" not in summary_lines
    assert "package: foxtrot" not in summary_lines


def test_build_project_corpus_caps_unsupported_skip_lines(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    build_project_corpus = cast(Callable[..., str], module["build_project_corpus"])

    project_root = tmp_path / "asset-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("Asset project\n", encoding="utf-8")
    (project_root / "assets").mkdir()
    for index in range(12):
        (project_root / "assets" / f"image-{index:02}.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    corpus = build_project_corpus(project_root)

    assert "SKIP assets/image-00.png unsupported" in corpus
    assert "SKIP assets/image-01.png unsupported" in corpus
    assert "SKIP assets/image-02.png unsupported" in corpus
    assert "SKIP assets/image-03.png unsupported" in corpus
    assert "SKIP assets/image-04.png unsupported" not in corpus
    assert "SKIP unsupported 8 more" in corpus


def test_build_project_corpus_caps_oversized_skip_lines(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    build_project_corpus = cast(Callable[..., str], module["build_project_corpus"])

    project_root = tmp_path / "oversized-project"
    project_root.mkdir()
    (project_root / "README.md").write_text("Oversized project\n", encoding="utf-8")
    (project_root / "src").mkdir()
    for index in range(8):
        (project_root / "src" / f"huge_{index}.py").write_text("x" * 256, encoding="utf-8")

    corpus = build_project_corpus(project_root, max_file_bytes=64)

    assert "SKIP src/huge_0.py oversized" in corpus
    assert "SKIP src/huge_1.py oversized" in corpus
    assert "SKIP src/huge_2.py oversized" in corpus
    assert "SKIP src/huge_3.py oversized" in corpus
    assert "SKIP src/huge_4.py oversized" not in corpus
    assert "SKIP oversized 4 more" in corpus


def test_iter_project_files_prunes_ignored_directories_during_traversal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = load_kitty_theme_module()
    iter_project_files = cast(Callable[[Path], list[Path]], module["iter_project_files"])

    project_root = tmp_path / "walk-project"
    project_root.mkdir()
    ignored_dir = project_root / "node_modules"
    ignored_dir.mkdir()
    (ignored_dir / "ignored.js").write_text("console.log('ignored')\n", encoding="utf-8")
    src_dir = project_root / "src"
    src_dir.mkdir()
    visible_file = src_dir / "main.py"
    visible_file.write_text("print('visible')\n", encoding="utf-8")

    def guarded_rglob(self: Path, pattern: str) -> object:
        raise AssertionError(f"recursive glob traversal should not be used: {self} {pattern}")

    monkeypatch.setattr(Path, "rglob", guarded_rglob)

    assert iter_project_files(project_root) == [visible_file]


def test_iter_project_files_is_deterministic_with_case_variant_names(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    iter_project_files = cast(Callable[[Path], list[Path]], module["iter_project_files"])

    project_root = tmp_path / "case-files-project"
    project_root.mkdir()
    (project_root / "Alpha.py").write_text("print('A')\n", encoding="utf-8")
    (project_root / "alpha.py").write_text("print('a')\n", encoding="utf-8")
    (project_root / "src").mkdir()
    (project_root / "src" / "Beta.py").write_text("print('B')\n", encoding="utf-8")
    (project_root / "src" / "beta.py").write_text("print('b')\n", encoding="utf-8")

    assert iter_project_files(project_root) == [
        project_root / "Alpha.py",
        project_root / "alpha.py",
        project_root / "src" / "Beta.py",
        project_root / "src" / "beta.py",
    ]


def test_recompute_writes_semantic_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project_alpha = tmp_path / "projects" / "alpha"
    project_alpha.mkdir(parents=True)
    (project_alpha / ".git").mkdir()
    (project_alpha / "README.md").write_text("Alpha service\n", encoding="utf-8")

    project_beta = tmp_path / "projects" / "beta"
    project_beta.mkdir()
    (project_beta / ".git").mkdir()
    (project_beta / "README.md").write_text("Beta service\n", encoding="utf-8")

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text(f"{project_alpha}\n{project_beta}\n", encoding="utf-8")

    themes_dir = tmp_path / "kitty" / "themes"
    themes_dir.mkdir()
    (themes_dir / "Aurora.conf").write_text("# aurora\n", encoding="utf-8")
    (themes_dir / "Nordic.conf").write_text("# nordic\n", encoding="utf-8")

    cache_path = tmp_path / "kitty" / "semantic-themes.json"

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "recompute",
            "--registry",
            str(registry),
            "--themes-dir",
            str(themes_dir),
            "--cache",
            str(cache_path),
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for 2 project roots to {cache_path.resolve()}\n"

    cache_text = cache_path.read_text(encoding="utf-8")
    cache_data = json.loads(cache_text)
    assert cache_data["backend"] == SEMANTIC_BACKEND
    assert cache_data["version"] == 1
    assert [project["project_root"] for project in cache_data["projects"]] == [
        str(project_alpha.resolve()),
        str(project_beta.resolve()),
    ]
    assert {project["target_theme"] for project in cache_data["projects"]} == {"Aurora.conf", "Nordic.conf"}
    assert len({project["cluster_id"] for project in cache_data["projects"]}) == 2
    assert all(isinstance(project["cluster_id"], str) and project["cluster_id"] for project in cache_data["projects"])
    assert all(0.0 <= project["confidence"] <= 1.0 for project in cache_data["projects"])

    second_exit_code, second_stdout, second_stderr = run_kitty_theme(
        [
            "recompute",
            "--registry",
            str(registry),
            "--themes-dir",
            str(themes_dir),
            "--cache",
            str(cache_path),
        ],
        monkeypatch,
    )

    assert second_exit_code == 0
    assert second_stderr == ""
    assert second_stdout == f"wrote semantic cache for 2 project roots to {cache_path.resolve()}\n"
    assert cache_path.read_text(encoding="utf-8") == cache_text


def test_recompute_normalizes_registry_entries_to_git_roots(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project_root = tmp_path / "workspace" / "service"
    nested_path = project_root / "src" / "package"
    nested_path.mkdir(parents=True)
    (project_root / ".git").mkdir()
    (project_root / "README.md").write_text("Service overview\n", encoding="utf-8")

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text(f"{nested_path}\n", encoding="utf-8")

    themes_dir = tmp_path / "kitty" / "themes"
    themes_dir.mkdir()
    (themes_dir / "Nordic.conf").write_text("# nordic\n", encoding="utf-8")

    cache_path = tmp_path / "kitty" / "semantic-themes.json"

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "recompute",
            "--registry",
            str(registry),
            "--themes-dir",
            str(themes_dir),
            "--cache",
            str(cache_path),
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for 1 project root to {cache_path.resolve()}\n"

    cache_data = json.loads(cache_path.read_text(encoding="utf-8"))
    assert cache_data["backend"] == SEMANTIC_BACKEND
    assert cache_data["projects"] == [
        {
            "cluster_id": cache_data["projects"][0]["cluster_id"],
            "confidence": cache_data["projects"][0]["confidence"],
            "project_root": str(project_root.resolve()),
            "target_theme": "Nordic.conf",
        }
    ]
    assert isinstance(cache_data["projects"][0]["cluster_id"], str)
    assert cache_data["projects"][0]["cluster_id"]
    assert 0.0 <= cache_data["projects"][0]["confidence"] <= 1.0


def test_resolve_prints_target_theme_for_git_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project_root = tmp_path / "workspace" / "service"
    project_root.mkdir(parents=True)
    (project_root / ".git").mkdir()
    nested_path = project_root / "src" / "module"
    nested_path.mkdir(parents=True)

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "projects": [
                    {
                        "cluster_id": "cluster-0003",
                        "confidence": 0.875,
                        "project_root": str(project_root.resolve()),
                        "target_theme": "Nordic.conf",
                    }
                ],
                "version": 1,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    exit_code, stdout, stderr = run_kitty_theme(
        ["resolve", str(nested_path), "--cache", str(cache_path)],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == "Nordic.conf\n"


@pytest.mark.parametrize("metadata_name", ["pyproject.toml", "package.json", "uv.lock"])
def test_recompute_reports_clean_metadata_parse_failures(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, metadata_name: str
) -> None:
    project_root = tmp_path / "workspace" / "broken-project"
    project_root.mkdir(parents=True)
    (project_root / ".git").mkdir()
    (project_root / "README.md").write_text("Broken project\n", encoding="utf-8")
    (project_root / metadata_name).write_text("{not valid\n", encoding="utf-8")

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text(f"{project_root}\n", encoding="utf-8")

    themes_dir = tmp_path / "kitty" / "themes"
    themes_dir.mkdir()
    (themes_dir / "Nordic.conf").write_text("# nordic\n", encoding="utf-8")

    cache_path = tmp_path / "kitty" / "semantic-themes.json"

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "recompute",
            "--registry",
            str(registry),
            "--themes-dir",
            str(themes_dir),
            "--cache",
            str(cache_path),
        ],
        monkeypatch,
    )

    assert exit_code == 1
    assert stdout == ""
    assert stderr == f"failed to parse metadata file: {(project_root / metadata_name).resolve()}\n"


def test_load_semantic_cache_rejects_missing_or_malformed_files(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    load_semantic_cache = cast(Callable[[Path], Any], module["load_semantic_cache"])
    kitty_theme_error = cast(type[Exception], module["KittyThemeError"])

    missing_cache = tmp_path / "missing-semantic-themes.json"
    with pytest.raises(kitty_theme_error, match="semantic cache not found"):
        load_semantic_cache(missing_cache)

    malformed_cache = tmp_path / "semantic-themes.json"
    malformed_cache.write_text('{"version": 1, "projects": [}', encoding="utf-8")
    with pytest.raises(kitty_theme_error, match="semantic cache is malformed"):
        load_semantic_cache(malformed_cache)


@pytest.mark.parametrize(
    ("cache_payload", "message_pattern"),
    [
        (
            {"backend": SEMANTIC_BACKEND, "projects": [], "version": 2},
            "semantic cache has unsupported version",
        ),
        ({"backend": 123, "projects": [], "version": 1}, "semantic cache is malformed"),
        ({"backend": "other-backend", "projects": [], "version": 1}, "semantic cache has unsupported backend"),
        ({"backend": SEMANTIC_BACKEND, "projects": {}, "version": 1}, "semantic cache is malformed"),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "projects": [{"cluster_id": "cluster-0001", "confidence": 1.0, "project_root": "/tmp/example"}],
                "version": 1,
            },
            "semantic cache is malformed",
        ),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "projects": [
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 1.0,
                        "project_root": "relative/path",
                        "target_theme": "Nordic.conf",
                    }
                ],
                "version": 1,
            },
            "semantic cache is malformed",
        ),
    ],
)
def test_load_semantic_cache_validates_typed_contract(
    tmp_path: Path, cache_payload: dict[str, object], message_pattern: str
) -> None:
    module = load_kitty_theme_module()
    load_semantic_cache = cast(Callable[[Path], Any], module["load_semantic_cache"])
    kitty_theme_error = cast(type[Exception], module["KittyThemeError"])

    cache_path = tmp_path / "semantic-themes.json"
    cache_path.write_text(json.dumps(cache_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    with pytest.raises(kitty_theme_error, match=message_pattern):
        load_semantic_cache(cache_path)
