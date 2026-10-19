"""Exercise lookout installation without changing the host's launchers."""

import os
from pathlib import Path
import subprocess

import pytest


REPO = Path(__file__).resolve().parents[1]


@pytest.fixture
def home(tmp_path):
    root = tmp_path / "home"
    checkout = root / "d/lookout"
    (checkout / "src").mkdir(parents=True)
    # The real just command runs a disposable dependency installer.
    (checkout / "justfile").write_text(
        'setup:\n    test "${INSTALL_STATUS:-0}" = 0\n    touch hydrated\n'
    )
    entry = checkout / "src/bin.ts"
    entry.write_text('#!/bin/sh\necho "lookout fixture"\n')
    entry.chmod(0o755)
    return root


def setup(home, *args, **env):
    return subprocess.run(
        ["bash", str(REPO / "setup.sh"), "--only", "lookout", *args],
        env={**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), **env},
        capture_output=True, text=True,
    )


def test_setup_hydrates_and_links_idempotently(home):
    for _ in range(2):
        result = setup(home)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (home / "d/lookout/hydrated").exists()
        link = home / ".local/bin/lookout"
        assert link.is_symlink()
        assert link.readlink() == home / "d/lookout/src/bin.ts"
        assert subprocess.check_output([str(link), "--version"], text=True) == "lookout fixture\n"


def test_missing_checkout_fails_with_a_fix(home):
    (home / "d/lookout/src/bin.ts").unlink()
    result = setup(home)
    assert result.returncode != 0
    assert "Phase failed" in result.stderr
    assert "lookout" in result.stdout and "clone" in result.stdout
    assert not (home / ".local/bin/lookout").exists()


def test_dependency_failure_leaves_no_launcher(home):
    result = setup(home, INSTALL_STATUS="1")
    assert result.returncode != 0
    assert "Phase failed" in result.stderr
    assert not (home / ".local/bin/lookout").exists()


@pytest.mark.parametrize("args", [("--dry-run",), ("--link-only",)])
def test_preview_and_link_only_do_not_install_dependencies(home, args):
    result = setup(home, *args)
    assert result.returncode == 0, result.stdout + result.stderr
    assert not (home / "d/lookout/hydrated").exists()
    link = home / ".local/bin/lookout"
    assert link.is_symlink() == ("--link-only" in args)
