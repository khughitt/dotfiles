#!/usr/bin/env python3
"""bar1-guard gates GPU clients on free BAR1 aperture.

titan's RTX 3070 is windowed through a fixed 256 MiB BAR1 -- X399 predates
Resizable BAR, so there is no way to enlarge it. When enough GPU clients map
buffers at once the aperture runs out, and the NVIDIA driver's failure path can
issue a mapping that runs past the end of BAR1 into the neighbouring BAR, which
wedges the GPU MMU and hard-freezes the machine.

Exhaustion on its own is survivable (one boot took 173 allocation failures and
lived). Staying clear of the edge is what matters, so anything about to add a
GL client should gate on headroom first.

Critically, an unreadable GPU must NOT be treated as "plenty of headroom" --
that would silently disable the guard exactly when something is wrong.
"""

import os
import subprocess
import textwrap
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
GUARD = ROOT / "bin" / "bar1-guard"


def nvidia_smi_stub(free_file):
    """A stub whose reported free BAR1 the test can change mid-run."""
    return textwrap.dedent(f"""\
        #!/usr/bin/env bash
        free=$(cat "{free_file}")
        cat <<EOF
            FB Memory Usage
                Total                             : 8192 MiB
                Free                              : 7000 MiB
            BAR1 Memory Usage
                Total                             : 256 MiB
                Used                              : $((256 - free)) MiB
                Free                              : $free MiB
            Conf Compute Protected Memory Usage
                Total                             : 0 MiB
        EOF
    """)


class Rig:
    def __init__(self, tmp_path):
        self.tmp = tmp_path
        self.free = tmp_path / "free"
        self.free.write_text("200\n")
        self.bindir = tmp_path / "bin"
        self.bindir.mkdir()
        self.smi = self.bindir / "nvidia-smi"
        self.write_smi(nvidia_smi_stub(self.free))

    def write_smi(self, body):
        self.smi.write_text(body)
        self.smi.chmod(0o755)

    def remove_smi(self):
        self.smi.unlink()

    def set_free(self, mib):
        self.free.write_text(f"{mib}\n")

    def env(self, smi=None):
        # NVIDIA_SMI keeps the test off PATH games, which would otherwise have
        # to hide the real nvidia-smi that exists on this machine.
        return {**os.environ, "NVIDIA_SMI": str(smi if smi is not None else self.smi)}

    def run(self, *args, timeout=30, smi=None):
        return subprocess.run(
            ["bash", str(GUARD), *args],
            capture_output=True, text=True, timeout=timeout, env=self.env(smi))


@pytest.fixture
def rig(tmp_path):
    return Rig(tmp_path)


def test_print_reports_free_bar1(rig):
    rig.set_free(231)
    out = rig.run("--print")
    assert out.returncode == 0, out.stderr
    assert out.stdout.strip() == "231"


def test_print_skips_the_fb_memory_free_line(rig):
    """FB Memory Usage also has a Free field and comes first -- do not read it."""
    rig.set_free(120)
    out = rig.run("--print")
    assert out.stdout.strip() == "120", \
        f"parsed the wrong Free field: got {out.stdout.strip()!r}"


def test_check_passes_when_headroom_is_sufficient(rig):
    rig.set_free(200)
    assert rig.run("--check", "--min", "96").returncode == 0


def test_check_fails_when_headroom_is_thin(rig):
    rig.set_free(40)
    out = rig.run("--check", "--min", "96")
    assert out.returncode != 0
    assert "40" in (out.stdout + out.stderr)


def test_wait_returns_once_headroom_appears(rig):
    """The normal path: block while another client holds the aperture."""
    rig.set_free(30)

    proc = subprocess.Popen(
        ["bash", str(GUARD), "--min", "96", "--interval", "1", "--timeout", "30"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, env=rig.env())
    try:
        time.sleep(3)
        assert proc.poll() is None, "guard exited while headroom was still thin"
        rig.set_free(200)
        assert proc.wait(timeout=30) == 0
    finally:
        if proc.poll() is None:
            proc.kill()


def test_wait_times_out_rather_than_blocking_forever(rig):
    rig.set_free(10)
    out = rig.run("--min", "96", "--interval", "1", "--timeout", "3", timeout=30)
    assert out.returncode != 0
    assert "timed out" in (out.stdout + out.stderr).lower()


def test_missing_nvidia_smi_is_an_error_not_a_free_pass(rig):
    """Fail early. A guard that passes when it cannot measure is worse than none."""
    out = rig.run("--check", smi=rig.tmp / "definitely-not-here")
    assert out.returncode != 0, \
        "guard passed with no nvidia-smi available -- silent fallback"
    assert "nvidia-smi" in (out.stdout + out.stderr)


def test_unparseable_output_is_an_error_not_a_free_pass(rig):
    rig.write_smi("#!/usr/bin/env bash\necho 'no BAR1 section here'\n")
    out = rig.run("--check")
    assert out.returncode != 0, \
        "guard passed on unparseable nvidia-smi output -- silent fallback"
    assert "bar1" in (out.stdout + out.stderr).lower()


def test_nvidia_smi_failure_is_an_error_not_a_free_pass(rig):
    rig.write_smi("#!/usr/bin/env bash\nexit 9\n")
    out = rig.run("--check")
    assert out.returncode != 0, \
        "guard passed when nvidia-smi failed -- silent fallback"
