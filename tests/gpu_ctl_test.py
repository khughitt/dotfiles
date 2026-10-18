"""Exercise gpu-ctl's argument contract and NVML dispatch without touching a GPU."""

import ctypes.util
import io
import runpy
import subprocess
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin/gpu-ctl"


@pytest.fixture
def gpu_ctl():
    return runpy.run_path(str(SCRIPT))


class FakeNvml:
    def __init__(self, error, fans=2, fail=None):
        self.error = error
        self.fans = fans
        self.fail = fail
        self.calls = []

    def _record(self, *call):
        self.calls.append(call)
        if call[0] == self.fail:
            raise self.error(f"{call[0]}: Insufficient Permissions")

    def num_fans(self):
        return self.fans

    def persistence(self):
        return False

    def fan_policy(self, fan):
        return "manual"

    def fan_target(self, fan):
        return 45

    def fan_speed(self, fan):
        return 45

    def set_persistence(self, enabled):
        self._record("set_persistence", enabled)

    def set_fan_auto(self, fan):
        self._record("set_fan_auto", fan)

    def set_fan_speed(self, fan, percent):
        self._record("set_fan_speed", fan, percent)

    def close(self):
        self.calls.append(("close",))


def run(gpu_ctl, argv, nvml=None):
    opened = []

    def open_nvml():
        opened.append(nvml)
        return nvml

    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        status = gpu_ctl["main"](argv, open_nvml)
    return status, out.getvalue(), err.getvalue(), opened


def test_shebang_runs_the_system_interpreter_isolated():
    # sudo runs this as root: no user site, no PYTHON* environment, no cwd on sys.path.
    assert SCRIPT.read_text().splitlines()[0] == "#!/usr/bin/python3 -I"


@pytest.mark.parametrize("argv", [
    [], ["status", "x"], ["--help"], ["persistence"], ["persistence", "1"],
    ["persistence", "on", "x"], ["persistence", "ON"], ["fan"], ["fan", "auto", "x"],
    ["fan", "44"], ["fan", "101"], ["fan", "0"], ["fan", "045"], ["fan", "+45"],
    ["fan", " 45"], ["fan", "45 "], ["fan", "45.0"], ["fan", "٤٥"], ["fan", "45", "x"],
])
def test_rejects_everything_outside_the_contract_before_opening_nvml(gpu_ctl, argv):
    status, out, err, opened = run(gpu_ctl, argv)
    assert status == 2
    assert err.startswith("usage: gpu-ctl")
    assert out == ""
    assert opened == []


def test_fan_auto_restores_the_cards_curve_on_every_fan(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"])
    status, out, err, _ = run(gpu_ctl, ["fan", "auto"], nvml)
    assert (status, err) == (0, "")
    assert nvml.calls == [("set_fan_auto", 0), ("set_fan_auto", 1), ("close",)]
    assert "fan 1: manual, target 45%, speed 45%" in out


@pytest.mark.parametrize("percent", [45, 60, 100])
def test_fan_percent_sets_every_fan(gpu_ctl, percent):
    nvml = FakeNvml(gpu_ctl["NvmlError"])
    status, _, err, _ = run(gpu_ctl, ["fan", str(percent)], nvml)
    assert (status, err) == (0, "")
    assert nvml.calls == [("set_fan_speed", 0, percent), ("set_fan_speed", 1, percent), ("close",)]


@pytest.mark.parametrize("word, enabled", [("on", True), ("off", False)])
def test_persistence(gpu_ctl, word, enabled):
    nvml = FakeNvml(gpu_ctl["NvmlError"])
    status, out, err, _ = run(gpu_ctl, ["persistence", word], nvml)
    assert (status, err) == (0, "")
    assert nvml.calls == [("set_persistence", enabled), ("close",)]
    assert out.startswith("persistence: off\n")


def test_status_changes_nothing(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"])
    status, out, err, _ = run(gpu_ctl, ["status"], nvml)
    assert (status, err) == (0, "")
    assert nvml.calls == [("close",)]
    assert out == ("persistence: off\n"
                   "fan 0: manual, target 45%, speed 45%\n"
                   "fan 1: manual, target 45%, speed 45%\n")


def test_nvml_failure_exits_1_and_still_closes(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"], fail="set_fan_speed")
    status, out, err, _ = run(gpu_ctl, ["fan", "60"], nvml)
    assert status == 1
    assert err == "gpu-ctl: set_fan_speed: Insufficient Permissions\n"
    assert out == ""
    assert nvml.calls == [("set_fan_speed", 0, 60), ("close",)]


def test_a_fan_command_on_a_gpu_without_fans_fails(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"], fans=0)
    status, _, err, _ = run(gpu_ctl, ["fan", "auto"], nvml)
    assert status == 1
    assert err == "gpu-ctl: GPU 0 reports no fans\n"
    assert nvml.calls == [("close",)]


def test_failing_to_open_nvml_exits_1(gpu_ctl):
    def open_nvml():
        raise gpu_ctl["NvmlError"]("nvmlInit_v2: Driver Not Loaded")

    err = io.StringIO()
    with redirect_stderr(err):
        status = gpu_ctl["main"](["status"], open_nvml)
    assert status == 1
    assert err.getvalue() == "gpu-ctl: nvmlInit_v2: Driver Not Loaded\n"


@pytest.mark.skipif(not ctypes.util.find_library("nvidia-ml"), reason="no NVML on this host")
def test_status_reads_the_real_gpu():
    # Read-only: status needs no privilege and changes nothing.
    result = subprocess.run([str(SCRIPT), "status"], capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    lines = result.stdout.splitlines()
    assert lines[0] in ("persistence: on", "persistence: off")
    assert lines[1].startswith("fan 0: ")
