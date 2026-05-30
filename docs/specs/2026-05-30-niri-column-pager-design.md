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
- In-memory focused-workspace and window state bootstrapped from the initial `EventStream` snapshots and maintained from later event stream updates.
- A small debounce timer for layout-affecting events.
- A target-width cache for focused workspaces to prevent self-induced layout feedback loops.

Direct IPC is preferred over repeated `niri msg` subprocesses because this helper is expected to run continuously and react to frequent window events.

## Data Model

The script tracks tiled windows by workspace, but applies widths only on the globally focused workspace: the workspace whose niri state has `is_focused=true`.

This is intentionally different from niri's per-output `is_active` workspaces. On multi-monitor setups, a workspace can be visible and active on another output without being focused. The daemon must not resize that workspace until it becomes focused, because `FocusWindow` would move keyboard focus across outputs. Those visible-but-unfocused workspaces reconcile the next time they receive focus.

A managed column is identified by `window.layout.pos_in_scrolling_layout[0]`.

For the focused workspace:

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

The daemon tracks events that can change focused workspace state, column membership, column ordering, or overview state:

- `WindowsChanged`
- `WindowOpenedOrChanged`
- `WindowClosed`
- `WindowLayoutsChanged`
- `WorkspaceActivated`
- `OverviewOpenedOrClosed`

It ignores pure window focus changes for resizing, so normal navigation does not cause repeated width churn. When a workspace becomes focused through `WorkspaceActivated`, the daemon may apply widths to that newly focused workspace because doing so does not require cross-workspace focus.

After a relevant event, the daemon recomputes the focused workspace signature. If the signature changed, or if a `WindowLayoutsChanged` event arrives outside the self-apply suppression window, it schedules a short debounce before recomputing widths. This gives niri time to finish related layout updates and prevents repeated resize passes during bursts of events.

If the overview is open, the daemon records that a pass is pending but does not resize columns. It applies the pending pass after `OverviewOpenedOrClosed` reports that the overview closed.

Applying `SetColumnWidth` emits `WindowLayoutsChanged`, so feedback-loop prevention is part of the core behavior, not an optimization:

- When the daemon issues width actions, it records a short self-apply suppression deadline, initially the same duration as the debounce delay.
- During suppression, `WindowLayoutsChanged` events are ignored when the focused workspace signature is unchanged.
- During suppression, any event that changes the focused workspace id or focused workspace signature cancels suppression and schedules a fresh recompute.
- Each column signature is the sorted set of window ids currently in that column.
- The focused workspace signature is the ordered list of those column signatures.
- The target-width cache stores `last_applied[workspace_id][column_signature] = width`.
- Each pass prunes cache entries for column signatures that no longer exist in that workspace. It does not invalidate the whole workspace cache on membership changes.

## Applying Widths

Before applying widths, the script records the currently focused tiled window id if one exists on the focused workspace.

If there is no focused tiled window to restore, such as when focus is on a layer-shell surface, a floating window, or no window, the script skips the pass. This avoids focusing a tiled window for resizing and then leaving keyboard focus somewhere different from where the user started.

For each managed column:

1. Focus the representative window for the column.
2. Send `SetColumnWidth` with the target percentage.

After all width changes complete, refocus the original window if it still exists.

The script skips an action when its cached target width for that column signature already matches the desired width. The cache stores attempted target widths, not measured actual widths. This intentionally accepts niri clamping caused by min-width or max-width window rules; after a clamp, the daemon should not keep retrying the same target on every layout event.

If a future implementation reads actual widths after applying actions, it may record clamped columns for diagnostics, but that is not required for the initial version.

The first successful pass after daemon startup may focus each managed column because the target-width cache is empty. This is expected. Later passes should touch only columns whose target width changed or whose column signature has not been seen before.

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
- A changed workspace signature prunes cache entries for removed column signatures without invalidating unchanged column signatures.
- An unchanged workspace signature with unchanged target widths produces no resize actions.
- A changed workspace signature during self-apply suppression schedules a new pass.
- An unchanged workspace signature during self-apply suppression does not schedule a new pass for `WindowLayoutsChanged`.

Manual verification in a running niri session:

1. Start the helper.
2. Open one, two, and three tiled windows on a workspace and confirm they span the workspace width evenly.
3. Open a fourth window and confirm it overflows as a full-width column.
4. Open fifth and sixth windows and confirm the second page becomes halves, then thirds.
5. Stack two windows in one column and confirm only the column count matters.
6. Close windows and confirm remaining columns are recomputed.
7. Confirm floating scratchpad windows are ignored.
8. On two monitors, open or move a window on a visible-but-unfocused workspace and confirm the helper does not pull keyboard focus to that output; confirm it reconciles after that workspace becomes focused.
9. Confirm the helper does not spin on its own `WindowLayoutsChanged` events after applying widths.
10. Open overview during a layout change and confirm resizing is deferred until overview closes.

## Open Decisions

None. The agreed scope is column-only management for tiled niri windows.
