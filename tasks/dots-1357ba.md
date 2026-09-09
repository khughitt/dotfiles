---
id: dots-1357ba
title: Document the per-machine artifact class and a new-machine checklist
status: done
priority: 2
size: s
owner: main
created: 2026-09-08T15:13:04Z
updated: 2026-09-09T09:41:48Z
depends: []
tags: [docs, bootstrap, multi-machine]
---

Found bringing europa (laptop) up to date on 2026-09-08 after ~3 weeks. prism node_modules, the niri-material package, noctalia-qs, familiar node_modules, ~/.config/mindful.env and ~/.config/tasks/projects.toml are all invisible to both git and Dropbox, and nothing names them as a class. Outcome: README documents what does not sync and how to reproduce each on a new machine, so a fresh install by someone else is not reverse-engineered from crashes.

## Notes

- 2026-09-08T22:44:31Z (main): The per-machine artifact class now has a concrete rule to state, verified in dots-e4570d and dots-708876: whole-directory ~/.config symlinks into the shared tree are the leak surface (niri, hypr, kitty, zathura leak; btop, yazi, bat, lsd, gtk-3.0, fastfetch, all real dirs, cannot). Anything per-machine belongs in XDG_STATE_HOME. Two Noctalia behaviours worth recording for whoever writes the checklist: it writes through a symlink rather than replacing it, and 'templates-apply' will not force a regeneration - only a real theme change does.
- 2026-09-09T09:41:48Z (main): Two claims in the earlier note are corrected in the README: hypr is no longer one of the leaking config dirs (dots-c618a4 removed it), and templates-apply does force a rewrite of the generated theme output — verified against an emptied file and one holding wrong content (dots-2ee196).
- 2026-09-09T09:41:48Z (main): README documents the three kinds of state, the per-machine artifacts with how to reproduce each, and setup.sh --check as the one command that names them all at once; the stale phase list is corrected too.
