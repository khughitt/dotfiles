import runpy
from pathlib import Path

import pytest

# Load the filter the way kitty does: runpy on the file, then look up filter_paste.
SCRIPT = Path(__file__).resolve().parents[2] / "kitty" / "paste-actions.py"
filter_paste = runpy.run_path(str(SCRIPT))["filter_paste"]


@pytest.fixture
def report(tmp_path):
    path = tmp_path / "report.md"
    path.write_text("")
    return path


@pytest.mark.parametrize("trail", [".", ",", ";", ":", ".."])
def test_trims_trailing_punctuation_when_only_trimmed_path_exists(report, trail):
    assert filter_paste(f"{report}{trail}") == str(report)


def test_trims_surrounding_whitespace_with_the_punctuation(report):
    assert filter_paste(f"  {report}.\n") == str(report)


@pytest.mark.usefixtures("report")
def test_trims_tilde_path_and_keeps_tilde(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    assert filter_paste("~/report.md.") == "~/report.md"


def test_keeps_path_that_exists_with_its_trailing_period(tmp_path):
    dotted = tmp_path / "odd."
    dotted.write_text("")
    (tmp_path / "odd").write_text("")
    assert filter_paste(f"{dotted}") == str(dotted)


def test_keeps_text_when_trimmed_path_does_not_exist(tmp_path):
    text = f"{tmp_path}/missing.md."
    assert filter_paste(text) == text


@pytest.mark.parametrize(
    "text",
    [
        "report.md.",  # relative: kitty cannot see the shell's working directory
        "see {report}.",  # more than one word
        "{report}.\n{report}.",  # more than one line
        "{report}",  # nothing to trim
        "",
    ],
)
def test_leaves_other_pastes_untouched(report, text):
    text = text.format(report=report)
    assert filter_paste(text) == text
