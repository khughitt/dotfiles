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
Runtime health, setup.sh installation and live desktop validation are separate
host actions. Worktree hydration uses the frozen uv lock; do not run the live
installer to prepare a test fixture or repoint a shared launcher to a worktree.
