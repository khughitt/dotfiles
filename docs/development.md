# Development and verification

Type: guide; document types 1.

This guide covers isolated development, test policy and documentation maintenance.
[Host setup](setup.md) covers installation; [desktop themes](desktop-themes.md)
covers the palette contract. Development commands do not authorize live setup.

## Prepare a worktree

Use a task worktree under `.worktrees/`. In a synced checkout, run
`work-link --ensure .worktrees` before `git worktree add`; lock the resulting
worktree on its host storage. Hydrate with `uv sync --frozen` inside it, using
`work-link --ensure .venv` for the synced main checkout. Never use live `setup.sh`
as worktree hydration. The lockfile determines dependencies.

## Focused checks

```sh
just test-one pytest tests/front_door_test.py -k guide_hygiene_and_docs_recipe
just test-one zsh tests/console_keymap.zsh
just check-hygiene
```

`just test-one <runner> <args...>` accepts `pytest`, `zsh` and `nvim`, forwarding
arguments intact through [tools/test-one](../tools/test-one). Use the runner and
case that exercise the changed behavior. Prose-only edits need no invented tests.
For bootstrap, installed hooks, Noctalia or host interaction changes, also choose
an explicit affected integration check before live use. Run worktree code by its
own path; never repoint a shared launcher to test it.

The validated [.tt.toml](../.tt.toml) disables automatic broad requests for
`test`, `check-code` and `test-portable`. A skip starts no child and records a null
outcome: it is not a pass. Missing policy enables broad work; invalid policy fails.
Focused checks and `just check-hygiene` always run. Hygiene includes format/source
syntax, links/modelines, promoted-glass consistency, generated guide regions and
private task-record checks. Known failures still need an explicit disposition.

Deliberate broad checks are `just test-full`, `TT_FORCE=1 just test-portable`, and
`TT_FORCE=1 just check`. The full test route retains Python discovery and eleven
Zsh scripts, including nested Neovim. Supplementary Noctalia checks are separate.
`gate` composes check/test; `verify` additionally checks actual host health. A
policy skip establishes neither a passing suite nor a healthy host.

## Public clone and CI

A standalone clone can use `just ci-hygiene` without private records or live
promoted state. This is a narrower source check than local hygiene. It does not
establish installed links, active services, GPU behavior or host health.

The Ubuntu 26.04 workflow installs ordinary command-line packages and three
hash-pinned uv/Python/Just downloads, then uses the frozen lockfile. `just ci-test`
forces source hygiene plus seven Python modules: front-door, kernel-gate, and the
five niri modules for column paging, backdrop startup, dropdowns, scratch UI and
scratch parsing. They use fake host APIs; no desktop starts.

[tools/test-suite.py](../tools/test-suite.py) requires a fresh absolute
`CI_STATE_DIR` outside the checkout and explicit installed `UV_PYTHON` for its
`ci` mode. CI isolates HOME/XDG/Git/cache/TT state and supplies an explicit child
environment. It retains source SHA, output, selected/excluded modules, JUnit
counts and phase/outer status for fourteen days, with a fifteen-minute job limit.
Empty or failed execution cannot pass.

Other Python modules, full Zsh/real Neovim integration, Noctalia/GPU/systemd/console
behavior and live configuration are outside automatic CI. CI does not provision
Noctalia/Git builds, shell/editor plugins or parsers. A clean local rehearsal is
not evidence of a hosted run.

## Hooks and documentation

Prepared project hooks retain SSH keepalive checks and push stdin. Their local
installation and workflow publication are separate operations. `ci_suite_refs`
stays empty because portable CI does not cover the full suite. The push hook
warns when local policy skips a suite with no declared remote coverage. Hosted
broad requests require `TT_FORCE=1`, including nested requests.

The pre-commit hook classifies every staged path against `docs_paths`; a mixed
change or classification failure takes the normal route. A docs-only commit uses
the docs gate. These are recorded through the same test front door.

Edit [identity.toml](../identity.toml), then run `just docs` to regenerate root
identity regions; `python3 tools/ops-docs check` detects drift. README requires
Setup, Usage, Layout, Consumers; AGENTS requires Setup, Gates, Layout, Rules.
Current subject references live in `docs/`, use document-types standard 1 and are
updated with their source behavior. State combined types where needed; protocols
include Failure. Keep new dated specs, plans, task IDs and private evidence out of
public guides. Historical material belongs in the project's records destination;
keep public runtime citations pointed at current references.
