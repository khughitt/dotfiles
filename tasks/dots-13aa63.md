---
id: dots-13aa63
title: Track familiar/identities.yaml as shared configuration instead of per-machine state
status: todo
priority: 2
size: s
complexity: low
process: direct
created: 2026-10-17T21:03:50Z
updated: 2026-10-17T21:03:50Z
depends: []
tags: [familiar]
source: fam-a877b3
agent: claude-code
---

Why: the user decided (2026-10-17, fam-a877b3) that every host shares one familiar identity catalog. familiar only reads identities.yaml (fam-090b35: it is authored configuration; only path selectors bind to a host), and the live catalog pins only ~/d/... paths, which the ~/d convention makes portable; a pin for a directory absent on a host is inert. Today dotfiles gitignores it (.gitignore:82), lists it in lib/dotfiles-setup-data.bash:29 for the com.dropbox.ignored mark, and tests that mark (tests/setup_and_health.zsh ~2026-2061).

Done: familiar/identities.yaml is tracked; its .gitignore line and DOTFILES_DROPBOX_IGNORED entry are gone; the Dropbox mark is cleared on the live file (attr -r com.dropbox.ignored) so it syncs; the setup/health tests no longer expect it ignored; before committing, compare the copies on each host and reconcile any difference deliberately (never by mtime or union) — the brief's cutover steps in familiar docs/notes/2026-10-07-project-identity-brief.md apply. Removes this file's share of dots-85a593 (atomic save drops the mark).

Where: .gitignore, lib/dotfiles-setup-data.bash, tests/setup_and_health.zsh, familiar/identities.yaml.
