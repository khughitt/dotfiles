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
- `just test` — Python and initial shell checks passed (80 Python tests, dropbox/history/secrets checks); `tests/setup_and_health.zsh` failed on its existing live Noctalia expectation: `unexpected Noctalia test command: msg plugins disable test/never-live`.

Files changed: `bin/walictl`, `tests/bin/test_walictl.py`.

Self-review found no task-scoped issues. The full repository test command has the unrelated setup/health failure noted above; transitional consumers are expected to fail until later tasks.
