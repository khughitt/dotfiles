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
OFF = 'automatic_broad = false\nbroad_targets = ["test", "check-code", "test-portable"]\n'
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
        for name in ["justfile", ".gitignore", "bin/dotfiles-check", "bin/mindful", "bin/prism",
                     "tests/dotfiles_check.zsh", "tests/justfile.zsh", "tests/tmp_cleanup.zsh", "tools/tt", "tools/test-one",
                     "tools/test-suite.py",
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
  --set portable_cmd 'python3 tools/emit.py portable' \\
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
        controls = {key: self.env[key] for key in ["EVENTS", "FAIL_PHASE", "FAIL_STATUS"]
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


@pytest.mark.parametrize("broken", ["setup.sh", "zshenv"])
def test_mandatory_hygiene_checks_later_shell_files(door, broken):
    for name in ["tools/check-hygiene", "bin/dotfiles-layout-check", "bin/noctalia-glass-check",
                 "tests/front_door_test.py"]:
        shutil.copy2(ROOT / name, door.root / name)
    (Path(door.env["PATH"].split(":")[0]) / "zsh").unlink()
    node = shutil.which("node")
    assert node
    (Path(door.env["PATH"].split(":")[0]) / "node").symlink_to(node)
    (door.root / "lib").mkdir()
    (door.root / "lib/dotfiles-check-data.bash").write_text(
        'bash_files=(bashrc setup.sh)\nzsh_files=(zshrc zshenv)\n')
    (door.root / "shell").mkdir()
    for name in ["bashrc", "setup.sh", "zshrc", "zshenv", "bin/mindful-backup.mjs", "bin/mindful-release"]:
        (door.root / name).write_text("\n")
    valid = door.invoke("ci-hygiene", policy=OFF)
    assert valid.returncode == 0, valid.stdout + valid.stderr
    (door.root / broken).write_text("if then\n")
    invalid = door.invoke("ci-hygiene", policy=OFF)
    assert invalid.returncode != 0, invalid.stdout + invalid.stderr
    assert broken in invalid.stderr
    assert door.rows()[-1]["target"] == "ci-hygiene"
    assert door.rows()[-1]["exit"] != 0


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


def test_ci_hygiene_without_records(door):
    result = door.invoke("ci-hygiene", policy=OFF)
    assert result.returncode == 0, result.stderr
    assert [event["name"] for event in door.events()] == ["source"]
    assert [row["target"] for row in door.rows()] == ["ci-hygiene"]


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
    assert 1 <= job["timeout-minutes"] <= 15
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
    door.env.update(CI_STATE_DIR=str(state), UV_PYTHON=sys.executable,
                    PARENT_SECRET="fake-caller-credential", GIT_DIR=str(door.root.parent / "forbidden-git"))
    just = Path(door.env["PATH"].split(":")[0]) / "just"
    just.write_text(f"#!{sys.executable}\n" + '''import json,os,sys
print(json.dumps({"force":os.getenv("TT_FORCE"),"actions":os.getenv("GITHUB_ACTIONS"),
                  "secret":os.getenv("PARENT_SECRET"),"git_dir":os.getenv("GIT_DIR")}))
print("stderr-must-be-retained",file=sys.stderr)
sys.exit(17)
''')
    result = door.script("ci")
    assert result.returncode == 17, result.stdout + result.stderr
    evidence = state / "evidence"
    output = (evidence / "ci-test.log").read_text()
    assert "stderr-must-be-retained" in output
    assert '"force": "1"' in output and '"actions": "true"' in output
    assert '"secret": null' in output and '"git_dir": null' in output
    assert "fake-caller-credential" not in output
    assert json.loads((evidence / "outer.json").read_text())["exit"] == 17


def test_ci_pipeline_stops_its_surviving_child(door):
    state = door.root.parent / "ci-state"
    door.env.update(CI_STATE_DIR=str(state), UV_PYTHON=sys.executable)
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


PORTABLE = [
    "tests/front_door_test.py", "tests/kernel_gate_test.py",
    "tests/niri/test_column_pager.py", "tests/niri/test_debug_backdrop_startup.py",
    "tests/niri/test_dropdown.py", "tests/niri/test_mindful_scratch.py",
    "tests/niri/test_mindful_scratch_op.py",
]


def test_portable_inventory(door):
    result = door.script("portable")
    assert result.returncode == 0, result.stdout + result.stderr
    events = door.events()
    assert [e["name"] for e in events] == ["lua", "lua", "lua", "uv"]
    assert [e["argv"] for e in events[:3]] == [[f"noctalia/plugins/resource-pressure-alert/{n}"] for n in LUA]
    args = events[-1]["argv"]
    assert args[:4] == ["run", "--frozen", "pytest", "-q"]
    assert [a for a in args[4:] if not a.startswith("--junitxml=")] == PORTABLE
    phases = [json.loads(s) for s in Path(door.env["EVIDENCE_DIR"], "phases.jsonl").read_text().splitlines()]
    assert [r["event"] for r in phases] == ["start", "end"] * 4


@pytest.mark.parametrize("leaf,status,count", [("lua", 19, 1), ("uv", 23, 4)])
def test_portable_failure_stops_later_phases(door, leaf, status, count):
    result = door.script("portable", fail_phase=leaf, fail_status=status)
    assert result.returncode == status, result.stdout + result.stderr
    assert len(door.events()) == count


@pytest.mark.parametrize("xml", ["", '<testsuites><testsuite tests="0"/></testsuites>',
    '<testsuites><testsuite><testcase name="a"><skipped/></testcase></testsuite></testsuites>',
    '<testsuites><testsuite><testcase name="a"><failure/></testcase></testsuite></testsuites>'])
def test_portable_rejects_no_successful_execution(door, xml):
    # A leaf returning zero must still supply actual executed cases.
    uv = Path(door.env["PATH"].split(":")[0]) / "uv"
    controls = {"EVENTS": door.env["EVENTS"]}
    uv.write_text(f"#!{sys.executable}\nimport os\nos.environ.update({controls!r})\n" +
                  EMIT.replace("'<testsuites><testsuite tests=\"2\"><testcase name=\"a\"/>'\n                '<testcase name=\"b\"/></testsuite></testsuites>'", repr(xml)))
    result = door.run([sys.executable, "tools/test-suite.py", "portable"])
    assert result.returncode != 0, result.stdout + result.stderr
    assert [e["name"] for e in door.events()] == ["lua", "lua", "lua", "uv"]


@pytest.mark.parametrize("force,hosted,want", [(None, False, 0), (None, True, 2), ("1", True, 17)])
def test_portable_policy_skip_force_and_hosted_refusal(door, force, hosted, want):
    if hosted:
        door.env["GITHUB_ACTIONS"] = "true"
    result = door.invoke("test-portable", policy=OFF, force=force, fail_phase="portable", fail_status=17)
    assert result.returncode == want, result.stdout + result.stderr
    rows = door.rows()
    if hosted and force is None:
        assert not rows and not door.events()
        assert "TT_FORCE=1" in result.stderr
        return
    assert rows[-1]["target"] == "test-portable"
    if want == 0:
        assert not door.events()
        assert rows[-1]["execution"] == "skipped"
        assert all(rows[-1][key] is None for key in ["exit", "tests", "selection", "slowest"])
    elif force:
        assert [e["name"] for e in door.events()] == ["portable"]


def test_portable_ci_routes_only_source_and_subset(door):
    door.env["GITHUB_ACTIONS"] = "true"
    result = door.invoke("ci-test", policy=OFF, fail_phase="portable", fail_status=17)
    assert result.returncode == 17, result.stdout + result.stderr
    assert [e["name"] for e in door.events()] == ["source", "portable"]
    assert all(r["execution"] == "ran" and r["execution_reason"] == "forced" for r in door.rows())


def test_portable_scope_does_not_claim_full_push_coverage(door):
    (door.root / ".tt.toml").write_text(OFF)
    result = door.run(["sh", ".githooks/pre-push", "origin", "https://example.invalid/repo"],
                      "refs/heads/a " + "1"*40 + " refs/heads/a " + "2"*40 + "\n")
    assert result.returncode == 0, result.stderr
    assert "remote full-suite coverage is not declared" in result.stderr
    assert [e["name"] for e in door.events()] == ["hygiene"]


@pytest.mark.parametrize("location", ["relative", "inside", "existing"])
def test_portable_ci_requires_fresh_external_state(door, location):
    state = {"relative": "ci-state", "inside": str(door.root / "ci-state"),
             "existing": str(door.root.parent)}[location]
    door.env.update(CI_STATE_DIR=state, UV_PYTHON=sys.executable)
    result = door.script("ci")
    assert result.returncode != 0
    assert door.events() == []


def test_portable_ci_retains_subset_evidence(door):
    state = door.root.parent / "ci-state"
    door.env.update(CI_STATE_DIR=str(state), UV_PYTHON=sys.executable)
    # Keep actual recipes, tt and the runner; only the command leaves are doubled.
    shim = Path(door.env["PATH"].split(":")[0]) / "just"
    script = shim.read_text().replace("--set portable_cmd 'python3 tools/emit.py portable'", "")
    script = script.replace('case "$1"', f"export EVENTS={shlex.quote(door.env['EVENTS'])}\ncase \"$1\"")
    shim.write_text(script)
    (door.root / "tests/omitted_test.py").write_text("assert False\n")
    door.run(["git", "add", "."]).check_returncode()
    door.run(["git", "commit", "-qm", "test: seed portable fixture"]).check_returncode()
    result = door.script("ci")
    assert result.returncode == 0, result.stdout + result.stderr
    evidence = state / "evidence"
    report = json.loads((evidence / "verdict.json").read_text())
    assert report["selected_modules"] == PORTABLE
    assert report["excluded_modules"] == ["tests/omitted_test.py"]
    assert report["pytest"] == {"total": 2, "passed": 2, "failed": 0, "skipped": 0}
    assert report["source_sha"] == door.run(["git", "rev-parse", "HEAD"]).stdout.strip()
    phases = [json.loads(line) for line in (evidence / "phases.jsonl").read_text().splitlines()]
    assert len(phases) == 8
    assert all(row["exit"] == 0 for row in phases if row["event"] == "end")
    assert json.loads((evidence / "outer.json").read_text())["exit"] == 0
