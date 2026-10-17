# Ops dashboard: exploration, 2026-10-17

Four read-only explorers (Claude Code Explore agents, claude-opus-5-5) for dots-06eb59, run on titan.
Paths are written with `~/d/` for the project checkouts. Latencies were timed live on titan.

## Cross-cutting

- Almost all the state already exists and is cheap to read. The hard parts are freshness, noise
  and joins, not data.
- Live agent identity comes from three partial sources that join on session id. familiar
  (`~/.local/state/familiar/intent.json`, `agents.json`) has state, urgency, hue and sprite.
  `tasks claims` has the task, worktree and liveness. The relay registry is not running yet
  (fam-6e8321).
- "Doing" is not "running": 47 of 56 doing tasks are parked, and live claims are the only
  running-now signal.
- What the person is owed: 38 parks waiting on them (24 review), 2 captures awaiting triage,
  the inbox (not persistently served), 157 scope-queue rows and 59 feedback ideas.
- Prior judgments to respect:
  - mind6 DESIGN.md:157, "Density is editorial, not dashboard".
  - The crew allocation brief rejects "a second account of what is pending" and reads tasks'
    parked list instead.
  - The tasks multi-project spec (`~/d/tasks/docs/specs/2026-09-04-multi-project-design.md`)
    puts a dashboard in a separate project that consumes JSON.
  - The capture-triage spec §8 deferred a desktop widget to dots, "on the same read".
  - obs's 10-06 friction review found that the browser dashboard surfaced only spend and
    friction.

## tasks and tasks-tui

- A home-view poll costs about 2 s: `tasks projects` 0.18 s (counts, `last_activity`, colour),
  `tasks claims` 4 ms (every store, no checkout opened), `tasks list --parked --all-projects`
  0.35 s and `tasks lanes --all-projects` 1.4 s.
  - `tasks prime --all-projects` costs 6.7 s and 1.2 MB; per-project prime costs 0.01–0.26 s,
    so run those in parallel instead.
- The person's queue: `tasks list --parked --waiting-on user --all-projects` takes 0.3 s and
  returned 38 rows. Each has `park{at,next_step,waiting_on,reason,minutes?,session,host,worktree}`.
  Reasons: review 24, environment 5, quiet 3.
- Other queues:
  - scope: `--needs-review --all-projects`, 0.7 s, 157 rows (unassessed 101, unreviewed 37,
    stranded 19)
  - feedback: `--tag feedback --status idea`, 59 rows (ops 30, tasks 17)
  - `tasks quiet`: 3 entries
  - halts: 2 open (atoms-286555, beliefs-ce9d05)
- Change over time:
  - The tracker has no history, watch or event command.
  - git log of `tasks/` is already an event stream for the 28 of 34 projects with
    `[git] commit = true`. Commit subjects read `chore(tasks): <verb> <id> [title…]`
    (`~/d/tasks/src/record_commit.rs:361`).
  - Over 7 days: about 950 commits in ops, 830 in mind6 and 610 in tasks; reading one repo
    takes about 0.13 s.
  - Daily completions come from `created`/`completed`/`closed` stamps (5.4 s via list + jq):
    55–171 a day recently.
  - Six projects have no record commits: mind3, nexc, nexp, nrp, rad, trans.
  - A `tasks watch` or per-project change stamp is floated in
    `~/d/tasks-tui/docs/notes/2026-10-17-tasks-tui-v2-surface-brief.md` §4, not filed.
- tasks-tui:
  - Views are a stack: Projects → Project (Ready/Doing/Open/Ideas/Done) → Task.
  - The Projects view has a table plus a prime pane, and a strip reading "N doing · N parked
    across N projects".
  - It refreshes the top view on a `tea.Tick` (30 s), with coalesced, generation-tagged loads
    and a 10 s timeout.
  - Adding a view means implementing the `view` interface and pushing it on the stack.
  - Its rules: never read the claim store, never parse `tasks/*.md`.
  - Launch keys (`c l` etc.) open `kitty --directory` in the park's worktree or the claim's,
    and never run `start`.
  - Open items: tui-f67715 (lanes pane), tui-c30d88 and tui-bbd26e (tree and graph views).
- Safe actions from a dashboard: `add` (idempotent with `--source`), `note`, `park`, each run
  with `-C <checkout>`. Never `start`: the claim would belong to the dashboard process.
  Refusals to handle: `claimed`, `need_held`, halts, `stale_copy`.
- Gotchas:
  - Claims and parks are host-local (`~/.local/state/tasks/claims/`).
  - Worktrees live outside Dropbox, so main-checkout git log misses branch work until it
    merges.
  - Warnings embed whole next-step paragraphs; truncate them.

## obs and ops host tools

- obs:
  - The hourly snapshot `~/.local/state/obs/dashboard/snapshot.js` (10.5 MB) holds 30 days of
    rows at day grain, keyed by session, day, model and project. Summing 7 days of tokens for
    30 projects took 0.4 s.
  - The 4.5 GB index costs 2–17 s a report and must never be queried from a refresh loop.
    Never run `obs index`, `dashboard build` or `ANALYZE` from one either.
  - Freshness is 5–65 minutes.
  - The index holds:
    - sessions and turns (model, effort, tokens)
    - tool calls and errors, shell runs
    - Stop-hook runs, skill calls, subagent dispatches
    - tasks, tt runs
    - outcome measures M1–M7
    - drift
  - Not yet recorded: failure modes (obs-18b8eb), loops, CI.
- Attention is broken today:
  - `findings.json` is never written, because the 60 s reconcile timer was never installed
    (ops-94e273).
  - Drift has 78 open, unacknowledged episodes, and `dashboard summary` prints one line each.
    That is noise.
  - Related: obs-b3b6a0 (does any alarm reach the person).
- `obs dashboard summary` (0.4 s, `--json`) prints:
  - live findings status
  - a line per drift episode
  - the snapshot age
  - two headline lines, e.g. `yesterday billing=… turns=5507 sessions=137 tool_calls=5490 tool_errors=2.7%`, and the same for `7d`.
- The browser page sections (`~/d/obs/dashboard/app.js`):
  - Attention: findings, drift, spikes (a day over 2× the median day)
  - Spend, Cost per task, Tool failures
  - Session friction, Sessions, Tasks
  - Context and cache, Skills, Coverage, Outcomes
  - Placeholders for Loops, Tests and CI
- ops live tools (`~/d/ops/bin/`):
  - `host-load [--json]` 1.2 s: load against 32 CPUs, top processes by unit, orphans.
  - `host-budget show` 0.6 s.
  - `disk-report --section volumes|inotify|services` 2 s: for example `/mnt/hmcl` at 88% and
    `work-link.service failed`.
  - `tt-latency check` 2.5 s: test breaches per project and target.
  - `tt-report --since 7d` 0.8 s.
- Time zone: obs cuts days in America/Los_Angeles (`~/.config/ops/obs.toml`, which also masks
  quiet hours) while the host runs US/Eastern.
- Project colours: ops-30b965, `~/d/ops/bin/project-colors check|suggest|sheet`.
- Privacy: no transcript text, but task titles and transcript paths are present. Work-profile
  projects are indexed too.

## crew and mind6

- crew:
  - No daemon, queue or status command. The CLI has `run` and `recover`, and `crew` is not on
    PATH.
  - An attempt lives at `~/.local/state/crew/attempts/<ULID>/events.jsonl`. Its states run
    `preparing → working → verifying → reviewing → reporting → ended`, plus `recovering`
    (`stateOf`, `~/d/crew/src/attempts.ts:93`).
  - Each attempt ends with a `verdict` event; `usage` events carry tokens and USD.
  - Waiting on the person shows up as a tasks park with `session: crew:<id>`; 1 of the 38
    today.
  - Model pass rate is a ready trend: 27 attempts across 4 models on 10-16 and 10-17.
  - Gotchas:
    - Never probe the attempt lock: it makes a concurrent `recover` skip the attempt. Check
      `created.runner` against `/proc` instead.
    - Read only `events.jsonl` and the report: attempt directories hold credentials.
- mind6:
  - Read it through `POST http://localhost:3331/api/op` with the header
    `Origin: http://localhost:3331`; reads take 70–520 ms.
  - Every op, reads included, runs in one service queue (`service.ts:219-241`), so polling
    would delay captures. Subscribe to `GET /api/events` (catalog generation, index status,
    ping every 25 s) and re-query on change.
  - Reads a dashboard could use:
    - `triage.queue {limit:0}` (pending, oldest), 180 ms
    - `journal {from,to}`
    - `due.list`, `frecent`, `list`
    - `walk {lens: review|garden|old|explore}`
    - `index.status`, `catalog.generation`
  - Captures per day come from bucketing `capturedAt` by local day (52 in 14 days).
  - Views and edits are in `~/d/thoughts/.mindful-index/activity.jsonl` (rotating).
  - Capture should go through `mindful-op --capture-paste --self` with an idempotency `key`;
    mindful-op sends none today.
  - Never show an unknown count as zero: copy `~/d/ops/hooks/capture-notice`'s 1.5 s timeout
    and its "unavailable (reason)" line.
  - Privacy: show titles and counts, not bodies.
  - Related: mind6-09e178 (TUI home density and status counts).

## familiar, forge, relay, transponder: agents and art

- familiar live state (`~/.local/state/familiar/`):
  - `intent.json` per session holds identity {project, slot, member, label}, state, urgency
    none|notice|demand, motion breathe|pulse|flash|static, a five-colour ramp and the sprite
    path.
  - `agents.json` holds session, project, cwd, pid and state.
  - `niri-windows.json` maps a session to its window and workspace, so the dashboard could
    jump to an agent's window.
  - The files are replaced by atomic rename, so watch the directory (as `familiar-niri` does).
  - `done` decays to idle after 8 s and `error` after 30 s.
- relay:
  - The registry (schema 2: harness, session, project, state idle|working|needs-input|
    needs-approval|done|error) is not running; `relay list --json` returns null.
  - Neither registry records the task, so join through `tasks claims`.
- Identity:
  - Project colours come from `tasks projects`. fam-053b0d (started 2026-10-17) makes the
    tasks colour the single source, with the pet at the nearest of 12 slot hues. Today the
    two disagree.
  - Pins are in the dotfiles' `familiar/identities.yaml`.
- Terminal art:
  - familiar's renderer (`~/d/familiar/src/render/term/`) has kitty direct placement, U+10EEEE
    placeholders, contact strips and a HUD (●⚡?!✕✓, ▰▱).
  - `familiar projects --state working` is essentially a roster.
  - The `cats` theme has 12 pixel-art cats with six static states each (about 430×480 px,
    about 141 KB per PNG; downscale them).
  - A dashboard that owns its TTY can upload each image once with a stable id and re-place
    it cheaply.
- Art direction, recorded but shelved: a retro 16-bit JRPG look, with dialogue-box portraits
  in the familiar hue and its complements and animation on arrival and answer. Sources:
  - `~/d/transponder/docs/specs/2026-10-13-phone-inbox-client-design.md` §1
  - ops-dba151; ops-998bbb ("old video game chat dialogs" for notifications)
  - ops-cb50a8 and ops-6ddb13; forge-9db1d5
  - forge style variants `jrpg-dialogue-clean`, `arcade-character-select`,
    `handheld-dithered`
  - The art is stuck in a dependency loop (the design waits on portraits, the portraits on
    the design); `~/d/familiar-forge/docs/notes/2026-10-17-forge-art-consumers-brief.md`
    recommends inverting it.
- Inbox:
  - The terminal client already works: `relay inbox list|show|answer|defer`,
    `relay presence here|away`, and a newline-JSON `watch` on `serve.sock`.
  - `relay serve` is not installed as a persistent service (ops-764942).
  - Entries hold question and answer text (mode 0600).
- No spec exists for a roster, party or scene view. Nearest relatives: `familiar projects`,
  fam-a5e9d5 and fam-68c372, and relay-29b7a0.
