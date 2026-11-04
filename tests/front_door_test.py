"""Exercise the real front doors; replace only expensive leaf commands."""

import json
import os
import signal
import time
import re
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
if name == "uv" and args == ["run", "--frozen", "python", "tools/test-suite.py", "collect"]:
    if os.environ.get("FAIL_COLLECTION"):
        sys.exit(29)
    pathlib.Path(os.environ["EVIDENCE_DIR"], "collection.json").write_text('{"fixture": true}')
    sys.exit(0)
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
        for name in ["justfile", ".gitignore", "bin/dotfiles-check", "bin/mindful", "bin/prism",
                     "tests/dotfiles_check.zsh", "tests/justfile.zsh", "tests/tmp_cleanup.zsh", "tools/tt", "tools/test-one",
                     "tools/test-suite.py", "tools/ci-setup", "tools/ci-pins.json",
                     ".github/workflows/ci.yml", ".githooks/pre-commit", ".githooks/pre-push"]:
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
case "$1" in --fmt) exec {just} "$@" ;; esac
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
        # Leaf doubles own their controls; production's child allowlist stays real.
        controls = {key: self.env[key] for key in ["EVENTS", "FAIL_PHASE", "FAIL_STATUS", "FAIL_COLLECTION"]
                    if key in self.env}
        uv = Path(self.env["PATH"].split(":")[0]) / "uv"
        uv.write_text(f"#!{sys.executable}\nimport os\nos.environ.update({controls!r})\n" + EMIT)
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


@pytest.mark.parametrize("mode,os_id,version,docker,runner,actions,want", [
    ("container", "ubuntu", "26.04", "1", "", "", 0),
    ("github-hosted", "ubuntu", "26.04", "0", "github-hosted", "true", 0),
    ("unknown", "ubuntu", "26.04", "1", "", "", 2),
    ("container", "ubuntu", "24.04", "1", "", "", 2),
    ("container", "arch", "26.04", "1", "", "", 2),
    ("container", "", "", "1", "", "", 2),
    ("container", "ubuntu", "26.04", "0", "", "", 2),
    ("github-hosted", "ubuntu", "26.04", "0", "self-hosted", "true", 2),
    ("github-hosted", "ubuntu", "26.04", "0", "github-hosted", "false", 2),
    ("github-hosted", "ubuntu", "26.04", "1", "github-hosted", "true", 2),
])
def test_ci_setup_namespace_guard(door, mode, os_id, version, docker, runner, actions, want):
    assert (door.root / "tools/ci-setup").is_file(), "CI setup is missing"
    result = door.run(["bash", "-c", 'source "$1"; shift; validate_namespace "$@"',
                       "guard", "tools/ci-setup", mode, os_id, version, docker, runner, actions])
    assert result.returncode == want, result.stdout + result.stderr
    assert door.events() == []


def test_ci_setup_refuses_host_before_package_commands(door):
    assert (door.root / "tools/ci-setup").is_file(), "CI setup is missing"
    for name in ["apt-get", "sudo"]:
        target = Path(door.env["PATH"].split(":")[0]) / name
        target.write_text(f"#!{sys.executable}\n" + EMIT)
        target.chmod(0o755)
    result = door.run(["bash", "tools/ci-setup", "unknown"])
    assert result.returncode == 2, result.stdout + result.stderr
    assert door.events() == []


def test_ci_hygiene_without_records(door):
    result = door.invoke("ci-hygiene", policy=OFF)
    assert result.returncode == 0, result.stderr
    assert [event["name"] for event in door.events()] == ["source"]
    assert [row["target"] for row in door.rows()] == ["ci-hygiene"]


def test_ci_force_reaches_nested_check(door):
    shim = Path(door.env["PATH"].split(":")[0]) / "just"
    shim.write_text(shim.read_text().replace("--set test_cmd 'python3 tools/emit.py test'",
                                            "--set test_cmd 'bash bin/dotfiles-check'"))
    emitter = door.root / "tools/emit.py"
    emitter.write_text(emitter.read_text() + '''
if name == "code":
    events = [json.loads(line) for line in pathlib.Path(os.environ["EVENTS"]).read_text().splitlines()]
    if sum(event["name"] == "code" for event in events) == 2:
        sys.exit(23)
''')
    door.env["GITHUB_ACTIONS"] = "true"
    result = door.invoke("ci-test", policy=OFF)
    assert result.returncode == 23, result.stderr
    assert [event["name"] for event in door.events()] == ["source", "code", "source", "code"]
    assert all(row["execution"] == "ran" and row["execution_reason"] == "forced" for row in door.rows())


def test_workflow_branch_refs_and_isolation(door):
    workflow_path = ROOT / ".github/workflows/ci.yml"
    assert workflow_path.is_file(), "Hosted workflow is missing"
    workflow = json.loads(workflow_path.read_text())
    assert workflow["on"] == {"push": {"branches": ["**"]}, "workflow_dispatch": {}}
    assert workflow["permissions"] == {"contents": "read"}
    assert workflow["concurrency"] == {"group": "${{ github.workflow }}-${{ github.ref }}",
                                       "cancel-in-progress": True}
    assert len(workflow["jobs"]) == 1
    job = next(iter(workflow["jobs"].values()))
    assert job["runs-on"] == "ubuntu-26.04"
    assert 1 <= job["timeout-minutes"] <= 90
    assert job["env"]["TT_FORCE"] == "1"
    for step in job["steps"]:
        if "uses" in step:
            assert re.fullmatch(r"[a-f0-9]{40}", step["uses"].rsplit("@", 1)[1])
    checkout = next(step for step in job["steps"] if step.get("uses", "").startswith("actions/checkout@"))
    assert checkout["with"]["persist-credentials"] is False
    upload = next(step for step in job["steps"] if step.get("uses", "").startswith("actions/upload-artifact@"))
    assert upload["if"] == "always()"
    assert upload["with"]["if-no-files-found"] == "error"
    assert 1 <= upload["with"]["retention-days"] <= 30
    assert 'ci_suite_refs := ""' in (ROOT / "justfile").read_text()


def test_ci_pipeline_contains_stderr_failure_and_no_caller_credentials(door):
    state = door.root.parent / "ci-state"
    state.mkdir()
    keys = ["PATH", "HOME", "USER", "TERM", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
            "XDG_CACHE_HOME", "XDG_STATE_HOME", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM",
            "TT_LOG", "EVIDENCE_DIR"]
    (state / "setup.json").write_text(json.dumps({"namespace": "container",
                                                 "environment": {**{key: door.env[key] for key in keys},
                                                                 "PARENT_SECRET": "fake-setup-credential",
                                                                 "GIT_DIR": "/forbidden-setup-git"}}))
    door.env.update(CI_STATE_DIR=str(state), PARENT_SECRET="fake-caller-credential",
                    GIT_DIR=str(door.root.parent / "forbidden-git"))
    just = Path(door.env["PATH"].split(":")[0]) / "just"
    just.write_text(f"#!{sys.executable}\n" + '''import json,os,sys
print(json.dumps({"force":os.getenv("TT_FORCE"),"actions":os.getenv("GITHUB_ACTIONS"),
                  "secret":os.getenv("PARENT_SECRET"),"git_dir":os.getenv("GIT_DIR")}))
print("stderr-must-be-retained",file=sys.stderr)
sys.exit(17)
''')
    result = door.script("ci")
    assert result.returncode == 17, result.stdout + result.stderr
    evidence = Path(door.env["EVIDENCE_DIR"])
    output = (evidence / "ci-test.log").read_text()
    assert "stderr-must-be-retained" in output
    assert '"force": "1"' in output and '"actions": "true"' in output
    assert '"secret": null' in output and '"git_dir": null' in output
    assert "fake-caller-credential" not in output
    assert "fake-setup-credential" not in output
    assert json.loads((evidence / "outer.json").read_text())["exit"] == 17


@pytest.fixture
def complete_evidence(door):
    module = door.root / "tests/unit_test.py"
    module.write_text("def test_one():\n    assert 1 == 1\n")
    paths = [f"noctalia/plugins/resource-pressure-alert/{name}" for name in LUA]
    paths += [f"tests/{name}.zsh" for name in ZSH]
    for path in paths:
        target = door.root / path
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("fixture\n")
    door.run(["git", "add", "."]).check_returncode()
    door.run(["git", "commit", "-qm", "test: seed evidence fixture"]).check_returncode()
    sha = door.run(["git", "rev-parse", "HEAD"]).stdout.strip()
    evidence = Path(door.env["EVIDENCE_DIR"])
    collection = {"exit": 0, "source_sha": sha, "source_root": str(door.root),
                  "source_modules": ["tests/unit_test.py"],
                  "modules": [{"path": "tests/unit_test.py", "outcome": "passed"}],
                  "cases": [{"nodeid": "tests/unit_test.py::test_one", "classname": "tests.unit_test",
                             "name": "test_one", "module": "tests/unit_test.py"}]}
    (evidence / "collection.json").write_text(json.dumps(collection))
    (evidence / "execution-collection.json").write_text(json.dumps(collection))
    (evidence / "pytest.xml").write_text('<testsuites><testsuite tests="1"><testcase classname="tests.unit_test" name="test_one"/></testsuite></testsuites>')
    (evidence / "outer.json").write_text(json.dumps({"exit": 0, "timed_out": False, "interrupted": 0}))
    rows = []

    def start(name, argv):
        rows.append({"event": "start", "name": name, "argv": argv, "at": "2026-11-03T00:00:00Z"})

    def end(name):
        rows.append({"event": "end", "name": name, "exit": 0, "seconds": .1, "at": "2026-11-03T00:00:01Z"})

    for path in paths[:3]:
        start(path, ["lua", path]); end(path)
    start("pytest", ["uv", "run", "--frozen", "pytest", "-q", "--junitxml=/fixture/pytest.xml"])
    end("pytest")
    for name in ZSH:
        path = f"tests/{name}.zsh"
        start(path, ["zsh", path])
        if name == "dotfiles_check":
            for file in ["zshrc", "shell/aliases", "shell/audio", "shell/functions", "shell/history",
                         "shell/macos", "shell/tmux", "shell/ubuntu", "shell/vconsole", "shell/zoxide"]:
                phase = "modeline:" + file
                start(phase, ["nvim", "--headless", "-i", "NONE", "-u", "NONE", "--cmd", "set noswapfile",
                              "--cmd", "filetype on", "--cmd", "syntax on", str(door.root / file),
                              '+lua print("DOTFILES_FT:" .. vim.bo.filetype .. ":" .. vim.bo.syntax)', "+qa!"])
                end(phase)
            for phase, args in [("nvim-clipboard", [f"+lua dofile('{door.root}/nvim/tests/clipboard_test.lua')", "+qa!"]),
                                ("nvim-theme", ["-l", str(door.root / "nvim/tests/theme_test.lua")])]:
                start(phase, ["nvim", "--headless", "-i", "NONE", "-u", str(door.root / "nvim/init.lua"),
                              "--cmd", "set noswapfile", *args]); end(phase)
        end(path)
    (evidence / "phases.jsonl").write_text("".join(json.dumps(row) + "\n" for row in rows))
    timing = [{"target": target, "execution": "ran", "execution_reason": "forced", "exit": 0,
               "tests": 1 if target == "test" else None}
              for target in ["ci-hygiene", "check-code", "check-code", "test"]]
    Path(door.env["TT_LOG"]).write_text("".join(json.dumps(row) + "\n" for row in timing))
    (evidence / "runs.jsonl").write_text(Path(door.env["TT_LOG"]).read_text())
    return evidence


def test_collection_records_tracked_modules_and_real_nodeids(door):
    (door.root / "tests/unit_test.py").write_text("def test_one():\n    assert 1 == 1\n")
    (door.root / "tests/assertions_test.py").write_text("assert 2 == 2\n")
    door.run(["git", "add", "."]).check_returncode()
    door.run(["git", "commit", "-qm", "test: seed collection fixture"]).check_returncode()
    result = door.script("collect")
    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads((Path(door.env["EVIDENCE_DIR"]) / "collection.json").read_text())
    assert report["source_modules"] == ["tests/assertions_test.py", "tests/unit_test.py"]
    assert {row["path"] for row in report["modules"]} == set(report["source_modules"])
    assert [case["nodeid"] for case in report["cases"]] == ["tests/unit_test.py::test_one"]


def test_full_collection_failure_stops_before_pytest(door):
    door.env["FAIL_COLLECTION"] = "1"
    result = door.script()
    assert result.returncode == 29, result.stdout + result.stderr
    assert [event["name"] for event in door.events()] == ["lua", "lua", "lua"]


@pytest.mark.parametrize("damage", [None, "missing_collection", "missing_case", "duplicate_case", "all_skipped",
                                    "partial_skipped", "timing_count", "source_dirty", "duplicate_module", "missing_execution", "missing_module", "failed_collection", "missing_phase", "out_of_order", "bad_argv", "late_failure",
                                    "late_timeout", "missing_outer", "policy_skip", "unforced", "malformed_xml"])
def test_complete_evidence_rejects_partial_success(door, complete_evidence, damage):
    evidence = complete_evidence
    if damage == "source_dirty":
        (door.root / "tests/unit_test.py").write_text("assert False\n")
    elif damage == "partial_skipped":
        (door.root / "tests/unit_test.py").write_text("import pytest\ndef test_one():\n    assert 1 == 1\ndef test_two():\n    pytest.skip('fixture omission')\n")
        door.run(["git", "add", "."]).check_returncode()
        door.run(["git", "commit", "-qm", "test: seed partially skipped module"]).check_returncode()
        for name in ["collection.json", "execution-collection.json"]:
            p = evidence / name; data = json.loads(p.read_text())
            data["source_sha"] = door.run(["git", "rev-parse", "HEAD"]).stdout.strip()
            data["cases"].append({"nodeid":"tests/unit_test.py::test_two", "classname":"tests.unit_test", "name":"test_two", "module":"tests/unit_test.py"})
            p.write_text(json.dumps(data))
        (evidence / "pytest.xml").write_text('<testsuites><testsuite tests="2"><testcase classname="tests.unit_test" name="test_one"/><testcase classname="tests.unit_test" name="test_two"><skipped message="fixture omission"/></testcase></testsuite></testsuites>')
    elif damage == "timing_count":
        p = evidence / "runs.jsonl"; rows = [json.loads(line) for line in p.read_text().splitlines()]
        rows[-1]["tests"] = 999
        p.write_text("".join(json.dumps(row) + "\n" for row in rows))
    elif damage == "missing_collection":
        (evidence / "collection.json").unlink()
    elif damage in ["missing_case", "duplicate_case", "all_skipped", "malformed_xml"]:
        xml = {"missing_case": '<testsuites><testsuite tests="0"/></testsuites>',
               "duplicate_case": '<testsuites><testsuite tests="2"><testcase classname="tests.unit_test" name="test_one"/><testcase classname="tests.unit_test" name="test_one"/></testsuite></testsuites>',
               "all_skipped": '<testsuites><testsuite tests="1"><testcase classname="tests.unit_test" name="test_one"><skipped message="not a passing module"/></testcase></testsuite></testsuites>',
               "malformed_xml": '<testsuites>'}[damage]
        (evidence / "pytest.xml").write_text(xml)
    elif damage == "missing_execution":
        (evidence / "execution-collection.json").unlink()
    elif damage in ["missing_module", "failed_collection"]:
        p = evidence / "collection.json"; data = json.loads(p.read_text())
        if damage == "missing_module":
            data["modules"] = []
        else:
            data["exit"] = 2
        p.write_text(json.dumps(data))
    elif damage == "duplicate_module":
        p = evidence / "collection.json"; data = json.loads(p.read_text())
        data["modules"] *= 2; p.write_text(json.dumps(data))
    elif damage in ["missing_phase", "out_of_order", "bad_argv"]:
        p = evidence / "phases.jsonl"; data = [json.loads(line) for line in p.read_text().splitlines()]
        if damage == "missing_phase":
            data = [row for row in data if row["name"] != "nvim-theme"]
        elif damage == "out_of_order":
            data[0], data[2] = data[2], data[0]
        else:
            data[0]["argv"] = ["true"]
        p.write_text("".join(json.dumps(row) + "\n" for row in data))
    elif damage in ["late_failure", "late_timeout", "missing_outer"]:
        p = evidence / "outer.json"
        if damage == "missing_outer":
            p.unlink()
        else:
            p.write_text(json.dumps({"exit": 23 if damage == "late_failure" else 124,
                                     "timed_out": damage == "late_timeout", "interrupted": 0}))
    elif damage in ["policy_skip", "unforced"]:
        p = evidence / "runs.jsonl"; data = [json.loads(line) for line in p.read_text().splitlines()]
        data[-1]["execution" if damage == "policy_skip" else "execution_reason"] = "skipped" if damage == "policy_skip" else "default"
        p.write_text("".join(json.dumps(row) + "\n" for row in data))
    result = door.script("verify", str(evidence))
    if damage in [None, "partial_skipped"]:
        assert result.returncode == 0, result.stdout + result.stderr
        report = json.loads((evidence / "verdict.json").read_text())
        assert report["pytest"] == {"total": 2 if damage == "partial_skipped" else 1, "passed": 1, "failed": 0, "skipped": 1 if damage == "partial_skipped" else 0}
        assert report["phases"] == 28
    else:
        assert result.returncode != 0
        assert "evidence:" in result.stdout + result.stderr


def test_execution_collection_observes_real_pytest(door):
    (door.root / "tests/unit_test.py").write_text("def test_one():\n    assert 1 == 1\n")
    door.run(["git", "add", "."]).check_returncode()
    door.run(["git", "commit", "-qm", "test: seed execution fixture"]).check_returncode()
    door.env.update(PYTHONPATH=str(door.root), PYTEST_PLUGINS="tools.test-suite")
    result = door.run([sys.executable, "-m", "pytest", "tests/unit_test.py", "-q"])
    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads((Path(door.env["EVIDENCE_DIR"]) / "execution-collection.json").read_text())
    assert report["source_modules"] == ["tests/unit_test.py"]
    assert [case["nodeid"] for case in report["cases"]] == ["tests/unit_test.py::test_one"]


def test_ci_pipeline_stops_its_surviving_child(door):
    state = door.root.parent / "ci-state"
    state.mkdir()
    keys = ["PATH", "HOME", "USER", "TERM", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "TT_LOG", "EVIDENCE_DIR"]
    (state / "setup.json").write_text(json.dumps({"namespace": "container", "environment": {key: door.env[key] for key in keys}}))
    door.env["CI_STATE_DIR"] = str(state)
    pidfile = state / "child.json"
    just = Path(door.env["PATH"].split(":")[0]) / "just"
    just.write_text(f"#!{sys.executable}\n" + f'''import json,os,subprocess,sys
from pathlib import Path
child = subprocess.Popen(["/usr/bin/sleep", "300"], env={{"PATH":"/usr/bin:/bin","HOME":{door.env['HOME']!r}}},
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
Path({str(pidfile)!r}).write_text(json.dumps({{"pid":child.pid,"group":os.getpgrp()}}))
sys.exit(17)
''')
    pid = None
    try:
        result = door.script("ci")
        assert result.returncode == 17, result.stdout + result.stderr
        pid = json.loads(pidfile.read_text())["pid"]
        status = Path(f"/proc/{pid}/stat")
        for _ in range(50):
            if not status.exists() or status.read_text().rsplit(")", 1)[1].split()[0] == "Z":
                break
            time.sleep(.01)
        else:
            pytest.fail("CI command left its fixture child running")
    finally:
        if pid is None and pidfile.exists():
            pid = json.loads(pidfile.read_text())["pid"]
        if pid is not None:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
