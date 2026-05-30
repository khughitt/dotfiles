# Niri Column Pager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a long-running niri helper that resizes tiled columns on the globally focused workspace into pages of up to three equal-width columns.

**Architecture:** Implement one executable Python daemon at `niri/scripts/column-pager`. Keep the domain logic pure and unit-tested, isolate niri IPC framing in a small socket wrapper, and have the daemon wire event-stream state, debounce/suppression logic, and focus-then-resize actions together. The daemon manages only the `is_focused=true` workspace to avoid cross-monitor focus yanks.

**Tech Stack:** Python 3 standard library, `unittest`, niri JSON IPC over `NIRI_SOCKET`, niri KDL startup config.

---

## File Structure

- Create `niri/scripts/column-pager`: executable Python daemon. Owns pure layout functions, cache/scheduler state, niri IPC socket framing, action helpers, event-state updates, and the main loop.
- Create `tests/niri/test_column_pager.py`: unit tests for layout grouping, representative selection, cache behavior, suppression scheduling, startup snapshot gating, IPC message builders, and daemon action application using fake action sockets.
- Modify `niri/config.kdl`: add the startup entry after the existing niri helper startup entries.
- Use existing design spec: `docs/specs/2026-05-30-niri-column-pager-design.md`.

This repository has no existing Python test harness. Use `python3 -m unittest` so the implementation does not introduce a package manager or test dependency.

---

### Task 1: Pure Column Model

**Files:**
- Create: `tests/niri/test_column_pager.py`
- Create: `niri/scripts/column-pager`

- [ ] **Step 1: Write the failing pure-model tests**

Create `tests/niri/test_column_pager.py` with this content:

```python
import importlib.machinery
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "niri" / "scripts" / "column-pager"


def load_column_pager():
    loader = importlib.machinery.SourceFileLoader("column_pager", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


cp = load_column_pager()


def window(
    window_id,
    workspace_id=1,
    col=0,
    row=0,
    is_floating=False,
    is_focused=False,
    focus_secs=0,
    focus_nanos=0,
):
    return {
        "id": window_id,
        "workspace_id": workspace_id,
        "is_floating": is_floating,
        "is_focused": is_focused,
        "focus_timestamp": {"secs": focus_secs, "nanos": focus_nanos},
        "layout": {
            "pos_in_scrolling_layout": [col, row],
        },
    }


class PureColumnModelTests(unittest.TestCase):
    def test_target_widths_for_default_pages(self):
        columns = [
            cp.Column(signature=(1,), representative_id=1),
            cp.Column(signature=(2,), representative_id=2),
            cp.Column(signature=(3,), representative_id=3),
            cp.Column(signature=(4,), representative_id=4),
            cp.Column(signature=(5,), representative_id=5),
            cp.Column(signature=(6,), representative_id=6),
            cp.Column(signature=(7,), representative_id=7),
        ]

        planned = cp.plan_widths(columns, page_size=3)

        self.assertEqual(
            [(item.column.signature, item.target_percent) for item in planned],
            [
                ((1,), 100.0 / 3),
                ((2,), 100.0 / 3),
                ((3,), 100.0 / 3),
                ((4,), 100.0 / 3),
                ((5,), 100.0 / 3),
                ((6,), 100.0 / 3),
                ((7,), 100.0),
            ],
        )

    def test_plan_widths_handles_zero_columns(self):
        self.assertEqual(cp.plan_widths([], page_size=3), [])

    def test_collect_columns_ignores_floating_and_other_workspaces(self):
        windows = {
            1: window(1, workspace_id=1, col=0),
            2: window(2, workspace_id=1, col=1, is_floating=True),
            3: window(3, workspace_id=2, col=0),
            4: {**window(4, workspace_id=1), "layout": {"pos_in_scrolling_layout": None}},
            5: {**window(5, workspace_id=None), "workspace_id": None},
        }

        columns = cp.collect_columns(windows, focused_workspace_id=1)

        self.assertEqual([col.signature for col in columns], [(1,)])
        self.assertEqual([col.representative_id for col in columns], [1])

    def test_collect_columns_groups_stacked_windows(self):
        windows = {
            1: window(1, col=0, row=0, focus_secs=1),
            2: window(2, col=0, row=1, focus_secs=3),
            3: window(3, col=1, row=0, focus_secs=2),
        }

        columns = cp.collect_columns(windows, focused_workspace_id=1)

        self.assertEqual([col.signature for col in columns], [(1, 2), (3,)])
        self.assertEqual(columns[0].representative_id, 2)
        self.assertEqual(columns[1].representative_id, 3)

    def test_collect_columns_prefers_currently_focused_window_as_representative(self):
        windows = {
            1: window(1, col=0, row=0, is_focused=True, focus_secs=1),
            2: window(2, col=0, row=1, focus_secs=3),
        }

        columns = cp.collect_columns(windows, focused_workspace_id=1)

        self.assertEqual(columns[0].signature, (1, 2))
        self.assertEqual(columns[0].representative_id, 1)

    def test_workspace_signature_is_ordered_column_signatures(self):
        columns = [
            cp.Column(signature=(1, 2), representative_id=1),
            cp.Column(signature=(3,), representative_id=3),
        ]

        self.assertEqual(cp.workspace_signature(columns), ((1, 2), (3,)))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the pure-model tests and verify they fail**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: fail while importing because `niri/scripts/column-pager` does not exist.

- [ ] **Step 3: Write the minimal pure-model implementation**

Create `niri/scripts/column-pager` with this content:

```python
#!/usr/bin/env python3
"""Keep niri tiled columns sized into focused-workspace pages."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Column:
    signature: tuple[int, ...]
    representative_id: int


@dataclass(frozen=True)
class PlannedWidth:
    column: Column
    target_percent: float


def focus_timestamp_key(window: dict[str, Any]) -> tuple[int, int]:
    timestamp = window.get("focus_timestamp") or {}
    return (
        int(timestamp.get("secs") or 0),
        int(timestamp.get("nanos") or 0),
    )


def collect_columns(
    windows: dict[int, dict[str, Any]],
    focused_workspace_id: int | None,
) -> list[Column]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)

    if focused_workspace_id is None:
        return []

    for win in windows.values():
        if win.get("workspace_id") != focused_workspace_id:
            continue
        if win.get("is_floating"):
            continue
        layout = win.get("layout") or {}
        position = layout.get("pos_in_scrolling_layout")
        if position is None:
            continue
        col_idx = int(position[0])
        grouped[col_idx].append(win)

    columns: list[Column] = []
    for _col_idx, column_windows in sorted(grouped.items()):
        signature = tuple(sorted(int(win["id"]) for win in column_windows))
        representative = choose_representative(column_windows)
        columns.append(Column(signature=signature, representative_id=representative))
    return columns


def choose_representative(column_windows: list[dict[str, Any]]) -> int:
    focused = [win for win in column_windows if win.get("is_focused")]
    if focused:
        return int(focused[0]["id"])

    with_timestamp = sorted(
        column_windows,
        key=lambda win: (focus_timestamp_key(win), -row_index(win)),
        reverse=True,
    )
    if focus_timestamp_key(with_timestamp[0]) != (0, 0):
        return int(with_timestamp[0]["id"])

    by_row = sorted(column_windows, key=row_index)
    return int(by_row[0]["id"])


def row_index(window: dict[str, Any]) -> int:
    layout = window.get("layout") or {}
    position = layout.get("pos_in_scrolling_layout") or [0, 0]
    return int(position[1])


def plan_widths(columns: list[Column], page_size: int = 3) -> list[PlannedWidth]:
    if page_size < 1:
        raise ValueError("page_size must be at least 1")

    planned: list[PlannedWidth] = []
    for start in range(0, len(columns), page_size):
        page = columns[start : start + page_size]
        target_percent = 100.0 / len(page)
        for column in page:
            planned.append(PlannedWidth(column=column, target_percent=target_percent))
    return planned


def workspace_signature(columns: list[Column]) -> tuple[tuple[int, ...], ...]:
    return tuple(column.signature for column in columns)


def main() -> int:
    raise SystemExit("daemon implementation is not complete")


if __name__ == "__main__":
    raise SystemExit(main())
```

Then make it executable:

```bash
rtk chmod +x niri/scripts/column-pager
```

- [ ] **Step 4: Run the pure-model tests and verify they pass**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/niri/test_column_pager.py niri/scripts/column-pager
rtk git commit -m "feat: add niri column pager model"
```

---

### Task 2: Cache And Scheduling Rules

**Files:**
- Modify: `tests/niri/test_column_pager.py`
- Modify: `niri/scripts/column-pager`

- [ ] **Step 1: Add failing cache and scheduler tests**

Append these tests above the `if __name__ == "__main__":` block in `tests/niri/test_column_pager.py`:

```python
class CacheAndSchedulingTests(unittest.TestCase):
    def test_width_cache_skips_unchanged_columns_and_prunes_removed_columns(self):
        cache = cp.WidthCache()
        workspace_id = 1
        first = [
            cp.PlannedWidth(cp.Column((1,), 1), 100.0 / 3),
            cp.PlannedWidth(cp.Column((2,), 2), 100.0 / 3),
            cp.PlannedWidth(cp.Column((3,), 3), 100.0 / 3),
        ]
        self.assertEqual(cache.filter_needed(workspace_id, first), first)
        cache.mark_applied(workspace_id, first)

        second = [
            cp.PlannedWidth(cp.Column((1,), 1), 100.0 / 3),
            cp.PlannedWidth(cp.Column((2,), 2), 100.0 / 3),
            cp.PlannedWidth(cp.Column((4,), 4), 100.0 / 3),
        ]

        needed = cache.filter_needed(workspace_id, second)
        cache.prune(workspace_id, [item.column for item in second])

        self.assertEqual([(item.column.signature, item.target_percent) for item in needed], [((4,), 100.0 / 3)])
        self.assertEqual(set(cache.by_workspace[workspace_id]), {(1,), (2,), (4,)})

    def test_scheduler_waits_for_initial_snapshots(self):
        scheduler = cp.Scheduler(debounce_ms=100)

        scheduler.note_workspaces_snapshot(now_ms=0)
        self.assertFalse(scheduler.ready_for_first_pass)
        scheduler.note_windows_snapshot(now_ms=10)

        self.assertTrue(scheduler.ready_for_first_pass)
        self.assertTrue(scheduler.pending)
        self.assertEqual(scheduler.next_run_ms, 110)

    def test_scheduler_ignores_self_layout_event_when_signature_unchanged(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.workspace_id = 1
        scheduler.workspace_signature = ((1,),)
        scheduler.note_batch_completed(now_ms=100)

        scheduler.note_layout_event(workspace_id=1, signature=((1,),), now_ms=150)

        self.assertFalse(scheduler.pending)

    def test_scheduler_schedules_during_suppression_when_signature_changes(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.workspace_id = 1
        scheduler.workspace_signature = ((1,),)
        scheduler.note_batch_completed(now_ms=100)

        scheduler.note_layout_event(workspace_id=1, signature=((1,), (2,)), now_ms=150)

        self.assertTrue(scheduler.pending)
        self.assertEqual(scheduler.next_run_ms, 250)
        self.assertEqual(scheduler.workspace_signature, ((1,), (2,)))

    def test_scheduler_defers_while_overview_is_open(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.ready_for_first_pass = True

        scheduler.note_overview(is_open=True)
        scheduler.schedule(now_ms=0)
        self.assertTrue(scheduler.pending)
        self.assertIsNone(scheduler.next_run_ms)

        scheduler.note_overview(is_open=False, now_ms=20)
        self.assertTrue(scheduler.pending)
        self.assertEqual(scheduler.next_run_ms, 120)
```

- [ ] **Step 2: Run the cache/scheduler tests and verify they fail**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: fail with missing `WidthCache` and `Scheduler`.

- [ ] **Step 3: Add cache and scheduler implementation**

Insert this code in `niri/scripts/column-pager` after `workspace_signature`:

```python
class WidthCache:
    def __init__(self) -> None:
        self.by_workspace: dict[int, dict[tuple[int, ...], float]] = {}

    def filter_needed(
        self,
        workspace_id: int,
        planned: list[PlannedWidth],
    ) -> list[PlannedWidth]:
        workspace_cache = self.by_workspace.setdefault(workspace_id, {})
        return [
            item
            for item in planned
            if workspace_cache.get(item.column.signature) != item.target_percent
        ]

    def mark_applied(self, workspace_id: int, planned: list[PlannedWidth]) -> None:
        workspace_cache = self.by_workspace.setdefault(workspace_id, {})
        for item in planned:
            workspace_cache[item.column.signature] = item.target_percent

    def prune(self, workspace_id: int, columns: list[Column]) -> None:
        workspace_cache = self.by_workspace.setdefault(workspace_id, {})
        live_signatures = {column.signature for column in columns}
        for signature in list(workspace_cache):
            if signature not in live_signatures:
                del workspace_cache[signature]


class Scheduler:
    def __init__(self, debounce_ms: int = 100) -> None:
        self.debounce_ms = debounce_ms
        self.pending = False
        self.next_run_ms: int | None = None
        self.ready_for_first_pass = False
        self._saw_workspaces_snapshot = False
        self._saw_windows_snapshot = False
        self.overview_open = False
        self.workspace_id: int | None = None
        self.workspace_signature: tuple[tuple[int, ...], ...] = ()
        self.suppress_until_ms: int | None = None

    def note_workspaces_snapshot(self, now_ms: int) -> None:
        self._saw_workspaces_snapshot = True
        self._maybe_ready(now_ms)

    def note_windows_snapshot(self, now_ms: int) -> None:
        self._saw_windows_snapshot = True
        self._maybe_ready(now_ms)

    def _maybe_ready(self, now_ms: int) -> None:
        if self._saw_workspaces_snapshot and self._saw_windows_snapshot:
            self.ready_for_first_pass = True
            self.schedule(now_ms)

    def schedule(self, now_ms: int) -> None:
        if not self.ready_for_first_pass:
            return
        self.pending = True
        self.next_run_ms = None if self.overview_open else now_ms + self.debounce_ms

    def note_overview(self, is_open: bool, now_ms: int | None = None) -> None:
        self.overview_open = is_open
        if not is_open and self.pending and self.next_run_ms is None and now_ms is not None:
            self.next_run_ms = now_ms + self.debounce_ms

    def note_batch_completed(self, now_ms: int) -> None:
        self.suppress_until_ms = now_ms + self.debounce_ms
        self.pending = False
        self.next_run_ms = None

    def note_layout_event(
        self,
        workspace_id: int | None,
        signature: tuple[tuple[int, ...], ...],
        now_ms: int,
    ) -> None:
        unchanged = workspace_id == self.workspace_id and signature == self.workspace_signature
        suppressed = self.suppress_until_ms is not None and now_ms <= self.suppress_until_ms
        if suppressed and unchanged:
            return
        self.workspace_id = workspace_id
        self.workspace_signature = signature
        self.schedule(now_ms)
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/niri/test_column_pager.py niri/scripts/column-pager
rtk git commit -m "feat: add niri column pager scheduling"
```

---

### Task 3: IPC Framing And Action Builders

**Files:**
- Modify: `tests/niri/test_column_pager.py`
- Modify: `niri/scripts/column-pager`

- [ ] **Step 1: Add failing IPC tests**

Append these tests above the `if __name__ == "__main__":` block in `tests/niri/test_column_pager.py`:

```python
class IpcFramingTests(unittest.TestCase):
    def test_action_messages_match_niri_json_shape(self):
        self.assertEqual(
            cp.focus_window_message(42),
            {"Action": {"FocusWindow": {"id": 42}}},
        )
        self.assertEqual(
            cp.set_column_width_message(100.0 / 3),
            {"Action": {"SetColumnWidth": {"change": {"SetProportion": 100.0 / 3}}}},
        )

    def test_niri_socket_reads_newline_delimited_json(self):
        fake = cp.FakeRawSocket([b'{"Ok":1}\n{"Ok":2}\n{"Ok":'])
        sock = cp.NiriSocket(fake)

        self.assertEqual(sock.read_json(), {"Ok": 1})
        self.assertEqual(sock.read_json(), {"Ok": 2})

        fake.chunks.append(b'3}\n')
        self.assertEqual(sock.read_json(), {"Ok": 3})

    def test_niri_socket_writes_json_with_newline(self):
        fake = cp.FakeRawSocket([])
        sock = cp.NiriSocket(fake)

        sock.send_json({"Action": {"FocusWindow": {"id": 7}}})

        self.assertEqual(fake.sent, [b'{"Action":{"FocusWindow":{"id":7}}}\n'])

    def test_niri_socket_writes_string_request_with_newline(self):
        fake = cp.FakeRawSocket([])
        sock = cp.NiriSocket(fake)

        sock.send_request("EventStream")

        self.assertEqual(fake.sent, [b'"EventStream"\n'])
```

- [ ] **Step 2: Run IPC tests and verify they fail**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: fail with missing IPC helpers.

- [ ] **Step 3: Add IPC framing implementation**

Add these imports near the top of `niri/scripts/column-pager`:

```python
import json
import socket
```

Insert this code after the scheduler implementation:

```python
def focus_window_message(window_id: int) -> dict[str, Any]:
    return {"Action": {"FocusWindow": {"id": int(window_id)}}}


def set_column_width_message(target_percent: float) -> dict[str, Any]:
    return {
        "Action": {
            "SetColumnWidth": {
                "change": {
                    "SetProportion": float(target_percent),
                },
            },
        },
    }


def event_stream_request() -> str:
    return "EventStream"


class NiriSocket:
    def __init__(self, raw_socket: socket.socket, buffer_size: int = 4096) -> None:
        self.raw_socket = raw_socket
        self.buffer_size = buffer_size
        self._pending: list[str] = []
        self._partial = ""

    @classmethod
    def connect(cls, socket_path: str) -> "NiriSocket":
        raw = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        raw.connect(socket_path)
        return cls(raw)

    def send_request(self, request: str) -> None:
        self.raw_socket.sendall(json.dumps(request, separators=(",", ":")).encode("utf-8") + b"\n")

    def send_json(self, message: dict[str, Any]) -> None:
        encoded = json.dumps(message, separators=(",", ":")).encode("utf-8") + b"\n"
        self.raw_socket.sendall(encoded)

    def read_json(self) -> dict[str, Any]:
        while not self._pending:
            chunk = self.raw_socket.recv(self.buffer_size)
            if not chunk:
                raise EOFError("niri IPC socket closed")
            text = self._partial + chunk.decode("utf-8")
            pieces = text.split("\n")
            self._partial = pieces.pop()
            self._pending.extend(piece for piece in pieces if piece)
        return json.loads(self._pending.pop(0))

    def close(self) -> None:
        self.raw_socket.close()


class FakeRawSocket:
    def __init__(self, chunks: list[bytes]) -> None:
        self.chunks = chunks
        self.sent: list[bytes] = []
        self.closed = False

    def recv(self, _buffer_size: int) -> bytes:
        if not self.chunks:
            return b""
        return self.chunks.pop(0)

    def sendall(self, data: bytes) -> None:
        self.sent.append(data)

    def close(self) -> None:
        self.closed = True
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/niri/test_column_pager.py niri/scripts/column-pager
rtk git commit -m "feat: add niri column pager ipc framing"
```

---

### Task 4: Daemon State And Width Application

**Files:**
- Modify: `tests/niri/test_column_pager.py`
- Modify: `niri/scripts/column-pager`

- [ ] **Step 1: Add failing daemon-state and action-application tests**

Append these tests above the `if __name__ == "__main__":` block in `tests/niri/test_column_pager.py`:

```python
class FakeActionSocket:
    def __init__(self):
        self.messages = []

    def send_json(self, message):
        self.messages.append(message)


class DaemonStateTests(unittest.TestCase):
    def test_apply_widths_focuses_needed_columns_and_restores_focus(self):
        action_socket = FakeActionSocket()
        cache = cp.WidthCache()
        state = cp.DaemonState(
            workspaces={1: {"id": 1, "is_focused": True}},
            windows={
                1: window(1, col=0, is_focused=True),
                2: window(2, col=1),
            },
        )

        applied = cp.apply_widths(
            state=state,
            action_socket=action_socket,
            cache=cache,
            page_size=3,
        )

        self.assertEqual(len(applied), 2)
        self.assertEqual(
            action_socket.messages,
            [
                cp.focus_window_message(1),
                cp.set_column_width_message(50.0),
                cp.focus_window_message(2),
                cp.set_column_width_message(50.0),
                cp.focus_window_message(1),
            ],
        )

    def test_apply_widths_skips_when_cache_matches(self):
        action_socket = FakeActionSocket()
        cache = cp.WidthCache()
        state = cp.DaemonState(
            workspaces={1: {"id": 1, "is_focused": True}},
            windows={
                1: window(1, col=0, is_focused=True),
                2: window(2, col=1),
            },
        )
        cp.apply_widths(state, action_socket, cache, page_size=3)
        action_socket.messages.clear()

        applied = cp.apply_widths(state, action_socket, cache, page_size=3)

        self.assertEqual(applied, [])
        self.assertEqual(action_socket.messages, [])

    def test_apply_widths_skips_when_no_focused_tiled_window_can_be_restored(self):
        action_socket = FakeActionSocket()
        cache = cp.WidthCache()
        state = cp.DaemonState(
            workspaces={1: {"id": 1, "is_focused": True}},
            windows={
                1: window(1, col=0, is_focused=False),
                2: window(2, col=1, is_floating=True, is_focused=True),
            },
        )

        applied = cp.apply_widths(state, action_socket, cache, page_size=3)

        self.assertEqual(applied, [])
        self.assertEqual(action_socket.messages, [])

    def test_state_updates_from_initial_snapshots_and_window_events(self):
        state = cp.DaemonState()
        state.apply_event("WorkspacesChanged", {"workspaces": [{"id": 1, "is_focused": True}]})
        state.apply_event("WindowsChanged", {"windows": [window(1, col=0)]})

        self.assertEqual(state.focused_workspace_id(), 1)
        self.assertEqual(set(state.windows), {1})

        state.apply_event("WindowOpenedOrChanged", {"window": window(2, col=1)})
        self.assertEqual(set(state.windows), {1, 2})

        state.apply_event("WindowClosed", {"id": 1})
        self.assertEqual(set(state.windows), {2})

    def test_state_tracks_overview(self):
        state = cp.DaemonState()
        state.apply_event("OverviewOpenedOrClosed", {"is_open": True})
        self.assertTrue(state.overview_open)
        state.apply_event("OverviewOpenedOrClosed", {"is_open": False})
        self.assertFalse(state.overview_open)
```

- [ ] **Step 2: Run daemon tests and verify they fail**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: fail with missing `DaemonState` and `apply_widths`.

- [ ] **Step 3: Add daemon state and width application implementation**

Insert this code after the IPC classes in `niri/scripts/column-pager`:

```python
@dataclass
class DaemonState:
    workspaces: dict[int, dict[str, Any]] | None = None
    windows: dict[int, dict[str, Any]] | None = None
    overview_open: bool = False

    def __post_init__(self) -> None:
        if self.workspaces is None:
            self.workspaces = {}
        if self.windows is None:
            self.windows = {}

    def focused_workspace_id(self) -> int | None:
        for workspace in self.workspaces.values():
            if workspace.get("is_focused"):
                return int(workspace["id"])
        return None

    def focused_tiled_window_id(self) -> int | None:
        focused_workspace_id = self.focused_workspace_id()
        for win in self.windows.values():
            if not win.get("is_focused"):
                continue
            if win.get("workspace_id") != focused_workspace_id:
                continue
            if win.get("is_floating"):
                continue
            layout = win.get("layout") or {}
            if layout.get("pos_in_scrolling_layout") is None:
                continue
            return int(win["id"])
        return None

    def columns(self) -> list[Column]:
        return collect_columns(self.windows, self.focused_workspace_id())

    def signature(self) -> tuple[tuple[int, ...], ...]:
        return workspace_signature(self.columns())

    def apply_event(self, event_name: str, event_data: dict[str, Any]) -> None:
        if event_name == "WorkspacesChanged":
            self.workspaces = {int(item["id"]): item for item in event_data["workspaces"]}
        elif event_name == "WorkspaceActivated" and event_data.get("focused"):
            active_id = int(event_data["id"])
            for workspace in self.workspaces.values():
                workspace["is_focused"] = int(workspace["id"]) == active_id
        elif event_name == "WindowsChanged":
            self.windows = {int(item["id"]): item for item in event_data["windows"]}
        elif event_name == "WindowOpenedOrChanged":
            window = event_data["window"]
            self.windows[int(window["id"])] = window
        elif event_name == "WindowClosed":
            self.windows.pop(int(event_data["id"]), None)
        elif event_name == "WindowLayoutsChanged":
            for window_id, layout in event_data.get("changes", []):
                if int(window_id) in self.windows:
                    self.windows[int(window_id)]["layout"] = layout
        elif event_name == "WindowFocusChanged":
            focused_id = event_data.get("id")
            for window in self.windows.values():
                window["is_focused"] = int(window["id"]) == focused_id
        elif event_name == "WindowFocusTimestampChanged":
            window_id = int(event_data["id"])
            if window_id in self.windows:
                self.windows[window_id]["focus_timestamp"] = event_data["focus_timestamp"]
        elif event_name == "OverviewOpenedOrClosed":
            self.overview_open = bool(event_data["is_open"])


def apply_widths(
    state: DaemonState,
    action_socket: Any,
    cache: WidthCache,
    page_size: int,
) -> list[PlannedWidth]:
    workspace_id = state.focused_workspace_id()
    restore_id = state.focused_tiled_window_id()
    if workspace_id is None or restore_id is None:
        return []

    columns = state.columns()
    planned = plan_widths(columns, page_size=page_size)
    needed = cache.filter_needed(workspace_id, planned)
    if not needed:
        cache.prune(workspace_id, columns)
        return []

    for item in needed:
        action_socket.send_json(focus_window_message(item.column.representative_id))
        action_socket.send_json(set_column_width_message(item.target_percent))
    action_socket.send_json(focus_window_message(restore_id))
    cache.mark_applied(workspace_id, needed)
    cache.prune(workspace_id, columns)
    return needed
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/niri/test_column_pager.py niri/scripts/column-pager
rtk git commit -m "feat: apply niri column pager widths"
```

---

### Task 5: Main Daemon Loop And CLI

**Files:**
- Modify: `tests/niri/test_column_pager.py`
- Modify: `niri/scripts/column-pager`

- [ ] **Step 1: Add failing CLI tests**

Append these tests above the `if __name__ == "__main__":` block in `tests/niri/test_column_pager.py`:

```python
class CliTests(unittest.TestCase):
    def test_parse_args_defaults(self):
        args = cp.parse_args([])
        self.assertEqual(args.page_size, 3)
        self.assertEqual(args.debounce_ms, 100)

    def test_parse_args_rejects_invalid_page_size(self):
        with self.assertRaises(SystemExit):
            cp.parse_args(["--page-size", "0"])

    def test_event_name_and_data_extracts_single_variant(self):
        self.assertEqual(
            cp.event_name_and_data({"WindowClosed": {"id": 7}}),
            ("WindowClosed", {"id": 7}),
        )

    def test_event_name_and_data_rejects_bad_event(self):
        with self.assertRaises(ValueError):
            cp.event_name_and_data({"A": {}, "B": {}})
```

- [ ] **Step 2: Run CLI tests and verify they fail**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: fail with missing `parse_args` and `event_name_and_data`.

- [ ] **Step 3: Add CLI and daemon loop implementation**

Add these imports near the top of `niri/scripts/column-pager`:

```python
import argparse
import os
import sys
import time
```

Replace the current `main()` with this implementation:

```python
def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resize niri tiled columns into focused-workspace pages.",
    )
    parser.add_argument("--page-size", type=int, default=3)
    parser.add_argument("--debounce-ms", type=int, default=100)
    args = parser.parse_args(argv)
    if args.page_size < 1:
        parser.error("--page-size must be at least 1")
    if args.debounce_ms < 0:
        parser.error("--debounce-ms must be non-negative")
    return args


def event_name_and_data(event: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    if len(event) != 1:
        raise ValueError(f"expected exactly one event variant, got {event!r}")
    name, data = next(iter(event.items()))
    return name, data


def now_ms() -> int:
    return round(time.monotonic() * 1000)


def run_daemon(
    event_socket: NiriSocket,
    action_socket: NiriSocket,
    page_size: int,
    debounce_ms: int,
) -> int:
    state = DaemonState()
    cache = WidthCache()
    scheduler = Scheduler(debounce_ms=debounce_ms)

    event_socket.send_request(event_stream_request())
    response = event_socket.read_json()
    if "Err" in response:
        print(f"failed to start niri event stream: {response['Err']}", file=sys.stderr)
        return 1

    while True:
        current_ms = now_ms()
        if scheduler.pending and scheduler.next_run_ms is not None and current_ms >= scheduler.next_run_ms:
            if not state.overview_open:
                applied = apply_widths(state, action_socket, cache, page_size=page_size)
                if applied:
                    scheduler.note_batch_completed(now_ms())
                else:
                    scheduler.pending = False
                    scheduler.next_run_ms = None

        event = event_socket.read_json()
        event_name, event_data = event_name_and_data(event)
        state.apply_event(event_name, event_data)
        current_ms = now_ms()

        if event_name == "WorkspacesChanged":
            scheduler.note_workspaces_snapshot(current_ms)
        elif event_name == "WindowsChanged":
            scheduler.note_windows_snapshot(current_ms)
        elif event_name == "OverviewOpenedOrClosed":
            scheduler.note_overview(state.overview_open, current_ms)

        if not scheduler.ready_for_first_pass:
            continue

        signature = state.signature()
        workspace_id = state.focused_workspace_id()

        if event_name == "WindowLayoutsChanged":
            scheduler.note_layout_event(workspace_id, signature, current_ms)
        elif event_name in {
            "WindowsChanged",
            "WindowOpenedOrChanged",
            "WindowClosed",
            "WorkspaceActivated",
            "OverviewOpenedOrClosed",
        }:
            if workspace_id != scheduler.workspace_id or signature != scheduler.workspace_signature:
                scheduler.workspace_id = workspace_id
                scheduler.workspace_signature = signature
                scheduler.schedule(current_ms)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    socket_path = os.environ.get("NIRI_SOCKET")
    if not socket_path:
        print("NIRI_SOCKET is not set", file=sys.stderr)
        return 1

    event_socket = NiriSocket.connect(socket_path)
    action_socket = NiriSocket.connect(socket_path)
    try:
        return run_daemon(
            event_socket=event_socket,
            action_socket=action_socket,
            page_size=args.page_size,
            debounce_ms=args.debounce_ms,
        )
    except (EOFError, OSError) as exc:
        print(f"niri IPC disconnected: {exc}", file=sys.stderr)
        return 1
    finally:
        event_socket.close()
        action_socket.close()
```

- [ ] **Step 4: Run all unit tests**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all tests pass.

- [ ] **Step 5: Run script help**

Run:

```bash
rtk niri/scripts/column-pager --help
```

Expected: output includes `--page-size` and `--debounce-ms`.

- [ ] **Step 6: Commit**

```bash
rtk git add tests/niri/test_column_pager.py niri/scripts/column-pager
rtk git commit -m "feat: add niri column pager daemon"
```

---

### Task 6: Niri Config Integration

**Files:**
- Modify: `niri/config.kdl`
- Test: `niri/scripts/column-pager`

- [ ] **Step 1: Add startup entry**

Modify `niri/config.kdl` so the startup block includes `column-pager` next to the other niri helper scripts:

```kdl
spawn-at-startup "~/.config/niri/scripts/place-scratchpad-workspace"
spawn-at-startup "~/.config/niri/scripts/column-pager"
spawn-at-startup "qs" "-c" "noctalia-shell"
spawn-at-startup "wl-clip-persist" "--clipboard" "regular"
spawn-sh-at-startup "qs -p ~/d/software/ohai/ohai/shell.qml"
spawn-sh-at-startup "node ~/d/software/ohai/bin/ohai-mcp"
```

- [ ] **Step 2: Run unit tests**

Run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
```

Expected: all tests pass.

- [ ] **Step 3: Run a syntax check**

Run:

```bash
rtk python3 -m py_compile niri/scripts/column-pager
```

Expected: no output and exit code 0.

- [ ] **Step 4: Commit**

```bash
rtk git add niri/config.kdl niri/scripts/column-pager tests/niri/test_column_pager.py
rtk git commit -m "feat: start niri column pager"
```

---

### Task 7: Manual Verification In Live Niri

**Files:**
- Read: `docs/specs/2026-05-30-niri-column-pager-design.md`
- Run: `niri/scripts/column-pager`

- [ ] **Step 1: Start the helper manually in a terminal**

Run inside a live niri session:

```bash
rtk niri/scripts/column-pager
```

Expected: the command keeps running with no output. If `NIRI_SOCKET` is missing, expected output is `NIRI_SOCKET is not set` and exit code 1.

- [ ] **Step 2: Verify one to three columns**

Open one, two, and three tiled windows on the focused workspace.

Expected:
- 1 tiled column spans the workspace width.
- 2 tiled columns each receive 50%.
- 3 tiled columns each receive 33.33333%.

- [ ] **Step 3: Verify overflow pages**

Open fourth, fifth, sixth, and seventh tiled columns.

Expected:
- Column 4 is 100% on the next horizontally scrolled page.
- Columns 4 and 5 become 50% each.
- Columns 4, 5, and 6 become 33.33333% each.
- Column 7 starts a fresh 100% page.

- [ ] **Step 4: Verify stacked column behavior**

Stack two windows into one column with the existing niri consume binding:

```text
Super+Comma
```

Expected: the stacked windows count as one managed column, and the representative selection does not switch the active window inside that column unless it is already the focused window.

- [ ] **Step 5: Verify floating windows are ignored**

Open or toggle the scratchpad terminal:

```text
Alt+Return
```

Expected: the floating scratchpad does not change tiled column widths.

- [ ] **Step 6: Verify multi-monitor focus safety**

On two monitors, open or move a window on a visible-but-unfocused workspace.

Expected: keyboard focus stays on the current output. The visible-but-unfocused workspace is reconciled only after it becomes the globally focused workspace.

- [ ] **Step 7: Verify overview deferral**

Open overview during a layout change:

```text
Super+O
```

Expected: the helper does not visibly resize columns while overview is open. The pending resize pass runs after overview closes.

- [ ] **Step 8: Verify no self-induced layout loop**

Run the helper for several minutes while opening, closing, and moving columns.

Expected: CPU usage remains low, the terminal does not print repeated errors, and column resizing settles after each structural change.

- [ ] **Step 9: Commit verification notes if code changed during verification**

If manual verification required code changes, run:

```bash
rtk python3 -m unittest -v tests/niri/test_column_pager.py
rtk python3 -m py_compile niri/scripts/column-pager
rtk git add niri/scripts/column-pager tests/niri/test_column_pager.py niri/config.kdl
rtk git commit -m "fix: stabilize niri column pager"
```

Expected: tests and syntax check pass before the commit.

---

## Self-Review

Spec coverage:
- Column-only management, floating-window ignore, stacked columns, page-of-three widths, focused-workspace-only operation, self-induced `WindowLayoutsChanged` suppression, per-column width cache, startup snapshot gating, overview deferral, socket disconnect behavior, and live verification are each covered by tasks above.
- The implementation intentionally does not create a compatibility layer, config file, or reconnect loop.

Placeholder scan:
- The plan contains no placeholder markers or unspecified edge-handling steps.
- Every code-changing step includes concrete code or exact file edits.

Type consistency:
- `Column`, `PlannedWidth`, `WidthCache`, `Scheduler`, `DaemonState`, `NiriSocket`, `collect_columns`, `plan_widths`, `workspace_signature`, `apply_widths`, `parse_args`, and `event_name_and_data` are introduced before they are used in later tasks.
- Widths are consistently represented as niri percentage values such as `100.0 / 3`, not 0-1 fractions.
