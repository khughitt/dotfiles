#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
loader = importlib.machinery.SourceFileLoader("noctalia_glass_sync", str(ROOT / "bin/noctalia-glass-sync"))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
sync = importlib.util.module_from_spec(spec)
loader.exec_module(sync)

events = []
original_run = sync.subprocess.run
try:

    def record_run(argv, check=False):
        events.append(argv[-1])
        return type("R", (), {"returncode": 0})()

    sync.subprocess.run = record_run
    sync.signal_programs()
finally:
    sync.subprocess.run = original_run
assert events == ["kitty", "nvim"], events

events = []
try:

    def failing_run(argv, check=False):
        if argv[0] == "pkill":
            events.append(argv[-1])
        return type("R", (), {"returncode": 2})()

    sync.subprocess.run = failing_run
    try:
        sync.signal_programs()
    except SystemExit:
        pass
finally:
    sync.subprocess.run = original_run
assert events == ["kitty"], "nvim signalled after kitty reconciliation failed"

print("OK glass_signal")
