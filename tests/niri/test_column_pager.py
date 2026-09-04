import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "fill-new-window"


class ActionSocket:
    def __init__(self):
        self.messages = []

    def request(self, message):
        self.messages.append(message)


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


def test_new_column_uses_prism_gap(monkeypatch):
    column_pager = load_script()
    commands = {
        ("niri", "msg", "-j", "outputs"): json.dumps(
            {"DP-1": {"logical": {"width": 1000}}}
        ),
        ("prism", "get", "compositor.gaps"): "60\n",
    }

    def run(command, **kwargs):
        return subprocess.CompletedProcess(command, 0, commands[tuple(command)], "")

    monkeypatch.setattr(column_pager.subprocess, "run", run)
    state = column_pager.State()
    state.workspaces = {1: {"output": "DP-1"}}
    state.windows = {
        window_id: {
            "id": window_id,
            "workspace_id": 1,
            "is_floating": False,
            "layout": {
                "pos_in_scrolling_layout": [window_id, 1],
                "tile_size": [253.3333333333, 1000],
            },
        }
        for window_id in (1, 2)
    }
    action_socket = ActionSocket()

    column_pager.resize_new_window(
        state,
        {"id": 3, "workspace_id": 1, "is_floating": False, "is_focused": True},
        action_socket,
    )

    proportion = action_socket.messages[-1]["Action"]["SetColumnWidth"]["change"]["SetProportion"]
    assert proportion == pytest.approx(100 / 3)


def test_second_column_uses_prism_gap_to_split_evenly(monkeypatch):
    column_pager = load_script()
    commands = {
        ("niri", "msg", "-j", "outputs"): json.dumps(
            {"DP-1": {"logical": {"width": 3440}}}
        ),
        ("prism", "get", "compositor.gaps"): "60\n",
    }

    def run(command, **kwargs):
        return subprocess.CompletedProcess(command, 0, commands[tuple(command)], "")

    monkeypatch.setattr(column_pager.subprocess, "run", run)
    state = column_pager.State()
    state.workspaces = {1: {"output": "DP-1"}}
    state.windows = {
        1: {
            "id": 1,
            "workspace_id": 1,
            "is_floating": False,
            "layout": {
                "pos_in_scrolling_layout": [1, 1],
                "tile_size": [1630, 1000],
            },
        }
    }

    action_socket = ActionSocket()
    column_pager.resize_new_window(
        state,
        {"id": 2, "workspace_id": 1, "is_floating": False, "is_focused": True},
        action_socket,
    )

    assert action_socket.messages == [
        column_pager.focus_window_message(1),
        column_pager.set_column_width_message(.5),
        column_pager.focus_window_message(2),
        column_pager.set_column_width_message(.5),
    ]


def test_spread_resizes_every_partially_visible_column(monkeypatch):
    column_pager = load_script()
    commands = {
        ("niri", "msg", "-j", "outputs"): json.dumps(
            {"DP-1": {"logical": {"width": 700}}}
        ),
        ("prism", "get", "compositor.gaps"): "10\n",
    }

    def run(command, **kwargs):
        return subprocess.CompletedProcess(command, 0, commands[tuple(command)], "")

    monkeypatch.setattr(column_pager.subprocess, "run", run)
    state = column_pager.State()
    state.workspaces = {
        1: {
            "id": 1,
            "output": "DP-1",
            "is_focused": True,
            "scrolling_view_pos": 200,
        }
    }
    state.windows = {
        window_id: {
            "id": window_id,
            "workspace_id": 1,
            "is_focused": window_id == 2,
            "is_floating": False,
            "layout": {
                "pos_in_scrolling_layout": [window_id, 1],
                "tile_size": [300, 1000],
            },
        }
        for window_id in range(1, 6)
    }
    action_socket = ActionSocket()

    column_pager.spread_visible_columns(state, action_socket)

    set_third = column_pager.set_column_width_message(1 / 3)
    assert action_socket.messages == [
        column_pager.focus_window_message(1),
        set_third,
        column_pager.focus_window_message(2),
        set_third,
        column_pager.focus_window_message(3),
        set_third,
        column_pager.focus_window_message(2),
        {"Action": {"CenterVisibleColumns": {}}},
    ]
