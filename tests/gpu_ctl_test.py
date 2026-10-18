"""Exercise gpu-ctl's argument contract and NVML dispatch without touching a GPU."""

import ctypes
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
    def __init__(self, error, fans=2, fail=()):
        self.error = error
        self.fans = fans
        self.fail = fail
        self.calls = []

    def _record(self, *call):
        self.calls.append(call)
        if call[:len(self.fail)] == self.fail and self.fail:
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


def run(gpu_ctl, argv, nvml=None, environ=None):
    opened = []
    environ = {} if environ is None else environ

    def open_nvml():
        opened.append(dict(environ))
        return nvml

    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        status = gpu_ctl["main"](argv, open_nvml, environ)
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
    nvml = FakeNvml(gpu_ctl["NvmlError"], fail=("set_persistence",))
    status, out, err, _ = run(gpu_ctl, ["persistence", "on"], nvml)
    assert status == 1
    assert err == "gpu-ctl: set_persistence: Insufficient Permissions\n"
    assert out == ""
    assert nvml.calls == [("set_persistence", True), ("close",)]


def test_a_failed_fan_hold_hands_every_fan_back_to_the_card(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"], fail=("set_fan_speed", 1))
    status, out, err, _ = run(gpu_ctl, ["fan", "60"], nvml)
    assert status == 1
    assert err == ("gpu-ctl: set_fan_speed: Insufficient Permissions; "
                   "every fan handed back to the card's curve\n")
    assert out == ""
    assert nvml.calls == [("set_fan_speed", 0, 60), ("set_fan_speed", 1, 60),
                          ("set_fan_auto", 0), ("set_fan_auto", 1), ("close",)]


def test_a_failed_fallback_is_reported_too(gpu_ctl):
    nvml = FakeNvml(gpu_ctl["NvmlError"], fail=("set_fan_",))
    nvml.fail = ("set_fan_speed",)

    def set_fan_auto(fan):
        nvml.calls.append(("set_fan_auto", fan))
        raise gpu_ctl["NvmlError"]("set_fan_auto: Unknown Error")

    nvml.set_fan_auto = set_fan_auto
    status, _, err, _ = run(gpu_ctl, ["fan", "60"], nvml)
    assert status == 1
    assert err == ("gpu-ctl: set_fan_speed: Insufficient Permissions; "
                   "handing the fans back failed: set_fan_auto: Unknown Error\n")
    assert nvml.calls == [("set_fan_speed", 0, 60), ("set_fan_auto", 0), ("set_fan_auto", 1),
                          ("close",)]


@pytest.mark.parametrize("argv", [["status"], ["fan", "auto"], ["persistence", "off"]])
def test_the_environment_is_cleared_before_nvml_loads(gpu_ctl, argv):
    # libnvidia-ml getenv()s debug variables such as __NVML_DBG_FILE (a log path).
    environ = {"__NVML_DBG_FILE": "/etc/clobbered", "HOME": "/home/user"}
    nvml = FakeNvml(gpu_ctl["NvmlError"])
    status, _, _, opened = run(gpu_ctl, argv, nvml, environ)
    assert status == 0
    assert opened == [{}]


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
        status = gpu_ctl["main"](["status"], open_nvml, {})
    assert status == 1
    assert err.getvalue() == "gpu-ctl: nvmlInit_v2: Driver Not Loaded\n"


class FakeFunction:
    def __init__(self, lib, name):
        self.lib, self.name = lib, name

    def __call__(self, *args):
        return self.lib.dispatch(self.name, args)


class FakeLib:
    """Stands in for libnvidia-ml.so.1: records calls and fills by-reference outputs."""

    DEVICE = 0xD0

    def __init__(self, fail=None, values=None):
        self.calls = []
        self.fail = fail
        self.values = values or {}
        self.functions = {}

    def __getattr__(self, name):
        if name.startswith("nvml"):
            return self.functions.setdefault(name, FakeFunction(self, name))
        raise AttributeError(name)

    def dispatch(self, name, args):
        if name == "nvmlErrorString":
            assert self.functions[name].restype is ctypes.c_char_p
            return b"Insufficient Permissions"
        self.calls.append((name, tuple(describe(arg) for arg in args)))
        if name == self.fail:
            return 4
        if name == "nvmlDeviceGetHandleByIndex_v2":
            args[1]._obj.value = self.DEVICE
        elif name in self.values:
            args[-1]._obj.value = self.values[name]
        return 0


def describe(arg):
    if isinstance(arg, ctypes.c_uint):
        return "uint", arg.value
    if isinstance(arg, ctypes.c_void_p):
        return "ptr", arg.value
    return "ref", type(arg._obj).__name__


@pytest.fixture
def fake_lib(monkeypatch):
    libs = []

    def load(**kwargs):
        lib = FakeLib(**kwargs)

        def cdll(name):
            assert name == "libnvidia-ml.so.1"
            libs.append(lib)
            return lib

        monkeypatch.setattr(ctypes, "CDLL", cdll)
        return lib

    return load


DEVICE = ("ptr", FakeLib.DEVICE)
OPEN = [("nvmlInit_v2", ()), ("nvmlDeviceGetHandleByIndex_v2", (("uint", 0), ("ref", "c_void_p")))]


def test_nvml_opens_gpu_0_and_shuts_down_on_close(gpu_ctl, fake_lib):
    lib = fake_lib()
    gpu_ctl["Nvml"]().close()
    assert lib.calls == [*OPEN, ("nvmlShutdown", ())]


def test_nvml_failing_to_find_gpu_0_shuts_down(gpu_ctl, fake_lib):
    lib = fake_lib(fail="nvmlDeviceGetHandleByIndex_v2")
    with pytest.raises(gpu_ctl["NvmlError"], match="^nvmlDeviceGetHandleByIndex_v2: Insufficient Permissions$"):
        gpu_ctl["Nvml"]()
    assert lib.calls == [*OPEN, ("nvmlShutdown", ())]


def test_nvml_failing_to_initialize_does_not_shut_down(gpu_ctl, fake_lib):
    lib = fake_lib(fail="nvmlInit_v2")
    with pytest.raises(gpu_ctl["NvmlError"], match="^nvmlInit_v2: "):
        gpu_ctl["Nvml"]()
    assert lib.calls == [("nvmlInit_v2", ())]


def test_nvml_without_the_library(gpu_ctl, monkeypatch):
    def cdll(name):
        raise OSError(f"{name}: cannot open shared object file")

    monkeypatch.setattr(ctypes, "CDLL", cdll)
    with pytest.raises(gpu_ctl["NvmlError"], match="^cannot load libnvidia-ml.so.1: "):
        gpu_ctl["Nvml"]()


def test_nvml_writes_pass_the_device_fan_and_value(gpu_ctl, fake_lib):
    lib = fake_lib()
    nvml = gpu_ctl["Nvml"]()
    nvml.set_fan_speed(1, 60)
    nvml.set_fan_auto(0)
    nvml.set_persistence(True)
    nvml.set_persistence(False)
    assert lib.calls[len(OPEN):] == [
        ("nvmlDeviceSetFanSpeed_v2", (DEVICE, ("uint", 1), ("uint", 60))),
        ("nvmlDeviceSetDefaultFanSpeed_v2", (DEVICE, ("uint", 0))),
        ("nvmlDeviceSetPersistenceMode", (DEVICE, ("uint", 1))),
        ("nvmlDeviceSetPersistenceMode", (DEVICE, ("uint", 0))),
    ]


def test_nvml_write_failure_names_the_call(gpu_ctl, fake_lib):
    fake_lib(fail="nvmlDeviceSetFanSpeed_v2")
    nvml = gpu_ctl["Nvml"]()
    with pytest.raises(gpu_ctl["NvmlError"], match="^nvmlDeviceSetFanSpeed_v2: Insufficient Permissions$"):
        nvml.set_fan_speed(0, 45)


def test_nvml_reads(gpu_ctl, fake_lib):
    lib = fake_lib(values={"nvmlDeviceGetNumFans": 2, "nvmlDeviceGetPersistenceMode": 1,
                           "nvmlDeviceGetFanControlPolicy_v2": 0, "nvmlDeviceGetTargetFanSpeed": 45,
                           "nvmlDeviceGetFanSpeed_v2": 44})
    nvml = gpu_ctl["Nvml"]()
    assert (nvml.num_fans(), nvml.persistence(), nvml.fan_policy(1), nvml.fan_target(1),
            nvml.fan_speed(1)) == (2, True, "auto", 45, 44)
    assert lib.calls[len(OPEN):] == [
        ("nvmlDeviceGetNumFans", (DEVICE, ("ref", "c_uint"))),
        ("nvmlDeviceGetPersistenceMode", (DEVICE, ("ref", "c_uint"))),
        ("nvmlDeviceGetFanControlPolicy_v2", (DEVICE, ("uint", 1), ("ref", "c_uint"))),
        ("nvmlDeviceGetTargetFanSpeed", (DEVICE, ("uint", 1), ("ref", "c_uint"))),
        ("nvmlDeviceGetFanSpeed_v2", (DEVICE, ("uint", 1), ("ref", "c_uint"))),
    ]


NVML = ctypes.util.find_library("nvidia-ml")


@pytest.mark.skipif(not NVML, reason="no NVML on this host")
def test_every_symbol_the_helper_calls_exists():
    lib = ctypes.CDLL("libnvidia-ml.so.1")
    source = SCRIPT.read_text()
    names = sorted(set(__import__("re").findall(r'"(nvml[A-Za-z_0-9]+)"', source))
                   | {"nvmlErrorString", "nvmlShutdown"})
    assert len(names) >= 12
    assert [name for name in names if not hasattr(lib, name)] == []


@pytest.mark.skipif(not NVML, reason="no NVML on this host")
def test_status_reads_the_real_gpu():
    # Read-only: status needs no privilege and changes nothing.
    result = subprocess.run([str(SCRIPT), "status"], capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    lines = result.stdout.splitlines()
    assert lines[0] in ("persistence: on", "persistence: off")
    assert lines[1].startswith("fan 0: ")
