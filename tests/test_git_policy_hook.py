"""Global ops-policy hooks resolve ops-policy and Relay across PATH and sandboxed HOME."""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
EVENTS = ("pre-commit", "commit-msg", "pre-push")


@pytest.fixture
def policy_hook(tmp_path):
    home = tmp_path / "home with spaces"
    home.mkdir()
    commands = tmp_path / "commands"
    commands.mkdir()
    repo = tmp_path / "repo"
    repo.mkdir()
    calls = tmp_path / "calls"
    config = home / ".gitconfig"
    env = {
        "PATH": f"{commands}:/usr/bin:/bin",
        "HOME": str(home),
        "GIT_CONFIG_GLOBAL": str(config),
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_AUTHOR_NAME": "Fixture",
        "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
        "GIT_COMMITTER_NAME": "Fixture",
        "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        "HOOK_CALLS": str(calls),
        "HOOK_STATUS": "0",
    }

    def git(*args):
        return subprocess.run(
            [
                "git",
                "-C",
                str(repo),
                "-c",
                "hook.identity-check.enabled=false",
                "-c",
                "hook.index-health.enabled=false",
                *args,
            ],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    assert git("init", "-q").returncode == 0
    assert Path(git("rev-parse", "--show-toplevel").stdout.strip()).resolve() == repo.resolve()
    assert Path(git("rev-parse", "--absolute-git-dir").stdout.strip()).resolve().is_relative_to(repo.resolve())
    shutil.copyfile(ROOT / "git/config", config)

    def install_stub(location, name, body):
        path = location / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)
        return path

    return git, env, calls, install_stub, commands, home / ".local/bin"


@pytest.mark.parametrize("event", EVENTS)
def test_policy_hook_events_are_declared(policy_hook, event):
    git, *_ = policy_hook
    result = git("config", "--global", "--get-all", f"hook.ops-policy-{event}.event")
    assert result.returncode == 0, f"maintained config must declare ops-policy-{event}"
    assert result.stdout.splitlines() == [event]


@pytest.mark.parametrize("event", EVENTS)
@pytest.mark.parametrize("status", [0, 1])
def test_path_ops_policy_wins_when_home_is_sandboxed(policy_hook, event, status):
    git, env, calls, install_stub, commands, _ = policy_hook
    install_stub(commands, "ops-policy", 'printf "path:%s\\n" "$*" >> "$HOOK_CALLS"\nexit "$HOOK_STATUS"\n')
    env["HOOK_STATUS"] = str(status)
    result = git("hook", "run", event)
    assert result.returncode == status, result.stderr
    assert calls.read_text().splitlines() == [f"path:{event}"]


@pytest.mark.parametrize("event", EVENTS)
def test_installed_ops_policy_and_relay_found_with_system_only_path(policy_hook, event):
    git, env, calls, install_stub, _, installed = policy_hook
    env["PATH"] = "/usr/bin:/bin"
    install_stub(installed, "relay", "exit 0\n")
    install_stub(
        installed,
        "ops-policy",
        'relay_path=$(command -v relay || true)\nprintf "installed:%s:%s\\n" "$*" "$relay_path" >> "$HOOK_CALLS"\n',
    )
    result = git("hook", "run", event)
    assert result.returncode == 0, result.stderr
    assert calls.read_text().splitlines() == [f"installed:{event}:{installed / 'relay'}"]


@pytest.mark.parametrize("event", EVENTS)
def test_missing_ops_policy_fails_closed(policy_hook, event):
    git, _, calls, *_ = policy_hook
    result = git("hook", "run", event)
    assert result.returncode != 0
    assert not calls.exists()
