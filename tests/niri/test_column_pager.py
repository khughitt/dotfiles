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
        tiled_window(3, 410, focused=True),
        action_socket,
    )

    proportion = action_socket.messages[-1]["Action"]["SetWindowWidth"]["change"]["SetProportion"]
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
        tiled_window(2, 1630, focused=True),
        action_socket,
    )

    assert action_socket.messages == [
        {"Action": {"SetWindowWidth": {"id": 1, "change": {"SetProportion": 50}}}},
        {"Action": {"SetWindowWidth": {"id": 2, "change": {"SetProportion": 50}}}},
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


def tiled_window(window_id, width, *, focused=False, workspace_id=1, column=None):
    return {
        "id": window_id,
        "workspace_id": workspace_id,
        "is_floating": False,
        "is_focused": focused,
        "layout": {
            "pos_in_scrolling_layout": [column or window_id, 1],
            "tile_size": [width, 1000],
        },
    }


class EventSocket:
    def __init__(self, events):
        self.events = iter(events)

    def request(self, message):
        assert message == "EventStream"

    def read(self):
        try:
            return next(self.events)
        except StopIteration:
            raise EOFError from None


@pytest.mark.parametrize("count, initial_new_width, settled_width", [
    (1, 485, 485), (1, 650, 485), (2, 485, 320),
])
def test_rightmost_insertion_restores_whole_row_after_resize(
    monkeypatch, count, initial_new_width, settled_width,
):
    column_pager = load_script()
    monkeypatch.setattr(column_pager, "query_output_width", lambda name: 1000)
    monkeypatch.setattr(column_pager, "query_gap", lambda: 10)
    action_socket = ActionSocket()
    existing = [tiled_window(i, 320, focused=i == count) for i in range(1, count + 1)]
    new_id = count + 1
    new_window = tiled_window(new_id, initial_new_width, focused=True)

    def events():
        yield {"WorkspacesChanged": {"workspaces": [{"id": 1, "output": "DP-1"}]}}
        yield {"WindowsChanged": {"windows": existing}}
        yield {"WindowOpenedOrChanged": {"window": new_window}}
        # An unrelated layout event must not align using the pre-resize geometry.
        yield {"WindowLayoutsChanged": {"changes": [[new_id, new_window["layout"]]]}}
        assert all("FocusWindow" not in message["Action"] for message in action_socket.messages)
        resized_id = 1 if count == 1 else new_id
        yield {"WindowLayoutsChanged": {"changes": [
            [resized_id, tiled_window(resized_id, settled_width)["layout"]],
        ]}}
        if initial_new_width == 650:
            assert all("FocusWindow" not in message["Action"] for message in action_socket.messages)
            yield {"WindowLayoutsChanged": {"changes": [
                [new_id, tiled_window(new_id, settled_width)["layout"]],
            ]}}
        assert action_socket.messages[-2:] == [
            {"Action": {"FocusWindow": {"id": 1}}},
            {"Action": {"FocusWindow": {"id": new_id}}},
        ]
        completed = list(action_socket.messages)
        yield {"WindowLayoutsChanged": {"changes": [[resized_id, tiled_window(resized_id, settled_width)["layout"]]]}}
        assert action_socket.messages == completed

    with pytest.raises(EOFError):
        column_pager.run(EventSocket(events()), action_socket)


@pytest.mark.parametrize("case", [
    "overflow", "constrained", "background", "focus-moved", "closed", "middle", "floating",
])
def test_insertion_does_not_reposition_unrelated_views(monkeypatch, case):
    column_pager = load_script()
    monkeypatch.setattr(column_pager, "query_output_width", lambda name: 1000)
    monkeypatch.setattr(column_pager, "query_gap", lambda: 10)
    action_socket = ActionSocket()
    initial_width = 485 if case == "overflow" else 320
    existing = [tiled_window(1, initial_width), tiled_window(2, initial_width, focused=True)]
    new_window = tiled_window(3, 485, focused=case != "background", column=2 if case == "middle" else 3)
    if case == "middle":
        existing[1]["layout"]["pos_in_scrolling_layout"] = [3, 1]
    if case == "background":
        existing.append(tiled_window(4, 485, focused=True, workspace_id=2))
        existing[1]["is_focused"] = False
    events = [
        {"WorkspacesChanged": {"workspaces": [{"id": 1, "output": "DP-1"}]}},
        {"WindowsChanged": {"windows": existing}},
        {"WindowOpenedOrChanged": {"window": new_window}},
    ]
    if case == "focus-moved":
        events.append({"WindowFocusChanged": {"id": 1}})
    elif case == "closed":
        events.append({"WindowClosed": {"id": 3}})
    elif case == "floating":
        floating = tiled_window(3, 485, focused=True)
        floating["is_floating"] = True
        floating["layout"]["pos_in_scrolling_layout"] = None
        events.append({"WindowOpenedOrChanged": {"window": floating}})
    width = 400 if case == "constrained" else 320
    events.append({"WindowLayoutsChanged": {"changes": [[3, tiled_window(3, width)["layout"]]]}})
    with pytest.raises(EOFError):
        column_pager.run(EventSocket(events), action_socket)
    assert all("FocusWindow" not in message["Action"] for message in action_socket.messages)
