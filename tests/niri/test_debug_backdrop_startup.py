from dataclasses import dataclass
import json
import os
from pathlib import Path
import subprocess

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "prism-debug-backdrop-startup"


@dataclass
class Rig:
    tmp_path: Path
    bin_dir: Path

    def run(self, *, value: str, outputs: dict, layers: list[list[dict]]) -> subprocess.CompletedProcess[str]:
        if not SCRIPT.exists():
            pytest.fail(f"startup script is missing: {SCRIPT}")
        env = {
            **os.environ,
            "PATH": f"{self.bin_dir}:{os.environ['PATH']}",
            "PRISM_FAKE_VALUE": value,
            "PRISM_FAKE_LOG": str(self.tmp_path / "prism.log"),
            "NIRI_FAKE_OUTPUTS": json.dumps(outputs),
            "NIRI_FAKE_LAYERS": json.dumps(layers),
            "NIRI_FAKE_COUNT": str(self.tmp_path / "niri-count"),
        }
        return subprocess.run([SCRIPT], capture_output=True, text=True, env=env, check=False)

    def apply_calls(self) -> list[str]:
        log = self.tmp_path / "prism.log"
        return log.read_text().splitlines() if log.exists() else []

    def layer_calls(self) -> int:
        count = self.tmp_path / "niri-count"
        return int(count.read_text()) if count.exists() else 0


@pytest.fixture
def rig(tmp_path: Path) -> Rig:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    (bin_dir / "prism").write_text("""#!/bin/sh
if [ "$1 $2" = "get debug.backdrop" ]; then
    printf '%s\\n' "$PRISM_FAKE_VALUE"
    exit 0
fi
if [ "$1 $2" = "apply debug-backdrop" ]; then
    printf '%s\\n' "$*" >> "$PRISM_FAKE_LOG"
    exit 0
fi
printf 'unexpected prism command: %s\\n' "$*" >&2
exit 64
""")
    (bin_dir / "niri").write_text("""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

command = sys.argv[1:]
if command == ["msg", "-j", "outputs"]:
    print(os.environ["NIRI_FAKE_OUTPUTS"])
    raise SystemExit(0)
if command == ["msg", "-j", "layers"]:
    count_path = Path(os.environ["NIRI_FAKE_COUNT"])
    count = int(count_path.read_text()) if count_path.exists() else 0
    count_path.write_text(str(count + 1))
    sequence = json.loads(os.environ["NIRI_FAKE_LAYERS"])
    print(json.dumps(sequence[min(count, len(sequence) - 1)]))
    raise SystemExit(0)
print(f"unexpected niri command: {' '.join(command)}", file=sys.stderr)
raise SystemExit(64)
""")
    (bin_dir / "sleep").write_text("#!/bin/sh\nexit 0\n")
    for executable in bin_dir.iterdir():
        executable.chmod(0o755)

    return Rig(tmp_path, bin_dir)


def output(name: str, logical: dict | None) -> dict:
    return {"name": name, "logical": logical}


def wallpaper(output_name: str) -> dict:
    return {
        "namespace": "noctalia-wallpaper",
        "output": output_name,
        "layer": "Background",
        "keyboard_interactivity": "None",
    }


def test_false_applies_immediately_without_querying_layers(rig: Rig):
    result = rig.run(value="false", outputs={}, layers=[[]])

    assert result.returncode == 0, result.stderr
    assert rig.apply_calls() == ["apply debug-backdrop"]
    assert rig.layer_calls() == 0


def test_true_waits_for_wallpaper_on_every_enabled_output(rig: Rig):
    result = rig.run(
        value="true",
        outputs={
            "DP-1": output("DP-1", {"x": 0, "y": 0, "width": 3440, "height": 1440, "scale": 1.0}),
            "DP-2": output("DP-2", {"x": 3440, "y": 0, "width": 1920, "height": 1080, "scale": 1.0}),
        },
        layers=[
            [wallpaper("DP-1")],
            [wallpaper("DP-1"), wallpaper("DP-2")],
        ],
    )

    assert result.returncode == 0, result.stderr
    assert rig.apply_calls() == ["apply debug-backdrop"]
    assert rig.layer_calls() == 2


def test_disabled_outputs_do_not_block_startup(rig: Rig):
    result = rig.run(
        value="true",
        outputs={
            "DP-1": output("DP-1", {"x": 0, "y": 0, "width": 3440, "height": 1440, "scale": 1.0}),
            "eDP-1": output("eDP-1", None),
        },
        layers=[[wallpaper("DP-1")]],
    )

    assert result.returncode == 0, result.stderr
    assert rig.apply_calls() == ["apply debug-backdrop"]
    assert rig.layer_calls() == 1


def test_timeout_fails_without_applying(rig: Rig):
    result = rig.run(
        value="true",
        outputs={
            "DP-1": output("DP-1", {"x": 0, "y": 0, "width": 3440, "height": 1440, "scale": 1.0}),
        },
        layers=[[]],
    )

    assert result.returncode != 0
    assert rig.apply_calls() == []
    assert rig.layer_calls() == 30
    assert "DP-1" in result.stderr
