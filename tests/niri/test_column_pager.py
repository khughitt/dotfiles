import importlib.machinery
import importlib.util
from pathlib import Path
import sys

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "fill-new-window"


def load_script():
    loader = importlib.machinery.SourceFileLoader("column_pager", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules[loader.name] = module
    loader.exec_module(module)
    return module


def test_new_column_fills_only_useful_remaining_space():
    column_pager = load_script()
    target_width = getattr(column_pager, "target_width", None)

    assert target_width is not None, "target_width policy is missing"
    half = 1684
    third = 1114.66667
    full = 3392
    cases = [
        ([full], None),
        ([half], .5),
        ([third], 2 / 3),
        ([half, half], None),
        ([third, third], 1 / 3),
        ([half, third], None),
    ]

    for widths, expected in cases:
        actual = target_width(widths, output_width=3440, gap=24)
        assert actual is None if expected is None else actual == pytest.approx(expected)
