import io
import importlib.machinery
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "niri" / "scripts" / "column-pager"


def load_column_pager():
    loader = importlib.machinery.SourceFileLoader("column_pager", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules[loader.name] = module
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

    def test_collect_columns_falls_back_to_lowest_row_representative(self):
        windows = {
            1: window(1, col=0, row=2),
            2: window(2, col=0, row=0),
            3: window(3, col=0, row=1),
        }

        columns = cp.collect_columns(windows, focused_workspace_id=1)

        self.assertEqual(columns[0].signature, (1, 2, 3))
        self.assertEqual(columns[0].representative_id, 2)

    def test_workspace_signature_is_ordered_column_signatures(self):
        columns = [
            cp.Column(signature=(1, 2), representative_id=1),
            cp.Column(signature=(3,), representative_id=3),
        ]

        self.assertEqual(cp.workspace_signature(columns), ((1, 2), (3,)))


class CacheAndSchedulingTests(unittest.TestCase):
    def test_width_cache_filter_needed_does_not_create_workspace_entry(self):
        cache = cp.WidthCache()
        workspace_id = 1
        planned = [cp.PlannedWidth(cp.Column((1,), 1), 100.0)]

        self.assertEqual(cache.filter_needed(workspace_id, planned), planned)

        self.assertNotIn(workspace_id, cache.by_workspace)

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
        self.assertNotIn((4,), cache.by_workspace[workspace_id])
        cache.mark_applied(workspace_id, needed)
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

    def test_scheduler_batch_completion_does_not_enable_initial_scheduling(self):
        scheduler = cp.Scheduler(debounce_ms=100)

        scheduler.note_batch_completed(now_ms=100)
        scheduler.schedule(now_ms=150)

        self.assertFalse(scheduler.ready_for_first_pass)
        self.assertFalse(scheduler.pending)
        self.assertIsNone(scheduler.next_run_ms)

    def test_scheduler_ignores_self_layout_event_when_signature_unchanged(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.workspace_id = 1
        scheduler.workspace_signature = ((1,),)
        scheduler.ready_for_first_pass = True
        scheduler.note_batch_completed(now_ms=100)

        scheduler.note_layout_event(workspace_id=1, signature=((1,),), now_ms=150)

        self.assertFalse(scheduler.pending)

    def test_scheduler_schedules_during_suppression_when_signature_changes(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.workspace_id = 1
        scheduler.workspace_signature = ((1,),)
        scheduler.ready_for_first_pass = True
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

    def test_scheduler_defers_existing_deadline_when_overview_opens(self):
        scheduler = cp.Scheduler(debounce_ms=100)
        scheduler.ready_for_first_pass = True

        scheduler.schedule(now_ms=0)
        self.assertTrue(scheduler.pending)
        self.assertEqual(scheduler.next_run_ms, 100)

        scheduler.note_overview(is_open=True)
        self.assertTrue(scheduler.pending)
        self.assertIsNone(scheduler.next_run_ms)

        scheduler.note_overview(is_open=False, now_ms=20)
        self.assertTrue(scheduler.pending)
        self.assertEqual(scheduler.next_run_ms, 120)


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

    def test_niri_socket_decodes_utf8_after_complete_line_is_framed(self):
        fake = cp.FakeRawSocket([b'{"Title":"caf\xc3', b'\xa9"}\n'])
        sock = cp.NiriSocket(fake)

        self.assertEqual(sock.read_json(), {"Title": "caf\u00e9"})

    def test_niri_socket_timeout_is_overall_deadline_for_partial_frame(self):
        class MonotonicClock:
            def __init__(self):
                self.value = 1000.0

            def __call__(self):
                return self.value

        class PartialDeadlineRawSocket:
            def __init__(self, clock):
                self.clock = clock
                self.timeout = None
                self.recv_count = 0
                self.chunks = []

            def gettimeout(self):
                return self.timeout

            def settimeout(self, timeout):
                self.timeout = timeout

            def recv(self, _buffer_size):
                self.recv_count += 1
                if self.recv_count == 1:
                    self.clock.value += 0.075
                    return b'{"Ok":'
                if self.chunks:
                    return self.chunks.pop(0)
                if self.timeout is not None and self.timeout <= 0.03:
                    raise cp.socket.timeout("deadline reached")
                return b"1}\n"

            def close(self):
                pass

        clock = MonotonicClock()
        fake = PartialDeadlineRawSocket(clock)
        sock = cp.NiriSocket(fake)
        original_monotonic = cp.time.monotonic
        cp.time.monotonic = clock
        try:
            with self.assertRaises(cp.socket.timeout):
                sock.read_json(timeout_ms=100)
        finally:
            cp.time.monotonic = original_monotonic

        self.assertEqual(sock._partial, b'{"Ok":')

        fake.chunks.append(b"1}\n")
        self.assertEqual(sock.read_json(), {"Ok": 1})

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


class FakeActionSocket:
    def __init__(self):
        self.messages = []

    def send_json(self, message):
        self.messages.append(message)


class FailingActionSocket(FakeActionSocket):
    def __init__(self):
        super().__init__()
        self.set_width_count = 0

    def send_json(self, message):
        self.messages.append(message)
        if "SetColumnWidth" in message.get("Action", {}):
            self.set_width_count += 1
            if self.set_width_count == 2:
                raise RuntimeError("set width failed")


class FakeClock:
    def __init__(self):
        self.value = 0

    def __call__(self):
        return self.value

    def advance(self, delta_ms):
        self.value += delta_ms


class QuietEventSocket:
    def __init__(self, clock):
        self.clock = clock
        self.sent = []
        self.timed_out = False
        self.events = [
            {"Ok": {}},
            {"WorkspacesChanged": {"workspaces": [{"id": 1, "is_focused": True}]}},
            {
                "WindowsChanged": {
                    "windows": [
                        window(1, col=0, is_focused=True),
                        window(2, col=1),
                    ],
                },
            },
        ]

    def send_request(self, request):
        self.sent.append(request)

    def read_json(self, timeout_ms=None):
        if self.events:
            return self.events.pop(0)
        if timeout_ms is None:
            if self.timed_out:
                raise EOFError("stop test daemon")
            raise AssertionError("daemon attempted an unbounded read with scheduled work pending")
        self.timed_out = True
        self.clock.advance(timeout_ms)
        raise cp.socket.timeout("deadline reached")


class FakeConnectedSocket:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True


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

    def test_apply_widths_restores_focus_and_does_not_cache_on_action_failure(self):
        action_socket = FailingActionSocket()
        cache = cp.WidthCache()
        state = cp.DaemonState(
            workspaces={1: {"id": 1, "is_focused": True}},
            windows={
                1: window(1, col=0, is_focused=True),
                2: window(2, col=1),
            },
        )

        with self.assertRaisesRegex(RuntimeError, "set width failed"):
            cp.apply_widths(state, action_socket, cache, page_size=3)

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
        self.assertEqual(cache.by_workspace, {})

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

    def test_focused_window_opened_or_changed_clears_other_window_focus(self):
        state = cp.DaemonState(
            workspaces={1: {"id": 1, "is_focused": True}},
            windows={
                1: window(1, col=0, is_focused=True),
            },
        )

        state.apply_event("WindowOpenedOrChanged", {"window": window(2, col=1, is_focused=True)})

        self.assertFalse(state.windows[1]["is_focused"])
        self.assertTrue(state.windows[2]["is_focused"])
        self.assertEqual(state.focused_tiled_window_id(), 2)

    def test_state_tracks_overview(self):
        state = cp.DaemonState()
        state.apply_event("OverviewOpenedOrClosed", {"is_open": True})
        self.assertTrue(state.overview_open)
        state.apply_event("OverviewOpenedOrClosed", {"is_open": False})
        self.assertFalse(state.overview_open)

    def test_run_daemon_applies_pending_widths_after_deadline_without_next_event(self):
        clock = FakeClock()
        event_socket = QuietEventSocket(clock)
        action_socket = FakeActionSocket()
        original_now_ms = cp.now_ms
        cp.now_ms = clock
        try:
            with self.assertRaises(EOFError):
                cp.run_daemon(
                    event_socket=event_socket,
                    action_socket=action_socket,
                    page_size=3,
                    debounce_ms=100,
                )
        finally:
            cp.now_ms = original_now_ms

        self.assertEqual(event_socket.sent, ["EventStream"])
        self.assertTrue(event_socket.timed_out)
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

    def test_main_closes_first_socket_when_second_connect_fails(self):
        first_socket = FakeConnectedSocket()
        with (
            patch.dict(cp.os.environ, {"NIRI_SOCKET": "/tmp/niri.sock"}),
            patch.object(
                cp.NiriSocket,
                "connect",
                side_effect=[first_socket, OSError("connect failed")],
            ),
            patch.object(cp.sys, "stderr", new=io.StringIO()),
        ):
            result = cp.main([])

        self.assertEqual(result, 1)
        self.assertTrue(first_socket.closed)


if __name__ == "__main__":
    unittest.main()
