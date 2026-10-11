"""Dropbox rule installation preserves local rules and survives repeated setup."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
GIT_RULES = "**/.git/index*\n**/.git/sharedindex*\n**/.git/next-index-*\n"


@pytest.fixture
def setup_home(tmp_path):
    repo = tmp_path / "repo"
    (repo / "lib").mkdir(parents=True)
    shutil.copy2(ROOT / "setup.sh", repo)
    shutil.copy2(ROOT / "lib/dotfiles-setup-data.bash", repo / "lib")
    home = tmp_path / "home"
    (home / "d").mkdir(parents=True)

    def run(*args):
        return subprocess.run(
            ["bash", str(repo / "setup.sh"), "--headless", "--link-only", "--only", "dropbox-ignore", *args],
            env={**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")},
            capture_output=True,
            text=True,
        )

    return home, run


@pytest.mark.parametrize("existing", [None, "*.log", "*.log\n!**/.git/index\n"])
def test_setup_installs_git_rules_without_losing_local_rules(setup_home, existing):
    home, run = setup_home
    rules = home / "d/rules.dropboxignore"
    if existing is not None:
        rules.write_text(existing)
    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    content = rules.read_text()
    assert content == (existing or "") + "\n" + GIT_RULES
    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert rules.read_text() == content


def test_setup_dry_run_does_not_create_rules(setup_home):
    home, run = setup_home
    result = run("--dry-run")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "rules.dropboxignore" in result.stdout
    assert not (home / "d/rules.dropboxignore").exists()


def test_setup_skips_rules_without_dropbox_root(setup_home):
    home, run = setup_home
    (home / "d").rmdir()
    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert not (home / "d").exists()


def test_setup_reports_rule_write_failure(setup_home):
    home, run = setup_home
    (home / "d/rules.dropboxignore").mkdir()
    result = run()
    assert result.returncode != 0
