"""Exercise the installer without writing to /etc or requiring root."""

import os
import pwd
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin/install-capture-sudoers"
USERNAME = pwd.getpwuid(os.getuid()).pw_name
RULES = {
    "50-chvt": f"{USERNAME} ALL=(root) NOPASSWD: /usr/bin/chvt\n",
    "50-fb-blank": f"{USERNAME} ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/graphics/fb0/blank\n",
}


@pytest.fixture
def rig(tmp_path):
    bindir = tmp_path / "bin"
    bindir.mkdir()
    destination = tmp_path / "sudoers.d"
    destination.mkdir()
    temporary = tmp_path / "tmp"
    temporary.mkdir()
    env = dict(PATH=f"{bindir}:{os.environ['PATH']}", TMPDIR=str(temporary),
               RULE_DEST=str(destination), RULE_LOG=str(tmp_path / "calls"))
    visudo = shutil.which("visudo")
    assert visudo, "visudo is required to test capture-host sudoers installation"
    env["VISUDO"] = visudo
    stubs = {
        "id": '''#!/bin/bash
if [[ "$*" == -u ]]; then
    printf '%s\\n' "${TEST_UID:-0}"
else
    exec /usr/bin/id "$@"
fi
''',
        "visudo": '''#!/bin/bash
set -euo pipefail
[[ $# == 2 && $1 == -cf ]]
name=$(basename "$2")
printf 'check %s\\n' "$name" >> "$RULE_LOG"
[[ "$name" != "${FAIL_RULE:-}" ]] || exit 42
exec "$VISUDO" "$@"
''',
        "install": f'''#!/bin/bash
set -euo pipefail
[[ $# == 10 && $1 == -C && $2 == -T && $3 == -m && $4 == 0440 && $5 == -o && $6 == root && $7 == -g && $8 == root ]]
name=$(basename "$9")
[[ "${{10}}" == "/etc/sudoers.d/$name" ]]
printf 'install %s\\n' "$name" >> "$RULE_LOG"
exec /usr/bin/install -C -T -m 0440 -o {os.getuid()} -g {os.getgid()} "$9" "$RULE_DEST/$name"
''',
    }
    for name, source in stubs.items():
        path = bindir / name
        path.write_text(source)
        path.chmod(0o755)
    return tmp_path, env


def run(rig, *args, **overrides):
    _, env = rig
    return subprocess.run(["bash", str(SCRIPT), *args], env=dict(env, **overrides),
                          capture_output=True, text=True, timeout=10)


def test_installs_exact_rules_and_repeats_without_rewriting(rig):
    tmp, _ = rig
    result = run(rig, USERNAME)
    assert result.returncode == 0, result.stderr
    assert (tmp / "calls").read_text().splitlines() == [
        "check 50-chvt", "check 50-fb-blank", "install 50-chvt", "install 50-fb-blank",
    ]
    before = {}
    for name, expected in RULES.items():
        path = tmp / "sudoers.d" / name
        assert path.read_text() == expected
        assert path.stat().st_mode & 0o777 == 0o440
        before[name] = path.stat()
    result = run(rig, USERNAME)
    assert result.returncode == 0, result.stderr
    for name, previous in before.items():
        current = (tmp / "sudoers.d" / name).stat()
        assert (current.st_ino, current.st_mtime_ns) == (previous.st_ino, previous.st_mtime_ns)
    assert not list((tmp / "tmp").iterdir())


def test_repairs_content_and_permissions(rig):
    tmp, _ = rig
    for name in RULES:
        path = tmp / "sudoers.d" / name
        path.write_text("outdated rule\n")
        path.chmod(0o644)
    result = run(rig, USERNAME)
    assert result.returncode == 0, result.stderr
    for name, expected in RULES.items():
        path = tmp / "sudoers.d" / name
        assert path.read_text() == expected
        assert path.stat().st_mode & 0o777 == 0o440


@pytest.mark.parametrize("failed_rule", ["50-chvt", "50-fb-blank"])
def test_failed_validation_leaves_both_existing_files_alone(rig, failed_rule):
    tmp, _ = rig
    for name in RULES:
        (tmp / "sudoers.d" / name).write_text("existing rule\n")
    result = run(rig, USERNAME, FAIL_RULE=failed_rule)
    assert result.returncode == 42
    assert "install" not in (tmp / "calls").read_text()
    assert all((tmp / "sudoers.d" / name).read_text() == "existing rule\n" for name in RULES)
    assert not list((tmp / "tmp").iterdir())


@pytest.mark.parametrize("args, error", [
    ((), "Usage:"), ((USERNAME, "extra"), "Usage:"),
    (("",), "Invalid username:"), (("ALL",), "Invalid username:"),
    (("%wheel",), "Invalid username:"), (("root,other",), "Invalid username:"),
    (("root\nALL ALL=(ALL) ALL",), "Invalid username:"), (("-u",), "Invalid username:"),
    (("dots-capture-missing-account",), "Unknown user:"),
])
def test_rejects_missing_invalid_or_unknown_user_before_privileged_commands(rig, args, error):
    tmp, _ = rig
    result = run(rig, *args)
    assert result.returncode != 0
    assert error in result.stderr
    assert not (tmp / "calls").exists()
    assert not list((tmp / "sudoers.d").iterdir())
    assert not list((tmp / "tmp").iterdir())


def test_requires_root(rig):
    tmp, _ = rig
    result = run(rig, USERNAME, TEST_UID="1000")
    assert result.returncode != 0
    assert "Run with sudo:" in result.stderr
    assert not (tmp / "calls").exists()


def test_refuses_directory_at_rule_destination(rig):
    tmp, _ = rig
    destination = tmp / "sudoers.d" / "50-chvt"
    destination.mkdir()
    result = run(rig, USERNAME)
    assert result.returncode != 0
    assert not list(destination.iterdir())
    assert not (tmp / "sudoers.d" / "50-fb-blank").exists()
    assert not list((tmp / "tmp").iterdir())
