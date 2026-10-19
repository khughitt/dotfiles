---
id: dots-06eb59
title: "Ops dashboard v1: a read-only overview of agents, tasks and obs in a niri dropdown"
status: doing
priority: 2
size: l
complexity: high
process: planned
owner: docs/ops-dashboard-design
created: 2026-09-06T17:27:07Z
updated: 2026-10-19T00:58:41Z
started: 2026-10-19T00:52:30Z
depends: []
tags: [niri, dropdown]
spec: docs/specs/2026-10-18-ops-dashboard-design.md
---

Why: one toggle away from any workspace, the owner wants to see at a glance which agents are running and what each is doing, where tasks stand across recently active projects, and what obs says is going wrong, without opening a dozen tools. Filed 2026-09-06 as "dropdown: ops dashboard", a follow-up to dots-7b24fa. The owner widened it on 2026-10-17 after a cross-project exploration (attached).

Settled in the brainstorm (2026-10-17/18, owner's answers):
- v1 is a read-only overview of three modules: agents, tasks, obs. Further modules and per-project pages, each owned by the module behind it, are phased in later.
- Agents: one card per project with at least one live session, ordered by most recent activity. Each card has a small pet portrait, the project's hue as accent and border, the project name, and one line per session with its harness and harness state. Flow stage comes later.
- Tasks: per recently active project, counts of todo, doing, blocked, waiting on the owner (quiet runs separately) and unscoped/unreviewed.
- obs: the last few failure events if obs records them, otherwise recent rates per failure mode.
- Anti-goals: high latency, a cluttered UI.
- Builder's calls: a TypeScript terminal UI on OpenTUI under Bun (the mindful-tui stack), with a data layer kept separate so a web view can follow. It gets its own project, created by the plan's first step, and reads only each tool's commands and JSON.

Done when: the written design is reviewed by the owner, the plan is reviewed, and the plan runs.

## Notes

- 2026-10-17T21:20:19Z (main): scope: question; no terminal ops dashboard exists to run (ops bin/ has no live view; obs's dashboard is a browser page, its terminal summary is off PATH); body gains the evidence and one open question: what it shows, (a) a refreshed composition of host-load and tasks claims/lanes, (b) obs dashboard summary/findings, or (c) what was meant; checked at 69e226c
- 2026-10-17T22:25:13Z (main): answer (user, 2026-10-17): do a wider, deeper exploration and brainstorm across the projects most active with ops (tasks, obs, fam, crew, mind6). Consider what is useful to convey; interactive or read-only (e.g. the transponder inbox, a task launcher); nested or multiscale (a home view of all projects, each with a space, then a concise full-page view per project); keeping it uncluttered while conveying the most useful text and visuals; snapshot (point) vs change (rates, gradients); fam art (the video-game art style ideas in trans); other considerations.
- 2026-10-17T22:35:16Z (main): attached: ops-dashboard-exploration-2026-10-17.md (11494 bytes): Exploration for the ops dashboard brainstorm: what tasks, obs/ops, crew, mind6, familiar, relay and transponder expose, at what cost, plus prior judgments and the 16-bit art direction
- 2026-10-19T00:52:30Z (main): scope: scoped after the brainstorm; idea -> todo P2 l high planned; the spec is drafted in dotfiles docs/specs/ and moves to the dashboard's own project when the plan creates it
- 2026-10-19T00:52:30Z (main): started
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T00:52:48Z (docs/ops-dashboard-design): resumed
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T00:58:41Z (docs/ops-dashboard-design): parked (waiting on user, decision): Owner names the dashboard project (recommended: lookout, prefix look, ~/d/lookout, personal, khughitt on GitHub); then the agent records the name in the spec, hands it over for the owner's review with the list of builder's calls, and after approval writes the plan
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
