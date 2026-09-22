"""The scratchpad buffer convention: first line title, last-line #tags, body between."""
import json
from pathlib import Path
import subprocess

import pytest


SCRIPT = Path(__file__).resolve().parents[2] / "niri" / "scripts" / "mindful-scratch-op"


def op(text):
    proc = subprocess.run([str(SCRIPT)], input=text, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_title_tags_and_body_come_apart():
    assert op("A title\n\nfirst line\nsecond line\n\n#foo #x-y #z\n") == {
        "kind": "capture", "title": "A title", "body": "first line\nsecond line",
        "tags": ["scratch", "foo", "x-y", "z"],
    }


def test_a_single_line_is_a_title_alone():
    assert op("Just a title\n") == {"kind": "capture", "title": "Just a title", "body": "",
                                     "tags": ["scratch"]}


def test_a_last_line_with_words_among_the_tags_is_body():
    assert op("T\nbody\nsee #foo later\n") == {
        "kind": "capture", "title": "T", "body": "body\nsee #foo later", "tags": ["scratch"],
    }


def test_tags_on_the_title_line_are_tags_and_the_title_is_the_rest():
    # A two-line buffer: title, then the tag line.
    assert op("T\n#a #b\n") == {"kind": "capture", "title": "T", "body": "", "tags": ["scratch", "a", "b"]}


def test_blank_lines_around_the_buffer_and_a_long_first_line_are_handled():
    long = "x" * 100
    result = op(f"\n\n  {long}  \n\nbody\n\n\n")
    assert result["title"] == long[:80]
    assert result["body"] == "body"


def test_the_scratch_tag_is_not_doubled_and_tags_keep_their_order():
    assert op("T\n#scratch #b #a\n")["tags"] == ["scratch", "b", "a"]


def test_a_blank_buffer_is_refused():
    proc = subprocess.run([str(SCRIPT)], input=" \n\t\n", capture_output=True, text=True)
    assert proc.returncode == 2
    assert proc.stdout == ""
