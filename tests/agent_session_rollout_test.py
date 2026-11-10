"""Validate rollout receipts and the workload verdict without a live user manager."""

import hashlib
import importlib.util
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ROLLBACK = ROOT / "scripts/agent-session-rollback.py"
SMOKE = ROOT / "scripts/agent-session-smoke.py"


def write_json(path, value):
    path.write_text(json.dumps(value))


@pytest.fixture
def activation(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    env = {
        "PATH": f"{bin_dir}:/usr/bin:/bin",
        "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
        "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
        "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
    }
    runtime = tmp_path / "runtime.json"
    before = {"CPUQuotaPerSecUSec": "infinity", "CPUWeight": "[not set]"}
    after = {"CPUQuotaPerSecUSec": "24s", "CPUWeight": "30"}
    restored = {"CPUQuotaPerSecUSec": "infinity", "CPUWeight": "100"}
    write_json(runtime, after)
    env["TEST_RUNTIME"] = str(runtime)
    manager = bin_dir / "systemctl"
    manager.write_text(f"""#!{sys.executable}
import json, os, sys
from pathlib import Path
path = Path(os.environ["TEST_RUNTIME"])
if sys.argv[1:4] == ["--user", "show", "agents.slice"]:
    for name, value in json.loads(path.read_text()).items():
        print(f"{{name}}={{value}}")
elif sys.argv[1:] == ["--user", "set-property", "--runtime", "agents.slice", "CPUQuota=", "CPUWeight=100"]:
    path.write_text(json.dumps({restored!r}))
elif sys.argv[1:] != ["--user", "daemon-reload"]:
    sys.exit(9)
""")
    manager.chmod(0o755)

    def file_state(name, key, content):
        if content is None:
            return {"kind": "missing"}
        image = tmp_path / f"{name}.{key}"
        image.write_bytes(content)
        return {"kind": "file", "mode": 0o644, "sha256": hashlib.sha256(content).hexdigest(),
                "copy": image.name}

    files = []
    for name, original, changed in [
        ("unit", None, b"new slice\n"),
        ("alias", b"private line\nold alias\n", b"private line\nnew alias\n"),
    ]:
        path = home / name
        path.write_bytes(changed)
        path.chmod(0o644)
        files.append({"key": name, "path": str(path), "locator": str(path),
                      "before": file_state(name, "before", original),
                      "after": file_state(name, "after", changed)})
    data = {
        "version": 1, "host": os.uname().nodename, "files": files, "repositories": [],
        "runtime": {"before": before, "after": after, "restored": restored},
    }
    receipt = {"version": 1, "files": ["unit", "alias"], "runtime": True, "repositories": {},
               "restored": {"files": [], "runtime": False, "repositories": {}}}

    def run():
        packet = tmp_path / "activation.json"
        receipt_path = tmp_path / "activation-receipt.json"
        write_json(packet, data)
        receipt["packet_sha256"] = hashlib.sha256(packet.read_bytes()).hexdigest()
        if not receipt_path.exists():
            write_json(receipt_path, receipt)
        return subprocess.run([sys.executable, str(ROLLBACK), "--packet", str(packet)],
                              env=env, capture_output=True, text=True, timeout=15)

    return run, home, runtime, data, receipt, env


def test_rollback_checks_every_target_before_restoring_any(activation):
    run, home, runtime, _, _, _ = activation
    (home / "alias").write_text("another actor's edit\n")
    result = run()
    assert result.returncode == 2, result.stderr
    assert "drift" in result.stderr
    assert (home / "unit").read_text() == "new slice\n"
    assert json.loads(runtime.read_text())["CPUQuotaPerSecUSec"] == "24s"


def test_rollback_restores_private_bytes_and_leaves_populated_slice_running(activation):
    run, home, runtime, _, _, _ = activation
    result = run()
    assert result.returncode == 0, result.stderr
    assert (home / "alias").read_bytes() == b"private line\nold alias\n"
    assert not (home / "unit").exists()
    assert json.loads(runtime.read_text()) == {"CPUQuotaPerSecUSec": "infinity", "CPUWeight": "100"}
    assert run().returncode == 0


def test_rollback_restores_only_proven_partial_steps(activation):
    run, home, runtime, data, receipt, _ = activation
    (home / "alias").write_bytes(b"private line\nold alias\n")
    write_json(runtime, data["runtime"]["before"])
    receipt.update(files=["unit"], runtime=False)
    result = run()
    assert result.returncode == 0, result.stderr
    assert not (home / "unit").exists()
    assert (home / "alias").read_bytes() == b"private line\nold alias\n"


@pytest.mark.parametrize("alternate_index", [False, True])
def test_rollback_preserves_real_index_and_unrelated_draft(activation, tmp_path, alternate_index):
    run, home, _, data, receipt, env = activation
    repo = tmp_path / "repo"
    repo.mkdir()

    def git(*args):
        return subprocess.run(["git", "-C", str(repo), *args], env=env, check=True,
                              capture_output=True, text=True, timeout=10).stdout.strip()

    git("init", "-q", "-b", "main")
    assert Path(git("rev-parse", "--show-toplevel")) == repo
    assert Path(git("rev-parse", "--absolute-git-dir")) == repo / ".git"
    (repo / "policy").write_text("old\n")
    (repo / "draft").write_text("old draft\n")
    git("add", "policy", "draft")
    git("commit", "-qm", "base")
    base = git("rev-parse", "HEAD")
    git("switch", "-qc", "candidate")
    (repo / "policy").write_text("new\n")
    git("commit", "-qam", "candidate")
    candidate = git("rev-parse", "HEAD")
    git("switch", "-q", "main")
    git("merge", "-q", "--no-ff", "-m", "activate", candidate)
    merge = git("rev-parse", "HEAD")
    (repo / "draft").write_text("other session's draft\n")
    data["repositories"] = [{"key": "dots", "path": str(repo), "branch": "main",
                             "base": base, "candidate": candidate, "paths": ["policy"]}]
    receipt["repositories"] = {"dots": merge}
    if alternate_index:
        index = tmp_path / "alternate-index"
        subprocess.run(["git", "-C", str(repo), "read-tree", "HEAD"],
                       env={**env, "GIT_INDEX_FILE": str(index)}, check=True, timeout=10)
        git("add", "draft")
        env["GIT_INDEX_FILE"] = str(index)
        result = run()
        env.pop("GIT_INDEX_FILE")
        assert result.returncode == 2, result.stderr
        assert "GIT_INDEX_FILE" in result.stderr
        assert git("rev-parse", "HEAD") == merge
        assert git("diff", "--cached", "--name-only") == "draft"
        assert (home / "alias").read_bytes() == b"private line\nnew alias\n"
        return
    result = run()
    assert result.returncode == 0, result.stderr
    assert (repo / "policy").read_text() == "old\n"
    assert (repo / "draft").read_text() == "other session's draft\n"
    assert (home / "alias").read_bytes() == b"private line\nold alias\n"
    assert run().returncode == 0


def smoke_tool():
    assert SMOKE.exists(), "synthetic verification tool is missing"
    spec = importlib.util.spec_from_file_location("agent_session_smoke", SMOKE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_git_timeout_cleans_up_hook_and_descendant(tmp_path):
    home, repo = tmp_path / "home", tmp_path / "repo"
    home.mkdir()
    repo.mkdir()
    env = {"PATH": "/usr/bin:/bin", "HOME": str(home), "GIT_CONFIG_GLOBAL": os.devnull,
           "GIT_CONFIG_NOSYSTEM": "1", "GIT_AUTHOR_NAME": "Fixture",
           "GIT_AUTHOR_EMAIL": "fixture@example.invalid", "GIT_COMMITTER_NAME": "Fixture",
           "GIT_COMMITTER_EMAIL": "fixture@example.invalid"}

    def git(*args):
        return subprocess.run(["git", "-C", str(repo), *args], env=env, check=True,
                              capture_output=True, text=True, timeout=10).stdout.strip()

    git("init", "-q", "-b", "main")
    assert Path(git("rev-parse", "--show-toplevel")) == repo
    assert Path(git("rev-parse", "--absolute-git-dir")) == repo / ".git"
    marker = tmp_path / "pids"
    hook = repo / ".git/hooks/pre-commit"
    hook.write_text(f'#!/bin/sh\nsleep 60 &\nprintf "%s %s\\n" "$$" "$!" > "{marker}"\nwait\n')
    hook.chmod(0o755)
    code = """import importlib.util, subprocess, sys
spec = importlib.util.spec_from_file_location("rollout", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.COMMAND_TIMEOUT = 0.5
run = subprocess.run
def short_timeout(argv, **kwargs):
    return run(argv, **dict(kwargs, timeout=0.5))
module.subprocess.run = short_timeout
try:
    module.git({"path": sys.argv[2]}, "commit", "--allow-empty", "-m", "fixture")
except (RuntimeError, subprocess.TimeoutExpired) as error:
    print(error)
else:
    sys.exit("hook deadline did not fail")
"""
    def running(pid):
        try:
            return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0] != "Z"
        except FileNotFoundError:
            return False

    pids = []
    try:
        result = subprocess.run([sys.executable, "-c", code, str(ROLLBACK), str(repo)],
                                env=env, capture_output=True, text=True, timeout=8)
        pids = list(map(int, marker.read_text().split()))
        assert result.returncode == 0, result.stderr
        assert "timed out" in result.stdout
        until = time.monotonic() + 1
        while any(map(running, pids)) and time.monotonic() < until:
            time.sleep(0.01)
        assert not any(map(running, pids)), "a hook process survived the timeout"
    finally:
        if not pids and marker.exists():
            pids = list(map(int, marker.read_text().split()))
        for pid in pids:
            if running(pid):
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass


def test_terminal_probe_requires_all_descriptors_and_controlling_terminal(tmp_path):
    smoke = smoke_tool()
    env = {"HOME": str(tmp_path), "PATH": "/usr/bin:/bin"}
    code = """import json, os
try:
    with open("/dev/tty") as terminal:
        foreground = os.tcgetpgrp(terminal.fileno()) == os.getpgrp()
except OSError:
    foreground = False
print(json.dumps(dict(tty=[os.isatty(fd) for fd in (0,1,2)], foreground=foreground, token=input())))
raise SystemExit(7)
"""
    result = smoke.terminal_round_trip([sys.executable, "-c", code], env, tmp_path)
    assert result["tty"] == [True, True, True]
    lose_stderr = "import os; os.dup2(os.open(os.devnull, os.O_WRONLY), 2);\n"
    with pytest.raises(RuntimeError, match="terminal"):
        smoke.terminal_round_trip([sys.executable, "-c", lose_stderr + code], env, tmp_path)


@pytest.mark.parametrize(("usage", "throttles", "expected"), [
    (24_000_000, 10, "pass"), (28_800_000, 10, "pass"), (28_800_001, 10, "over-quota"),
    (20_000_000, 10, "unqualified"), (24_000_000, 0, "unqualified"),
])
def test_smoke_requires_saturation_and_enforces_period_tolerance(usage, throttles, expected):
    smoke = smoke_tool()
    result = smoke.assess_sample({"usage_usec": 100, "nr_throttled": 2},
                                 {"usage_usec": 100 + usage, "nr_throttled": 2 + throttles},
                                 elapsed=1.0, quota=2_400_000, period=100_000)
    assert result["verdict"] == expected


def test_smoke_checks_each_direct_scope_and_priority(tmp_path):
    smoke = smoke_tool()
    slice_dir = tmp_path / "agents.slice"
    scoped = slice_dir / "agent.scope"
    scoped.mkdir(parents=True)
    (scoped / "cpu.weight").write_text("100\n")
    assert smoke.check_scope(slice_dir, scoped, 10) is None
    for wrong_path, nice in [(slice_dir, 10), (scoped / "nested.scope", 10), (scoped, 19)]:
        with pytest.raises(RuntimeError):
            smoke.check_scope(slice_dir, wrong_path, nice)


def test_smoke_reaps_a_child_that_ignores_the_cleanup_deadline(tmp_path):
    smoke = smoke_tool()
    home = tmp_path / "home"
    home.mkdir()
    child = subprocess.Popen(
        [sys.executable, "-c",
         'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print("ready", flush=True); time.sleep(60)'],
        env={"HOME": str(home), "PATH": "/usr/bin:/bin"}, start_new_session=True,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    try:
        assert child.stdout.readline() == "ready\n"
        smoke.cleanup([child], grace=0.05)
        assert child.poll() == -signal.SIGKILL
    finally:
        if child.poll() is None:
            child.kill()
        child.wait(timeout=5)
        child.stdout.close()
