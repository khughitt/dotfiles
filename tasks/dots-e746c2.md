---
id: dots-e746c2
title: "Install dotfiles-health as a link, not a copy"
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-10-04T11:41:10Z
updated: 2026-10-04T11:41:10Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

Why: on europa ~/bin/dotfiles-health is a regular file dated 2026-09-21, not a link into the checkout, so DOTS_HOME resolves to the home directory and the script dies sourcing ~/lib/dotfiles-setup-data.bash. Done: setup.sh links it (and anything else under bin it installs) and dotfiles-health itself flags a copied rather than linked install; verified on europa.
