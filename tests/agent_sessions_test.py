"""Exercise interactive shell routing with harmless stand-ins for the launchers."""

import json
import os
import pty
import shlex
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ("claude", "codex", "agy", "pi", "opencode", "crush")
WORK_ALIASES = """alias clw="CLAUDE_CONFIG_DIR=~/.claude-work claude --dangerously-skip-permissions"
alias cow="CODEX_HOME=$HOME/.codex-work codex --no-daemon"
alias cowo="CODEX_HOME=$HOME/.codex-work codex --dangerously-bypass-approvals-and-sandbox --no-daemon"
alias cowor="CODEX_HOME=$HOME/.codex-work codex --dangerously-bypass-approvals-and-sandbox resume --no-daemon"
"""


@pytest.fixture
def shell(tmp_path):
    home, bin_dir = tmp_path / "home", tmp_path / "bin"
    home.mkdir()
    bin_dir.mkdir()
    aliases = tmp_path / "work-aliases"
    aliases.write_text(WORK_ALIASES)
    for tool in TOOLS:
        stub = bin_dir / tool
        stub.write_text(f"""#!{sys.executable}
import json, os, sys
print(json.dumps(dict(tool={tool!r}, argv=sys.argv[1:], scoped=os.getenv("TEST_SCOPE"),
                      home=os.getenv("CLAUDE_CONFIG_DIR") or os.getenv("CODEX_HOME"),
                      tty=os.isatty(0), tinted=os.getenv("TEST_TINT"))))
sys.exit(7)
""")
        stub.chmod(0o755)
    budget = bin_dir / "host-budget"
    budget.write_text('#!/bin/sh\n[ "$1" = session ] && [ "$2" = -- ] || exit 9\n'
                      'shift 2\nexport TEST_SCOPE=1\nexec "$@"\n')
    budget.chmod(0o755)
    tint = bin_dir / "tint"
    tint.write_text('#!/bin/sh\n[ "$1" = -- ] || exit 9\nshift\nexport TEST_TINT=1\nexec "$@"\n')
    tint.chmod(0o755)

    def run(command, *args, setting="1", stdin=None, stdout=None):
        env = {"HOME": str(home), "PATH": f"{bin_dir}:/usr/bin:/bin",
               "XDG_CONFIG_HOME": str(home / ".config"), "ZDOTDIR": str(home),
               "HOSTKIT_AGENT_SESSIONS": setting}
        return subprocess.run(
            ["zsh", "-f", "-c",
             '[[ ! -e "$1" ]] || source "$1"; source "$2"; source "$3"; eval "$4"',
             "zsh", str(ROOT / "shell/functions.d/agents.zsh"),
             str(ROOT / "shell/aliases.d/dev.zsh"), str(aliases), shlex.join((command, *args))],
            env=env, cwd=home, stdin=stdin, text=True, timeout=15,
            **(dict(stdout=stdout, stderr=subprocess.PIPE) if stdout is not None
               else dict(capture_output=True)))

    return run, home, budget


@pytest.mark.parametrize(("name", "tool"), [
    *[(name, name) for name in TOOLS],
    ("cl", "claude"), ("clr", "claude"), ("clp", "claude"),
    ("co", "codex"), ("cor", "codex"), ("ay", "agy"), ("cr", "crush"),
    ("clw", "claude"), ("cow", "codex"), ("cowo", "codex"), ("cowor", "codex"),
])
def test_agent_routes_preserve_arguments_and_homes(shell, name, tool):
    run, home, _ = shell
    result = run(name, "${HOME}", "a b")
    assert result.returncode == 7, result.stderr
    data = json.loads(result.stdout)
    assert data["tool"] == tool
    assert data["scoped"] == "1"
    assert data["tinted"] is None
    assert data["argv"][-2:] == ["${HOME}", "a b"]
    if tool == "codex":
        assert data["argv"].count("--no-daemon") == 1
    if name == "clw":
        assert data["home"] == str(home / ".claude-work")
    if name in {"cow", "cowo", "cowor"}:
        assert data["home"] == str(home / ".codex-work")
    if name == "cowor":
        assert "resume" in data["argv"]


def test_codex_literal_no_daemon_after_delimiter_is_preserved(shell):
    result = shell[0]("codex", "exec", "--", "--no-daemon")
    assert result.returncode == 7, result.stderr
    assert json.loads(result.stdout)["argv"] == ["--no-daemon", "exec", "--", "--no-daemon"]


def test_disabled_route_preserves_native_codex_defaults(shell):
    result = shell[0]("codex", "exec", setting="0")
    assert result.returncode == 7, result.stderr
    data = json.loads(result.stdout)
    assert data["argv"] == ["exec"]
    assert data["scoped"] is None


def test_enabled_failure_and_invalid_setting_never_launch_native(shell):
    run, _, budget = shell
    budget.write_text("#!/bin/sh\nexit 11\n")
    result = run("claude")
    assert result.returncode == 11 and result.stdout == ""
    budget.unlink()
    result = run("claude")
    assert result.returncode == 127 and result.stdout == ""
    result = run("claude", setting="typo")
    assert result.returncode == 2 and result.stdout == ""
    assert "HOSTKIT_AGENT_SESSIONS" in result.stderr


def test_scope_route_keeps_terminal_input(shell):
    master, slave = pty.openpty()
    try:
        result = shell[0]("claude", stdin=slave)
    finally:
        os.close(slave)
        os.close(master)
    assert result.returncode == 7, result.stderr
    data = json.loads(result.stdout)
    assert data["tty"] and data["scoped"] == "1"


def test_titan_drift_compares_the_unit_policy_and_opt_in(tmp_path):
    host = ROOT / "hosts/titan"
    env = {"HOME": str(tmp_path / "home"), "PATH": "/usr/bin:/bin",
           "XDG_CONFIG_HOME": str(tmp_path / "config"), "GIT_CONFIG_GLOBAL": os.devnull,
           "GIT_CONFIG_NOSYSTEM": "1"}
    # The existing drift tool is the interface consumed by the dotfiles recipe.
    drift = shutil.which("host-drift")
    assert drift, "host-drift must be installed for this focused integration check"
    manifest = tomllib.loads((host / "adopted.toml").read_text())
    for entry in manifest["file"] + manifest["block"]:
        source = (host / entry["source"]).read_text()
        path = tmp_path / "installed" / entry["installed"].replace("~", env["HOME"]).lstrip("/")
        path.parent.mkdir(parents=True, exist_ok=True)
        if "marker" in entry:
            source = f'# >>> {entry["marker"]} >>>\n{source}# <<< {entry["marker"]} <<<\n'
        path.write_text(source)
    argv = [drift, str(host), "--host", "titan", "--root", str(tmp_path / "installed")]
    check = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=15)
    assert check.returncode == 0, check.stderr + check.stdout
    assert check.stdout.count("ok ") == 3
    policy = tomllib.loads((host / "budget.toml").read_text())["scope"]
    assert policy["slice"] == "agents.slice" and policy["require_quota"] is True
    assert policy["nice"] == 10
    unit = host / "systemd/user/agents.slice"
    installed = tmp_path / "installed" / env["HOME"].lstrip("/") / ".config/systemd/user/agents.slice"
    installed.write_text(unit.read_text().replace("CPUQuota=2400%\n", ""))
    check = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=15)
    assert check.returncode == 1
    assert "drift" in check.stdout and "agents.slice" in check.stdout


def run_on_terminal(shell, name, **kwargs):
    """Run with stdin and stdout on one pseudo-terminal; the stub's JSON line."""
    master, slave = pty.openpty()
    try:
        result = shell[0](name, "a b", stdin=slave, stdout=slave, **kwargs)
        os.close(slave)
        slave = None
        out = b""
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
    finally:
        if slave is not None:
            os.close(slave)
        os.close(master)
    assert result.returncode == 7, result.stderr
    return json.loads(out.decode().strip().splitlines()[-1])


@pytest.mark.parametrize("setting", ["0", "1"])
@pytest.mark.parametrize(("name", "tinted"), [
    ("claude", True), ("codex", True), ("agy", True), ("cl", True), ("co", True),
    ("ay", True), ("clw", True), ("cowor", True),
    ("pi", False), ("opencode", False), ("crush", False),
])
def test_terminal_sessions_run_behind_tint(shell, name, tinted, setting):
    data = run_on_terminal(shell, name, setting=setting)
    assert data["tty"]
    assert (data["tinted"] == "1") is tinted
    assert data["scoped"] == ("1" if setting == "1" else None)
    assert data["argv"][-1] == "a b"


def test_terminal_session_without_tint_runs_plain(shell):
    run, home, _ = shell
    (home.parent / "bin" / "tint").unlink()
    data = run_on_terminal(shell, "claude")
    assert data["tool"] == "claude" and data["tinted"] is None and data["scoped"] == "1"
