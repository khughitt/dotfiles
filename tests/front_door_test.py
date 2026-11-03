"""Exercise the real front doors; replace only expensive leaf commands."""

import json
import shlex
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


ROOT = Path(__file__).resolve().parents[1]
OFF = 'automatic_broad = false\nbroad_targets = ["test", "check-code"]\n'
ON = OFF.replace("false", "true")
LUA = ["plugin_test.lua", "service_test.lua", "layer_test.lua"]
ZSH = [
    "task_json_search", "dropbox_ignore_flux", "work_link", "history",
    "icat_completion", "glow_completion", "secrets_check", "setup_and_health",
    "dotfiles_check", "layout_check", "justfile", "console_keymap",
]

EMIT = '''import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "tasks" and args[:1] == ["where"]:
    print('{"project": null}')
    sys.exit(0)
if name == "ssh":
    print("serveraliveinterval 60")
    sys.exit(0)
if name == "emit.py":
    name = args.pop(0)
if name == "tasks":
    name = "records"
with open(os.environ["EVENTS"], "a") as out:
    out.write(json.dumps({"name": name, "argv": args, "stdin": sys.stdin.read(),
                          "parent_secret": os.environ.get("PARENT_SECRET"), "home": os.environ.get("HOME")}) + "\\n")
if name == "uv":
    for arg in args:
        if arg.startswith("--junitxml="):
            pathlib.Path(arg.split("=", 1)[1]).write_text(
                '<testsuites><testsuite tests="2"><testcase name="a"/>'
                '<testcase name="b"/></testsuite></testsuites>')
if name == os.environ.get("FAIL_PHASE"):
    sys.exit(int(os.environ["FAIL_STATUS"]))
'''


class Door:
    def __init__(self, tmp_path):
        self.root = tmp_path / "repo"
        self.root.mkdir()
        self.events_path = tmp_path / "events.jsonl"
        self.log = tmp_path / "runs.jsonl"
        bindir = tmp_path / "bin"
        bindir.mkdir()
        home = tmp_path / "home"
        home.mkdir()
        self.env = {
            "PATH": f"{bindir}:/usr/bin:/bin",
            "HOME": str(home), "USER": "front-door-fixture", "TERM": "dumb",
            "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_DATA_HOME": str(home / "data"),
            "XDG_CACHE_HOME": str(home / "cache"),
            "XDG_STATE_HOME": str(home / "state"),
            "GIT_CONFIG_GLOBAL": str(home / "gitconfig"), "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "TT_LOG": str(self.log), "EVENTS": str(self.events_path),
            "TT_JUNIT_DIR": str(tmp_path / "junit"),
            "EVIDENCE_DIR": str(tmp_path / "evidence"),
        }
        for key in ["TT_JUNIT_DIR", "EVIDENCE_DIR"]:
            Path(self.env[key]).mkdir()
        self.run(["git", "init", "-q"]).check_returncode()
        assert Path(self.run(["git", "rev-parse", "--show-toplevel"]).stdout.strip()) == self.root
        assert Path(self.run(["git", "rev-parse", "--absolute-git-dir"]).stdout.strip()) == self.root / ".git"
        for name in ["justfile", "bin/dotfiles-check", "bin/mindful", "bin/prism",
                     "tests/dotfiles_check.zsh", "tests/justfile.zsh", "tests/tmp_cleanup.zsh", "tools/tt", "tools/test-one",
                     "tools/test-suite.py", ".githooks/pre-commit", ".githooks/pre-push"]:
            source = ROOT / name
            if source.exists():
                dest = self.root / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, dest)
        (self.root / "tools").mkdir(exist_ok=True)
        (self.root / "tools/emit.py").write_text(EMIT)
        for name in ["uv", "zsh", "lua", "nvim", "tasks", "ssh"]:
            p = bindir / name
            p.write_text(f"#!{sys.executable}\n" + EMIT)
            p.chmod(0o755)
        p = self.root / "tools/check-hygiene"
        p.write_text(f"#!{sys.executable}\n" + EMIT.replace('name = pathlib.Path(sys.argv[0]).name', 'name = "source"'))
        p.chmod(0o755)
        # Every nested Just invocation receives the same leaf overrides.
        just = shutil.which("just")
        assert just
        p = bindir / "just"
        p.write_text(f'''#!/bin/sh
exec {just} --set check_hygiene_cmd 'python3 tools/emit.py hygiene' \\
  --set check_code_cmd 'python3 tools/emit.py code' \\
  --set test_cmd 'python3 tools/emit.py test' \\
  --set resource_alert_cmd 'python3 tools/emit.py resource' \\
  --set ci_suite_refs "${{COVERAGE:-}}" "$@"
''')
        p.chmod(0o755)

    def run(self, argv, stdin=""):
        return subprocess.run(argv, cwd=self.root, env=self.env, input=stdin,
                              capture_output=True, text=True, timeout=20)

    def invoke(self, recipe, args=(), policy=None, force=None, fail_phase=None, fail_status=0):
        if policy is not None:
            (self.root / ".tt.toml").write_text(policy)
        if force is not None:
            self.env["TT_FORCE"] = force
        if fail_phase:
            self.env.update(FAIL_PHASE=fail_phase, FAIL_STATUS=str(fail_status))
        return self.run(["just", recipe, *args])

    def events(self):
        return [json.loads(s) for s in self.events_path.read_text().splitlines()] if self.events_path.exists() else []

    def rows(self):
        return [json.loads(s) for s in self.log.read_text().splitlines()] if self.log.exists() else []

    def script(self, mode="full", *args, fail_phase=None, fail_status=0):
        if fail_phase:
            self.env.update(FAIL_PHASE=fail_phase, FAIL_STATUS=str(fail_status))
        return self.run([sys.executable, "tools/test-suite.py", mode, *args])


@pytest.fixture
def door(tmp_path, monkeypatch):
    monkeypatch.setenv("PARENT_SECRET", "credential-must-not-reach-child")
    monkeypatch.setenv("GIT_DIR", str(tmp_path / "forbidden-git"))
    monkeypatch.setenv("GIT_INDEX_FILE", str(tmp_path / "forbidden-index"))
    return Door(tmp_path)


@pytest.mark.parametrize("runner,prefix", [("pytest", ["run", "--frozen", "pytest"]),
                                         ("zsh", []), ("lua", []), ("nvim", [])])
def test_focused_argv_and_exit(door, runner, prefix):
    args = ["two words", "'quoted'", "$(literal)", "*"]
    leaf = "uv" if runner == "pytest" else runner
    p = door.invoke("test-one", [runner, *args], policy=OFF, fail_phase=leaf, fail_status=17)
    assert p.returncode == 17, p.stderr
    assert door.events()[-1]["argv"] == prefix + args
    assert door.events()[-1]["parent_secret"] is None
    assert [r["target"] for r in door.rows()] == ["test-one"]
    assert door.rows()[0]["exit"] == 17
    assert "credential-must-not-reach-child" not in p.stdout + p.stderr
    assert not (door.root.parent / "forbidden-git").exists()


@pytest.mark.parametrize("policy,want", [(None, ["hygiene", "code", "test"]),
                                       (ON, ["hygiene", "code", "test"]),
                                       (OFF, ["hygiene"])])
def test_policy_off_keeps_hygiene(door, policy, want):
    p = door.invoke("gate", policy=policy)
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == want
    rows = door.rows()
    assert [r["target"] for r in rows] == ["check-hygiene", "check-code", "test"]
    if policy == OFF:
        for row in rows[1:]:
            assert row["execution"] == "skipped"
            assert row["execution_reason"] == "policy-disabled"
            assert all(row[k] is None for k in ["exit", "tests", "selection", "slowest"])


def test_mandatory_failure_stops_later_children(door):
    p = door.invoke("gate", fail_phase="hygiene", fail_status=19)
    assert p.returncode == 19, p.stderr
    assert [e["name"] for e in door.events()] == ["hygiene"]


def test_forced_failure_and_full_alias(door):
    p = door.invoke("test-full", policy=OFF, fail_phase="test", fail_status=23)
    assert p.returncode == 23, p.stderr
    assert [r["target"] for r in door.rows()] == ["test"]
    assert door.rows()[0]["execution_reason"] == "forced"


def test_hosted_refusal_before_nested_child(door):
    door.env["GITHUB_ACTIONS"] = "true"
    p = door.invoke("gate", policy=OFF)
    assert p.returncode != 0
    assert "TT_FORCE=1" in p.stderr
    assert [e["name"] for e in door.events()] == ["hygiene"]


@pytest.mark.parametrize("policy", ["automatic_broad = 0", 'unknown = true', 'automatic_broad = false\nbroad_targets=["test-one"]'])
def test_invalid_policy_never_launches_child(door, policy):
    p = door.invoke("test-one", ["zsh", "one.zsh"], policy=policy, force="1")
    assert p.returncode != 0
    assert door.events() == []


@pytest.mark.parametrize("args", [[], ["zsh"], ["unknown", "file"]])
def test_focused_requires_known_runner_and_arguments(door, args):
    p = door.invoke("test-one", args)
    assert p.returncode != 0
    assert door.events() == []


def test_component_is_focused_when_broad_is_off(door):
    p = door.invoke("test-resource-alert", policy=OFF)
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == ["resource"]
    assert len(door.rows()) == 1


@pytest.mark.parametrize("policy,force,want", [(OFF, None, ["source"]),
                                             (OFF, "1", ["source", "code"]),
                                             (None, None, ["source", "code"])])
def test_nested_source_check(door, policy, force, want):
    if policy:
        (door.root / ".tt.toml").write_text(policy)
    if force:
        door.env["TT_FORCE"] = force
    p = door.run(["bash", "bin/dotfiles-check"])
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == want
    assert all(e["name"] != "records" for e in door.events())


@pytest.mark.parametrize("remote,ref,coverage,recipe", [
    ("origin", "refs/heads/feature/x", "refs/heads/*", "hook-pre-push-fast"),
    ("other", "refs/heads/main", "refs/heads/*", "hook-pre-push"),
    ("origin", "refs/tags/v1", "refs/heads/*", "hook-pre-push"),
    ("origin", "refs/heads/main", "", "hook-pre-push"),
])
def test_hook_routes_and_stdin(door, remote, ref, coverage, recipe):
    door.env["COVERAGE"] = coverage
    payload = f"refs/heads/local {'1'*40} {ref} {'2'*40}\n"
    p = door.run(["sh", ".githooks/pre-push", remote, "git@example.invalid:repo"], payload)
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == ["hygiene", "code", "test"]
    assert door.events()[0]["stdin"] == payload
    assert [r["target"] for r in door.rows()] == [recipe, "check-code", "test"]


def test_uncovered_policy_warning(door):
    (door.root / ".tt.toml").write_text(OFF)
    p = door.run(["sh", ".githooks/pre-push", "other", "https://example.invalid/repo"], "malformed\n")
    assert p.returncode == 0, p.stderr
    assert "coverage is not declared" in p.stderr
    assert [e["name"] for e in door.events()] == ["hygiene"]


def test_precommit_conservative_for_renamed_document(door):
    (door.root / "README.md").write_text("fixture\n")
    door.run(["git", "add", "README.md"]).check_returncode()
    door.run(["git", "commit", "-qm", "test: seed fixture"]).check_returncode()
    door.run(["git", "mv", "README.md", "moved.md"]).check_returncode()
    p = door.run(["sh", ".githooks/pre-commit"])
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == ["hygiene", "code"]


def test_full_inventory_and_retained_junit(door):
    p = door.script()
    assert p.returncode == 0, p.stderr
    events = door.events()
    assert [e["argv"][0] for e in events[:3]] == [f"noctalia/plugins/resource-pressure-alert/{n}" for n in LUA]
    assert events[3]["argv"][:4] == ["run", "--frozen", "pytest", "-q"]
    assert [e["argv"] for e in events[4:]] == [[f"tests/{n}.zsh"] for n in ZSH]
    evidence = Path(door.env["EVIDENCE_DIR"])
    assert (evidence / "pytest.xml").read_text().count("testcase") == 2
    rows = [json.loads(s) for s in (evidence / "phases.jsonl").read_text().splitlines()]
    assert len(rows) == 32
    assert [r["event"] for r in rows] == ["start", "end"] * 16
    assert all(r["exit"] == 0 for r in rows if r["event"] == "end")


def test_full_phase_failure_stops_inventory(door):
    p = door.script(fail_phase="lua", fail_status=19)
    assert p.returncode == 19, p.stderr
    assert len(door.events()) == 1


@pytest.mark.parametrize("test_status,want", [(0, 1), (23, 23)])
def test_evidence_failure_preserves_test_failure(door, test_status, want):
    (Path(door.env["EVIDENCE_DIR"]) / "pytest.xml").mkdir()
    p = door.script(fail_phase="uv", fail_status=test_status)
    assert p.returncode == want, p.stderr
    assert [e["name"] for e in door.events()] == ["lua", "lua", "lua", "uv"]


def test_receipt_write_failure_prevents_child(door):
    Path(door.env["EVIDENCE_DIR"], "phases.jsonl").mkdir()
    p = door.script()
    assert p.returncode != 0
    assert door.events() == []


@pytest.mark.parametrize("payload", ["", "bad\n", "refs/heads/a " + "1"*40 + " refs/heads/a " + "2"*40 + "\n\n"])
def test_malformed_or_empty_push_keeps_full_route(door, payload):
    door.env["COVERAGE"] = "refs/heads/*"
    p = door.run(["sh", ".githooks/pre-push", "origin", "https://example.invalid/repo"], payload)
    assert p.returncode == 0, p.stderr
    assert door.rows()[0]["target"] == "hook-pre-push"
    assert door.events()[0]["stdin"] == payload


def test_component_helper_does_not_run_pytest_or_zsh(door):
    door.env.pop("TT_JUNIT_DIR")
    p = door.script("resource-alert")
    assert p.returncode == 0, p.stderr
    assert [e["name"] for e in door.events()] == ["lua", "lua", "lua"]


def test_nested_phase_preserves_argv_exit_and_output(door):
    p = door.script("phase", "nvim-fixture", "nvim", "two words", "$(literal)", fail_phase="nvim", fail_status=17)
    assert p.returncode == 17, p.stderr
    assert door.events()[0]["argv"] == ["two words", "$(literal)"]
    rows = [json.loads(s) for s in Path(door.env["EVIDENCE_DIR"], "phases.jsonl").read_text().splitlines()]
    assert [r["event"] for r in rows] == ["start", "end"]
    assert rows[0]["name"] == "nvim-fixture"
    assert rows[1]["exit"] == 17



def test_formatter_is_mandatory_even_when_policy_off(door):
    shim = Path(door.env["PATH"].split(":")[0]) / "just"
    shim.write_text(shim.read_text().replace("--set check_hygiene_cmd 'python3 tools/emit.py hygiene'", ""))
    p = door.root / "justfile"
    p.write_text(p.read_text().replace('ci_remote :=', 'ci_remote     :='))
    result = door.invoke("gate", policy=OFF)
    assert result.returncode != 0
    assert door.events() == []
    assert door.rows()[0]["target"] == "check-hygiene"


@pytest.mark.parametrize("payload,recipe", [
    ("refs/heads/a " + "1"*40 + " refs/heads/a " + "2"*40 + "\nrefs/heads/b " + "3"*40 + " refs/tags/v1 " + "4"*40 + "\n", "hook-pre-push"),
    ("refs/heads/a " + "0"*40 + " refs/heads/a " + "2"*40 + "\n", "hook-pre-push-fast"),
])
def test_mixed_and_deletion_refs_preserve_shared_routing(door, payload, recipe):
    door.env["COVERAGE"] = "refs/heads/*"
    result = door.run(["sh", ".githooks/pre-push", "origin", "https://example.invalid/repo"], payload)
    assert result.returncode == 0, result.stderr
    assert door.rows()[0]["target"] == recipe
    assert door.events()[0]["stdin"] == payload



def test_hosted_force_reaches_nested_failure(door):
    door.env["GITHUB_ACTIONS"] = "true"
    result = door.invoke("gate", policy=OFF, force="1", fail_phase="code", fail_status=23)
    assert result.returncode == 23, result.stderr
    assert [event["name"] for event in door.events()] == ["hygiene", "code"]
    assert all(row["execution_reason"] == "forced" for row in door.rows())



def test_native_nvim_fixture_drops_caller_credentials(door):
    door.env["PARENT_SECRET"] = "fake-caller-credential"
    editor = Path(door.env["PATH"].split(":")[0]) / "nvim"
    editor.write_text(editor.read_text().replace('open(os.environ["EVENTS"], "a")',
                                               f'open({str(door.events_path)!r}, "a")'))
    result = door.run(["/usr/bin/zsh", "tests/dotfiles_check.zsh"])
    assert result.returncode != 0  # The fake editor emits no filetype marker.
    editors = [event for event in door.events() if event["name"] == "nvim"]
    assert editors, result.stdout + result.stderr
    assert editors[0]["parent_secret"] is None
    assert editors[0]["home"] != door.env["HOME"]


def test_recipe_metadata_fixture_drops_caller_credentials(door):
    door.env["PARENT_SECRET"] = "fake-caller-credential"
    metadata = door.root.parent / "metadata.jsonl"
    code = ("import json,os;from pathlib import Path;"
            f"p=Path({str(metadata)!r});"
            "p.open('a').write(json.dumps({'secret':os.environ.get('PARENT_SECRET'),"
            "'home':os.environ['HOME']})+chr(10))")
    shim = Path(door.env["PATH"].split(":")[0]) / "just"
    contents = shim.read_text().replace("--set test_cmd 'python3 tools/emit.py test'", "")
    shim.write_text(contents.replace("#!/bin/sh\n", "#!/bin/sh\npython3 -c " + shlex.quote(code) + "\n"))
    result = door.run(["/usr/bin/zsh", "tests/justfile.zsh"])
    assert result.returncode == 0, result.stdout + result.stderr
    rows = [json.loads(line) for line in metadata.read_text().splitlines()]
    assert rows and all(row["secret"] is None for row in rows)
    assert all(row["home"] != door.env["HOME"] for row in rows)
