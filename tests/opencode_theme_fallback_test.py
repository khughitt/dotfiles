#!/usr/bin/env python3
import shlex
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

binary = shutil.which("opencode")
if not binary:
    print("SKIP opencode theme fallback: opencode is not installed")
    raise SystemExit(0)
tmux = shutil.which("tmux")
if not tmux:
    print("SKIP opencode theme fallback: tmux is not installed")
    raise SystemExit(0)


def probe(malformed):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        home = root / "home"
        config = home / ".config/opencode"
        themes = config / "themes"
        project = root / "project"
        themes.mkdir(parents=True)
        project.mkdir()
        (config / "tui.json").write_text('{"theme":"noctalia"}\n')
        theme = themes / "noctalia.json"
        if malformed:
            theme.write_text('{ broken\n')
        else:
            theme.symlink_to(root / "missing-theme.json")

        socket = "opencode-theme-test-" + uuid.uuid4().hex
        isolated = {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_STATE_HOME": str(home / ".local/state"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "TERM": "tmux-256color",
        }
        command = shlex.join(
            ["env", *(f"{key}={value}" for key, value in isolated.items()),
             binary, "--pure", str(project)])
        subprocess.run(
            [tmux, "-L", socket, "new-session", "-d", "-x", "100",
             "-y", "30", command], check=True, timeout=3,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 8
            capture = ""
            while time.monotonic() < deadline:
                result = subprocess.run(
                    [tmux, "-L", socket, "capture-pane", "-p", "-e"],
                    text=True, timeout=2, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE)
                capture = result.stdout
                if ("Ask anything" in capture
                        and "\x1b[48;2;10;10;10m" in capture):
                    break
                time.sleep(0.2)
            assert ("Ask anything" in capture
                    and "\x1b[48;2;10;10;10m" in capture), (
                f"OpenCode did not render built-in fallback for "
                f"{'malformed' if malformed else 'dangling'} theme: {capture!r}")
        finally:
            subprocess.run(
                [tmux, "-L", socket, "kill-server"], check=False, timeout=2,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


probe(malformed=False)
probe(malformed=True)
print("OK opencode theme fallback")
