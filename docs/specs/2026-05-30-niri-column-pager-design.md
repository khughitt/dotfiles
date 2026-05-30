# Niri Column Pager Design

## Goal

Create a small niri helper that keeps tiled columns sized into visible groups of up to three columns per workspace.

The intended behavior is:

- 1 tiled column on a workspace: width 100%.
- 2 tiled columns: each width 50%.
- 3 tiled columns: each width 33.33333%.
- 4 tiled columns: columns 1-3 are 33.33333%; column 4 is 100% and is reached through niri's normal horizontal scrolling.
- 5 tiled columns: columns 1-3 are 33.33333%; columns 4-5 are 50%.
- 6 tiled columns: two groups of three 33.33333% columns.
- Additional columns continue the same pattern in pages of three.

Floating windows are ignored. Multiple windows stacked in one niri column are treated as one managed column.

## Non-Goals

- Do not reimplement niri's tiling model.
- Do not manage vertical window stacking inside a column.
- Do not resize floating windows.
- Do not add compatibility layers around older niri IPC behavior.
- Do not override manual user resizing on every focus change.

## Location

Add the helper as an executable Python script:

```text
niri/scripts/column-pager
```

Start it from niri:

```kdl
spawn-at-startup "~/.config/niri/scripts/column-pager"
```

This keeps the helper near the existing niri scripts. Unlike the current one-shot bash helpers, this is a long-running Python daemon because it needs direct IPC event handling and action dispatch.

## Architecture

Use a single focused Python script with direct niri IPC access over `NIRI_SOCKET`.

The script maintains:

- A read socket subscribed to `EventStream`.
- A separate action socket for `Action` requests.
- In-memory focused-workspace and window state derived from startup queries and event stream updates.
- A small debounce timer for layout-affecting events.
- A target-width cache for the active workspace to prevent self-induced layout feedback loops.

Direct IPC is preferred over repeated `niri msg` subprocesses because this helper is expected to run continuously and react to frequent window events.

## Data Model

The script tracks tiled windows by workspace, but applies widths only on the active workspace. It must never focus a window on an inactive workspace, because `FocusWindow` would switch the user to that workspace and may also move focus across monitors.

A managed column is identified by `window.layout.pos_in_scrolling_layout[0]`.

For the active workspace:

1. Collect windows where `is_floating` is false.
2. Ignore windows without `workspace_id`.
3. Ignore windows whose layout has no `pos_in_scrolling_layout`.
4. Group by column index.
5. Sort columns by column index.

Each column group may contain more than one window. The representative window should be selected to minimize visible disruption:

1. Use the currently focused window if it is in the target column.
2. Otherwise, use the most recently focused window in that column when focus timestamp data is available.
3. Otherwise, use the first window in the column by layout row index.

This avoids flipping the active window in a stacked or tabbed column unnecessarily.

## Width Algorithm

Columns are split into consecutive pages of three:

```text
page = columns[i:i + 3]
width = 1.0 / len(page)
```

The action width values are:

- `100%` for page size 1.
- `50%` for page size 2.
- `33.33333%` for page size 3.

The algorithm applies widths per page. It does not try to keep every page visible at once; niri's normal horizontal scrolling handles overflow.

## Event Handling

The daemon reacts to events that can change column membership or ordering on the active workspace:

- `WindowsChanged`
- `WindowOpenedOrChanged`
- `WindowClosed`
- `WindowLayoutsChanged`
- `WorkspaceActivated`

It ignores pure window focus changes for resizing, so normal navigation does not cause repeated width churn. When a workspace becomes focused through `WorkspaceActivated`, the daemon may apply widths to that newly active workspace because doing so does not require cross-workspace focus.

After one of the layout-affecting events, the daemon schedules a short debounce before recomputing the active workspace. This gives niri time to finish related layout updates and prevents repeated resize passes during bursts of events.

Applying `SetColumnWidth` emits `WindowLayoutsChanged`, so feedback-loop prevention is part of the core behavior, not an optimization:

- When the daemon issues width actions, it records a short self-apply suppression deadline, initially the same duration as the debounce delay.
- `WindowLayoutsChanged` events received before that deadline are ignored unless a structural event also occurred.
- Structural events such as open, close, move, or workspace activation always invalidate suppression and schedule a fresh recompute.
- The target-width cache is scoped to the active workspace and keyed by the ordered column signature: each column signature is the sorted set of window ids currently in that column, and the workspace signature is the ordered list of those column signatures.
- When the workspace signature changes, the cache for that workspace is invalidated. This avoids stale cache entries after column indices shift.

## Applying Widths

Before applying widths, the script records the currently focused window id if one exists. If the focused window is not on the active workspace being managed, the script skips the pass rather than focusing across workspaces.

For each managed column:

1. Focus the representative window for the column.
2. Send `SetColumnWidth` with the target percentage.

After all width changes complete, refocus the original window if it still exists.

The script skips an action when its cached target width for that column signature already matches the desired width. The cache stores attempted target widths, not measured actual widths. This intentionally accepts niri clamping caused by min-width or max-width window rules; after a clamp, the daemon should not keep retrying the same target on every layout event.

If a future implementation reads actual widths after applying actions, it may record clamped columns for diagnostics, but that is not required for the initial version.

## Error Handling

The helper fails early when `NIRI_SOCKET` is missing or the IPC connection cannot be opened.

If niri restarts or the IPC socket disconnects while the helper is running, the helper exits cleanly with a non-zero status. Reconnection is out of scope for the first version; if persistent restart behavior is needed later, the helper should be run from a user service rather than `spawn-at-startup`.

If an action fails because a window disappeared while resizing, the script logs the failure and continues; a later event will reconcile state.

Unexpected event payloads should be logged with enough context to debug, then ignored rather than silently corrupting state.

## Configuration

The initial implementation should keep configuration minimal:

- Page size: default `3`.
- Debounce delay: default around `100ms`.
- Self-apply suppression delay: defaults to the debounce delay.

These can be exposed as command-line flags if needed:

```text
--page-size 3
--debounce-ms 100
```

No config file is needed.

## Testing

Unit-test the pure layout algorithm separately from niri IPC:

- 0 columns returns no actions.
- 1 column maps to `100%`.
- 2 columns map to `50%`.
- 3 columns map to `33.33333%`.
- 4 columns map to `33.33333%, 33.33333%, 33.33333%, 100%`.
- 5 columns map to `33.33333%, 33.33333%, 33.33333%, 50%, 50%`.
- 7 columns map to `33.33333%, 33.33333%, 33.33333%, 33.33333%, 33.33333%, 33.33333%, 100%`.
- Stacked windows in the same column produce one managed column.
- Floating windows are ignored before column grouping.
- A changed workspace signature invalidates the target-width cache.
- An unchanged workspace signature with unchanged target widths produces no resize actions.

Manual verification in a running niri session:

1. Start the helper.
2. Open one, two, and three tiled windows on a workspace and confirm they span the workspace width evenly.
3. Open a fourth window and confirm it overflows as a full-width column.
4. Open fifth and sixth windows and confirm the second page becomes halves, then thirds.
5. Stack two windows in one column and confirm only the column count matters.
6. Close windows and confirm remaining columns are recomputed.
7. Confirm floating scratchpad windows are ignored.
8. Switch workspaces and confirm the helper never pulls focus to an inactive workspace.
9. Confirm the helper does not spin on its own `WindowLayoutsChanged` events after applying widths.

## Open Decisions

None. The agreed scope is column-only management for tiled niri windows.
