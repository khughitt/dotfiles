#!/usr/bin/env python3
"""Local full suite and explicitly limited portable CI, with optional evidence."""

from datetime import datetime, timezone
import fnmatch
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
LUA = [
    "noctalia/plugins/resource-pressure-alert/plugin_test.lua",
    "noctalia/plugins/resource-pressure-alert/service_test.lua",
    "noctalia/plugins/resource-pressure-alert/layer_test.lua"
]
ZSH = [
    "task_json_search",
    "dropbox_ignore_flux",
    "work_link",
    "history",
    "icat_completion",
    "glow_completion",
    "secrets_check",
    "setup_and_health",
    "dotfiles_check",
    "layout_check",
    "justfile",
    "console_keymap"
]
ENVIRONMENT = [
    "PATH",
    "HOME",
    "USER",
    "TERM",
    "LANG",
    "TMPDIR",
    "DOTFILES",
    "XDG_CONFIG_HOME",
    "XDG_DATA_HOME",
    "XDG_CACHE_HOME",
    "XDG_STATE_HOME",
    "XDG_RUNTIME_DIR",
    "GIT_CONFIG_GLOBAL",
    "GIT_CONFIG_NOSYSTEM",
    "GIT_TERMINAL_PROMPT",
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME",
    "GIT_COMMITTER_EMAIL",
    "UV_PROJECT_ENVIRONMENT",
    "UV_CACHE_DIR",
    "UV_PYTHON",
    "UV_PYTHON_DOWNLOADS",
    "TT_LOG",
    "TT_JUNIT_DIR",
    "TT_FORCE",
    "GITHUB_ACTIONS",
    "EVIDENCE_DIR",
    "PYTHONDONTWRITEBYTECODE",
    "BUILD_JOBS",
    "NVM_DIR",
    "FAST_WORK_DIR"
]
PORTABLE_PYTHON = [
    "tests/front_door_test.py", "tests/kernel_gate_test.py",
    "tests/niri/test_column_pager.py", "tests/niri/test_debug_backdrop_startup.py",
    "tests/niri/test_dropdown.py", "tests/niri/test_mindful_scratch.py",
    "tests/niri/test_mindful_scratch_op.py",
]


def git(*args):
    env = {"PATH": os.environ["PATH"], "HOME": os.environ["HOME"],
           "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
    return subprocess.check_output(["git", *args], cwd=ROOT, env=env, text=True).strip()


def source_modules():
    return sorted(path for path in git("ls-files", "-z").split("\0") if path and
                  any(fnmatch.fnmatch(Path(path).name, pattern) for pattern in ["test_*.py", "*_test.py"]))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def pytest_counts(path):
    cases = ET.parse(path).findall(".//testcase")
    failed = sum(row.find("failure") is not None or row.find("error") is not None for row in cases)
    skipped = sum(row.find("skipped") is not None for row in cases)
    require(len(cases) > skipped and failed == 0, "portable pytest must execute nonzero cases without failures")
    return {"total": len(cases), "passed": len(cases) - failed - skipped, "failed": failed, "skipped": skipped}


def ci():
    state = Path(os.environ["CI_STATE_DIR"])
    require(state.is_absolute(), "CI_STATE_DIR must be a new absolute path outside the checkout")
    state = state.resolve()
    require(not state.is_relative_to(ROOT) and not state.exists(), "CI_STATE_DIR must be fresh and outside the checkout")
    python = Path(os.environ["UV_PYTHON"])
    require(python.is_absolute() and python.is_file(), "UV_PYTHON must name an installed interpreter")
    state.mkdir(parents=True)
    for name in ["home", "config", "data", "cache", "state", "runtime", "evidence"]:
        (state / name).mkdir()
    evidence = state / "evidence"
    with tempfile.TemporaryDirectory(prefix="dt-", dir="/tmp") as temp:
        env = {
            "PATH": os.environ["PATH"], "HOME": str(state / "home"), "USER": "dots-ci",
            "TERM": "xterm-256color", "LANG": "C.UTF-8", "TMPDIR": temp,
            "XDG_CONFIG_HOME": str(state / "config"), "XDG_DATA_HOME": str(state / "data"),
            "XDG_CACHE_HOME": str(state / "cache"), "XDG_STATE_HOME": str(state / "state"),
            "XDG_RUNTIME_DIR": str(state / "runtime"), "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "UV_PROJECT_ENVIRONMENT": str(ROOT / ".venv"), "UV_CACHE_DIR": str(state / "cache/uv"),
            "UV_PYTHON": str(python), "UV_PYTHON_DOWNLOADS": "never", "PYTHONDONTWRITEBYTECODE": "1",
            "TT_LOG": str(evidence / "runs.jsonl"), "EVIDENCE_DIR": str(evidence),
            "TT_FORCE": "1", "GITHUB_ACTIONS": "true",
        }
        interrupted = 0
        process = subprocess.Popen(["bash", "-c", 'set -o pipefail; { uv sync --frozen && just ci-test; } 2>&1 | tee "$EVIDENCE_DIR/ci-test.log"'],
                                   cwd=ROOT, env=env, stdin=subprocess.DEVNULL, start_new_session=True)

        def stop(signum, frame):
            nonlocal interrupted
            interrupted = signum
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

        previous = {sig: signal.signal(sig, stop) for sig in [signal.SIGTERM, signal.SIGINT]}
        try:
            status = process.wait()
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        outer = 128 + interrupted if interrupted else status if status >= 0 else 128 - status
        (evidence / "outer.json").write_text(json.dumps({"exit": outer, "interrupted": interrupted}) + "\n")
        if outer:
            return outer
    phases = [json.loads(line) for line in (evidence / "phases.jsonl").read_text().splitlines()]
    expected = [(event, name) for name in [*LUA, "pytest"] for event in ["start", "end"]]
    require([(r["event"], r["name"]) for r in phases] == expected and
            all(r["exit"] == 0 for r in phases if r["event"] == "end"), "portable phases did not complete")
    verdict = {"source_sha": git("rev-parse", "HEAD"), "selected_modules": PORTABLE_PYTHON,
               "excluded_modules": [name for name in source_modules() if name not in PORTABLE_PYTHON],
               "pytest": pytest_counts(evidence / "pytest.xml")}
    (evidence / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict))
    return 0


def receipt(directory, event):
    if directory is not None:
        directory.mkdir(parents=True, exist_ok=True)
        with (directory / "phases.jsonl").open("a") as out:
            out.write(json.dumps({"at": datetime.now(timezone.utc).isoformat(), **event}) + "\n")


def run_phase(name: str, argv: list[str], evidence_dir: Path | None, env=None) -> int:
    receipt(evidence_dir, {"event": "start", "name": name, "argv": argv})
    start = time.monotonic()
    result = subprocess.run(argv, cwd=ROOT, env=env)
    receipt(evidence_dir, {"event": "end", "name": name, "exit": result.returncode,
                           "seconds": round(time.monotonic() - start, 6)})
    return result.returncode


def main(argv):
    evidence = Path(os.environ["EVIDENCE_DIR"]) if os.environ.get("EVIDENCE_DIR") else None
    if argv == ["ci"]:
        return ci()
    if len(argv) >= 3 and argv[0] == "phase":
        return run_phase(argv[1], argv[2:], evidence)
    if argv not in [["full"], ["resource-alert"], ["portable"]]:
        print("usage: test-suite.py {full|portable|resource-alert|ci|phase NAME COMMAND...}", file=sys.stderr)
        return 2
    mode = argv[0]
    junit = None
    if mode != "resource-alert":
        junit_dir = os.environ.get("TT_JUNIT_DIR")
        if not junit_dir:
            print("test-suite: run the suite through tt", file=sys.stderr)
            return 2
        junit = Path(junit_dir) / "pytest.xml"
    for script in LUA:
        status = run_phase(script, ["lua", script], evidence)
        if status:
            return status
    if mode == "resource-alert":
        return 0
    env = {key: os.environ[key] for key in ENVIRONMENT if key in os.environ} if evidence is not None else None
    selected = PORTABLE_PYTHON if mode == "portable" else []
    status = run_phase("pytest", ["uv", "run", "--frozen", "pytest", "-q", *selected, f"--junitxml={junit}"], evidence, env)
    if evidence is not None:
        try:
            shutil.copyfile(junit, evidence / "pytest.xml")
        except OSError as error:
            print(f"test-suite: cannot retain JUnit: {error}", file=sys.stderr)
            return status or 1
    if status:
        return status
    if mode == "portable":
        pytest_counts(junit)
        return 0
    for name in ZSH:
        script = f"tests/{name}.zsh"
        status = run_phase(script, ["zsh", script], evidence)
        if status:
            return status
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, KeyError, ET.ParseError) as error:
        print(f"test-suite: {error}", file=sys.stderr)
        sys.exit(1)
