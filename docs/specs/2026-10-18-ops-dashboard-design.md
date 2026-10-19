# lookout v1: the ops dashboard, design

2026-10-18. Task `dots-06eb59`. Status: draft, for the owner's review.

The exploration behind this design is attached to the task as
`ops-dashboard-exploration-2026-10-17.md`. It covers what tasks, obs, ops, crew, mind6,
familiar, relay and transponder expose, at what cost.

## Intent

The owner runs many coding agents (Claude Code, Codex and others) across about 30 personal
projects. On coming back to the desk they want three answers at a glance, from one toggle
on any workspace:

1. Which agents are running, and what is each one doing?
2. Where do tasks stand across the recently active projects?
3. What does obs say is going wrong?

Today those answers are spread over a dozen commands and a browser page, and the obvious
signals mislead. On 2026-10-17, 47 of 56 `doing` tasks were parked rather than running.

The dashboard is a kitty quick-access dropdown on niri, beside the existing dropdowns
(`niri/scripts/dropdown`). It is built as modules. Three ship first; others are phased in as
they prove useful, and each later module also owns a page of detail.

## Goals

- **Agents module.** One card per project with at least one live session, ordered by most
  recent activity, newest first. A card's activity is the newest `updatedAt` among its
  sessions. Each card shows:
  - a small pet portrait from familiar's current theme;
  - the project's hue as accent and border;
  - the project name;
  - one line per live session: harness, harness state, its task, and a faint niri workspace
    number.

  Sessions come from familiar alone: a session is listed whether or not any claim joins
  it. On 2026-10-19 the live read had 14 familiar sessions, only 2 with claims, and one
  session holding two claims. The task part of the line follows the session's claims:
  - **none:** the line shows no task;
  - **one:** the task id and its short title;
  - **several:** the most recently started claim's id and title, then "+N".

  The portrait shows the pose of the card's most urgent session (needs input or approval
  outranks error, which outranks working, done and idle). A card drops off when its project
  has no live session.

  **Overflow.** When the cards exceed the module's budget, the module scrolls with the
  keyboard. Its last visible line is always an overflow line naming what is hidden, with
  any hidden attention items first, for example "+3 more · needs input: mind6". Newest-first
  ordering never hides a session that needs the owner without saying so.
- **Tasks module.** One row per project that was active in the last 7 days **or** needs
  the owner's attention: a park waiting on the owner, or an open halt. A review owed for a
  month stays on the screen however quiet the project has been. Each row shows:
  - todo
  - doing, split three ways over one reconciled population so the parts add up:
    - **claimed**, with uncertain liveness kept visible: "3 claimed (1 unverified)";
    - **parked**;
    - **unattended**: neither claimed nor parked (7 of 56 on 2026-10-17).

    A task both parked and claimed counts as claimed. The bucket is called claimed, not
    running, because a claim does not prove a process. `tasks claims` reports
    `live: true` with an `unverified` reason when it cannot judge a pid. A claim without a
    pid (Codex) lives on its four-hour TTL.
  - blocked
  - waiting on the owner, with quiet runs counted separately. This counts every park
    waiting on the owner, whatever the task's status (todo and blocked tasks hold parks
    too), because it measures what is owed, not what is in progress.
  - unscoped/unreviewed: the scope queue

  Rows are ordered by what is owed (waiting on the owner, then halts), then by recent
  activity. Waiting on the owner is the column the eye should land on.

  **Overflow.** The tasks module scrolls with the keyboard like the agents module. When
  rows are hidden, its last visible line counts them and names hidden rows that need
  attention, for example "+6 more · owed: wali 1, mm 2". *(Builder's call, from the
  review: the three-way doing split and the owed-parks count.)*
- **obs module.** The tool-failure rate for yesterday against the 7-day rate, plus the top
  three failure hotspots over 7 days (project × tool, with counts).
  - obs records each failed call, but every row's mode and kind are still empty on
    2026-10-17 (they wait on obs-18b8eb). A list of recent events would read "Bash failed"
    about 250 times a day, which is clutter.
  - When obs-18b8eb fills mode and kind, the hotspots group by failure mode instead, and the
    last few events can join them.

  *(Builder's call, from the review.)*
- **Instant to open.** Showing the dropdown never waits on a read.
- **Honest freshness.** Every module shows how old its data is, and an unavailable source
  says so with its reason.

## Non-goals (v1)

- Any write or action: v1 is read-only. Starting, parking, answering the inbox and launching
  a harness come later.
- Per-project pages. Each later module owns its own page; v1 has the overview only.
- Further modules: mind6 (captures to triage), the transponder inbox, crew attempts and
  model pass rates, host load and test-latency breaches, stale-park detection, and
  waiting-on-you grouped by the kind of session it needs (phone, audio rig, decision,
  review, idle machine).
- A web view. The data layer is kept separate so one can follow.
- Flow stage on session lines; it follows when flows exposes it.
- Notifications. The dashboard is looked at; it never interrupts.

## Anti-goals

- **High latency.** If toggling it ever feels slow, it has failed, whatever it shows.
- **Clutter.** A screen of zeros, idle projects, raw warnings or a number on every cell has
  failed too. A row earns its place by being active or needing attention.

## Constraints

- **Sources and costs** (measured 2026-10-17):

  | Source | Read | Cost |
  |---|---|---|
  | familiar | `$XDG_STATE_HOME/familiar/{intent,agents,niri-windows}.json` | files; replaced by atomic rename, so watch the directory |
  | tasks | `tasks claims` | 4 ms |
  | tasks | `tasks projects` | 0.18 s |
  | tasks | `tasks list --parked --all-projects` | 0.35 s |
  | tasks | `tasks list --needs-review --all-projects` | 0.7 s |
  | obs | `$XDG_STATE_HOME/obs/dashboard/snapshot.js`, rebuilt hourly by the obs timer | 10.5 MB; summing a 7-day window for 30 projects took 0.4 s |

  The obs index itself (2–17 s a report) must never be read from a refresh loop. Neither
  must `obs index`, `dashboard build` or `ANALYZE`.
- **Joins.** familiar and the task claims share the session id. Claims carry task ids, not
  titles. A title comes from the task's authoritative record, read as the population rule
  below says, and is cached per id until that claim or park changes.
  - niri-windows.json holds niri's internal workspace id. The number to show is the
    workspace index from `niri msg -j workspaces`.
  - The relay live-agent registry is not running yet (fam-6e8321). Until it runs, the
    harness comes from what familiar and the claims record.
- **One task population, from authoritative records.** `tasks projects` and
  `tasks list --all-projects` read records in registered checkouts. Claims and parks also
  name worktrees, whose copy of a record may be newer or exist only there. A task marked
  doing in main may be blocked and parked in its worktree. Every count in the tasks module
  therefore comes from one population keyed by task id:
  - **Members:** every open record with status todo, doing or blocked, from
    `tasks list --all-projects --status todo --status doing --status blocked`, plus every
    id named by `tasks claims` or by `tasks list --parked --all-projects`.
  - **Record precedence:** when a live claim or a park names a worktree, that worktree's
    copy is authoritative. It is read explicitly with
    `tasks -C <worktree> show <id> --no-fetch`. `tasks show` without `-C` consults a
    worktree only when the registered record is absent, and never picks the newer copy.
    Otherwise the registered checkout's record stands. Cache each worktree read until its
    claim or park changes.
  - **Counts:** todo, doing and blocked are counted from each member's authoritative
    status. Only the doing members are partitioned into claimed, parked and unattended, so
    those three sum to doing. Waiting on the owner counts every member's park waiting on
    the owner, whatever its status.
- **Meaning.** "Doing" is not "running", and a live claim is not proof of running either.
  The dashboard says claimed and shows unverified liveness as such.
- **Read-only contract.** The dashboard reads each tool's own commands and published files.
  It never parses `tasks/*.md`, never takes another tool's lock, and never reads attempt
  directories or thought bodies.
- **Identity.** fam-053b0d (in progress) makes the tasks project colour the single source
  and maps each pet to the nearest of familiar's 12 slot hues. Use the colour that familiar's
  intent record carries, so the two always agree.
- **Rendering.** kitty is the host terminal.
  - OpenTUI and kitty's image placeholder cells have clashed before: placeholders with two
    diacritics break, one-row cells with none survive.
  - The dashboard owns its terminal, so it can upload each image once with a stable id and
    place it directly.
  - The cats theme PNGs are about 430×480 px and about 141 KB; downscale them before
    uploading.
- **Time.** Days are cut in the host's local zone. obs cuts days in its own configured zone
  (`ops/obs.toml`), so label obs windows as obs's.
- **Privacy.** Show task titles, counts and project names. Show no transcript text and no
  thought or inbox bodies.
- **Profiles.** v1 shows `personal` projects only. Work-profile projects are filtered out by
  the profile `ops-profile` reports for each checkout, not by a hand-kept list. This keeps
  employer names and titles out of a personal repository's fixtures and screenshots. It
  also stops parks waiting on colleagues' reviews from swamping the owner's column. A
  profile-aware work view can come later. *(Builder's call, from the review.)*
- **Host.** v1 shows the host it runs on, named in its header. Claims, parks, familiar's
  files and the obs snapshot are all local to a host, and the dropdown starts on every host
  that shares the dotfiles. Work running on the other machine is not shown as running there.
  A source a host lacks (obs on europa) reads "unavailable". Covering both hosts needs a
  cross-host read that no source provides, and comes later if wanted. *(Builder's call,
  from the review.)*

## Decided (builder's calls, accepted by the owner as handed over)

- **Stack.** A terminal UI in TypeScript on OpenTUI under Bun, the stack mindful-tui uses.
- **Home.** Its own project, `lookout` (owner's pick, 2026-10-19): tasks prefix `look`,
  checkout `~/d/lookout`, `personal` profile, GitHub `khughitt/lookout`. The plan's first
  step creates and registers it and moves this spec there.
- **Structure.** A data layer of independent sources, each with its own refresh schedule,
  feeding a render layer, so a web view can reuse the sources.
- **Launch.** It runs as a `dashboard` case in `niri/scripts/dropdown`, spawned hidden at
  login like the other dropdowns.
- **Refresh.** Data refreshes in the background, so showing the dropdown is just showing
  it:
  - agents: on familiar's file changes, plus a claims read every 2 s, plus a timer at each
    intent record's `expiresAt`. An intent record carries `current`, `expiresAt` and
    `after`: past `expiresAt` the state is `after`'s (done decays to idle after 8 s, error
    after 30 s) with no file change. The state and the portrait are recomputed at that
    moment.
  - tasks: every 30 s
  - obs: when the snapshot file changes

  A slow or failing source never blocks the others. It keeps its last good data with its
  age, or shows "unavailable (reason)". It never shows a guessed zero.
- **Layout.** A fixed line budget per module, with the agents module getting the most room.
  Colour carries identity and state; numbers are kept for what the owner would act on.

## Left to the builder

- Line budgets, card dimensions, the portrait size in cells, and the dropdown's size and
  key. The bind and the cheatsheet row follow the existing dropdowns.
- How the obs module reads failure events: from the snapshot rows, or a cheap published
  view. If neither is cheap, rates stand in.
- Hiding the tasks columns that are zero for every row.
- The harness label until relay runs.
- **The first step is a spike** (throwaway, then reported back): an OpenTUI screen in a kitty
  quick-access dropdown that places one downscaled pet image directly. It settles whether
  OpenTUI's own drawing and direct image placement coexist before the layout is built.

## Phasing after v1

The 16-bit portraits (forge-9db1d5, P1) replace the theme pictures with no layout change,
alongside the cats v3 roster pass (forge-d5c548, P1). The dashboard's card fixes the
portrait size and states those tasks draw.

Later modules, each with its own page, come in the order they prove useful. Candidates:
- mind6's triage count, read from its event feed and never by polling its op queue;
- the transponder inbox;
- crew attempts;
- host health;
- stale parks: parks whose condition has already happened (ops-df9e86 found 22 misleading
  `doing` tasks).
