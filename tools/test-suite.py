#!/usr/bin/env python3
"""The existing suite inventory, with optional ordered phase evidence."""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
LUA = [
    "noctalia/plugins/resource-pressure-alert/plugin_test.lua",
    "noctalia/plugins/resource-pressure-alert/service_test.lua",
    "noctalia/plugins/resource-pressure-alert/layer_test.lua",
]
ZSH = [
    "task_json_search", "dropbox_ignore_flux", "work_link", "history",
    "icat_completion", "glow_completion", "secrets_check", "setup_and_health",
    "dotfiles_check", "layout_check", "justfile", "console_keymap",
]


def receipt(directory, event):
    if directory is not None:
        directory.mkdir(parents=True, exist_ok=True)
        with (directory / "phases.jsonl").open("a") as out:
            out.write(json.dumps({"at": datetime.now(timezone.utc).isoformat(), **event}) + "\n")


def run_phase(name: str, argv: list[str], evidence_dir: Path | None) -> int:
    receipt(evidence_dir, {"event": "start", "name": name, "argv": argv})
    start = time.monotonic()
    result = subprocess.run(argv, cwd=ROOT)
    receipt(evidence_dir, {"event": "end", "name": name, "exit": result.returncode,
                           "seconds": round(time.monotonic() - start, 6)})
    return result.returncode


def main(argv):
    evidence = Path(os.environ["EVIDENCE_DIR"]) if os.environ.get("EVIDENCE_DIR") else None
    if len(argv) >= 3 and argv[0] == "phase":
        return run_phase(argv[1], argv[2:], evidence)
    if argv not in [["full"], ["resource-alert"]]:
        print("usage: test-suite.py {full|resource-alert|phase NAME COMMAND...}", file=sys.stderr)
        return 2
    full = argv == ["full"]
    junit = None
    if full:
        junit_dir = os.environ.get("TT_JUNIT_DIR")
        if not junit_dir:
            print("test-suite: run the full suite through tt", file=sys.stderr)
            return 2
        junit = Path(junit_dir) / "pytest.xml"
    for script in LUA:
        status = run_phase(script, ["lua", script], evidence)
        if status:
            return status
    if not full:
        return 0
    status = run_phase("pytest", ["uv", "run", "--frozen", "pytest", "-q", f"--junitxml={junit}"], evidence)
    if evidence is not None:
        try:
            shutil.copyfile(junit, evidence / "pytest.xml")
        except OSError as error:
            print(f"test-suite: cannot retain JUnit: {error}", file=sys.stderr)
            return status or 1
    if status:
        return status
    for name in ZSH:
        script = f"tests/{name}.zsh"
        status = run_phase(script, ["zsh", script], evidence)
        if status:
            return status
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except OSError as error:
        print(f"test-suite: {error}", file=sys.stderr)
        sys.exit(1)
