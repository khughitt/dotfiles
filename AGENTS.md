# dotfiles — agent guide

- Task records, design specs, implementation plans, briefs and handoffs live in the
  records root (`tasks where` names it); they are committed there. `docs/specs/` keeps
  only the designs that `bin/noctalia-glass-sync` cites.

## Verification

Use `just test-one <runner> <args...>` for changed behavior. Runners are `pytest`
(a path, node id or `-k` filter), `zsh`, `lua`, and `nvim` (existing headless
initialization arguments). Each argument reaches the runner intact. The existing
`just test-resource-alert` remains a deliberate three-harness component check.

`just check-hygiene` always runs source/formatting/record checks; `check-code`
runs ShellCheck and the existing three configuration regression scripts.
`just check` composes both, and `just gate` adds the complete test route.
`just verify` also runs actual host health; a skipped suite is not host proof.

`tools/tt` owns `.tt.toml` lookup at this checkout's Git root. Missing policy keeps
broad work enabled. Invalid policy fails. With valid automatic_broad=false,
the classified `test` and `check-code` targets skip without a child and record
null outcomes; focused tests and hygiene still execute. Use `just test-full`
or `TT_FORCE=1 just test` for deliberate broad verification, and
`TT_FORCE=1 just check` for deliberate complete checks. Skips are never passes.

The full route preserves the three Lua harnesses, unchanged pytest discovery and
twelve Zsh scripts, including nested source checks and Neovim initialization.
The supplementary Noctalia Neovim runner and science-md.nvim routes remain outside
that route. No affected selector or test-fast target is claimed.

Project hook files are prepared but no main-checkout installation or hosted-suite
coverage is activated here. Both push routes request full tests; no CI ref coverage
is declared yet. Gitleaks is separate security scanning. Hosted broad invocations
require explicit TT_FORCE=1 even under policy-off; a missing override fails.

## Prepared CI

The Tests workflow prepares an Ubuntu 26.04 VM using the hashes and versions in
tools/ci-pins.json. tools/ci-setup accepts only explicit matching container or
GitHub-hosted mode; package installation and source builds belong in that disposable
namespace. It builds real Noctalia and hydrates pinned shell/editor state. Use fresh
state for each run; setup.sh remains a live host installer.

`ci-hygiene` keeps formatting and source checks and omits detached task records.
Its fresh HOME also has no promoted live glass state to validate; fixture tests
still run. `ci-test` forces hygiene, code checks and the complete test route.
`python3 tools/test-suite.py ci` consumes the setup receipt, clears caller
credentials, retains both output streams and reconciles source/pytest collection,
JUnit, ordered native receipts, timing rows and the actual command status.
Missing, duplicate, failed or fully skipped module evidence fails verification.
An outer failure or timeout cannot be accepted through a late green report.

The prepared workflow covers branch pushes and manual runs when published. This
branch still has policy enabled and no declared CI ref coverage; activation requires
accepted hosted coverage. Ubuntu 24.04 and live desktop compatibility are unproved.

Runtime health, setup.sh installation and live desktop validation are separate
host actions. Worktree hydration uses the frozen uv lock; do not run the live
installer to prepare a test fixture or repoint a shared launcher to a worktree.
