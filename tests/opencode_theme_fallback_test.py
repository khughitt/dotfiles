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


def wait_gone(pid, seconds=5.0):
    """Block until pid has exited (gone or zombie): it can no longer write.

    kill-server only signals the pane process and returns immediately;
    opencode then runs its exit writes (db, log) into the temp HOME for
    ~0.5s. Without this wait, TemporaryDirectory's rmtree at context exit
    races that live writer and fails with Errno 39 (Directory not empty)
    under suite load. On timeout the wait gives up and rmtree surfaces
    whatever is still being written.
    """
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            stat = Path(f"/proc/{pid}/stat").read_text()
        except FileNotFoundError:
            return True
        # state char is the first field after the comm paren; a zombie has
        # already exited, it just has not been reaped yet
        if stat[stat.rindex(")") + 2:].split()[0] == "Z":
            return True
        time.sleep(0.02)
    return False


def probe(malformed):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        home = root / "home"
        config = home / ".config/opencode"
        themes = config / "themes"
        project = root / "project"
        themes.mkdir(parents=True)
        project.mkdir()
        (config / "cli.json").write_text('{"theme":{"name":"noctalia"}}\n')
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
        # --standalone keeps the probe off the shared background service
        # (opencode 2.x); stderr goes to a file so an exit before the first
        # frame is reported instead of an empty capture.
        stderr_path = root / "stderr.txt"
        command = shlex.join(
            ["env", *(f"{key}={value}" for key, value in isolated.items()),
             binary, "--standalone", str(project)]
        ) + f" 2>{shlex.quote(str(stderr_path))}"
        subprocess.run(
            [tmux, "-L", socket, "new-session", "-d", "-x", "100",
             "-y", "30", command], check=True, timeout=3,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        # capture the pane process's pid while the server still answers;
        # kill-server below only signals it, and the wait needs its pid
        listed = subprocess.run(
            [tmux, "-L", socket, "list-panes", "-a", "-F", "#{pane_pid}"],
            text=True, timeout=2, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL).stdout.strip()
        pane_pid = int(listed.splitlines()[0]) if listed else None
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
            stderr = stderr_path.read_text() if stderr_path.exists() else ""
            assert ("Ask anything" in capture
                    and "\x1b[48;2;10;10;10m" in capture), (
                f"OpenCode did not render built-in fallback for "
                f"{'malformed' if malformed else 'dangling'} theme: "
                f"{capture!r}\nstderr: {stderr[:500]!r}")
        finally:
            subprocess.run(
                [tmux, "-L", socket, "kill-server"], check=False, timeout=2,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # kill-server signals the pane but returns before the process
            # finishes its exit writes into the temp tree; wait it out or
            # the TemporaryDirectory cleanup below races a live writer
            if pane_pid:
                wait_gone(pane_pid)


probe(malformed=False)
probe(malformed=True)
print("OK opencode theme fallback")
