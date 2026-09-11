# Whole-review documentation fix

## Change

Corrected the wali verification summary in
`docs/specs/2026-09-11-wali-extraction-design.md` to match the actual
`/mnt/ssd/Dropbox/wali/justfile`: `just verify` runs `check test`, with
justfile formatting, zsh syntax, `tasks check`, pytest, the zsh suite, and the
Lua plugin test. The summary separately records the one-time Ruff and Pyright
results and the `wali-3bbc34` Ruff follow-up.

## Verification

- `git diff --check` — passed.
- `rg -n "wali:.*just verify|just verify.*pytest|ruff.*pyright|Pyright.*Ruff|Ruff.*Pyright" docs .superpowers tasks README.md --glob '*.md' --glob '*.txt'` — no other current extraction claim matched; historical implementation instructions and reports were left unchanged.

Documentation commit: `639bb15aab0317380da0678e1721cc6fcb90c8a6`.
