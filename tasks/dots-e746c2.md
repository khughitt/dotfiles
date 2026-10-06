---
id: dots-e746c2
title: "Install dotfiles-health as a link, not a copy"
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: fix/health-link
created: 2026-10-04T11:41:10Z
updated: 2026-10-06T13:34:31Z
started: 2026-10-06T13:23:29Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

Why: on europa ~/bin/dotfiles-health is a regular file dated 2026-09-21, not a link into the checkout, so DOTS_HOME resolves to the home directory and the script dies sourcing ~/lib/dotfiles-setup-data.bash. Done: setup.sh links it (and anything else under bin it installs) and dotfiles-health itself flags a copied rather than linked install; verified on europa.

## Notes

- 2026-10-06T13:23:29Z (main): started
- 2026-10-06T13:23:32Z (main): starting: worktree under .worktrees/
- 2026-10-06T13:24:10Z (fix/health-link): resumed
- 2026-10-06T13:34:31Z (fix/health-link): impl: bin link is its own setup phase; health flags a copied install (early self-check plus ~/bin link check); ops stub added to the test harness
