---
id: dots-06eb59
title: "dropdown: ops dashboard"
status: idea
priority: 2
created: 2026-09-06T17:27:07Z
updated: 2026-10-17T22:25:13Z
depends: []
tags: [niri, dropdown]
---

Follow-up to dots-7b24fa: another quick-access-terminal instance group running this tool.

## Evidence (scope 2026-10-17)

- No terminal "ops dashboard" exists to run. ops's bin/ holds host-load (machine load and orphans), host-budget, tt-latency, tt-report and ops-projects, and none of them is a live view. obs's dashboard is a static browser page written by `obs dashboard build` (obs-48acc0, obs-84dd35); its terminal counterparts are `obs dashboard summary` and `obs findings`, run as `python3 obs.py …` with nothing on PATH. `tasks prime --all-projects`, `tasks lanes` and `tasks claims` print once and exit. The tasks view has its own dropdown task, dots-a6f6de (tasks-tui).
- Adding the dropdown case itself follows the xs pattern dots-a6f6de uses (a case in niri/scripts/dropdown, a bind, a hidden pre-spawn, a test). What it shows is the open part.

## Open questions

1. What should the ops dashboard show, and from which tool? (a) A periodically refreshed text view composed from existing commands (host-load, `tasks claims`, `tasks lanes`): a small dotfiles script. (b) obs's live view (`obs dashboard summary` or `obs findings`) on a refresh, which needs an obs launcher on PATH. (c) Something else you had in mind when this was filed on 2026-09-06. Lean: (a), unless you meant obs's numbers.

## Notes

- 2026-10-17T21:20:19Z (main): scope: question; no terminal ops dashboard exists to run (ops bin/ has no live view; obs's dashboard is a browser page, its terminal summary is off PATH); body gains the evidence and one open question: what it shows, (a) a refreshed composition of host-load and tasks claims/lanes, (b) obs dashboard summary/findings, or (c) what was meant; checked at 69e226c
- 2026-10-17T22:25:13Z (main): answer (user, 2026-10-17): do a wider, deeper exploration and brainstorm across the projects most active with ops (tasks, obs, fam, crew, mind6). Consider what is useful to convey; interactive or read-only (e.g. the transponder inbox, a task launcher); nested or multiscale (a home view of all projects, each with a space, then a concise full-page view per project); keeping it uncluttered while conveying the most useful text and visuals; snapshot (point) vs change (rates, gradients); fam art (the video-game art style ideas in trans); other considerations.
