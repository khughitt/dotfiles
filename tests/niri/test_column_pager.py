import importlib.machinery
import importlib.util
from pathlib import Path
import sys
import unittest


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


if __name__ == "__main__":
    unittest.main()
