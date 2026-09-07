# Task 1 report

Status: DONE_WITH_CONCERNS

Implemented the XDG config/state paths, frozen `Sampling` and `Config` models, TOML loading with required/optional values, tilde expansion, symlink resolution, sampling validation, and the transitional `main` stub. Expected `OSError`/`UnicodeError` failures now exit 1 with flattened one-line stderr; argparse behavior remains unchanged. Removed unused preamble imports so Ruff passes.

TDD evidence:

- RED: the task brief's expected baseline was the old CLI without `load_config`, `Sampling`, or the new `main`; the replacement focused tests cover those missing interfaces.
- GREEN: `uv run --frozen pytest -q tests/bin/test_walictl.py` — 23 passed.

Validation:

- `uv run --frozen ruff check --no-cache bin/walictl tests/bin/test_walictl.py` — passed.
- `uv run --frozen pyright` — 0 errors, 0 warnings, 0 informations.
- `tasks check` — passed with no errors or warnings.
- `just test` — Python suite passed: 80 passed in 27.33s. `tests/dropbox_ignore_flux.zsh`, `tests/history.zsh`, and `tests/secrets_check.zsh` passed. It then failed in `tests/setup_and_health.zsh` immediately after the deliberate unknown-command probe printed `unexpected Noctalia test command: msg plugins disable test/never-live`. That test installs a stub which intentionally handles only `msg plugins enable ...` and `msg plugins list`; it invokes `msg plugins disable test/never-live` specifically to assert unknown mutating commands return status 64. The command's expected diagnostic was emitted, but the script did not reach its final `setup and health tests passed` line, so the aggregate command exited nonzero. This is an existing setup/health harness failure outside the two assigned files.

Files changed: `bin/walictl`, `tests/bin/test_walictl.py`.

Self-review found no task-scoped issues. Transitional consumer failures are expected until later tasks.
