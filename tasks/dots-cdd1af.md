---
id: dots-cdd1af
title: Verify lookout's q→relaunch in the dashboard dropdown with wtype
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-19T18:16:55Z
updated: 2026-10-19T18:16:55Z
depends: []
tags: [niri, dropdown]
agent: claude-code
---

Why: the dropdown's live check could not press a real `q` (no key-injection tool); killing lookout ended the instance and the next Alt+D relaunched it, but the keypress path and the cheatsheet's claim ('q quits it; the next toggle relaunches') are unverified. niri advertises zwp_virtual_keyboard_manager_v1, so `wtype` (Arch extra) can type into the focused dropdown. Add wtype to the host package list, then: toggle the dashboard, `wtype q`, toggle again, confirm a fresh instance renders. Done when verified or the cheatsheet is corrected.
