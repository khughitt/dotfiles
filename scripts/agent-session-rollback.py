#!/usr/bin/env python3
"""Restore the applied steps of a reviewed agent-slice activation packet."""

import argparse
import hashlib
import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

UNIT = "agents.slice"
COMMAND_TIMEOUT = 45
GIT_CONTEXT = {
    "GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_NAMESPACE",
    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_QUARANTINE_PATH",
    "GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_bytes())


def atomic_bytes(path, data, mode):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(data)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
            os.fsync(stream.fileno())
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def file_state(path):
    try:
        entry = path.lstat()
    except FileNotFoundError:
        return {"kind": "missing"}
    if stat.S_ISLNK(entry.st_mode):
        return {"kind": "link", "target": os.readlink(path)}
    if stat.S_ISREG(entry.st_mode):
        return {"kind": "file", "mode": stat.S_IMODE(entry.st_mode),
                "sha256": digest(path.read_bytes())}
    raise RuntimeError(f"unsupported file type at {path}")


def expect_file(row, key):
    path = Path(row["path"])
    locator = Path(row["locator"])
    if locator.parent.resolve() / locator.name != path:
        raise RuntimeError(f"path drift at {locator}")
    expected = {name: value for name, value in row[key].items() if name != "copy"}
    if file_state(path) != expected:
        raise RuntimeError(f"file drift at {path}, expected {key} state")


def image(root, snapshot):
    if snapshot["kind"] != "file":
        return None
    path = (root / snapshot["copy"]).resolve(strict=True)
    if not path.is_relative_to(root):
        raise RuntimeError(f"snapshot escapes the packet directory: {path}")
    data = path.read_bytes()
    if digest(data) != snapshot["sha256"]:
        raise RuntimeError(f"snapshot hash mismatch: {path}")
    return data


def write_state(path, snapshot, data):
    kind = snapshot["kind"]
    if kind == "missing":
        path.unlink(missing_ok=True)
    elif kind == "link":
        with tempfile.TemporaryDirectory(dir=path.parent) as directory:
            temporary = Path(directory) / "link"
            temporary.symlink_to(snapshot["target"])
            temporary.replace(path)
    elif kind == "file":
        atomic_bytes(path, data, snapshot["mode"])
    else:
        raise RuntimeError(f"unknown file state {kind}")


def command(*argv):
    interrupted = False

    def stop(_signal, _frame):
        nonlocal interrupted
        interrupted = True

    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        process = subprocess.Popen(argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        completed = False
        try:
            deadline = time.monotonic() + COMMAND_TIMEOUT
            while not interrupted and (remaining := deadline - time.monotonic()) > 0:
                try:
                    stdout, stderr = process.communicate(timeout=min(0.25, remaining))
                except subprocess.TimeoutExpired:
                    continue
                if interrupted:
                    break
                if process.returncode:
                    raise RuntimeError(f"{argv[0]} exited {process.returncode}: {stderr.strip()}")
                completed = True
                return stdout.strip()
            why = "interrupted" if interrupted else "timed out"
            raise RuntimeError(f"{argv[0]} {why}; inspect the applied-step receipt")
        finally:
            if not completed:
                # A child of a hook can hold the process group after Git exits.
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.communicate(timeout=1)
                except subprocess.TimeoutExpired:
                    pass
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=2)
            process.stdout.close()
            process.stderr.close()
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def check_git_environment():
    overrides = sorted(GIT_CONTEXT.intersection(os.environ))
    if overrides:
        raise RuntimeError("unset Git context overrides: " + ", ".join(overrides))


def git(repo, *argv):
    check_git_environment()
    return command("git", "-C", repo["path"], *argv)


def expect_repo(repo, head, content):
    if (git(repo, "rev-parse", "--show-toplevel") != repo["path"]
            or Path(git(repo, "rev-parse", "--absolute-git-dir")).resolve()
            != (Path(repo["path"]) / ".git").resolve()
            or git(repo, "branch", "--show-current") != repo["branch"]
            or git(repo, "rev-parse", "HEAD") != head
            or git(repo, "rev-parse", "HEAD^{tree}") != git(repo, "rev-parse", content + "^{tree}")
            or git(repo, "status", "--porcelain", "--", *repo["paths"])
            or git(repo, "diff", "--cached", "--name-only")):
        raise RuntimeError(f"repository drift at {repo['path']}")


def runtime_state(keys):
    output = command("systemctl", "--user", "show", UNIT, *(f"--property={key}" for key in keys))
    fields = dict(line.split("=", 1) for line in output.splitlines() if "=" in line)
    return {key: fields[key] for key in keys}


def save_receipt(path, receipt):
    atomic_bytes(path, (json.dumps(receipt, indent=2) + "\n").encode(), 0o600)


def rollback(packet_path):
    check_git_environment()
    root = packet_path.parent
    receipt_path = root / "activation-receipt.json"
    packet, receipt = read_json(packet_path), read_json(receipt_path)
    if (packet["version"] != 1 or receipt["version"] != 1
            or packet["host"] != os.uname().nodename
            or receipt["packet_sha256"] != digest(packet_path.read_bytes())):
        raise RuntimeError("receipt does not belong to this packet and host")
    files = {row["key"]: row for row in packet["files"]}
    repos = {repo["key"]: repo for repo in packet["repositories"]}
    restored = receipt["restored"]
    if (set(receipt["files"]) - files.keys() or receipt["repositories"].keys() - repos.keys()
            or set(restored["files"]) - set(receipt["files"])
            or restored["repositories"].keys() - receipt["repositories"].keys()
            or (restored["runtime"] and not receipt["runtime"])):
        raise RuntimeError("receipt names unknown or unapplied steps")

    # Validate every state and every original image before changing any target.
    originals = {}
    for key, row in files.items():
        pending = key in receipt["files"] and key not in restored["files"]
        expect_file(row, "after" if pending else "before")
        if pending:
            originals[key] = image(root, row["before"])
    for key, repo in repos.items():
        applied = receipt["repositories"].get(key)
        reverted = restored["repositories"].get(key)
        expect_repo(repo, reverted or applied or repo["base"],
                    repo["candidate"] if applied and not reverted else repo["base"])
        if applied and not reverted:
            parents = git(repo, "rev-list", "--parents", "-n", "1", applied).split()[1:]
            if not 1 <= len(parents) <= 2 or (
                git(repo, "rev-parse", parents[0] + "^{tree}")
                != git(repo, "rev-parse", repo["base"] + "^{tree}")
            ):
                raise RuntimeError(f"unproven activation revision for {key}")
    runtime = packet["runtime"]
    pending_runtime = receipt["runtime"] and not restored["runtime"]
    expected = runtime["after" if pending_runtime else "restored" if restored["runtime"] else "before"]
    if runtime_state(expected) != expected:
        raise RuntimeError(f"runtime drift for {UNIT}")

    for key in reversed(receipt["files"]):
        if key == "unit" or key not in originals:
            continue
        row = files[key]
        expect_file(row, "after")
        write_state(Path(row["path"]), row["before"], originals[key])
        expect_file(row, "before")
        restored["files"].append(key)
        save_receipt(receipt_path, receipt)
    for key, applied in reversed(list(receipt["repositories"].items())):
        if key in restored["repositories"]:
            continue
        repo = repos[key]
        expect_repo(repo, applied, repo["candidate"])
        parents = git(repo, "rev-list", "--parents", "-n", "1", applied).split()[1:]
        git(repo, "revert", "--no-edit", *(["-m", "1"] if len(parents) == 2 else []), applied)
        head = git(repo, "rev-parse", "HEAD")
        expect_repo(repo, head, repo["base"])
        restored["repositories"][key] = head
        save_receipt(receipt_path, receipt)
    if pending_runtime:
        command("systemctl", "--user", "set-property", "--runtime", UNIT, "CPUQuota=", "CPUWeight=100")
        if runtime_state(runtime["restored"]) != runtime["restored"]:
            raise RuntimeError(f"runtime restore did not take effect for {UNIT}")
        restored["runtime"] = True
        save_receipt(receipt_path, receipt)
    if "unit" in originals:
        row = files["unit"]
        expect_file(row, "after")
        write_state(Path(row["path"]), row["before"], originals["unit"])
        command("systemctl", "--user", "daemon-reload")
        expect_file(row, "before")
        restored["files"].append("unit")
        save_receipt(receipt_path, receipt)
    if restored["runtime"] and runtime_state(runtime["restored"]) != runtime["restored"]:
        raise RuntimeError(f"runtime restore changed after reload for {UNIT}")
    print(json.dumps({"verdict": "restored", "slice_left_to_drain": restored["runtime"]}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, required=True)
    args = parser.parse_args()
    try:
        rollback(args.packet.resolve(strict=True))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"agent-session-rollback: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
