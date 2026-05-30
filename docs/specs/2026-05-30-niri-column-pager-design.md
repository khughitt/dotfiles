# Niri Column Pager Design

## Goal

Create a small niri helper that keeps tiled columns sized into visible groups of up to three columns per workspace.

The intended behavior is:

- 1 tiled column on a workspace: width 100%.
- 2 tiled columns: each width 50%.
- 3 tiled columns: each width 33.33333%.
- 4 tiled columns: columns 1-3 are 33.33333%; column 4 is 100% and overflows to the right.
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

This follows the existing `niri/scripts/` pattern used by the scratchpad and monitor helpers.

## Architecture

Use a single focused Python script with direct niri IPC access over `NIRI_SOCKET`.

The script maintains:

- A read socket subscribed to `EventStream`.
- A separate action socket for `Action` requests.
- In-memory workspace and window state derived from startup queries and event stream updates.
- A small debounce timer for layout-affecting events.

Direct IPC is preferred over repeated `niri msg` subprocesses because this helper is expected to run continuously and react to frequent window events.

## Data Model

The script tracks tiled windows by workspace. A managed column is identified by `window.layout.pos_in_scrolling_layout[0]`.

For each workspace:

1. Collect windows where `is_floating` is false.
2. Ignore windows without `workspace_id`.
3. Ignore windows whose layout has no `pos_in_scrolling_layout`.
4. Group by column index.
5. Sort columns by column index.

Each column group may contain more than one window. Only one representative window id is needed to focus the column before applying width actions.

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

The daemon reacts to events that can change column membership or ordering:

- `WindowsChanged`
- `WindowOpenedOrChanged`
- `WindowClosed`
- `WindowLayoutsChanged`

It ignores pure focus changes for resizing, so normal navigation does not cause repeated width churn.

After one of the layout-affecting events, the daemon schedules a short debounce before recomputing the affected workspace. This gives niri time to finish related layout updates and prevents repeated resize passes during bursts of events.

## Applying Widths

Before applying widths, the script records the currently focused window id if one exists.

For each managed column:

1. Focus the representative window for the column.
2. Send `SetColumnWidth` with the target percentage.

After all width changes complete, refocus the original window if it still exists.

The script should skip an action when its cached target width for that column already matches the desired width. This reduces unnecessary focus movement and IPC traffic.

## Error Handling

The helper fails early when `NIRI_SOCKET` is missing or the IPC connection cannot be opened.

If an action fails because a window disappeared while resizing, the script logs the failure and continues; a later event will reconcile state.

Unexpected event payloads should be logged with enough context to debug, then ignored rather than silently corrupting state.

## Configuration

The initial implementation should keep configuration minimal:

- Page size: default `3`.
- Debounce delay: default around `100ms`.

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
- Stacked windows in the same column produce one managed column.
- Floating windows are ignored before column grouping.

Manual verification in a running niri session:

1. Start the helper.
2. Open one, two, and three tiled windows on a workspace and confirm they span the workspace width evenly.
3. Open a fourth window and confirm it overflows as a full-width column.
4. Open fifth and sixth windows and confirm the second page becomes halves, then thirds.
5. Stack two windows in one column and confirm only the column count matters.
6. Close windows and confirm remaining columns are recomputed.
7. Confirm floating scratchpad windows are ignored.

## Open Decisions

None. The agreed scope is column-only management for tiled niri windows.
