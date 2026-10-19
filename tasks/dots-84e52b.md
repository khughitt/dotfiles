---
id: dots-84e52b
title: "Dropdown: a dashboard case that runs lookout"
status: todo
priority: 2
complexity: mid
process: direct
created: 2026-10-19T14:17:39Z
updated: 2026-10-19T14:17:45Z
depends: [look-56087a]
tags: [niri, dropdown]
source: look-1f22ce
agent: claude-code
---

Task 9 of the lookout v1 plan (look-1f22ce; lookout docs/plans/2026-10-19-lookout-v1.md, "Task 9 (dotfiles): The dropdown case"). Add a `dashboard` case to niri/scripts/dropdown (40 lines, exclusive focus; instance group and app_id `dropdown-dashboard`, last argument `lookout`), a hidden pre-spawn and a bind in niri/config.kdl (the owner picks the key; suggest Alt+D), and a cheatsheets/niri row. Test first in tests/niri/test_dropdown.py. Runs in a dotfiles worktree; the live check needs the owner's approval to use the desktop. Consumes `lookout` on PATH per lookout's README.

Done when: the test passes, `just test` is green, and the owner has seen the dropdown open lookout live.
