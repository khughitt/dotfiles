---
id: dots-45b45d
title: "dropdown: mindful-tui for finding and reading thoughts"
status: todo
priority: 2
size: s
complexity: mid
process: direct
created: 2026-09-06T17:27:07Z
updated: 2026-10-17T21:19:43Z
depends: []
tags: [niri, dropdown]
---

Why: the mind6 "quick thought i/o terminal", capturing and finding thoughts with one keypress over any workspace. Follow-up to dots-7b24fa, filed with it on 2026-09-06; its original body read "another quick-access-terminal instance group running this tool". The capture seed behind the scratchpad (mindful:thought:becb975d687b4b8d8d2e3ff8eef11180) names the aim: "i/o; reduce friction to find or capture thoughts".

Established (scope 2026-10-17):
- The input half landed: dots-8cf055 (e844874, 2026-09-22) is the Alt+M scratchpad dropdown (nvim, then mindful-scratch-op, then ops's mindful-op; it hides before it posts). Its mind6 follow-ups, mind6-f105a9 (capture latency) and mind6-d3b92a (context from the web's subject), are shelved. What remains is the output half: finding and reading thoughts.
- The tool for it exists: mindful-tui (mind6's packages/tui, on OpenTUI; launcher in ~/bin, on niri's spawn PATH) talks to the running mindful-web.service (MINDFUL_WEB_ORIGIN, default http://localhost:3331). It offers search, a thought reader with related and similar hops, editing, and its own scratch panel. It holds no data directory, so it does not contend for the web's writer lock.
- It exits with one line when nothing answers at the web origin. mindful-web.service is WantedBy default.target with no ordering against niri, and it restarts on its own schedule (it last started 2026-10-17 17:07, a day after niri). A hidden pre-spawn at login can therefore race it, and a restart can strand a hidden instance.
- The pattern to copy is the `mindful` case and its loop script (niri/scripts/dropdown, niri/scripts/mindful-scratch), with tests/niri/test_dropdown.py.

Done when:
- A dropdown case (suggested name `thoughts`; instance group and app_id `dropdown-thoughts`) runs mindful-tui with exclusive focus, sized like ipython.
- A web that is down at spawn, or restarts while the dropdown is hidden, does not leave a dead toggle. First establish mindful-tui's exit status with no web, and whether its /api/events feed reconnects after a web restart. Then either wrap it in a retry loop beside the script (a clean exit ends the loop) or skip the hidden pre-spawn, and record which and why in a note.
- niri/config.kdl binds it (suggested Alt+Shift+M, beside Alt+M's capture) and pre-spawns it if that was chosen; cheatsheets/niri gains the row; tests/niri/test_dropdown.py covers the case: `uv run --frozen pytest -q tests/niri/test_dropdown.py`, then `just test` before committing.
- Live check: search, open a thought, hop to a related one, hide and show again with state kept, and confirm thought sprites render inside the kitty quick-access surface (OpenTUI and kitty's placeholder cells have clashed elsewhere). Taking the live desktop asks first; run the worktree's copy by explicit path and kill that instance at merge.

Where: niri/scripts/dropdown, niri/scripts/mindful-scratch (the loop pattern), niri/config.kdl, cheatsheets/niri, tests/niri/test_dropdown.py; keys and environment in mind6's packages/tui/README.md.

## Notes

- 2026-10-17T21:19:43Z (main): scope: scoped; idea -> todo P2 s mid direct, retitled from 'mind6 quick thought i/o terminal'; the capture half landed as dots-8cf055 (e844874), so this is the find/read half over mindful-tui; mid for two bounded unknowns (exit status with no web, reconnect after a web restart); checked at 69e226c
