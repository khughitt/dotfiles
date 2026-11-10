#!/usr/bin/env python3
"""Measure the shared titan CPU ceiling with bounded synthetic worker pools."""

import argparse
import errno
import json
import os
import pty
import select
import signal
import subprocess
import sys
import time
import tomllib
from pathlib import Path

CGROUP = Path("/sys/fs/cgroup")
SLICE = "agents.slice"
TERMINAL_TOKEN = "agent-scope-terminal"


def assess_sample(before, after, *, elapsed, quota, period):
    usage = after["usage_usec"] - before["usage_usec"]
    throttles = after["nr_throttled"] - before["nr_throttled"]
    ceiling = quota / period * elapsed * 1_000_000
    if usage > ceiling + 2 * quota:
        verdict = "over-quota"
    elif usage < 0.9 * ceiling or throttles <= 0:
        verdict = "unqualified"
    else:
        verdict = "pass"
    return {"verdict": verdict, "elapsed_seconds": elapsed, "cpu_seconds": usage / 1_000_000,
            "throttles": throttles, "quota_usec": quota, "period_usec": period}


def cgroup_of(pid):
    for line in Path(f"/proc/{pid}/cgroup").read_text().splitlines():
        if line.startswith("0::/"):
            return CGROUP / line[4:]
    raise RuntimeError(f"pid {pid} has no cgroup v2 membership")


def check_scope(slice_dir, scope, nice):
    if scope.parent != slice_dir or scope.suffix != ".scope":
        raise RuntimeError(f"expected a direct scope under {slice_dir}, got {scope}")
    if nice != 10 or (scope / "cpu.weight").read_text().strip() != "100":
        raise RuntimeError(f"{scope} needs nice 10 and CPUWeight=100")


def terminal_round_trip(argv, env, cwd, timeout=10):
    """Run one scoped launch as a foreground job on a headless controlling PTY."""
    stopping = False

    def stop(_signal, _frame):
        nonlocal stopping
        stopping = True

    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGINT, signal.SIGTERM)}
    pid = None
    master = None
    reaped = False
    passed = False
    try:
        pid, master = pty.fork()
        if pid == 0:
            try:
                os.chdir(cwd)
                os.execvpe(argv[0], argv, env)
            except OSError as error:
                os.write(2, f"{error}\n".encode())
                os._exit(127)
        output = bytearray()
        os.write(master, (TERMINAL_TOKEN + "\n").encode())
        deadline = time.monotonic() + timeout
        eof = False
        while not stopping and time.monotonic() < deadline:
            if not eof and select.select([master], [], [], 0.1)[0]:
                try:
                    block = os.read(master, 4096)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    block = b""
                output.extend(block)
                eof = not block
                if len(output) > 8192:
                    raise RuntimeError("terminal proof exceeded its output bound")
            if not reaped:
                done, status = os.waitpid(pid, os.WNOHANG)
                reaped = bool(done)
            if reaped and eof:
                reports = [line for line in output.splitlines() if line.startswith(b"{")]
                report = json.loads(reports[-1]) if reports else {}
                if (os.waitstatus_to_exitcode(status) != 7 or report.get("tty") != [True] * 3
                        or report.get("foreground") is not True or report.get("token") != TERMINAL_TOKEN):
                    raise RuntimeError("terminal proof lost descriptors, foreground access, input or exit status")
                passed = True
                return report
            if eof:
                time.sleep(0.01)
        raise RuntimeError("terminal proof interrupted or timed out")
    finally:
        try:
            if pid and not passed:
                try:
                    os.killpg(pid, signal.SIGKILL)
                except ProcessLookupError:
                    # forkpty's child may not yet have created its process group.
                    if not reaped:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                if not reaped:
                    os.waitpid(pid, 0)
            if master is not None:
                os.close(master)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


def cpu_stat(slice_dir):
    return {key: int(value) for key, value in
            (line.split() for line in (slice_dir / "cpu.stat").read_text().splitlines())}


def cleanup(children, grace=2):
    for child in children:
        child.stdin.close()
    for child in children:
        try:
            status = child.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            status = None
        if status is None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                status = child.wait(timeout=grace)
            except subprocess.TimeoutExpired:
                pass
        if status != 0:
            # A failed launcher can leave workers in its process group.
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait(timeout=grace)
        child.stdout.close()


def interrupted(_signal, _frame):
    raise InterruptedError("synthetic workload interrupted")


def worker_pool(kind):
    scope = cgroup_of(os.getpid())
    if scope.parent.name != SLICE:
        raise RuntimeError("worker pool requires a direct agents.slice scope")
    check_scope(scope.parent, scope, os.nice(0))
    if kind == "unbudgeted" and ("OPS_BUDGET" in os.environ or "OPS_WORKERS" in os.environ):
        raise RuntimeError("session unexpectedly received a compute grant")
    grant = int(os.environ["OPS_BUDGET"]) if kind == "budgeted" else None
    count = grant if grant is not None else 40
    if not 1 <= count <= 40:
        raise RuntimeError("invalid worker count")
    children = []
    # The deadline also cleans up if the supervising process disappears.
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGALRM, interrupted)
    signal.alarm(45)
    try:
        signals = {signal.SIGTERM, signal.SIGINT, signal.SIGALRM}
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, signals)
        try:
            for _ in range(count):
                pid = os.fork()
                if pid == 0:
                    signal.signal(signal.SIGTERM, signal.SIG_DFL)
                    signal.signal(signal.SIGINT, signal.SIG_DFL)
                    signal.pthread_sigmask(signal.SIG_SETMASK, mask)
                    while True:
                        pass
                children.append(pid)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        print(json.dumps({"pid": os.getpid(), "scope": str(scope), "nice": os.nice(0),
                          "grant": grant, "workers": children}), flush=True)
        sys.stdin.buffer.read(1)
    finally:
        signal.alarm(0)
        for pid in children:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for pid in children:
            os.waitpid(pid, 0)


def worker_reading(child, deadline, stopped):
    pending = bytearray()
    while b"\n" not in pending:
        if stopped() or time.monotonic() >= deadline:
            raise RuntimeError("worker readiness interrupted or timed out")
        if not select.select([child.stdout], [], [], 0.1)[0]:
            continue
        chunk = os.read(child.stdout.fileno(), 4096)
        if not chunk or len(pending) + len(chunk) > 8192:
            raise RuntimeError("worker ended without a readiness report")
        pending.extend(chunk)
    line = pending.split(b"\n", 1)[0]
    try:
        return json.loads(line)
    except ValueError:
        raise RuntimeError(f"worker failed readiness: {line.decode(errors='replace')}") from None


def smoke(policy, host_budget, duration):
    scope = tomllib.loads(policy.read_text())["scope"]
    if scope["slice"] != SLICE or scope["nice"] != 10 or scope.get("require_quota") is not True:
        raise RuntimeError("expected the approved capped policy")
    uid = os.getuid()
    slice_dir = CGROUP / f"user.slice/user-{uid}.slice/user@{uid}.service" / SLICE
    if cgroup_of(os.getpid()).is_relative_to(slice_dir):
        raise RuntimeError("run the verifier from an ordinary shell outside agents.slice")
    quota, period = map(int, (slice_dir / "cpu.max").read_text().split())
    if period <= 0 or quota != 24 * period or (slice_dir / "cpu.weight").read_text().strip() != "30":
        raise RuntimeError("expected 24 CPU equivalents and CPUWeight=30")
    env = {name: os.environ[name] for name in (
        "PATH", "HOME", "USER", "LANG", "XDG_CONFIG_HOME", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS"
    ) if name in os.environ}
    children, readings = [], []
    stopping = False

    def request_stop(_signal, _frame):
        nonlocal stopping
        stopping = True

    previous = {sig: signal.signal(sig, request_stop) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        deadline = time.monotonic() + 10
        for verb, kind in (("session", "unbudgeted"), ("run", "budgeted")):
            if stopping:
                raise InterruptedError("synthetic workload interrupted")
            child = subprocess.Popen(
                [str(host_budget), verb, "--policy", str(policy), "--",
                 sys.executable, str(Path(__file__).resolve()), "--pool", kind],
                env=env, start_new_session=True, stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            children.append(child)
        for child in children:
            reading = worker_reading(child, deadline, lambda: stopping)
            actual_scope = cgroup_of(reading["pid"])
            if str(actual_scope) != reading["scope"]:
                raise RuntimeError("worker cgroup changed before measurement")
            check_scope(slice_dir, actual_scope, os.getpriority(os.PRIO_PROCESS, reading["pid"]))
            readings.append(reading)
        if len({row["scope"] for row in readings}) != 2:
            raise RuntimeError("expected two sibling scopes")
        start = time.monotonic()
        before = cpu_stat(slice_dir)
        end = start + duration
        while time.monotonic() < end:
            if stopping:
                raise InterruptedError("synthetic workload interrupted")
            time.sleep(min(0.1, max(0, end - time.monotonic())))
        after = cpu_stat(slice_dir)
        result = assess_sample(before, after, elapsed=time.monotonic() - start,
                               quota=quota, period=period)
    finally:
        try:
            cleanup(children)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
    result["pools"] = readings
    result["statuses"] = [child.returncode for child in children]
    if stopping or any(result["statuses"]):
        result["verdict"] = "worker-failed"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--host-budget", type=Path)
    parser.add_argument("--duration", type=int, choices=(2, 30))
    parser.add_argument("--pool", choices=("budgeted", "unbudgeted"), help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.pool:
            worker_pool(args.pool)
            return 0
        if args.policy is None or args.host_budget is None or args.duration is None:
            parser.error("--policy, --host-budget and --duration are required")
        result = smoke(args.policy.resolve(strict=True), args.host_budget.resolve(strict=True), args.duration)
        print(json.dumps(result))
        return 0 if result["verdict"] == "pass" else 1
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"verdict": "failed", "error": str(error)}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
