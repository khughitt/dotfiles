# Semantic Kitty Themes Design

## Goal

Replace the current hash-based kitty project theme assignment with a precomputed semantic mapping from project identity to theme cluster, and add subtle animated transitions for both automatic project switches and manual theme overrides.

The system should make terminal colors feel informative rather than arbitrary:

- nearby projects should tend to share nearby semantic identities
- theme assignment should be stable across sessions
- automatic project changes and manual overrides should animate through short palette fades
- the shell hook should stay lightweight and never depend on expensive live inference

## Scope

### Included in v1

- user-maintained registry of project paths to include in semantic analysis
- offline corpus construction from project docs, metadata, and a light code sample
- precomputed project embeddings and pairwise similarity matrix
- clustering projects into `4-6` latent semantic groups
- deterministic cluster labels from discriminative terms
- curated attractor theme selection for clusters
- runtime cache lookup from git root to assigned cluster/theme
- fast-medium, subtle palette fade on automatic project switches
- the same fade behavior for manual `alt+0..9` overrides
- manual override modes: `temporary` and `sticky`
- confidence-aware fallback to a neutral default theme
- debounce/hysteresis to avoid noisy re-animation during rapid directory changes
- an explainability CLI for inspecting assignment decisions

### Explicitly excluded from v1

- fully generated per-project palettes
- ontology-first or NER-first project classification
- recomputing embeddings live during shell navigation
- image or shader-based transition effects as the primary mechanism
- secondary visual cues such as icons or logos
- automatic response to every file change inside a project

## Main Decisions

### 1. Use precomputed semantic clustering, not live assignment

Theme assignment should be computed offline for a user-selected set of project roots. The runtime shell hook should only perform git root detection, cache lookup, and theme transition.

Why:

- shell navigation remains fast and predictable
- embeddings and clustering can use vectorized batch processing
- pairwise similarity and cluster diagnostics are available globally
- the project set can be recomputed only when the registry changes or a refresh policy triggers

### 2. Use latent clusters with post-hoc labels

Projects should cluster into stable latent groups rather than being forced into a hand-authored taxonomy. Human-readable names should be generated after clustering from discriminative terms.

Why:

- latent structure is likely to fit mixed personal projects better than a fixed ontology
- cluster membership remains driven by the actual embedding geometry
- labeling stays interpretable without becoming part of the classifier

### 3. Use dense embeddings as the primary representation

The main semantic representation should come from symmetric semantic embeddings over project corpora. Symbolic features should be sidecar metadata used for interpretability and cluster naming, not the main similarity space.

Why:

- semantic similarity is the real optimization target
- symbolic ontologies are brittle and high-maintenance
- the sidecar keeps the system explainable without weakening the geometry

### 4. Cluster to fixed attractor themes

Each latent cluster should map to a curated attractor theme selected from a scored theme library. v1 should not synthesize new palettes.

Why:

- fixed themes are safer for readability and ANSI semantics
- transitions are simpler between known-good endpoints
- the current kitty workflow already centers around static theme files

### 5. Animate by interpolating palette values

Theme fades should be implemented by generating intermediate palettes between the current and target theme and applying them in sequence over a short duration.

Why:

- kitty exposes color changes, but not a native palette tween API
- graphics protocol animation applies to images, not terminal theme tables
- repeated palette updates are the most direct way to approximate a fade

## Proposed File Layout

```text
bin/
  kitty-theme

docs/
  plans/
    2026-03-12-semantic-kitty-themes-design.md
    2026-03-12-semantic-kitty-themes.md

kitty/
  semantic-projects.txt
  semantic-themes.json
  theme-candidates/

shell/
  kitty

tests/
  bin/
    test_kitty_theme.py
```

If v1 stays script-first, a minimal Python project should also be added:

```text
pyproject.toml
```

## Architecture

### Offline semantic pipeline

The offline pipeline should read a registry of project roots and build a semantic cache artifact used by runtime.

Per project:

- validate the configured path and determine the canonical git root
- collect project text from `README*`, selected docs files, and package metadata
- collect a light code sample from representative files, capped by file count and byte budget
- summarize structured metadata such as language mix, lockfiles, framework hints, and package names
- assemble a normalized corpus string for embedding and labeling

Batch processing:

- compute embeddings for all projects
- compute the pairwise similarity matrix
- cluster projects into `4-6` latent groups
- compute cluster confidence from distance to centroid or nearest-neighbor structure
- derive top discriminative terms per cluster using `tf-idf` or `BM25`
- optionally pass those terms through an LLM to produce a compact title and description

Output:

- per-project embedding metadata
- pairwise similarity summary
- cluster id and confidence for each project
- deterministic cluster keywords
- optional display label and description
- assigned attractor theme for each cluster
- resolved target theme for each project

### Runtime path

The existing `shell/kitty` hook should remain the runtime entrypoint for automatic theme changes.

Runtime responsibilities:

- detect the nearest git root from `$PWD`
- resolve that root against the semantic cache
- determine whether a manual override is currently active for the kitty window
- choose the effective target theme
- skip work when the target theme is unchanged or negligibly different
- run a short palette transition into the target theme

Runtime should not:

- rebuild embeddings
- recompute clusters
- parse project corpora
- block shell startup on expensive work

### Manual override model

Manual `alt+0..9` overrides should feed into the same transition driver as automatic project changes.

Override modes:

- `temporary`: applies until the next project change
- `sticky`: applies for the current kitty window until reset

Reset behavior:

- an explicit reset action should return the window to semantic assignment

This preserves your existing manual control while making it part of one consistent runtime model.

## Theme Library and Selection

### Theme candidate library

The theme library should begin with the current dark themes and expand by importing additional built-in or community themes using kitty tooling such as `kitten themes --dump-theme`.

Each candidate should be normalized into a structured representation containing at least:

- background
- foreground
- selection colors
- cursor colors
- key ANSI colors

### Quality scoring

Attractor themes should be selected through explicit scoring rather than informal taste alone.

Scoring criteria:

- minimum foreground/background contrast
- distinct ANSI colors for common terminal workflows
- visible cursor and selection states
- low red/green ambiguity risk
- pairwise perceptual separation from the rest of the selected attractor set

The chosen `4-6` attractors should maximize diversity subject to these readability constraints.

## Transition Design

### Default feel

Transitions should be `fast-medium/subtle`:

- target duration: about `200-300 ms`
- step count: about `10-14`
- eased interpolation rather than strictly linear timing

### Interpolation boundary

Only a defined set of theme keys should be interpolated. Unknown config lines should not participate in animation.

Interpolated fields should likely include:

- background
- foreground
- selection colors
- cursor colors
- core ANSI colors

Non-color config such as font or layout should stay static.

### Debounce and hysteresis

Runtime should suppress unnecessary motion:

- debounce rapid consecutive project changes
- skip transitions when the target is unchanged
- skip or shorten transitions when the visual delta is tiny
- avoid re-animating repeatedly within a short cooldown window

## Errors and Fallbacks

### Offline failures

The offline pipeline should fail early when:

- a configured project path does not exist
- a path is not a git project and that is required by policy
- a theme candidate cannot be parsed
- the cache cannot be written cleanly

Failures should be explicit and actionable.

### Runtime failures

Runtime should fail safe:

- if the cache cannot be read, fall back to the neutral default theme
- if the current git root is not in the registry, use the neutral default theme
- if a target theme file is missing, use the neutral default theme
- if transition setup fails, apply the final target theme directly

The shell hook must never become fragile or slow because of semantic theming.

### Confidence-aware fallback

Projects that do not fit any cluster confidently should not be forced into an overconfident semantic identity.

Policy:

- compute confidence per project
- when confidence is below threshold, assign a neutral fallback theme or the nearest stable attractor with a low-confidence marker
- surface this in the explainability CLI

## Inspection and Explainability

Add a small CLI for inspecting semantic assignments and runtime state.

Suggested output:

- current git root
- effective project id
- cluster id
- confidence
- top cluster terms
- human-readable label and description when available
- assigned attractor theme
- active override mode and current effective theme

This keeps the system inspectable and easier to debug.

## Testing Strategy

### Unit tests

Add tests for:

- project registry parsing and validation
- corpus sampling from docs, metadata, and code
- stable cache serialization and lookup
- cluster labeling from term statistics
- theme parsing and normalization
- palette interpolation math
- override precedence
- runtime fallback behavior

### Regression tests

Use a small fixture set of fake projects to verify:

- clustering remains stable enough for repeated runs
- low-confidence projects fall back correctly
- manual overrides supersede semantic assignment correctly
- reset returns control to semantic assignment

### Manual verification

Verify in a real kitty session:

- automatic transition on `cd` between configured projects
- no transition spam during rapid directory hops
- `alt+0..9` overrides animate rather than jumping
- sticky and temporary overrides behave as designed
- the explainability CLI matches the visible theme outcome

## Risks

### Project corpus quality

Some projects have weak or misleading documentation. A docs-only pipeline would overfit sparse metadata; a code-only pipeline would overfit language and tooling noise. The mixed corpus approach is intended to reduce both risks, but sampling quality will still matter.

### Theme distance is not semantic distance

Even with good semantic clustering, the visual distance between themes is an independent design choice. The attractor set must be curated so that semantic proximity remains readable without collapsing into near-identical palettes.

### Animated palette updates may show artifacts

Repeated remote color updates may produce slight flicker or timing variability depending on terminal load and environment. The transition system should be designed so it can fall back to direct application if animation quality is poor.

## Future Directions

- add subtle intra-cluster theme variation for projects that share a cluster but differ locally
- refresh semantic assignments based on meaningful project-content changes rather than age alone
- add secondary visual cues such as tab-title markers or window logos
- explore background-image polish only if it complements, rather than replaces, palette transitions
- experiment with richer latent-space layouts or project-to-variant mapping inside each attractor cluster
