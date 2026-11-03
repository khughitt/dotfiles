# Files vendored from ops

Some files in this directory are maintained in the ops repository,
https://github.com/khughitt/ops (private for now; planned public), and copied here
unchanged. ops holds the shared tooling and vocabularies that a family of projects run in
the same way. This project holds only some of the files below; apart from this README,
any file in this directory that the table does not name belongs to this project itself.

| File | What it is | How this project uses it | Source in ops |
|---|---|---|---|
| `tt` | A timing wrapper: `tt <target> -- <command>` runs the command and appends one record of the run to a local log | The project's recipes run their gates (tests, checks) through `tools/tt` | `bin/tt` |
| `ops-check` | Hygiene checks shared by every project: references in the guides, layout, and the vendored contracts | The project's check command runs `tools/ops-check` first, so the pre-commit hook, `just check` and CI all run it | `bin/ops-check` |
| `ops-docs` | Renders and checks the project's guides, `README.md` for people and `AGENTS.md` for agents, from `identity.toml`; in a project declaring `[documents]`, also the type markers of its public reference documents | The project's docs recipe runs `tools/ops-docs write`; its check runs `tools/ops-docs check` | `bin/ops-docs` |
| `cli.toml` | The shared command-line vocabulary and the inventory of every in-scope command | A conformance test builds the project's parser surface and compares it with its rows here | `cli.toml` |
| `cli_surface.py` | The helper that builds a parser surface for that comparison | Imported by the conformance test, beside `cli.toml` | `bin/cli_surface.py` |
| `keys.toml` | The shared key vocabulary and the inventory of every application shortcut | A test compares the project's live key bindings with its rows here | `keys.toml` |
| `family.toml` | The project family's member list and shared text | `tools/ops-docs` renders the family section of the guides from it | the family home's `family.toml`, written by `ops-docs family publish` |

## Never edit these files here

A change is made in ops and lands on its default branch first; then it arrives here:

- `tt`, `ops-check`, `ops-docs` and this README are written into every project that
  holds them by `vendored publish`, run in ops right after the change lands.
- `cli.toml`, `cli_surface.py` and `keys.toml` arrive when this project runs
  `vendored adopt` together with the change of its own that needs them.
- `family.toml` arrives from the family home.

ops's `vendored check` reports any copy edited in place.
