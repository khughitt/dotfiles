---
id: dots-0e0cc5
title: "zshenv: keep inherited XDG_CONFIG_HOME and XDG_STATE_HOME instead of overwriting them"
status: done
priority: 2
size: xs
complexity: low
process: direct
owner: dots-0e0cc5
created: 2026-10-09T01:29:21Z
updated: 2026-10-11T11:16:42Z
started: 2026-10-11T09:16:52Z
completed: 2026-10-11T09:56:15Z
depends: []
tags: []
source: hq-c19b34
agent: claude-code/claude-opus-5-5
---

zshenv exports XDG_CONFIG_HOME=$HOME/.config and XDG_STATE_HOME=$HOME/.local/state unconditionally. zsh reads zshenv on every start, so a harness hook run through zsh replaces an isolated root the run inherited (XDG_CONFIG_HOME=$(mktemp -d) for a scratch tasks registry, for example), and the hook then reads a different claim inventory from the session's own tools. Use the default-preserving form, export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" (same for XDG_STATE_HOME), and check that an isolated root survives zsh -c and zsh -lc.

## Notes

- 2026-10-11T09:16:52Z (main): started
- 2026-10-11T09:18:25Z (dots-0e0cc5): resumed
- 2026-10-11T09:18:25Z (dots-0e0cc5): took over Unix session (owner main, stale)
- 2026-10-11T09:56:15Z (dots-0e0cc5): verified: worktree zshenv via ZDOTDIR — isolated root survives zsh -c and zsh -lc, unset falls back to ~/.config and ~/.local/state. just check green; just test fails at tests/setup_and_health.zsh noctalia stub assertion, pre-existing on main.
- 2026-10-11T09:56:15Z (dots-0e0cc5): done
- 2026-10-11T09:56:15Z (dots-0e0cc5): zshenv now uses default-preserving form for XDG_CONFIG_HOME and XDG_STATE_HOME so inherited isolated roots survive zsh -c and zsh -lc; verified via ZDOTDIR test against the worktree file
- 2026-10-11T11:16:41Z (dots-0e0cc5): review: impl round 1 — verdict: revise; findings: missing-regression-test 1, minor 2; reviewer: claude-code/claude-opus-5-5
- 2026-10-11T11:16:42Z (dots-0e0cc5): added regression tests test_zshenv_keeps_inherited_xdg_roots / test_zshenv_defaults_unset_xdg_roots (RED on main's zshenv, GREEN on fix, focused run); kit now honours XDG_CONFIG_HOME. just check green; just test still stops at dots-90f33d.
