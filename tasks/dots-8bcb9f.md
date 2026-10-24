---
id: dots-8bcb9f
title: "Adopt the project-guide contract: identity.toml, generated regions, ops-docs check in the gate"
status: todo
priority: 1
size: s
complexity: mid
process: direct
created: 2026-10-23T20:14:30Z
updated: 2026-10-24T18:57:43Z
depends: []
tags: []
source: ops-2c5fbc
agent: claude-code/claude-opus-5-5
---

Why: dotfiles has no root identity.toml (ops `bin/ops-projects check`, 2026-10-23), so its line in the global Projects block is hand-edited in ops's identity-mirror.toml, no identity region or authority line reaches its guides, and `ops-docs check` reads nothing here. ops-2c5fbc reconciled the project-guides rollout on 2026-10-23: the old sequential wave 3 continues as one adoption task per project, owned by that project. This is dots's.

Contract (ops repository): docs/specs/2026-09-22-project-guides-design.md §3 (identity.toml keys and limits), §4 (README and AGENTS.md section order, the identity region directly after the H1, CLAUDE.md as a one-line `@AGENTS.md` include or symlink, no status prose), §5 (`just docs`; `ops-docs check` after `ops-check` in the check recipe) and §9 step 3 (one adoption commit: identity.toml, the regions, sections reordered, status prose replaced by a pointer to the tracker or the authority document, global-layer restatements deleted, a budget raise declared where AGENTS.md cannot fit the default 120 lines; subsystems declared only where a boundary already has its own README). The default contract applies: this project belongs to no family (docs/specs/2026-10-09-family-guide-templates-design.md). Templates: ops templates/identity.toml, templates/README.md, templates/AGENTS.md and templates/justfile. Vendoring: ops docs/runbooks/project-lifecycle.md §2 step 2 (`vendored adopt ops-docs` in this checkout; bare `vendored` may not be on PATH, so use the explicit invocation in ops README's Consumers section). Before reshaping a guide, grep this repository's tests for reads of README.md or AGENTS.md.

Copy `name`, `aliases` and `purpose` from this project's table in ops's identity-mirror.toml unchanged. A new purpose changes the global Projects block, which needs `just projects` in ops and `just assemble` in lore under their own approval gate: record it here as a proposal instead.

At 2026-10-23: README.md 212 lines; AGENTS.md 4 lines (only the design-docs location), no CLAUDE.md. No tools/ (neither ops-check nor tt vendored) and no .githooks; the justfile has a check recipe. With no pre-commit hook, nothing fires the check on commit: wire it into the check recipe and say so in the done note; installing the front-door hooks (ops lifecycle runbook §2 step 3) is separate work.

Done when: `tools/ops-docs check` exits 0 here with identity.toml present; the project's check route runs it (and so its pre-commit hook, where it has one); and `bin/ops-projects check` in ops no longer lists dots and still exits 0.

Profile: personal; integrate under this repository's own rules.

## Notes

- 2026-10-24T13:48:51Z (main): curate-docs: dots-245e25 at f68131c confirms: One mechanical adoption gap: tools/ops-docs, tools/ops-check and root identity.toml are absent; both required mechanical commands exit 2 without checking guide shape/budgets/paths. Complete the existing tooling/identity/gate adoption.
- 2026-10-24T13:48:52Z (main): curate-docs: dots-245e25 at f68131c confirms: AGENTS.md:3-4 repeats the personal profile committed docs/specs and docs/plans convention. Remove that location/commitment restatement but retain the repository-specific restriction that docs/superpowers holds earlier documents and takes no new docs (one source line saved).
