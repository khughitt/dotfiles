# dotfiles — agent guide

- Task records, design specs, implementation plans, briefs and handoffs live in the
  records root (`tasks where` names it); they are committed there. `docs/specs/` keeps
  only the designs that `bin/noctalia-glass-sync` cites.

## Verification

Use `just test-one <runner> <args...>` for changed behavior. Runners are `pytest`,
`zsh`, `lua`, and `nvim`; arguments reach the selected runner intact. The existing
`just test-resource-alert` is a deliberate three-harness component check.

This is personal Linux configuration. Incomplete automatic integration coverage
and delayed discovery are accepted. `.tt.toml` disables automatic broad requests
for `test`, `check-code` and `test-portable`. Skips launch no child and record null
outcomes; they are never passes. Missing policy enables broad work; invalid policy
fails. Focused tests and `just check-hygiene` always run, including formatting,
source syntax, link/modeline checks, local promoted-glass consistency and records.

Use `just test-full` for deliberate complete Lua/Python/Zsh/Neovim verification,
`TT_FORCE=1 just test-portable` for the portable subset, and `TT_FORCE=1 just check`
for complete checks. `gate` composes check/test and `verify` also inspects actual
host health; a policy skip does not prove either tests or host health. The full
route retains three Lua harnesses, unchanged pytest discovery and twelve Zsh
scripts including nested Neovim. Supplementary Noctalia/science-md.nvim routes
remain outside it. No affected selector or test-fast route is claimed.

Run affected focused tests while implementing. After changes to shell/editor
bootstrap, setup, installed hooks, Noctalia templates/plugins or host interactions,
choose and record the relevant explicit local integration check, particularly
before live application. Unrelated configuration edits do not require full runs.
Broad diagnosis and cross-cutting changes may justify a deliberate full run.
With valid policy-off, commits, review and integration do not themselves require
broad reruns. Known failures still require a fix or explicit disposition.

## Portable CI

`just ci-test` forces source hygiene and the portable subset only. The subset is
three resource-pressure-alert Lua harnesses and seven Python modules:
`tests/front_door_test.py`, `tests/kernel_gate_test.py`, and the five existing
`tests/niri/` modules for column paging, backdrop startup, dropdowns, scratch UI and
scratch parsing. These use fake host APIs/commands; no desktop is started.

The Ubuntu 26.04 workflow uses ordinary command-line packages and three hash-pinned
uv/Python/Just downloads, frozen uv.lock, isolated HOME/XDG/Git/cache/TT state and
an explicit child environment. `python3 tools/test-suite.py ci` requires a fresh
absolute CI_STATE_DIR outside the checkout and an explicit installed UV_PYTHON.
It retains output, source SHA, selected/excluded modules, JUnit counts, phase
results and outer status; failed or empty execution cannot pass. Artifacts retain
only evidence for fourteen days. Jobs have a fifteen-minute ceiling.

Other Python modules, full Zsh/real Neovim integration, installed Noctalia/GPU/
systemd/console behavior and live configuration are not verified automatically.
`ci-hygiene` omits unavailable detached records and live promoted-state inspection;
its fresh HOME does not establish those host guarantees. Noctalia/Git builds and
shell/editor/plugin/parser provisioning are not part of CI.

`ci_suite_refs` deliberately stays empty: portable CI is not full-suite push
coverage. Prepared project hooks preserve the honest uncovered-push warning, SSH
checks and stdin. Their repository-local installation and workflow publication
remain separately gated; no hooks are installed by merging source files. Hosted
broad work requires explicit TT_FORCE=1, including nested requests.

Runtime health, setup.sh installation and live desktop checks remain explicit
host actions. Hydrate worktrees with frozen uv, not the live installer, and never
repoint host launchers into a worktree. Local adoption does not claim a hosted pass.
