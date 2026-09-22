import json
import os
from pathlib import Path
import subprocess

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "mindful-scratch"

# One buffer per nvim launch, scripted by a queue file: each line is what that launch
# writes to the buffer (`-` writes nothing, as :q! would; `!` exits 1, as :cq would).
FAKE_NVIM = """#!/usr/bin/env bash
buf=${@: -1}
step=$(head -n1 "$NVIM_FAKE_QUEUE"); sed -i 1d "$NVIM_FAKE_QUEUE"
printf '%s\\n' "$*" >> "$NVIM_FAKE_LOG"
case "$step" in
    '!') exit 1 ;;
    '-') ;;
    *) printf '%b' "$step" > "$buf" ;;
esac
"""

# Records what it was asked and what it read; fails when told to.
FAKE_MINDFUL_OP = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$OP_FAKE_LOG"
cat >> "$OP_FAKE_STDIN"
if [[ -n ${OP_FAKE_FAIL:-} ]]; then
    echo '{"error":{"type":"transport","message":"connection refused"}}' >&2
    exit 1
fi
echo '{"result":{"id":"thought:new"}}'
"""

FAKE_DROPDOWN = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$DROPDOWN_FAKE_LOG"
"""

FAKE_NOTIFY = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$NOTIFY_FAKE_LOG"
"""


@pytest.fixture
def run(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name, body in (("nvim", FAKE_NVIM), ("mindful-op", FAKE_MINDFUL_OP),
                       ("notify-send", FAKE_NOTIFY)):
        fake = bin_dir / name
        fake.write_text(body)
        fake.chmod(0o755)
    # The hide goes through the sibling dropdown script; a fake stands in for it.
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    (scripts / "mindful-scratch").symlink_to(SCRIPT)
    (scripts / "mindful-scratch-op").symlink_to(SCRIPT.with_name("mindful-scratch-op"))
    dropdown = scripts / "dropdown"
    dropdown.write_text(FAKE_DROPDOWN)
    dropdown.chmod(0o755)
    queue = tmp_path / "queue"
    logs = {name: tmp_path / f"{name}.log"
            for name in ("nvim", "op", "op_stdin", "dropdown", "notify")}
    state = tmp_path / "state"

    def _run(*steps, fail=False):
        if not SCRIPT.exists():
            pytest.fail(f"scratch script is missing: {SCRIPT}")
        queue.write_text("".join(f"{step}\n" for step in steps))
        env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "NVIM_FAKE_QUEUE": str(queue), "NVIM_FAKE_LOG": str(logs["nvim"]),
            "OP_FAKE_LOG": str(logs["op"]), "OP_FAKE_STDIN": str(logs["op_stdin"]),
            "DROPDOWN_FAKE_LOG": str(logs["dropdown"]), "NOTIFY_FAKE_LOG": str(logs["notify"]),
            "MINDFUL_OP": str(bin_dir / "mindful-op"),
            "XDG_STATE_HOME": str(state),
        }
        if fail:
            env["OP_FAKE_FAIL"] = "1"
        proc = subprocess.run([str(scripts / "mindful-scratch")], env=env,
                              capture_output=True, text=True, timeout=10)
        read = {name: (log.read_text().splitlines() if log.exists() else [])
                for name, log in logs.items()}
        return proc, read, state / "mindful-scratch"

    return _run


def test_a_written_buffer_is_posted_as_the_human_then_the_surface_hides(run):
    proc, logs, spool = run("Scratch title\\n\\nbody\\n", "!")

    assert proc.returncode == 1
    assert len(logs["nvim"]) == 2
    assert logs["op"] == ["--self"]
    assert json.loads(logs["op_stdin"][0]) == {"kind": "capture", "title": "Scratch title",
                                               "body": "body", "tags": ["scratch"]}
    assert logs["dropdown"] == ["mindful"]
    assert logs["notify"] == []
    # A posted buffer leaves nothing behind.
    assert sorted(spool.glob("*.md")) == []


def test_nvim_opens_a_fresh_markdown_buffer_in_insert_mode_each_time(run):
    _, logs, spool = run("one\\n", "two\\n", "!")

    buffers = [line.split()[-1] for line in logs["nvim"]]
    assert len(set(buffers)) == 3
    assert all(b.startswith(str(spool)) and b.endswith(".md") for b in buffers)
    assert all("+startinsert" in line for line in logs["nvim"])
    assert [json.loads(line)["title"] for line in logs["op_stdin"]] == ["one", "two"]


def test_quitting_without_writing_posts_nothing_and_still_hides(run):
    _, logs, spool = run("-", "!")

    assert logs["op"] == []
    assert logs["dropdown"] == ["mindful"]
    assert sorted(spool.glob("*.md")) == []


def test_a_blank_buffer_is_not_a_thought(run):
    _, logs, spool = run(" \\n\\t\\n", "!")

    assert logs["op"] == []
    assert sorted(spool.glob("*.md")) == []


def test_a_failed_post_keeps_the_buffer_notifies_and_reopens_it_next(run):
    _, logs, spool = run("kept\\n", "!", fail=True)

    assert logs["op"] == ["--self"]
    kept = sorted(spool.glob("*.md"))
    assert len(kept) == 1 and kept[0].read_text() == "kept\n"
    # The next toggle opens the kept buffer, not a fresh one, so a bad tag is fixed in place.
    buffers = [line.split()[-1] for line in logs["nvim"]]
    assert buffers == [str(kept[0]), str(kept[0])]
    notice = "\n".join(logs["notify"])
    assert notice.startswith("--urgency=critical mindful scratch: capture failed")
    assert str(kept[0]) in notice
    assert "connection refused" in notice


def test_missing_mindful_op_fails_before_opening_an_editor(run, tmp_path):
    env_missing = tmp_path / "nope"
    proc = subprocess.run([str(SCRIPT)], env={**os.environ, "MINDFUL_OP": str(env_missing),
                                              "NVIM_FAKE_LOG": str(tmp_path / "n.log")},
                          capture_output=True, text=True, timeout=10)

    assert proc.returncode == 2
    assert "mindful-op" in proc.stderr
    assert not (tmp_path / "n.log").exists()
