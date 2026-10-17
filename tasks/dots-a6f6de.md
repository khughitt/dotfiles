---
id: dots-a6f6de
title: "dropdown: tasks-tui as a toggled tasks view"
status: todo
priority: 2
size: xs
complexity: low
process: direct
created: 2026-09-06T17:27:07Z
updated: 2026-10-17T21:18:54Z
depends: []
tags: [niri, dropdown]
---

Why: a tasks view one keypress away, over whatever workspace is open, without taking a window on any workspace. Follow-up to dots-7b24fa (the dropdown mechanism), filed with it on 2026-09-06; its original body read "another quick-access-terminal instance group running this tool".

Established (scope 2026-10-17):
- The tool exists: tasks-tui (the `tui` project, a Bubble Tea front end over the tasks CLI) is installed as `tui` in ~/go/bin, which is on niri's spawn PATH. `tui --all` opens the Projects view whatever the cwd; a project opens on Ready/Doing/Open/Ideas/Done tabs, and `c l`/`c o` launch a harness in a new terminal in the task's checkout.
- The pattern to copy is the `ghci` and `mindful` cases (dots-464460, dots-8cf055): one case line in niri/scripts/dropdown, a hidden pre-spawn in niri/config.kdl's spawn-at-startup block, an Alt+<key> bind with a hotkey-overlay-title, a cheatsheets/niri row, and a test in tests/niri/test_dropdown.py asserting instance group, app_id and command.
- A hidden pre-spawned instance costs little: tui refreshes every 30 s by default, and `tasks projects` took 0.16 s here.

Done when:
- `niri/scripts/dropdown tasks` runs `tui --all` in instance group and app_id `dropdown-tasks`, with exclusive focus like the terminals and about 40 lines; the usage line lists it.
- niri/config.kdl pre-spawns it hidden and binds it (suggested Alt+T: it shadows readline's transpose-words the way Alt+P and Alt+M already shadow theirs; pick another key if that matters), and cheatsheets/niri gains the row.
- tests/niri/test_dropdown.py covers the case: `uv run --frozen pytest -q tests/niri/test_dropdown.py`, then `just test` before committing.
- Live check: the bind shows and hides the view on the focused output, and the keyboard returns to the window underneath on hide. Taking the live desktop asks first; run the worktree's copy by explicit path (`.worktrees/<name>/niri/scripts/dropdown tasks`) and kill that instance at merge, so the bind and pre-spawn run the main checkout's copy (as dots-8cf055 did).

Where: niri/scripts/dropdown, niri/config.kdl (spawn-at-startup and the Alt+Return/Alt+P/Alt+M binds), cheatsheets/niri, tests/niri/test_dropdown.py.
