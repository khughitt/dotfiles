# Semantic Kitty Themes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace hash-based kitty project theme assignment with a precomputed semantic clustering system that maps configured git projects to curated attractor themes and animates transitions for automatic and manual theme changes.

**Architecture:** Add a small `kitty-theme` CLI that owns project registry parsing, corpus sampling, embedding/clustering cache generation, theme parsing, and runtime theme transitions. Keep `shell/kitty` as the lightweight hook that detects the current git root and delegates resolution and animation to the CLI. Store semantic assignments and cluster-to-theme mapping in a cache artifact so runtime never performs expensive semantic work.

**Tech Stack:** Python with `uv`, `click`, `rich`, `pytest`, `ruff`, and `pyright`; kitty remote control; existing `shell/kitty` and `kitty/kitty.conf` configuration.

---

## Progress

Current execution status in the `semantic-kitty-themes` worktree:

- [x] Task 1: Scaffold the CLI, registry, and test harness
- [x] Task 2: Build corpus sampling from docs, metadata, and code
- [x] Task 3: Add cache models and semantic recompute plumbing
- [x] Task 4: Integrate embeddings, similarity, clustering, and labels
- [x] Task 5: Build theme parsing, quality scoring, and attractor selection
- [x] Task 6: Implement runtime transition logic and override state
- [x] Task 7: Wire `shell/kitty` into semantic resolution
- [x] Task 8: Add explainability commands and final verification

Audit summary for previously completed Tasks 1-4:

- validated Task 1-4 implementation against plan scope and existing tests
- confirmed deterministic semantic clustering path and typed cache contracts
- identified runtime integration gaps (Tasks 5-8 not yet wired) and completed those implementations
- validated shell/kitty and kitty.conf now delegate to `kitty-theme` runtime commands

Current verification checkpoint:

- latest reviewed worktree head: `semantic-kitty-themes` working tree (post Task 8)
- `uv run --frozen ruff check . --exclude .pytest-tmp` -> pass
- `uv run --frozen pyright` -> pass
- `uv run --frozen pytest tests/bin/test_kitty_theme.py -q --basetemp .pytest-tmp/test_kitty_theme` -> `53 passed`

Execution notes:

- Some pytest runs use a worktree-local `--basetemp` because host `/tmp` quota pressure can break tmp-path writes.

### Task 1: Scaffold the CLI, registry, and test harness [Completed]

**Files:**
- Create: `pyproject.toml`
- Create: `bin/kitty-theme`
- Create: `kitty/semantic-projects.txt`
- Create: `tests/bin/test_kitty_theme.py`

**Step 1: Write the failing test**

Create `tests/bin/test_kitty_theme.py` with a first test for registry parsing and path validation:

```python
from __future__ import annotations

from pathlib import Path


def test_registry_parses_existing_project_roots(tmp_path: Path) -> None:
    registry = tmp_path / "semantic-projects.txt"
    registry.write_text("/tmp/project-a\n# comment\n/tmp/project-b\n", encoding="utf-8")
    ...
```

Cover at least:

- blank lines and comments are ignored
- configured paths are normalized
- duplicate roots collapse deterministically
- nonexistent paths raise an explicit error

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because the CLI and project metadata do not exist yet.

**Step 3: Write minimal implementation**

Create:

- `pyproject.toml` with runtime dependencies such as `click` and `rich`, plus dev dependencies for `pytest`, `ruff`, and `pyright`
- `kitty/semantic-projects.txt` with commented examples and no implicit fallback entries
- `bin/kitty-theme` as an executable Python CLI with a `projects validate` command and a focused registry parser

Keep the implementation small and typed. Use `pathlib`, fail early, and follow the existing dotfiles style.

**Step 4: Run test to verify it passes**

Run:

```bash
uv sync
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for registry parsing and validation.

**Step 5: Commit**

```bash
git add pyproject.toml bin/kitty-theme kitty/semantic-projects.txt tests/bin/test_kitty_theme.py
git commit -m "feat: scaffold semantic kitty theme cli"
```

### Task 2: Build corpus sampling from docs, metadata, and code [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`

**Step 1: Write the failing tests**

Add tests for corpus construction:

- README and docs files are included in priority order
- metadata such as `pyproject.toml`, `package.json`, or lockfile hints contribute structured tokens
- code sampling respects file-count and byte-budget caps
- unsupported or oversized files are skipped explicitly

Example:

```python
def test_build_corpus_includes_docs_metadata_and_sampled_code(tmp_path: Path) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL on the new corpus expectations.

**Step 3: Write minimal implementation**

Add focused helpers in `bin/kitty-theme` to:

- discover preferred docs files
- extract small structured metadata summaries
- sample representative source files
- produce a normalized corpus string per project

Keep the first version deterministic. Do not add model-specific logic yet.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for corpus sampling behavior.

**Step 5: Commit**

```bash
git add bin/kitty-theme tests/bin/test_kitty_theme.py
git commit -m "feat: add semantic corpus sampling"
```

### Task 3: Add cache models and semantic recompute plumbing [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`
- Create: `kitty/semantic-themes.json`

**Step 1: Write the failing tests**

Add tests for cache serialization and recompute flow:

- recompute command writes a stable cache artifact
- project entries include project root, cluster id, confidence, and target theme
- cache lookup fails clearly when the file is missing or malformed

Example:

```python
def test_recompute_writes_semantic_cache(tmp_path: Path) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because no cache model or recompute flow exists yet.

**Step 3: Write minimal implementation**

Add:

- typed cache structures
- `recompute` command plumbing
- deterministic JSON serialization
- `resolve` command that looks up a git root in the cache

For this task, use a placeholder deterministic embedding backend behind a small interface so the cache shape can be implemented before integrating the real model. Do not add a legacy path; replace the hash-based assignment at the architecture boundary.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for cache write and read behavior.

**Step 5: Commit**

```bash
git add bin/kitty-theme kitty/semantic-themes.json tests/bin/test_kitty_theme.py
git commit -m "feat: add semantic cache plumbing"
```

### Task 4: Integrate embeddings, similarity, clustering, and labels [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`

**Step 1: Write the failing tests**

Add tests for the semantic layer:

- embeddings are computed for each project corpus
- pairwise similarity output is symmetric
- projects cluster into `4-6` groups deterministically for a fixed fixture set
- discriminative cluster terms are produced from `tf-idf` or `BM25`
- low-confidence projects are identified correctly

Example:

```python
def test_cluster_terms_are_discriminative_for_fixture_projects(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL on embedding, clustering, and labeling expectations.

**Step 3: Write minimal implementation**

Add the real semantic backend:

- choose and integrate the embedding model
- compute vector similarities
- cluster projects into the configured attractor count
- compute cluster confidence
- derive deterministic cluster keywords
- optionally support a presentation-only LLM naming path behind an explicit flag

Keep the core assignment path deterministic and offline.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for the fixed fixture set and deterministic labels.

**Step 5: Commit**

```bash
git add bin/kitty-theme tests/bin/test_kitty_theme.py
git commit -m "feat: add semantic clustering and labels"
```

### Task 5: Build theme parsing, quality scoring, and attractor selection [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`
- Create: `kitty/theme-candidates/.gitkeep`

**Step 1: Write the failing tests**

Add tests for theme normalization and scoring:

- kitty theme files are parsed into a structured palette
- minimum required colors are validated
- pairwise visual distance is computed deterministically
- a diverse attractor subset is chosen subject to quality constraints

Example:

```python
def test_select_attractor_themes_prefers_diverse_readable_candidates(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because theme parsing and selection are not implemented yet.

**Step 3: Write minimal implementation**

Add support to:

- ingest current repo themes and imported candidate themes
- parse the relevant kitty color keys
- score readability and diversity
- assign each latent cluster to an attractor theme

Also add a command for dumping candidate-theme diagnostics to aid curation.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for theme parsing and attractor selection.

**Step 5: Commit**

```bash
git add bin/kitty-theme kitty/theme-candidates/.gitkeep tests/bin/test_kitty_theme.py
git commit -m "feat: add theme attractor selection"
```

### Task 6: Implement runtime transition logic and override state [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`

**Step 1: Write the failing tests**

Add tests for runtime behavior:

- palette interpolation produces the expected step count and endpoints
- near-identical themes skip animation
- `temporary` overrides clear on project change
- `sticky` overrides persist until reset
- low-confidence or missing projects resolve to the neutral fallback theme

Example:

```python
def test_apply_transition_skips_when_target_matches_current(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because transition and override state logic do not exist yet.

**Step 3: Write minimal implementation**

Add commands and helpers to:

- load the current and target palette
- interpolate the defined theme keys over `10-14` eased steps
- apply intermediate palettes with kitty remote control
- store per-window override state
- implement reset, debounce, and hysteresis

Keep the implementation explicit. If animation fails, fall back to applying the final target theme directly.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for transition and override behavior.

**Step 5: Commit**

```bash
git add bin/kitty-theme tests/bin/test_kitty_theme.py
git commit -m "feat: add kitty theme transitions"
```

### Task 7: Wire `shell/kitty` into semantic resolution [Completed]

**Files:**
- Modify: `shell/kitty`
- Modify: `kitty/kitty.conf`
- Modify: `tests/bin/test_kitty_theme.py`

**Step 1: Write the failing test**

Add a regression test or fixture-backed command test proving the runtime hook delegates to the CLI instead of hashing git roots directly.

Example:

```python
def test_shell_runtime_resolves_theme_from_semantic_cache(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because the shell hook still uses hash-based assignment.

**Step 3: Write minimal implementation**

Update `shell/kitty` to:

- keep git root detection
- call `kitty-theme resolve` or `kitty-theme apply`
- remove hash-based theme selection
- preserve per-window targeting and current-theme short-circuiting

Update `kitty/kitty.conf` so the manual `alt+0..9` mappings flow through `kitty-theme` rather than calling `set-colors` directly, and add any reset or mode-toggle bindings required for override control.

**Step 4: Run test to verify it passes**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for semantic lookup and override integration.

**Step 5: Commit**

```bash
git add shell/kitty kitty/kitty.conf tests/bin/test_kitty_theme.py
git commit -m "feat: switch kitty themes to semantic assignment"
```

### Task 8: Add explainability commands and final verification [Completed]

**Files:**
- Modify: `bin/kitty-theme`
- Modify: `tests/bin/test_kitty_theme.py`
- Modify: `docs/plans/2026-03-12-semantic-kitty-themes-design.md`

**Step 1: Write the failing tests**

Add tests for an inspection command:

- shows current project root
- shows cluster id and confidence
- shows top terms and assigned theme
- shows override mode and effective theme when active

Example:

```python
def test_explain_command_reports_effective_assignment(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run:

```bash
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: FAIL because explainability output is not implemented yet.

**Step 3: Write minimal implementation**

Add a `kitty-theme explain` command using `rich` for clear terminal output. Update the design doc only if implementation discoveries require narrowing or clarifying the agreed design.

**Step 4: Run verification to confirm everything passes**

Run:

```bash
uv run --frozen ruff check .
uv run --frozen pyright
uv run --frozen pytest tests/bin/test_kitty_theme.py -q
```

Expected: PASS for linting, types, and tests.

Manual verification in kitty:

- `cd` between two configured projects and confirm a subtle fade occurs
- trigger manual overrides and confirm they animate
- confirm temporary vs sticky override behavior
- confirm reset returns to semantic assignment
- run `kitty-theme explain` and confirm the reported state matches the visible theme

**Step 5: Commit**

```bash
git add bin/kitty-theme tests/bin/test_kitty_theme.py docs/plans/2026-03-12-semantic-kitty-themes-design.md
git commit -m "feat: add semantic kitty theme inspection"
```
