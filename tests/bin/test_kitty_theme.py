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
SEMANTIC_CLUSTER_COUNT = 5


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


def write_valid_theme(theme_path: Path, background: str, foreground: str) -> None:
    selection_background = "#303030" if background == "#101010" else "#dddddd"
    selection_foreground = "#ffffff" if foreground != "#101010" else "#000000"
    cursor = foreground
    ansi_values = [
        "#000000",
        "#aa0000",
        "#00aa00",
        "#aa5500",
        "#0000aa",
        "#aa00aa",
        "#00aaaa",
        "#aaaaaa",
        "#555555",
        "#ff5555",
        "#55ff55",
        "#ffff55",
        "#5555ff",
        "#ff55ff",
        "#55ffff",
        "#ffffff",
    ]
    if background != "#101010":
        ansi_values = list(reversed(ansi_values))

    lines = [
        f"background {background}",
        f"foreground {foreground}",
        f"selection_background {selection_background}",
        f"selection_foreground {selection_foreground}",
        f"cursor {cursor}",
    ]
    lines.extend(f"color{index} {value}" for index, value in enumerate(ansi_values))
    theme_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


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


def test_semantic_corpus_section_counts_tracks_doc_metadata_code_and_skip_lines(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_corpus_section_counts = cast(
        Callable[[str], tuple[int, int, int, int]], module["semantic_corpus_section_counts"]
    )

    corpus = "\n".join(
        [
            "DOC README.md",
            "hello",
            "DOC docs/guide.md",
            "METADATA pyproject.toml",
            "CODE src/app.py",
            "SKIP assets/logo.png unsupported",
            "SKIP oversized 10 more",
        ]
    )

    assert semantic_corpus_section_counts(corpus) == (2, 1, 1, 2)


def test_parse_semantic_stopwords_file_ignores_comments_and_deduplicates(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_semantic_stopwords_file = cast(Callable[[Path], set[str]], module["parse_semantic_stopwords_file"])

    stopwords_path = tmp_path / "semantic-stopwords.txt"
    stopwords_path.write_text(
        """
# comment
terminal
Terminal
shell
""".strip()
        + "\n",
        encoding="utf-8",
    )

    assert parse_semantic_stopwords_file(stopwords_path) == {"shell", "terminal"}


def test_parse_semantic_stopwords_file_rejects_invalid_tokens(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_semantic_stopwords_file = cast(Callable[[Path], set[str]], module["parse_semantic_stopwords_file"])
    kitty_theme_error = cast(type[Exception], module["KittyThemeError"])

    stopwords_path = tmp_path / "semantic-stopwords.txt"
    stopwords_path.write_text("validtoken\ninvalid token\n", encoding="utf-8")

    with pytest.raises(kitty_theme_error, match="semantic stopwords file has invalid token at line 2"):
        parse_semantic_stopwords_file(stopwords_path)


def test_tokenize_semantic_corpus_accepts_external_stopwords_file(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    load_semantic_stopwords = cast(Callable[[Path | None], frozenset[str]], module["load_semantic_stopwords"])
    tokenize_semantic_corpus = cast(Callable[..., list[str]], module["tokenize_semantic_corpus"])

    stopwords_path = tmp_path / "semantic-stopwords.txt"
    stopwords_path.write_text("terminal\nprompt\n", encoding="utf-8")

    stopwords = load_semantic_stopwords(stopwords_path)
    tokens = tokenize_semantic_corpus(
        "terminal shell prompt workflow sequence terminal",
        stopwords=stopwords,
    )

    assert tokens == ["shell", "workflow", "sequence"]


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
    assert (
        semantic_space.similarity_matrix[cli_a_index, cli_b_index]
        > semantic_space.similarity_matrix[cli_a_index, react_a_index]
    )


def test_fixture_projects_cluster_into_deterministic_semantic_groups(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[..., Any], module["cluster_semantic_space"])

    project_inputs, _ = build_semantic_fixture_inputs(tmp_path, semantic_project_input)

    first_result = cluster_semantic_space(build_semantic_space(project_inputs), cluster_count=SEMANTIC_CLUSTER_COUNT)
    second_result = cluster_semantic_space(build_semantic_space(project_inputs), cluster_count=SEMANTIC_CLUSTER_COUNT)

    assert len(first_result.cluster_terms) == SEMANTIC_CLUSTER_COUNT
    assert list(first_result.cluster_terms) == list(second_result.cluster_terms)
    assert first_result.project_labels == second_result.project_labels


def test_cluster_terms_are_discriminative_for_fixture_projects(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[..., Any], module["cluster_semantic_space"])

    project_inputs, project_roots = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    cluster_result = cluster_semantic_space(build_semantic_space(project_inputs), cluster_count=SEMANTIC_CLUSTER_COUNT)

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
    cluster_semantic_space = cast(Callable[..., Any], module["cluster_semantic_space"])
    low_confidence_project_roots = cast(Callable[[Any], list[Path]], module["low_confidence_project_roots"])

    project_inputs, project_roots = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    cluster_result = cluster_semantic_space(build_semantic_space(project_inputs), cluster_count=SEMANTIC_CLUSTER_COUNT)

    assert low_confidence_project_roots(cluster_result) == [project_roots["hybrid-workbench"]]


def test_cluster_semantic_space_rejects_cluster_count_larger_than_project_count(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    semantic_project_input = cast(type[Any], module["SemanticProjectInput"])
    build_semantic_space = cast(Callable[[list[Any]], Any], module["build_semantic_space"])
    cluster_semantic_space = cast(Callable[..., Any], module["cluster_semantic_space"])
    kitty_theme_error = cast(type[Exception], module["KittyThemeError"])

    project_inputs, _ = build_semantic_fixture_inputs(tmp_path, semantic_project_input)
    small_fixture_inputs = project_inputs[:2]

    with pytest.raises(
        kitty_theme_error, match="semantic cluster count exceeds project count: requested 3 for 2 projects"
    ):
        cluster_semantic_space(build_semantic_space(small_fixture_inputs), cluster_count=3)


def test_recompute_accepts_configured_cluster_count(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fixture_names = [
        "cli-terminal-a",
        "cli-terminal-b",
        "react-ui-a",
        "react-ui-b",
        "data-analytics-a",
        "data-analytics-b",
        "nix-config-a",
        "nix-config-b",
        "graphics-render-a",
        "graphics-render-b",
        "hybrid-workbench",
    ]
    fixture_corpora = {
        "cli-terminal-a": "terminal command palette shell prompt ansi console hotkey tmux cli terminal shell keybinding",
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
    project_roots: list[Path] = []
    for fixture_name in fixture_names:
        project_root = tmp_path / "projects" / fixture_name
        project_root.mkdir(parents=True)
        (project_root / ".git").mkdir()
        (project_root / "README.md").write_text(fixture_corpora[fixture_name] + "\n", encoding="utf-8")
        project_roots.append(project_root.resolve())

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text("\n".join(str(project_root) for project_root in project_roots) + "\n", encoding="utf-8")

    themes_dir = tmp_path / "kitty" / "themes"
    themes_dir.mkdir()
    for theme_name, colors in {
        "Aurora.conf": ("#101010", "#f0f0f0"),
        "Nordic.conf": ("#101010", "#e6f0ff"),
        "Dawn.conf": ("#f5f5f5", "#121212"),
        "Ember.conf": ("#181818", "#f4d7a1"),
        "Forest.conf": ("#0f1a12", "#d6f5de"),
    }.items():
        write_valid_theme(themes_dir / theme_name, background=colors[0], foreground=colors[1])

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
            "--cluster-count",
            str(SEMANTIC_CLUSTER_COUNT),
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for {len(project_roots)} project roots to {cache_path.resolve()}\n"
    cache_data = json.loads(cache_path.read_text(encoding="utf-8"))
    assert cache_data["cluster_count"] == SEMANTIC_CLUSTER_COUNT
    assert len({project["cluster_id"] for project in cache_data["projects"]}) == SEMANTIC_CLUSTER_COUNT


def test_recompute_rejects_configured_cluster_count_larger_than_registry_size(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
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
    write_valid_theme(themes_dir / "Aurora.conf", background="#101010", foreground="#f0f0f0")
    write_valid_theme(themes_dir / "Nordic.conf", background="#f5f5f5", foreground="#121212")

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
            "--cluster-count",
            "3",
        ],
        monkeypatch,
    )

    assert exit_code == 1
    assert stdout == ""
    assert stderr == "semantic cluster count exceeds project count: requested 3 for 2 projects\n"
    assert not cache_path.exists()


def test_recompute_rejects_invalid_stopwords_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
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
    write_valid_theme(themes_dir / "Aurora.conf", background="#101010", foreground="#f0f0f0")
    write_valid_theme(themes_dir / "Nordic.conf", background="#f5f5f5", foreground="#121212")

    stopwords_path = tmp_path / "kitty" / "semantic-stopwords.txt"
    stopwords_path.write_text("validtoken\ninvalid token\n", encoding="utf-8")

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
            "--cluster-count",
            "2",
            "--stopwords-file",
            str(stopwords_path),
        ],
        monkeypatch,
    )

    assert exit_code == 1
    assert stdout == ""
    assert stderr == f"semantic stopwords file has invalid token at line 2: {stopwords_path.resolve()}\n"
    assert not cache_path.exists()


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
    write_valid_theme(themes_dir / "Aurora.conf", background="#101010", foreground="#f0f0f0")
    write_valid_theme(themes_dir / "Nordic.conf", background="#f5f5f5", foreground="#121212")

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
            "--cluster-count",
            "2",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for 2 project roots to {cache_path.resolve()}\n"

    cache_text = cache_path.read_text(encoding="utf-8")
    cache_data = json.loads(cache_text)
    assert cache_data["backend"] == SEMANTIC_BACKEND
    assert cache_data["cluster_count"] == 2
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
            "--cluster-count",
            "2",
        ],
        monkeypatch,
    )

    assert second_exit_code == 0
    assert second_stderr == ""
    assert second_stdout == f"wrote semantic cache for 2 project roots to {cache_path.resolve()}\n"
    assert cache_path.read_text(encoding="utf-8") == cache_text


def test_recompute_excludes_projects_with_no_docs_metadata_or_code(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    valid_project = tmp_path / "projects" / "valid"
    valid_project.mkdir(parents=True)
    (valid_project / ".git").mkdir()
    (valid_project / "README.md").write_text("Valid project docs\n", encoding="utf-8")
    (valid_project / "src").mkdir()
    (valid_project / "src" / "main.py").write_text("def run() -> None:\n    return None\n", encoding="utf-8")

    low_signal_project = tmp_path / "projects" / "low-signal"
    low_signal_project.mkdir()
    (low_signal_project / ".git").mkdir()
    (low_signal_project / "assets").mkdir()
    (low_signal_project / "assets" / "logo.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text(f"{valid_project}\n{low_signal_project}\n", encoding="utf-8")

    themes_dir = tmp_path / "kitty" / "themes"
    themes_dir.mkdir()
    write_valid_theme(themes_dir / "Aurora.conf", background="#101010", foreground="#f0f0f0")

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
            "--cluster-count",
            "1",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for 1 project root to {cache_path.resolve()}\n"

    cache_data = json.loads(cache_path.read_text(encoding="utf-8"))
    assert [project["project_root"] for project in cache_data["projects"]] == [str(valid_project.resolve())]
    assert len(cache_data["excluded_projects"]) == 1
    excluded_entry = cache_data["excluded_projects"][0]
    assert excluded_entry["project_root"] == str(low_signal_project.resolve())
    assert excluded_entry["reason"] == "no_doc_metadata_or_code_sections"
    assert excluded_entry["token_count"] >= 1
    assert excluded_entry["unique_token_count"] >= 1
    assert excluded_entry["unique_token_count"] <= excluded_entry["token_count"]


def test_diagnose_reports_low_confidence_and_excluded_projects(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    valid_project = tmp_path / "projects" / "valid"
    valid_project.mkdir(parents=True)
    (valid_project / ".git").mkdir()
    (valid_project / "README.md").write_text("Valid project docs\n", encoding="utf-8")
    (valid_project / "src").mkdir()
    (valid_project / "src" / "main.py").write_text("def run() -> None:\n    return None\n", encoding="utf-8")

    low_signal_project = tmp_path / "projects" / "low-signal"
    low_signal_project.mkdir()
    (low_signal_project / ".git").mkdir()
    (low_signal_project / "assets").mkdir()
    (low_signal_project / "assets" / "logo.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    registry = tmp_path / "kitty" / "semantic-projects.txt"
    registry.parent.mkdir()
    registry.write_text(f"{valid_project}\n{low_signal_project}\n", encoding="utf-8")

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "diagnose",
            "--registry",
            str(registry),
            "--cluster-count",
            "1",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert "diagnosed 1 project root (1 below 0.500, 1 excluded)" in stdout
    assert f"- {low_signal_project.resolve()} reason=no_doc_metadata_or_code_sections" in stdout
    assert f"{valid_project.resolve()}" in stdout
    assert "nearest_in=<none> <none>" in stdout


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
    write_valid_theme(themes_dir / "Nordic.conf", background="#101010", foreground="#f0f0f0")

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
            "--cluster-count",
            "1",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert stdout == f"wrote semantic cache for 1 project root to {cache_path.resolve()}\n"

    cache_data = json.loads(cache_path.read_text(encoding="utf-8"))
    assert cache_data["backend"] == SEMANTIC_BACKEND
    assert cache_data["cluster_count"] == 1
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
                "cluster_count": 1,
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


def test_list_groups_projects_by_theme_and_reports_excluded_entries(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "excluded_projects": [
                    {
                        "project_root": "/tmp/low-signal",
                        "reason": "no_doc_metadata_or_code_sections",
                        "token_count": 4,
                        "unique_token_count": 3,
                    }
                ],
                "projects": [
                    {
                        "cluster_id": "cluster-a",
                        "confidence": 0.92,
                        "project_root": "/tmp/project-a",
                        "target_theme": "Nord.conf",
                    },
                    {
                        "cluster_id": "cluster-b",
                        "confidence": 0.63,
                        "project_root": "/tmp/project-b",
                        "target_theme": "Ayu Mirage.conf",
                    },
                    {
                        "cluster_id": "cluster-a",
                        "confidence": 0.88,
                        "project_root": "/tmp/project-c",
                        "target_theme": "Nord.conf",
                    },
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
        ["list", "--cache", str(cache_path)],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert "Ayu Mirage.conf (1)" in stdout
    assert "Nord.conf (2)" in stdout
    assert "  /tmp/project-a cluster=cluster-a confidence=0.920000" in stdout
    assert "  /tmp/project-c cluster=cluster-a confidence=0.880000" in stdout
    assert "excluded (1)" in stdout
    assert "  /tmp/low-signal reason=no_doc_metadata_or_code_sections tokens=4 unique=3" in stdout


def test_list_can_group_projects_by_cluster(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "projects": [
                    {
                        "cluster_id": "cluster-a",
                        "confidence": 0.92,
                        "project_root": "/tmp/project-a",
                        "target_theme": "Nord.conf",
                    },
                    {
                        "cluster_id": "cluster-b",
                        "confidence": 0.63,
                        "project_root": "/tmp/project-b",
                        "target_theme": "Ayu Mirage.conf",
                    },
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
        ["list", "--cache", str(cache_path), "--group-by", "cluster"],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert "cluster-a (1)" in stdout
    assert "cluster-b (1)" in stdout
    assert "  /tmp/project-a cluster=cluster-a confidence=0.920000" in stdout
    assert "  /tmp/project-b cluster=cluster-b confidence=0.630000" in stdout


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
            "--cluster-count",
            "1",
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
            {"backend": SEMANTIC_BACKEND, "cluster_count": SEMANTIC_CLUSTER_COUNT, "projects": [], "version": 2},
            "semantic cache has unsupported version",
        ),
        (
            {"backend": 123, "cluster_count": SEMANTIC_CLUSTER_COUNT, "projects": [], "version": 1},
            "semantic cache is malformed",
        ),
        ({"backend": SEMANTIC_BACKEND, "projects": [], "version": 1}, "semantic cache is malformed"),
        (
            {"backend": SEMANTIC_BACKEND, "cluster_count": 0, "projects": [], "version": 1},
            "semantic cache is malformed",
        ),
        (
            {"backend": "other-backend", "cluster_count": SEMANTIC_CLUSTER_COUNT, "projects": [], "version": 1},
            "semantic cache has unsupported backend",
        ),
        (
            {"backend": SEMANTIC_BACKEND, "cluster_count": SEMANTIC_CLUSTER_COUNT, "projects": {}, "version": 1},
            "semantic cache is malformed",
        ),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": SEMANTIC_CLUSTER_COUNT,
                "excluded_projects": {},
                "projects": [],
                "version": 1,
            },
            "semantic cache is malformed",
        ),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": SEMANTIC_CLUSTER_COUNT,
                "projects": [{"cluster_id": "cluster-0001", "confidence": 1.0, "project_root": "/tmp/example"}],
                "version": 1,
            },
            "semantic cache is malformed",
        ),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": SEMANTIC_CLUSTER_COUNT,
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
        (
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "projects": [
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 1.0,
                        "project_root": "/tmp/example-a",
                        "target_theme": "Nordic.conf",
                    },
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 0.9,
                        "project_root": "/tmp/example-b",
                        "target_theme": "Aurora.conf",
                    },
                ],
                "version": 1,
            },
            "semantic cache is malformed",
        ),
        (
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 1,
                "excluded_projects": [
                    {
                        "project_root": "/tmp/example",
                        "reason": "no_doc_metadata_or_code_sections",
                        "token_count": 5,
                        "unique_token_count": 5,
                    }
                ],
                "projects": [
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 1.0,
                        "project_root": "/tmp/example",
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


def test_load_semantic_cache_accepts_excluded_projects_metadata(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    load_semantic_cache = cast(Callable[[Path], Any], module["load_semantic_cache"])

    cache_path = tmp_path / "semantic-themes.json"
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 1,
                "excluded_projects": [
                    {
                        "project_root": "/tmp/low-signal",
                        "reason": "no_doc_metadata_or_code_sections",
                        "token_count": 5,
                        "unique_token_count": 4,
                    }
                ],
                "projects": [
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 0.95,
                        "project_root": "/tmp/semantic-project",
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

    loaded_cache = load_semantic_cache(cache_path)
    assert len(loaded_cache.projects) == 1
    assert len(loaded_cache.excluded_projects) == 1
    assert loaded_cache.excluded_projects[0].project_root == Path("/tmp/low-signal")
    assert loaded_cache.excluded_projects[0].reason == "no_doc_metadata_or_code_sections"


def test_parse_kitty_theme_palette_extracts_required_colors(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_kitty_theme_palette = cast(Callable[[Path], dict[str, str]], module["parse_kitty_theme_palette"])

    theme_path = tmp_path / "Aurora.conf"
    theme_path.write_text(
        "\n".join(
            [
                "background #111111",
                "foreground #eeeeee",
                "selection_background #444444",
                "selection_foreground #ffffff",
                "cursor #eeeeee",
                "color0 #000000",
                "color1 #111111",
                "color2 #222222",
                "color3 #333333",
                "color4 #444444",
                "color5 #555555",
                "color6 #666666",
                "color7 #777777",
                "color8 #888888",
                "color9 #999999",
                "color10 #aaaaaa",
                "color11 #bbbbbb",
                "color12 #cccccc",
                "color13 #dddddd",
                "color14 #eeeeee",
                "color15 #ffffff",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    palette = parse_kitty_theme_palette(theme_path)

    assert palette["background"] == "#111111"
    assert palette["foreground"] == "#eeeeee"
    assert palette["selection_background"] == "#444444"
    assert palette["selection_foreground"] == "#ffffff"
    assert palette["cursor"] == "#eeeeee"
    assert palette["color0"] == "#000000"
    assert palette["color15"] == "#ffffff"


def test_parse_kitty_theme_palette_rejects_missing_required_keys(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    parse_kitty_theme_palette = cast(Callable[[Path], dict[str, str]], module["parse_kitty_theme_palette"])
    kitty_theme_error = cast(type[Exception], module["KittyThemeError"])

    theme_path = tmp_path / "Broken.conf"
    theme_path.write_text(
        "\n".join(
            [
                "background #111111",
                "foreground #eeeeee",
                "selection_background #444444",
                "selection_foreground #ffffff",
                "cursor #eeeeee",
                "color0 #000000",
                "color1 #111111",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    with pytest.raises(kitty_theme_error, match="missing required color keys"):
        parse_kitty_theme_palette(theme_path)


def test_palette_visual_distance_is_deterministic() -> None:
    module = load_kitty_theme_module()
    palette_visual_distance = cast(Callable[[dict[str, str], dict[str, str]], float], module["palette_visual_distance"])

    palette_a = {
        "background": "#111111",
        "foreground": "#eeeeee",
        "selection_background": "#222222",
        "selection_foreground": "#ffffff",
        "cursor": "#eeeeee",
        **{f"color{index}": "#111111" for index in range(16)},
    }
    palette_b = {
        "background": "#111111",
        "foreground": "#eeeeee",
        "selection_background": "#222222",
        "selection_foreground": "#ffffff",
        "cursor": "#eeeeee",
        **{f"color{index}": "#111111" for index in range(16)},
    }
    palette_c = {
        "background": "#f0f0f0",
        "foreground": "#101010",
        "selection_background": "#dddddd",
        "selection_foreground": "#121212",
        "cursor": "#101010",
        **{f"color{index}": "#f0f0f0" for index in range(16)},
    }

    assert palette_visual_distance(palette_a, palette_b) == pytest.approx(0.0)
    assert palette_visual_distance(palette_a, palette_c) == pytest.approx(palette_visual_distance(palette_c, palette_a))
    assert palette_visual_distance(palette_a, palette_c) > 0.0


def test_select_attractor_themes_prefers_diverse_readable_candidates(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    select_attractor_themes = cast(Callable[[Path, int], list[str]], module["select_attractor_themes"])

    themes_dir = tmp_path / "themes"
    themes_dir.mkdir()

    (themes_dir / "Alpha.conf").write_text(
        "\n".join(
            [
                "background #101010",
                "foreground #f0f0f0",
                "selection_background #303030",
                "selection_foreground #ffffff",
                "cursor #f0f0f0",
                *[
                    f"color{index} #{index:01x}{index:01x}{index:01x}{index:01x}{index:01x}{index:01x}"
                    for index in range(16)
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    (themes_dir / "Beta.conf").write_text(
        "\n".join(
            [
                "background #111111",
                "foreground #efefef",
                "selection_background #2f2f2f",
                "selection_foreground #ffffff",
                "cursor #efefef",
                *[
                    f"color{index} #{index:01x}{index:01x}{index:01x}{index:01x}{index:01x}{index:01x}"
                    for index in range(16)
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    (themes_dir / "Gamma.conf").write_text(
        "\n".join(
            [
                "background #f5f5f5",
                "foreground #121212",
                "selection_background #dddddd",
                "selection_foreground #000000",
                "cursor #121212",
                *[
                    f"color{index} #{15 - index:01x}{15 - index:01x}{15 - index:01x}{15 - index:01x}{15 - index:01x}{15 - index:01x}"
                    for index in range(16)
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    selected = select_attractor_themes(themes_dir, 2)

    assert len(selected) == 2
    assert selected[0] == "Alpha.conf"
    assert "Gamma.conf" in selected


def test_themes_diagnose_reports_quality_metrics(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    themes_dir = tmp_path / "themes"
    themes_dir.mkdir()
    write_valid_theme(themes_dir / "Alpha.conf", background="#101010", foreground="#f0f0f0")
    write_valid_theme(themes_dir / "Gamma.conf", background="#f5f5f5", foreground="#121212")

    exit_code, stdout, stderr = run_kitty_theme(
        ["themes", "diagnose", "--themes-dir", str(themes_dir)],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert "Alpha.conf quality=" in stdout
    assert "Gamma.conf quality=" in stdout
    assert "fg=" in stdout
    assert "cursor=" in stdout


def build_uniform_palette(value: str) -> dict[str, str]:
    return {
        "background": value,
        "foreground": value,
        "selection_background": value,
        "selection_foreground": value,
        "cursor": value,
        **{f"color{index}": value for index in range(16)},
    }


def test_build_transition_palettes_has_expected_step_count_and_endpoints() -> None:
    module = load_kitty_theme_module()
    build_transition_palettes = cast(
        Callable[[dict[str, str], dict[str, str], int], list[dict[str, str]]],
        module["build_transition_palettes"],
    )

    start_palette = build_uniform_palette("#111111")
    end_palette = build_uniform_palette("#eeeeee")

    transition_palettes = build_transition_palettes(start_palette, end_palette, 5)

    assert len(transition_palettes) == 5
    assert transition_palettes[0] == start_palette
    assert transition_palettes[-1] == end_palette


def test_should_skip_transition_when_delta_is_negligible() -> None:
    module = load_kitty_theme_module()
    should_skip_transition = cast(
        Callable[[dict[str, str], dict[str, str], int], bool],
        module["should_skip_transition"],
    )

    start_palette = build_uniform_palette("#111111")
    almost_same_palette = build_uniform_palette("#121212")
    very_different_palette = build_uniform_palette("#f0f0f0")

    assert should_skip_transition(start_palette, almost_same_palette, 4)
    assert not should_skip_transition(start_palette, very_different_palette, 4)


def test_build_set_colors_command_includes_listen_socket_when_provided() -> None:
    module = load_kitty_theme_module()
    build_set_colors_command = cast(
        Callable[[str, list[str], str | None], list[str]], module["build_set_colors_command"]
    )

    command = build_set_colors_command("42", ["Nord.conf"], "unix:/tmp/kitty.sock")

    assert command[:4] == ["kitten", "@", "--to", "unix:/tmp/kitty.sock"]
    assert command[4:] == ["set-colors", "-m", "id:42", "Nord.conf"]


def test_build_set_colors_command_omits_listen_socket_when_not_provided() -> None:
    module = load_kitty_theme_module()
    build_set_colors_command = cast(
        Callable[[str, list[str], str | None], list[str]], module["build_set_colors_command"]
    )

    command = build_set_colors_command("42", ["Nord.conf"], None)

    assert command == ["kitten", "@", "set-colors", "-m", "id:42", "Nord.conf"]


def test_apply_theme_file_uses_devnull_and_optional_listen_socket(monkeypatch: pytest.MonkeyPatch) -> None:
    module = load_kitty_theme_module()
    apply_theme_file = cast(Callable[[str, Path, str | None], None], module["apply_theme_file"])

    captured: dict[str, Any] = {}

    def fake_run(command: list[str], **kwargs: Any) -> None:
        captured["command"] = command
        captured["kwargs"] = kwargs

    monkeypatch.setattr(module["subprocess"], "run", fake_run)

    apply_theme_file("42", Path("/tmp/Nord.conf"), "unix:/tmp/kitty.sock")

    assert captured["command"] == [
        "kitten",
        "@",
        "--to",
        "unix:/tmp/kitty.sock",
        "set-colors",
        "-m",
        "id:42",
        "/tmp/Nord.conf",
    ]
    assert captured["kwargs"]["check"] is True
    assert captured["kwargs"]["capture_output"] is True
    assert captured["kwargs"]["text"] is True
    assert captured["kwargs"]["stdin"] is module["subprocess"].DEVNULL


def test_load_runtime_state_recovers_from_malformed_json(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    load_runtime_state = cast(Callable[[Path], Any], module["load_runtime_state"])

    state_path = tmp_path / "kitty" / "runtime-state.json"
    state_path.parent.mkdir(parents=True)
    state_path.write_text('{"windows": [}', encoding="utf-8")

    state = load_runtime_state(state_path)
    assert state.windows == {}


def test_runtime_state_window_id_is_namespaced_by_listen_socket() -> None:
    module = load_kitty_theme_module()
    runtime_state_window_id = cast(Callable[[str, str | None], str], module["runtime_state_window_id"])

    assert runtime_state_window_id("1", None) == "1"
    assert runtime_state_window_id("1", "") == "1"
    assert runtime_state_window_id("1", "unix:@dotfiles-kitty-100") == "unix:@dotfiles-kitty-100|1"
    assert runtime_state_window_id("1", "unix:@dotfiles-kitty-100") != runtime_state_window_id(
        "1", "unix:@dotfiles-kitty-200"
    )


def test_temporary_override_clears_on_project_change(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    load_runtime_state = cast(Callable[[Path], Any], module["load_runtime_state"])
    set_window_override = cast(Callable[[Any, str, str, str, Path | None], None], module["set_window_override"])
    write_runtime_state = cast(Callable[[Path, Any], None], module["write_runtime_state"])
    resolve_effective_theme_for_window = cast(
        Callable[[Path, Path, Path, str, str], tuple[str, str | None, str | None]],
        module["resolve_effective_theme_for_window"],
    )

    project_a = tmp_path / "workspace" / "project-a"
    project_a.mkdir(parents=True)
    (project_a / ".git").mkdir()
    project_b = tmp_path / "workspace" / "project-b"
    project_b.mkdir(parents=True)
    (project_b / ".git").mkdir()

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "projects": [
                    {
                        "cluster_id": "cli-shell",
                        "confidence": 0.95,
                        "project_root": str(project_a.resolve()),
                        "target_theme": "Nordic.conf",
                    },
                    {
                        "cluster_id": "data-warehouse",
                        "confidence": 0.91,
                        "project_root": str(project_b.resolve()),
                        "target_theme": "Aurora.conf",
                    },
                ],
                "version": 1,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    state_path = tmp_path / "kitty" / "runtime-state.json"
    state = load_runtime_state(state_path)
    set_window_override(state, "42", "manual/solarized-light.conf", "temporary", project_a.resolve())
    write_runtime_state(state_path, state)

    first_theme, first_override_mode, _ = resolve_effective_theme_for_window(
        project_a,
        cache_path,
        state_path,
        "42",
        "noctalia.conf",
    )
    assert first_theme == "manual/solarized-light.conf"
    assert first_override_mode == "temporary"

    second_theme, second_override_mode, _ = resolve_effective_theme_for_window(
        project_b,
        cache_path,
        state_path,
        "42",
        "noctalia.conf",
    )
    assert second_theme == "Aurora.conf"
    assert second_override_mode is None


def test_sticky_override_persists_until_reset(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    clear_window_override = cast(Callable[[Any, str], None], module["clear_window_override"])
    load_runtime_state = cast(Callable[[Path], Any], module["load_runtime_state"])
    resolve_effective_theme_for_window = cast(
        Callable[[Path, Path, Path, str, str], tuple[str, str | None, str | None]],
        module["resolve_effective_theme_for_window"],
    )
    set_window_override = cast(Callable[[Any, str, str, str, Path | None], None], module["set_window_override"])
    write_runtime_state = cast(Callable[[Path, Any], None], module["write_runtime_state"])

    project_a = tmp_path / "workspace" / "project-a"
    project_a.mkdir(parents=True)
    (project_a / ".git").mkdir()
    project_b = tmp_path / "workspace" / "project-b"
    project_b.mkdir(parents=True)
    (project_b / ".git").mkdir()

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "projects": [
                    {
                        "cluster_id": "cli-shell",
                        "confidence": 0.95,
                        "project_root": str(project_a.resolve()),
                        "target_theme": "Nordic.conf",
                    },
                    {
                        "cluster_id": "data-warehouse",
                        "confidence": 0.91,
                        "project_root": str(project_b.resolve()),
                        "target_theme": "Aurora.conf",
                    },
                ],
                "version": 1,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    state_path = tmp_path / "kitty" / "runtime-state.json"
    state = load_runtime_state(state_path)
    set_window_override(state, "42", "manual/catppuccin-latte.conf", "sticky", project_a.resolve())
    write_runtime_state(state_path, state)

    theme_before_reset, override_mode_before_reset, _ = resolve_effective_theme_for_window(
        project_b,
        cache_path,
        state_path,
        "42",
        "noctalia.conf",
    )
    assert theme_before_reset == "manual/catppuccin-latte.conf"
    assert override_mode_before_reset == "sticky"

    state_after_read = load_runtime_state(state_path)
    clear_window_override(state_after_read, "42")
    write_runtime_state(state_path, state_after_read)

    theme_after_reset, override_mode_after_reset, _ = resolve_effective_theme_for_window(
        project_b,
        cache_path,
        state_path,
        "42",
        "noctalia.conf",
    )
    assert theme_after_reset == "Aurora.conf"
    assert override_mode_after_reset is None


def test_resolve_semantic_theme_uses_neutral_fallback_for_low_confidence_and_missing_projects(tmp_path: Path) -> None:
    module = load_kitty_theme_module()
    resolve_semantic_theme_with_fallback = cast(
        Callable[[Path, Path, str, float], tuple[str, str | None]],
        module["resolve_semantic_theme_with_fallback"],
    )

    project_a = tmp_path / "workspace" / "project-a"
    project_a.mkdir(parents=True)
    (project_a / ".git").mkdir()
    project_b = tmp_path / "workspace" / "project-b"
    project_b.mkdir(parents=True)
    (project_b / ".git").mkdir()
    project_c = tmp_path / "workspace" / "project-c"
    project_c.mkdir(parents=True)
    (project_c / ".git").mkdir()

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 2,
                "projects": [
                    {
                        "cluster_id": "cli-shell",
                        "confidence": 0.95,
                        "project_root": str(project_a.resolve()),
                        "target_theme": "Nordic.conf",
                    },
                    {
                        "cluster_id": "data-warehouse",
                        "confidence": 0.11,
                        "project_root": str(project_b.resolve()),
                        "target_theme": "Aurora.conf",
                    },
                ],
                "version": 1,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    resolved_high_confidence, _ = resolve_semantic_theme_with_fallback(
        project_a,
        cache_path,
        "noctalia.conf",
        0.5,
    )
    assert resolved_high_confidence == "Nordic.conf"

    resolved_low_confidence, _ = resolve_semantic_theme_with_fallback(
        project_b,
        cache_path,
        "noctalia.conf",
        0.5,
    )
    assert resolved_low_confidence == "noctalia.conf"

    resolved_missing, _ = resolve_semantic_theme_with_fallback(
        project_c,
        cache_path,
        "noctalia.conf",
        0.5,
    )
    assert resolved_missing == "noctalia.conf"


def test_shell_runtime_delegates_to_kitty_theme_cli() -> None:
    shell_script = Path(__file__).resolve().parents[2] / "shell" / "kitty"
    shell_text = shell_script.read_text(encoding="utf-8")

    assert "_KITTY_THEME_CLI" in shell_text
    assert "_KITTY_THEME_APPLY_PID" in shell_text
    assert "apply_args=(" in shell_text
    assert 'apply_args+=(--listen-on "$KITTY_LISTEN_ON")' in shell_text
    assert 'setsid "${apply_args[@]}" >/dev/null 2>&1 < /dev/null &!' in shell_text
    assert '"${apply_args[@]}" >/dev/null 2>&1' in shell_text
    assert '_KITTY_THEME_APPLY_PID="$!"' in shell_text
    assert "applied_theme=$(" not in shell_text
    assert "md5sum" not in shell_text
    assert "set-colors" not in shell_text


def test_kitty_conf_manual_mappings_flow_through_override_commands() -> None:
    kitty_conf = Path(__file__).resolve().parents[2] / "kitty" / "kitty.conf"
    kitty_text = kitty_conf.read_text(encoding="utf-8")

    assert "listen_on unix:@dotfiles-kitty" in kitty_text
    assert "kitty-theme override set" in kitty_text
    assert "kitty-theme override reset" in kitty_text
    assert "remote_control set-colors" not in kitty_text


def test_explain_command_reports_effective_assignment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    module = load_kitty_theme_module()
    load_runtime_state = cast(Callable[[Path], Any], module["load_runtime_state"])
    set_window_override = cast(Callable[[Any, str, str, str, Path | None], None], module["set_window_override"])
    write_runtime_state = cast(Callable[[Path, Any], None], module["write_runtime_state"])

    project_root = tmp_path / "workspace" / "project-a"
    project_root.mkdir(parents=True)
    (project_root / ".git").mkdir()
    nested_path = project_root / "src"
    nested_path.mkdir()

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 1,
                "projects": [
                    {
                        "cluster_id": "sql-dbt-warehouse",
                        "confidence": 0.93,
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

    state_path = tmp_path / "kitty" / "runtime-state.json"
    state = load_runtime_state(state_path)
    set_window_override(state, "42", "manual/solarized-light.conf", "sticky", project_root.resolve())
    write_runtime_state(state_path, state)

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "explain",
            str(nested_path),
            "--window-id",
            "42",
            "--cache",
            str(cache_path),
            "--state",
            str(state_path),
            "--fallback-theme",
            "noctalia.conf",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert f"project_root: {project_root.resolve()}" in stdout
    assert "cluster_id: sql-dbt-warehouse" in stdout
    assert "confidence: 0.930000" in stdout
    assert "top_terms: sql, dbt, warehouse" in stdout
    assert "assigned_theme: Nordic.conf" in stdout
    assert "override_mode: sticky" in stdout
    assert "effective_theme: manual/solarized-light.conf" in stdout


def test_explain_command_reports_excluded_reason_for_low_signal_project(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    project_root = tmp_path / "workspace" / "project-a"
    project_root.mkdir(parents=True)
    (project_root / ".git").mkdir()
    nested_path = project_root / "src"
    nested_path.mkdir()

    other_project_root = tmp_path / "workspace" / "other-project"
    other_project_root.mkdir()
    (other_project_root / ".git").mkdir()

    cache_path = tmp_path / "kitty" / "semantic-themes.json"
    cache_path.parent.mkdir()
    cache_path.write_text(
        json.dumps(
            {
                "backend": SEMANTIC_BACKEND,
                "cluster_count": 1,
                "excluded_projects": [
                    {
                        "project_root": str(project_root.resolve()),
                        "reason": "no_doc_metadata_or_code_sections",
                        "token_count": 8,
                        "unique_token_count": 6,
                    }
                ],
                "projects": [
                    {
                        "cluster_id": "cluster-0001",
                        "confidence": 0.9,
                        "project_root": str(other_project_root.resolve()),
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

    state_path = tmp_path / "kitty" / "runtime-state.json"

    exit_code, stdout, stderr = run_kitty_theme(
        [
            "explain",
            str(nested_path),
            "--window-id",
            "42",
            "--cache",
            str(cache_path),
            "--state",
            str(state_path),
            "--fallback-theme",
            "noctalia.conf",
        ],
        monkeypatch,
    )

    assert exit_code == 0
    assert stderr == ""
    assert f"project_root: {project_root.resolve()}" in stdout
    assert "cluster_id: <none>" in stdout
    assert "assigned_theme: noctalia.conf" in stdout
    assert "excluded_reason: no_doc_metadata_or_code_sections tokens=8 unique=6" in stdout
