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
updated: 2026-10-19T13:02:50Z
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
- 2026-10-19T11:53:09Z (docs/ops-dashboard-design): resumed
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T11:53:20Z (docs/ops-dashboard-design): parked (waiting on user, review): Owner reviews the lookout v1 design (.worktrees/ops-dashboard-design/docs/specs/2026-10-18-ops-dashboard-design.md); on approval the agent writes the implementation plan, step 1 creating the lookout project
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T11:57:19Z (docs/ops-dashboard-design): review: spec round 1 — verdict: revise; findings: Important 5, minor 1; reviewer: codex
- 2026-10-19T11:57:35Z (docs/ops-dashboard-design): Spec review details (read-only review; spec unchanged): Important 1 — lines 42-44/92-95 combine registered-checkout counts from tasks projects with claims that include worktree-only tasks; define one task-id population and reconcile claim/park worktree records before deriving the doing partition, otherwise parts can exceed doing or use stale statuses. Important 2 — lines 42-44/106 equate a live claim with running; ClaimInfo deliberately returns live=true with unverified for unverifiable PID views, and PID-less claims use a four-hour TTL. Preserve uncertain liveness explicitly, preferably label the bucket claimed rather than asserting execution. Important 3 — line 39 removes projects after seven inactive days even if they still owe an owner review or quiet run (lines 46-48/83); retain attention-bearing projects regardless of recency. Important 4 — lines 33-34/100-105 assume one claimed task per session; the live read had 14 familiar sessions, only two sessions with claims, and one session holding two claims. Specify session liveness independently, optional/multiple task presentation, and title resolution from the claim worktree through the tasks CLI. Important 5 — lines 154-155 allocate fixed module budgets without an overflow rule despite one card per project and one line per session; define scrolling and visible overflow/attention counts so older waiting sessions remain discoverable. Minor 1 — line 148 refreshes familiar on file changes, but intent records contain current/expiresAt/after and done/error decay without a file write; schedule deadline-driven state/portrait recomputation. Confirmed obs snapshot tables tools and failed_calls support rates and project/tool hotspots; no obs index build, tests, or desktop rendering was run.
- 2026-10-19T12:36:33Z (docs/ops-dashboard-design): resumed
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T12:37:16Z (docs/ops-dashboard-design): spec revised for round 1 (7c06328): doing breakdown over one id-keyed population (doing list ∪ claims ∪ parks, status from the record); bucket renamed claimed with unverified liveness kept visible; tasks rows include projects needing owner attention, not only 7-day activity; sessions listed from familiar alone, with none/one/several claims rendered and titles via tasks show; agents overflow scrolls with an overflow line naming hidden attention items; intent expiry timer recomputes state and portrait at expiresAt
- 2026-10-19T12:37:16Z (docs/ops-dashboard-design): parked (waiting on user, review): Owner reviews the revised lookout design (round 2; .worktrees/ops-dashboard-design/docs/specs/2026-10-18-ops-dashboard-design.md); on approval the agent writes the implementation plan
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T12:42:44Z (docs/ops-dashboard-design): review: spec round 2 — verdict: revise; findings: Important 3; reviewer: codex
- 2026-10-19T12:42:44Z (docs/ops-dashboard-design): Scoped re-review of 7c06328: prior findings 2 (claimed/unverified), 3 (attention survives recency), 4 (session/claim cardinality), and 6 (intent expiry) are closed. Three Important findings remain in the population/overflow revisions. 1 — lines 128-135 read only --status doing but say todo and blocked come from the same list; an unclaimed/unparked todo or blocked task never enters the population. Read the relevant open statuses, then derive each status count and partition doing. 2 — lines 120-132 do not reconcile existing records with their claimed/parked worktree: tasks show only falls back to the recorded worktree when the local record is absent (tasks src/commands/show.rs:39-46), and the spec skips show entirely for returned ids. A registered doing record changed to blocked and parked in its worktree still counts as doing. Define record-source precedence and explicitly read the recorded checkout via tasks -C <worktree> show <id> --no-fetch when it is authoritative; use its status/title before counting. 3 — lines 48-51 give overflow only to agents, while line 193 still gives every module a fixed budget. Excess task rows, including projects retained for owner attention, remain inaccessible. Apply scrolling and an attention-aware overflow indication to the tasks module too. Review only; spec unchanged. No live rendering or latency tests run.
- 2026-10-19T12:46:15Z (docs/ops-dashboard-design): resumed
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T12:46:59Z (docs/ops-dashboard-design): spec revised for round 2 (8d5234e): population members are every open todo/doing/blocked record plus every claimed or parked id; a live claim's or park's worktree copy is authoritative, read with tasks -C <worktree> show <id> --no-fetch (titles too); only doing members are partitioned; tasks rows ordered owed-first and scroll with an overflow line naming hidden owed rows. Both named commands checked live.
- 2026-10-19T12:47:00Z (docs/ops-dashboard-design): parked (waiting on user, review): Owner reviews the revised lookout design (round 3; .worktrees/ops-dashboard-design/docs/specs/2026-10-18-ops-dashboard-design.md); on approval the agent writes the implementation plan
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T12:56:06Z (docs/ops-dashboard-design): review: spec round 3 — verdict: revise; findings: Important 1; reviewer: codex
- 2026-10-19T12:56:06Z (docs/ops-dashboard-design): Scoped re-review of 8d5234e: all three round-2 findings are closed (full open-status population, explicit worktree record precedence, and tasks overflow). One Important issue introduced by extending the cache to entire worktree reads at lines 144-145: claim/park changes are not a record-version signal. A cached parked todo task can be blocked or unblocked in its worktree while its park remains unchanged, leaving authoritative status and counts stale indefinitely despite the 30-second task refresh. Confirmed in tasks src/commands/mod.rs:565-569 (nonclosing transitions preserve parks) and existing tests/cli.rs:1388 block_unblock_note_and_dep_leave_a_park_entry_alone. Smallest fix: expire/re-read authoritative worktree records on the existing 30-second tasks refresh and use those refreshed records for titles too; claim/park changes may invalidate sooner. Full open-status CLI query returned todo/doing/blocked successfully. Review only; spec unchanged. No implementation tests or live rendering/latency checks run.
- 2026-10-19T13:02:49Z (docs/ops-dashboard-design): resumed
  provenance: {"harness_session":"claude-code:c13e4910-a2ef-4255-98f3-a1b169eaf5a3","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-19T13:02:49Z (docs/ops-dashboard-design): spec round-3 fix (cache refreshes on the 30 s tasks schedule; block/unblock keep the park) and owner approval recorded in the spec; next: implementation plan
