import os
from pathlib import Path
import subprocess

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "dropdown"

FAKE_KITTEN = """#!/usr/bin/env bash
printf '%s\\n' "$@" > "$KITTEN_FAKE_LOG"
"""

# `niri msg -j focused-output`, trimmed to what the script reads.
FAKE_NIRI = """#!/usr/bin/env bash
[[ "$*" == "msg -j focused-output" ]] || { echo "unexpected niri call: $*" >&2; exit 1; }
echo '{"name": "DP-1", "logical": {"x": 0, "y": 0, "width": 3440, "height": 1440, "scale": 1.0}}'
"""


@pytest.fixture
def run(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    fake = bin_dir / "kitten"
    fake.write_text(FAKE_KITTEN)
    fake.chmod(0o755)
    niri = bin_dir / "niri"
    niri.write_text(FAKE_NIRI)
    niri.chmod(0o755)
    log = tmp_path / "kitten.log"

    def _run(*args):
        if not SCRIPT.exists():
            pytest.fail(f"dropdown script is missing: {SCRIPT}")
        env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "KITTEN_FAKE_LOG": str(log),
        }
        proc = subprocess.run([str(SCRIPT), *args], env=env, capture_output=True, text=True)
        argv = log.read_text().splitlines() if log.exists() else None
        return proc, argv

    return _run


def test_term_toggles_a_shell_in_its_own_instance_group(run):
    proc, argv = run("term")

    assert proc.returncode == 0, proc.stderr
    assert argv[:2] == ["quick-access-terminal", "--instance-group=dropdown-term"]
    assert "-o" in argv and "app_id=dropdown-term" in argv
    assert "hide_on_focus_loss=no" in argv
    # A bare shell: the option list is the whole command line.
    assert argv[-2] == "-o"


def test_ipython_runs_ipython_inside_its_own_group(run):
    proc, argv = run("ipython")

    assert proc.returncode == 0, proc.stderr
    assert argv[1] == "--instance-group=dropdown-ipython"
    assert "app_id=dropdown-ipython" in argv
    assert argv[-1] == "ipython"


def test_ghci_runs_the_colour_wrapper_not_the_shell_alias(run):
    proc, argv = run("ghci")

    assert proc.returncode == 0, proc.stderr
    assert argv[1] == "--instance-group=dropdown-ghci"
    assert "app_id=dropdown-ghci" in argv
    # `ghci` is only an alias in interactive zsh; kitten execs without a shell.
    assert argv[-1] == "ghci-color"


def test_width_is_80_percent_of_the_focused_output(run):
    _, argv = run("term")

    # 3440 wide output: 10% margin each side leaves 2752 px, i.e. 80%.
    assert "margin_left=344" in argv
    assert "margin_right=344" in argv


def test_hidden_flag_only_adds_the_start_hidden_option(run):
    _, shown = run("term")
    _, hidden = run("--hidden", "term")

    assert "start_as_hidden=yes" not in shown
    i = hidden.index("start_as_hidden=yes")
    assert hidden[i - 1] == "-o"
    assert hidden[: i - 1] + hidden[i + 1 :] == shown


def test_unknown_name_fails_before_touching_kitten(run):
    proc, argv = run("julia")

    assert proc.returncode == 2
    assert "julia" in proc.stderr
    assert argv is None


def test_missing_name_prints_usage(run):
    proc, argv = run()

    assert proc.returncode == 2
    assert "usage" in proc.stderr
    assert argv is None
