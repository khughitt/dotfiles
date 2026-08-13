#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import signal
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
loader = importlib.machinery.SourceFileLoader(
    "noctalia_glass_sync", str(ROOT / "bin/noctalia-glass-sync"))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
sync = importlib.util.module_from_spec(spec)
loader.exec_module(sync)


def status(root, pid, name="opencode", uid=None, caught=0):
    uid = os.getuid() if uid is None else uid
    path = root / str(pid)
    path.mkdir()
    (path / "status").write_text(
        f"Name:\t{name}\nUid:\t{uid}\t{uid}\t{uid}\t{uid}\n"
        f"SigCgt:\t{caught:016x}\n"
    )


with tempfile.TemporaryDirectory() as tmp:
    proc = Path(tmp)
    usr2 = 1 << (signal.SIGUSR2 - 1)
    status(proc, 101, caught=usr2)  # interactive TUI
    status(proc, 102, caught=usr2 | 1)  # run --interactive footer
    status(proc, 103, caught=0)  # serve: SIGUSR2 default action, must live
    status(proc, 104, name="not-opencode", caught=usr2)
    status(proc, 105, uid=os.getuid() + 1, caught=usr2)

    calls = []
    original_kill = sync.os.kill
    sync.os.kill = lambda pid, sig: calls.append((pid, sig))
    try:
        sync.signal_opencode(proc)
    finally:
        sync.os.kill = original_kill
    assert calls == [(101, signal.SIGUSR2), (102, signal.SIGUSR2)], calls

events = []
original_run = sync.subprocess.run
original_signal = sync.signal_opencode
sync.subprocess.run = lambda argv, check=False: type("R", (), {"returncode": 0})()
sync.signal_opencode = lambda: events.append("opencode")
try:
    def record_run(argv, check=False):
        events.append(argv[-1])
        return type("R", (), {"returncode": 0})()
    sync.subprocess.run = record_run
    sync.signal_programs()
finally:
    sync.subprocess.run = original_run
    sync.signal_opencode = original_signal
assert events == ["kitty", "nvim", "opencode"], events

events = []
sync.subprocess.run = lambda argv, check=False: type("R", (), {"returncode": 2})()
sync.signal_opencode = lambda: events.append("opencode")
try:
    try:
        sync.signal_programs()
    except SystemExit:
        pass
finally:
    sync.subprocess.run = original_run
    sync.signal_opencode = original_signal
assert events == [], "OpenCode signalled after Kitty reconciliation failed"

with tempfile.TemporaryDirectory() as tmp:
    proc = Path(tmp)
    status(proc, 201, caught=1 << (signal.SIGUSR2 - 1))
    original_kill = sync.os.kill
    sync.os.kill = lambda pid, sig: (_ for _ in ()).throw(ProcessLookupError())
    try:
        sync.signal_opencode(proc)  # vanished is success
    finally:
        sync.os.kill = original_kill

print("OK glass_signal")
