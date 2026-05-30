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

    def test_workspace_signature_is_ordered_column_signatures(self):
        columns = [
            cp.Column(signature=(1, 2), representative_id=1),
            cp.Column(signature=(3,), representative_id=3),
        ]

        self.assertEqual(cp.workspace_signature(columns), ((1, 2), (3,)))


if __name__ == "__main__":
    unittest.main()
