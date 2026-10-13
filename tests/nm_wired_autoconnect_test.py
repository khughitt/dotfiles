#!/usr/bin/env python3
"""nm-wired-autoconnect must reconnect a wired port when its link returns, and only then.

A user disconnect (nm-applet's or Noctalia's "disconnect") makes NetworkManager
block autoconnect on the device, and the block survives the cable being
unplugged and replugged: an accidental click once left a host on Wi-Fi for two
days with a live cable. Setting the device's autoconnect back to yes is not
enough either; NetworkManager clears the flag but does not activate anything.
So the daemon watches device states and runs `nmcli device connect` when an
ethernet device regains carrier (unavailable -> disconnected) while its
autoconnect is still blocked.

A deliberate disconnect must keep holding while the link stays up, and Wi-Fi
is never touched.

These tests drive the real script against a stub nmcli whose monitor stream
and per-device answers come from files.
"""

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "bin" / "nm-wired-autoconnect"

# `device monitor` replays a fixture and exits; `device show` answers
# `-g GENERAL.TYPE,GENERAL.AUTOCONNECT` from a per-device file; `device
# connect` is recorded.
NMCLI_STUB = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "{calls}"
case "$*" in
    'device monitor') cat "{stream}" ;;
    '-g GENERAL.TYPE,GENERAL.AUTOCONNECT device show '*)
        dev=${{@: -1}}
        if [ -f "{devices}/$dev" ]; then
            cat "{devices}/$dev"
        else
            printf "Error: Device '%s' not found.\\n" "$dev" >&2
            exit 10
        fi
        ;;
    'device connect '*) ;;
    *) printf 'unexpected nmcli call: %s\\n' "$*" >&2; exit 2 ;;
esac
"""


def run(
    tmp_path: Path, stream: list[str], devices: dict[str, tuple[str, str]]
) -> tuple[subprocess.CompletedProcess, list[str]]:
    bindir = tmp_path / "bin"
    bindir.mkdir()
    devdir = tmp_path / "devices"
    devdir.mkdir()
    calls = tmp_path / "calls"
    calls.touch()
    stream_file = tmp_path / "stream"
    stream_file.write_text("".join(f"{line}\n" for line in stream))
    for dev, (kind, autoconnect) in devices.items():
        (devdir / dev).write_text(f"{kind}\n{autoconnect}\n")
    stub = bindir / "nmcli"
    stub.write_text(NMCLI_STUB.format(calls=calls, stream=stream_file, devices=devdir))
    stub.chmod(0o755)
    environ = {**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}"}
    result = subprocess.run([str(SCRIPT)], capture_output=True, text=True, env=environ, timeout=10)
    return result, calls.read_text().splitlines()


def connects(calls: list[str]) -> list[str]:
    return [call for call in calls if call.startswith("device connect")]


def test_reconnects_blocked_ethernet_when_carrier_returns(tmp_path):
    result, calls = run(
        tmp_path,
        ["enp6s0: unavailable", "enp6s0: disconnected"],
        {"enp6s0": ("ethernet", "no")},
    )
    assert connects(calls) == ["device connect enp6s0"]
    assert "enp6s0" in result.stdout


def test_leaves_unblocked_ethernet_to_networkmanager(tmp_path):
    _, calls = run(
        tmp_path,
        ["enp6s0: unavailable", "enp6s0: disconnected", "enp6s0: connecting (prepare)"],
        {"enp6s0": ("ethernet", "yes")},
    )
    assert connects(calls) == []


def test_user_disconnect_holds_while_link_stays_up(tmp_path):
    _, calls = run(
        tmp_path,
        ["enp6s0: connected", "enp6s0: deactivating", "enp6s0: disconnected"],
        {"enp6s0": ("ethernet", "no")},
    )
    assert connects(calls) == []


def test_ignores_wifi(tmp_path):
    _, calls = run(
        tmp_path,
        ["wlp5s0: unavailable", "wlp5s0: disconnected"],
        {"wlp5s0": ("wifi", "no")},
    )
    assert connects(calls) == []


def test_tracks_devices_independently(tmp_path):
    # enp4s0's dropped carrier must not count as enp6s0's transition.
    _, calls = run(
        tmp_path,
        ["enp4s0: unavailable", "enp6s0: disconnected", "enp4s0: disconnected"],
        {"enp4s0": ("ethernet", "no"), "enp6s0": ("ethernet", "no")},
    )
    assert connects(calls) == ["device connect enp4s0"]


def test_vanished_device_is_skipped_not_fatal(tmp_path):
    # A USB adapter can disappear between the event and the query.
    _, calls = run(
        tmp_path,
        ["enx0: unavailable", "enx0: disconnected", "enp6s0: unavailable", "enp6s0: disconnected"],
        {"enp6s0": ("ethernet", "no")},
    )
    assert connects(calls) == ["device connect enp6s0"]


def test_exits_nonzero_when_monitor_ends(tmp_path):
    # systemd restarts it; a silent exit 0 would leave the port unwatched.
    result, _ = run(tmp_path, [], {})
    assert result.returncode != 0
