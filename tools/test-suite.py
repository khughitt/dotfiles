#!/usr/bin/env python3
"""The existing suite inventory, with optional ordered phase evidence."""

from datetime import datetime, timezone
from collections import Counter
import fnmatch
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


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
ENVIRONMENT = [
    "PATH", "HOME", "USER", "TERM", "LANG", "TMPDIR", "DOTFILES",
    "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR",
    "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_TERMINAL_PROMPT",
    "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL",
    "UV_PROJECT_ENVIRONMENT", "UV_CACHE_DIR", "UV_PYTHON", "UV_PYTHON_DOWNLOADS",
    "TT_LOG", "TT_JUNIT_DIR", "TT_FORCE", "GITHUB_ACTIONS", "EVIDENCE_DIR",
    "PYTHONDONTWRITEBYTECODE", "BUILD_JOBS", "NVM_DIR", "FAST_WORK_DIR",
]
_modules = []
_cases = []
_collection_file = "execution-collection.json"


def git(*args):
    env = {"PATH": os.environ["PATH"], "HOME": os.environ["HOME"],
           "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
    return subprocess.check_output(["git", *args], cwd=ROOT, env=env, text=True).strip()


def source_modules():
    # Match this repository's unchanged default pytest discovery.
    return sorted(path for path in git("ls-files", "-z").split("\0") if path and
                  any(fnmatch.fnmatch(Path(path).name, pattern) for pattern in ["test_*.py", "*_test.py"]))


# Loaded as an observational pytest plugin during the unchanged full invocation.
def pytest_collectreport(report):
    if report.nodeid.endswith(".py"):
        _modules.append({"path": report.nodeid, "outcome": report.outcome})


def pytest_collection_finish(session):
    from _pytest.junitxml import bin_xml_escape, mangle_test_address
    for item in session.items:
        names = mangle_test_address(item.nodeid)
        _cases.append({"nodeid": item.nodeid, "module": item.path.relative_to(ROOT).as_posix(),
                       "classname": ".".join(names[:-1]), "name": bin_xml_escape(names[-1])})


def pytest_sessionfinish(session, exitstatus):
    directory = Path(os.environ["EVIDENCE_DIR"])
    directory.mkdir(parents=True, exist_ok=True)
    data = {"exit": int(exitstatus), "source_sha": git("rev-parse", "HEAD"),
            "source_root": str(ROOT), "source_modules": source_modules(),
            "modules": _modules, "cases": _cases}
    (directory / _collection_file).write_text(json.dumps(data, indent=2) + "\n")


def collect():
    import pytest
    global _collection_file
    _collection_file = "collection.json"
    return int(pytest.main(["--collect-only", "-q"], plugins=[sys.modules[__name__]]))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(directory):
    def read(name):
        return json.loads((directory / name).read_text())

    require(not git("status", "--porcelain", "--untracked-files=no"), "tracked source changed during verification")
    outer = read("outer.json")
    require(outer["exit"] == 0 and outer["timed_out"] is False and outer["interrupted"] == 0,
            "outer command did not complete successfully")
    collection = read("collection.json")
    require(collection == read("execution-collection.json"), "collection changed during execution")
    require(collection["exit"] == 0 and collection["source_sha"] == git("rev-parse", "HEAD") and
            collection["source_root"] == str(ROOT), "collection source or status mismatch")
    expected_modules = source_modules()
    require(collection["source_modules"] == expected_modules, "tracked module inventory mismatch")
    modules = collection["modules"]
    require(Counter(row["path"] for row in modules) == Counter(expected_modules) and
            all(row["outcome"] == "passed" for row in modules), "missing, duplicate or uncollected module")
    cases = collection["cases"]
    require(cases and len({row["nodeid"] for row in cases}) == len(cases), "empty or duplicate collection")
    require(all(row["module"] in expected_modules for row in cases), "case outside source inventory")
    xml = ET.parse(directory / "pytest.xml")
    results = xml.findall(".//testcase")
    identities = [(row["classname"], row["name"]) for row in cases]
    require(len(set(identities)) == len(identities) and
            Counter((row.get("classname"), row.get("name")) for row in results) == Counter(identities),
            "missing, duplicate or unexpected JUnit case")
    outcomes = {(row.get("classname"), row.get("name")):
                "failed" if row.find("failure") is not None or row.find("error") is not None else
                "skipped" if row.find("skipped") is not None else "passed" for row in results}
    require("failed" not in outcomes.values(), "JUnit contains a failure")
    fully_skipped = [module for module in expected_modules if
                     (members := [outcomes[(row["classname"], row["name"])] for row in cases
                                  if row["module"] == module]) and all(value == "skipped" for value in members)]
    require(not fully_skipped, f"fully skipped modules: {fully_skipped}")
    phases = [json.loads(line) for line in (directory / "phases.jsonl").read_text().splitlines()]
    expected = []

    def start(name, argv):
        expected.append(("start", name, argv))

    def end(name):
        expected.append(("end", name, None))

    for script in LUA:
        start(script, ["lua", script]); end(script)
    start("pytest", None); end("pytest")
    for name in ZSH:
        script = f"tests/{name}.zsh"
        start(script, ["zsh", script])
        if name == "dotfiles_check":
            for file in ["zshrc", "shell/aliases", "shell/audio", "shell/functions", "shell/history",
                         "shell/macos", "shell/tmux", "shell/ubuntu", "shell/vconsole", "shell/zoxide"]:
                phase = "modeline:" + file
                start(phase, ["nvim", "--headless", "-i", "NONE", "-u", "NONE", "--cmd", "set noswapfile",
                              "--cmd", "filetype on", "--cmd", "syntax on", str(ROOT / file),
                              '+lua print("DOTFILES_FT:" .. vim.bo.filetype .. ":" .. vim.bo.syntax)', "+qa!"])
                end(phase)
            for phase, args in [("nvim-clipboard", [f"+lua dofile('{ROOT}/nvim/tests/clipboard_test.lua')", "+qa!"]),
                                ("nvim-theme", ["-l", str(ROOT / "nvim/tests/theme_test.lua")])]:
                start(phase, ["nvim", "--headless", "-i", "NONE", "-u", str(ROOT / "nvim/init.lua"),
                              "--cmd", "set noswapfile", *args]); end(phase)
        end(script)
    require(len(phases) == len(expected), "missing or extra native phase receipt")
    for row, (event, name, argv) in zip(phases, expected, strict=True):
        require(row["event"] == event and row["name"] == name, "native phase order mismatch")
        if event == "end":
            require(row["exit"] == 0, f"failed native phase: {name}")
        elif name == "pytest":
            require(row["argv"][:5] == ["uv", "run", "--frozen", "pytest", "-q"] and
                    len(row["argv"]) == 6 and row["argv"][5].startswith("--junitxml=") and
                    row["argv"][5].endswith("/pytest.xml"), "pytest invocation changed")
        else:
            require(row["argv"] == argv, f"native invocation changed: {name}")
    timing = [json.loads(line) for line in (directory / "runs.jsonl").read_text().splitlines()]
    require([row["target"] for row in timing] == ["ci-hygiene", "check-code", "check-code", "test"],
            "missing or extra timed target")
    require(all(row["execution"] == "ran" and row["execution_reason"] == "forced" and row["exit"] == 0
                for row in timing), "timed work was skipped, unforced or failed")
    require(timing[-1]["tests"] == sum(value != "skipped" for value in outcomes.values()) > 0,
            "timing executed-test count differs from JUnit")
    counts = Counter(outcomes.values())
    verdict = {"source_sha": collection["source_sha"],
               "pytest": {"total": len(results), "passed": counts["passed"],
                          "failed": counts["failed"], "skipped": counts["skipped"]},
               "modules": len(modules), "fully_skipped_modules": fully_skipped,
               "phases": len(expected) // 2}
    (directory / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict))
    return 0


def ci():
    setup = json.loads((Path(os.environ["CI_STATE_DIR"]) / "setup.json").read_text())
    require(setup["namespace"] in ["container", "github-hosted"], "unknown setup namespace")
    inputs = setup["environment"]
    env = {key: inputs[key] for key in ENVIRONMENT if key in inputs}
    env.update(TT_FORCE="1", GITHUB_ACTIONS="true")
    evidence = Path(env["EVIDENCE_DIR"])
    interrupted = 0
    process = subprocess.Popen(["bash", "-c", 'set -o pipefail; just ci-test 2>&1 | tee "$EVIDENCE_DIR/ci-test.log"'],
                               cwd=ROOT, env=env, start_new_session=True)

    def stop(signum, frame):
        nonlocal interrupted
        interrupted = signum
        try:
            os.killpg(process.pid, signal.SIGTERM)
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
    (evidence / "outer.json").write_text(json.dumps({"exit": outer, "timed_out": False,
                                                   "interrupted": interrupted}) + "\n")
    if outer:
        return outer
    return verify(evidence)


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
    if argv == ["collect"]:
        return collect()
    if argv == ["ci"]:
        return ci()
    if len(argv) == 2 and argv[0] == "verify":
        try:
            return verify(Path(argv[1]))
        except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
            print(f"evidence: {error}", file=sys.stderr)
            return 1
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
    env = None
    if evidence is not None:
        status = subprocess.call(["uv", "run", "--frozen", "python", "tools/test-suite.py", "collect"], cwd=ROOT)
        if status:
            return status
        env = {key: os.environ[key] for key in ENVIRONMENT if key in os.environ}
        env.update(PYTHONPATH=str(ROOT), PYTEST_PLUGINS="tools.test-suite")
    status = run_phase("pytest", ["uv", "run", "--frozen", "pytest", "-q", f"--junitxml={junit}"], evidence, env)
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
