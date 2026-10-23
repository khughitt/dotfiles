"""The maintained named hook resolves once and preserves the guard's verdict."""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
EVENTS = ("pre-commit", "pre-merge-commit")


@pytest.fixture
def hook(tmp_path):
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
            ["git", "-C", str(repo), *args], env=env, capture_output=True, text=True, check=False
        )

    assert git("init", "-q").returncode == 0
    assert Path(git("rev-parse", "--show-toplevel").stdout.strip()).resolve() == repo.resolve()
    assert Path(git("rev-parse", "--absolute-git-dir").stdout.strip()).resolve().is_relative_to(repo.resolve())
    shutil.copyfile(ROOT / "git/config", config)
    identity = commands / "git-identity-check"
    identity.write_text("#!/bin/sh\nexit 0\n")
    identity.chmod(0o755)

    def executable(location, label):
        path = location / "git-index-health"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'#!/bin/sh\nprintf "{label}:%s\\n" "$*" >> "$HOOK_CALLS"\nexit "$HOOK_STATUS"\n')
        path.chmod(0o755)

    return git, env, calls, executable, commands, home / ".local/bin"


def test_both_events_are_declared(hook):
    git, *_ = hook
    result = git("config", "--global", "--get-all", "hook.index-health.event")
    assert result.returncode == 0, "maintained config must declare the index-health hook"
    assert result.stdout.splitlines() == list(EVENTS)


@pytest.mark.parametrize("event", EVENTS)
@pytest.mark.parametrize("status", [0, 1, 2])
def test_path_wins_and_verdict_never_retries_the_installed_command(hook, event, status):
    git, env, calls, executable, commands, installed = hook
    executable(commands, "path")
    executable(installed, "installed")
    env["HOOK_STATUS"] = str(status)
    result = git("hook", "run", event)
    assert result.returncode == status, result.stderr
    assert calls.read_text().splitlines() == ["path:--guard"]


@pytest.mark.parametrize("event", EVENTS)
@pytest.mark.parametrize("status", [0, 1, 2])
def test_installed_command_is_used_when_absent_from_path(hook, event, status):
    git, env, calls, executable, _, installed = hook
    executable(installed, "installed")
    env["HOOK_STATUS"] = str(status)
    result = git("hook", "run", event)
    assert result.returncode == status, result.stderr
    assert calls.read_text().splitlines() == ["installed:--guard"]


@pytest.mark.parametrize("event", EVENTS)
def test_missing_installation_warns_and_allows_the_event(hook, event):
    git, _, calls, *_ = hook
    result = git("hook", "run", event)
    assert result.returncode == 0, result.stderr
    assert "no index check ran" in result.stderr
    assert not calls.exists()
