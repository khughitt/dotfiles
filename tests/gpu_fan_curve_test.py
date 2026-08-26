#!/usr/bin/env python3
"""gpu-fan-curve must keep re-asserting control, not set the fans once and go quiet.

The daemon engages manual control, commands a speed, and then compares each new
target against the last *commanded* value. At a steady idle temperature the
target never moves, so the comparison never fires and no further command is
ever sent -- a six-day boot produced six log lines total.

That is fine until something resets the card to automatic control behind its
back: a driver reinit, an external nvidia-settings, or a GPU reset after a
BAR1 wedge. The fans then fall back to the card's zero-RPM curve, and the
daemon neither notices nor logs it, because it never asks the card what state
it is actually in.

These tests drive the real script against stub nvidia-settings/nvidia-smi
binaries and a throwaway Wayland socket.
"""

import os
import socket
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "gpu-fan-curve"

# The stub records every invocation, and answers queries from a state file that
# the test can flip underneath the daemon to simulate an external reset.
NVIDIA_SETTINGS_STUB = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "{calls}"
for arg in "$@"; do
    case "$arg" in
        '[gpu:0]/GPUFanControlState=1') printf '1\\n' > "{state}" ;;
        '[gpu:0]/GPUFanControlState=0') printf '0\\n' > "{state}" ;;
        '[fan:'*']/GPUTargetFanSpeed='*) printf '%s\\n' "${{arg##*=}}" > "{speed}" ;;
    esac
done
for arg in "$@"; do
    case "$arg" in
        '[gpu:0]/GPUFanControlState') cat "{state}"; exit 0 ;;
    esac
done
exit 0
"""

NVIDIA_SMI_STUB = """#!/usr/bin/env bash
cat "{temp}"
"""


class Rig:
    def __init__(self, tmp_path):
        self.tmp = tmp_path
        self.calls = tmp_path / "calls.log"
        self.state = tmp_path / "control_state"
        self.speed = tmp_path / "speed"
        self.temp = tmp_path / "temp"
        self.runtime = tmp_path / "runtime"
        self.runtime.mkdir()

        self.calls.write_text("")
        self.state.write_text("0\n")
        self.speed.write_text("")
        self.temp.write_text("40\n")

        bindir = tmp_path / "bin"
        bindir.mkdir()
        self._write_stub(bindir / "nvidia-settings", NVIDIA_SETTINGS_STUB.format(
            calls=self.calls, state=self.state, speed=self.speed))
        self._write_stub(bindir / "nvidia-smi", NVIDIA_SMI_STUB.format(temp=self.temp))
        self.bindir = bindir

        # find_session requires a real socket, not just a file.
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.bind(str(self.runtime / "wayland-1"))

        self.proc = None

    @staticmethod
    def _write_stub(path, body):
        path.write_text(body)
        path.chmod(0o755)

    def start(self, **env_overrides):
        env = dict(os.environ)
        env["PATH"] = f"{self.bindir}:{env['PATH']}"
        env["RUNTIME_ROOT"] = str(self.runtime)
        env["POLL"] = "1"
        env["VERIFY"] = "2"
        env.update(env_overrides)
        self.proc = subprocess.Popen(
            ["bash", str(SCRIPT)], env=env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        return self.proc

    def call_log(self):
        return self.calls.read_text()

    def wait_for(self, predicate, timeout=15.0, interval=0.2):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(interval)
        return False

    def stop(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=10)
        self.sock.close()


@pytest.fixture
def rig(tmp_path):
    r = Rig(tmp_path)
    yield r
    r.stop()


def engage_count(log):
    return log.count("[gpu:0]/GPUFanControlState=1")


def speed_command_count(log):
    return log.count("GPUTargetFanSpeed=")


def test_engages_manual_control_and_commands_the_floor(rig):
    """Baseline: the daemon takes control and applies the 45% floor."""
    rig.start()
    assert rig.wait_for(lambda: engage_count(rig.call_log()) >= 1), \
        f"never engaged manual control; calls were:\n{rig.call_log()}"
    assert rig.wait_for(lambda: rig.speed.read_text().strip() == "45"), \
        f"never commanded the 45% floor; calls were:\n{rig.call_log()}"


def test_reasserts_control_after_an_external_reset(rig):
    """The regression: an external reset to automatic must be detected and undone.

    This is what a driver reinit or GPU reset looks like from the daemon's
    side. Before the fix the daemon sails straight past it, because `want`
    still equals `last_set` and it never re-queries the card.
    """
    rig.start()
    assert rig.wait_for(lambda: engage_count(rig.call_log()) >= 1), \
        "daemon never engaged in the first place"
    assert rig.wait_for(lambda: rig.speed.read_text().strip() == "45")

    engages_before = engage_count(rig.call_log())

    # Simulate the card reverting to automatic control behind the daemon's back.
    rig.state.write_text("0\n")

    assert rig.wait_for(lambda: engage_count(rig.call_log()) > engages_before), (
        "daemon did not re-engage manual control after an external reset.\n"
        f"engages before={engages_before}, after={engage_count(rig.call_log())}\n"
        f"calls were:\n{rig.call_log()}")

    # And having re-taken control it must re-apply the speed, otherwise the
    # fans stay wherever the card's own curve left them.
    assert rig.wait_for(lambda: rig.state.read_text().strip() == "1"), \
        "control state never returned to manual"


def test_reissues_speed_periodically_at_a_steady_temperature(rig):
    """Even with control intact, the commanded speed must be refreshed.

    A silently dropped speed (control still manual, fan percentage reset) is
    invisible to a daemon that only ever commands on a change of target.
    """
    rig.start()
    assert rig.wait_for(lambda: speed_command_count(rig.call_log()) >= 1)
    first = speed_command_count(rig.call_log())

    # Temperature never moves, so nothing about the target changes.
    assert rig.wait_for(
        lambda: speed_command_count(rig.call_log()) > first, timeout=15), (
        "daemon never re-issued the fan speed at a steady temperature; "
        f"calls were:\n{rig.call_log()}")


@pytest.mark.parametrize("temp,expected", [
    (0, 45),    # floor
    (30, 45),   # still floor
    (55, 45),   # last floor point
    (60, 50),   # interpolated between 55:45 and 65:55
    (65, 55),
    (70, 62),   # interpolated between 65:55 and 75:70
    (75, 70),
    (85, 100),
    (200, 100),  # above the curve, clamps to the last point
])
def test_curve_interpolation_is_unchanged(temp, expected):
    """Guard the curve maths against regressions while editing the loop."""
    out = subprocess.run(
        ["bash", "-c", f'source "{SCRIPT}"; curve_pct {temp}'],
        capture_output=True, text=True, timeout=20,
        env={**os.environ, "SOURCED_FOR_TEST": "1"})
    assert out.returncode == 0, f"sourcing failed: {out.stdout}{out.stderr}"
    assert out.stdout.strip() == str(expected), \
        f"curve_pct({temp}) = {out.stdout.strip()}, expected {expected}"
