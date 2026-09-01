#!/usr/bin/env python3
"""kernel-gate holds the kernel back; the pair it holds must never split.

`linux` and `linux-headers` are pinned in pacman's IgnorePkg so that a routine
`pacman -Syu` cannot de-certify the atoms durability tuple, which keys on an
exact `uname -r`. The pin is only safe while both packages move together: DKMS
modules build against the headers, so a kernel at one version and headers at
another breaks every module build, and the breakage surfaces at the next boot
rather than at the transaction that caused it.

`check-sync` is the pacman hook that refuses to let that pass silently, so its
mismatch path is the one thing here that must not regress. The rest of these
tests pin the reporting: `status` has to distinguish "held" from "not held",
and `unlock --dry-run` has to touch nothing.

The script is driven for real against stub pacman/pacman-conf/uname/file
binaries on PATH.
"""

import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "kernel-gate"

PACMAN_STUB = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$STUB_CALLS"
pkg="$2"
case "$1" in
    -Q)
        case "$pkg" in
            linux)         [ -n "${LINUX_VER:-}" ] && printf 'linux %s\\n' "$LINUX_VER" ;;
            linux-headers) [ -n "${HEADERS_VER:-}" ] && printf 'linux-headers %s\\n' "$HEADERS_VER" ;;
        esac
        ;;
    -Qu)
        case "$pkg" in
            linux)
                [ -n "${LINUX_NEW:-}" ] || exit 1
                printf 'linux %s -> %s [ignored]\\n' "$LINUX_VER" "$LINUX_NEW" ;;
            linux-headers)
                [ -n "${HEADERS_NEW:-}" ] || exit 1
                printf 'linux-headers %s -> %s [ignored]\\n' "$HEADERS_VER" "$HEADERS_NEW" ;;
        esac
        ;;
esac
exit 0
"""

PACMAN_CONF_STUB = """#!/usr/bin/env bash
[ "$1" = IgnorePkg ] || exit 0
printf '%s' "${IGNORED:-}" | tr ' ' '\\n' | grep -v '^$' || true
"""

UNAME_STUB = """#!/usr/bin/env bash
[ "$1" = -r ] && printf '%s\\n' "$RUNNING_KERNEL"
"""

# The real `file -b` output the script greps 'version \\K[^ ]+' out of.
FILE_STUB = """#!/usr/bin/env bash
printf 'Linux kernel x86 boot executable bzImage, version %s (linux@archlinux) #1 SMP, RO-rootFS\\n' \\
    "${BOOT_KERNEL:-$RUNNING_KERNEL}"
"""

NOTIFY_STUB = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$NOTIFY_CALLS"
"""

GIT_STUB = """#!/usr/bin/env bash
exit "${GIT_RC:-1}"
"""

STUBS = {
    "pacman": PACMAN_STUB,
    "pacman-conf": PACMAN_CONF_STUB,
    "uname": UNAME_STUB,
    "file": FILE_STUB,
    "notify-send": NOTIFY_STUB,
    "git": GIT_STUB,
}


@pytest.fixture
def gate(tmp_path):
    """Return a runner for the real script against stubbed system binaries."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    for name, body in STUBS.items():
        stub = bindir / name
        stub.write_text(body)
        stub.chmod(0o755)

    calls = tmp_path / "calls"
    notify_calls = tmp_path / "notify"
    conf = tmp_path / "kernel-gate.conf"
    conf.write_text("ATOMS_REPO=\n")

    def run(*args, atoms_repo=None, **env):
        if atoms_repo is not None:
            conf.write_text(f"ATOMS_REPO={atoms_repo}\n")
        environ = {
            **os.environ,
            "PATH": f"{bindir}:{os.environ['PATH']}",
            "KERNEL_GATE_CONF": str(conf),
            "STUB_CALLS": str(calls),
            "NOTIFY_CALLS": str(notify_calls),
            "RUNNING_KERNEL": "7.1.11-arch1-1",
            "LINUX_VER": "7.1.11.arch1-1",
            "HEADERS_VER": "7.1.11.arch1-1",
            "IGNORED": "linux linux-headers",
        }
        environ.update({k: str(v) for k, v in env.items()})
        return subprocess.run(
            [str(SCRIPT), *args], capture_output=True, text=True, env=environ
        )

    run.calls = lambda: calls.read_text() if calls.exists() else ""
    run.notifications = lambda: notify_calls.read_text() if notify_calls.exists() else ""
    return run


def certified_repo(tmp_path, kernel):
    """A checkout stub holding just the allowlist line kernel-gate reads."""
    volume = tmp_path / "repo" / "python" / "src" / "atoms" / "fs" / "volume.py"
    volume.parent.mkdir(parents=True)
    volume.write_text(
        "CERTIFIED_ALLOWLIST = DurabilityAllowlist(\n"
        f'    kernel_identifier="{kernel}",\n'
        ")\n"
    )
    return tmp_path / "repo"


# --- check-sync: the hook that keeps the pinned pair from splitting ---------

def test_check_sync_passes_when_the_pair_matches(gate):
    assert gate("check-sync").returncode == 0


def test_check_sync_fails_and_explains_when_the_pair_splits(gate):
    result = gate("check-sync", LINUX_VER="7.2.2.arch1-1", HEADERS_VER="7.1.11.arch1-1")
    assert result.returncode == 1
    assert "out of sync" in result.stderr
    # The message must name the real consequence, not just the mismatch.
    assert "dkms" in result.stderr.lower()
    assert "kernel-gate unlock" in result.stderr


def test_check_sync_ignores_a_machine_without_headers(gate):
    # linux-headers is not required to be installed; absent is not a mismatch.
    assert gate("check-sync", HEADERS_VER="").returncode == 0


# --- status ----------------------------------------------------------------

def test_status_reports_the_pin_and_the_withheld_upgrade(gate):
    result = gate("status", LINUX_NEW="7.2.2.arch1-1", HEADERS_NEW="7.2.2.arch1-1")
    assert result.returncode == 0
    assert "linux linux-headers" in result.stdout
    assert "7.2.2.arch1-1 available" in result.stdout


def test_status_says_so_loudly_when_the_gate_is_missing(gate):
    result = gate("status", IGNORED="")
    assert "the gate is not in place" in result.stdout


def test_status_reports_a_pending_reboot(gate):
    result = gate("status", BOOT_KERNEL="7.2.2-arch1-1")
    assert "REBOOT PENDING" in result.stdout
    assert "7.2.2-arch1-1" in result.stdout


def test_status_confirms_a_matching_certification(gate, tmp_path):
    repo = certified_repo(tmp_path, "7.1.11-arch1-1")
    result = gate("status", atoms_repo=repo)
    assert "matches running kernel" in result.stdout


def test_status_flags_a_stale_certification(gate, tmp_path):
    repo = certified_repo(tmp_path, "7.1.10-arch1-1")
    result = gate("status", atoms_repo=repo)
    assert "STALE" in result.stdout


def test_status_skips_the_certification_check_without_a_repo(gate):
    result = gate("status")
    assert result.returncode == 0
    assert "unknown" in result.stdout


# --- unlock ----------------------------------------------------------------

def test_unlock_dry_run_changes_nothing(gate):
    result = gate("unlock", "--dry-run", LINUX_NEW="7.2.2.arch1-1")
    assert result.returncode == 0
    # A full -Syu first, so taking the kernel afterwards is not a partial upgrade.
    assert "pacman -Syu" in result.stdout
    assert "pacman -S --needed linux linux-headers" in result.stdout
    assert gate.calls() == ""


def test_unlock_rejects_an_unknown_option(gate):
    result = gate("unlock", "--force")
    assert result.returncode == 1
    assert gate.calls() == ""


def test_unknown_subcommand_fails(gate):
    assert gate("bogus").returncode == 1


# --- nudge -----------------------------------------------------------------

def test_nudge_is_silent_when_there_is_nothing_to_do(gate, tmp_path):
    repo = certified_repo(tmp_path, "7.1.11-arch1-1")
    result = gate("nudge", atoms_repo=repo)
    assert result.returncode == 0
    assert gate.notifications() == ""


def test_nudge_notifies_when_an_upgrade_is_being_held(gate):
    result = gate("nudge", LINUX_NEW="7.2.2.arch1-1")
    assert result.returncode == 0
    assert "kernel-gate" in gate.notifications()


def test_nudge_stays_quiet_on_a_machine_without_the_gate(gate):
    # Upgrades are merely available here, not withheld -- claiming otherwise
    # would make the timer unsafe to enable before the root install runs.
    result = gate("nudge", IGNORED="", LINUX_NEW="7.2.2.arch1-1")
    assert result.returncode == 0
    assert "the gate is not in place" in result.stdout
    assert gate.notifications() == ""
