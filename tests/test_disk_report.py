"""disk-report: volumes, hot spots, WORK_ROOT by repository, inotify holders and the
work-link units, measured over a fake home, /proc and mounts file. It only measures;
the thresholds are the caller's.

Reference: docs/host-configuration.md.
"""
import contextlib
import io
import json
import os
import pathlib
import stat
import tempfile
import unittest
from unittest import mock

import importlib.machinery
import importlib.util

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "bin" / "disk-report"


def load(path):
    """Loads the extensionless script as a module under a valid module name."""
    loader = importlib.machinery.SourceFileLoader("disk_report", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


report = load(SCRIPT)

MIB = 1024 * 1024


def fill(path, mib):
    """A file of `mib` MiB of real blocks, so du sizes order as written."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"x" * (mib * MIB))


class HomeTests(unittest.TestCase):
    """A fake home with the four roots, a ~/d holding real and linked intermediates,
    and a WORK_ROOT behind the links."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = pathlib.Path(tmp.name)
        self.home = self.base / "home"
        self.work = self.base / "work"
        fill(self.home / ".cache" / "big" / "blob", 3)
        fill(self.home / ".cache" / "small" / "blob", 1)
        (self.home / ".codex").mkdir()
        # ~/d: one project with a real node_modules, a .venv linked out, a nested
        # .git to prune, and a worktree whose own .venv must not be scanned.
        proj = self.home / "d" / "proj"
        fill(proj / "node_modules" / "dep" / "index.js", 2)
        fill(proj / ".git" / ".venv" / "decoy", 1)
        (self.work / "proj" / ".venv").mkdir(parents=True)
        fill(self.work / "proj" / ".venv" / "lib", 1)
        (proj / ".venv").symlink_to(self.work / "proj" / ".venv")
        fill(self.work / "proj" / ".worktrees" / "wt" / ".venv" / "inner", 1)
        (proj / ".worktrees").symlink_to(self.work / "proj" / ".worktrees")
        # An external entry with no repository behind it.
        fill(self.work / "gone" / "target" / "debug" / "bin", 1)

    def test_hotspots_rank_children_and_report_absent_and_unset_roots(self):
        spots = {s["label"]: s for s in report.hotspots(self.home, None, 5)}
        cache = spots["~/.cache"]
        self.assertEqual(cache["state"], "ok")
        self.assertEqual([pathlib.Path(e["path"]).name for e in cache["entries"]], ["big", "small"])
        self.assertGreaterEqual(cache["bytes"], 4 * MIB)
        self.assertEqual(spots["CACHE_DIR"]["state"], "unset")
        self.assertEqual(spots["~/.codex"], {"label": "~/.codex", "root": str(self.home / ".codex"),
                                              "state": "ok", "bytes": 0, "entries": []})
        self.assertEqual(spots["~/.claude"]["state"], "absent")

    def test_cache_dir_is_its_own_hotspot_unless_it_is_the_cache(self):
        spots = report.hotspots(self.home, str(self.home / ".cache"), 5)
        self.assertNotIn("CACHE_DIR", [s["label"] for s in spots])
        spots = {s["label"]: s for s in report.hotspots(self.home, str(self.work), 5)}
        self.assertEqual(spots["CACHE_DIR"]["root"], str(self.work))
        self.assertEqual({pathlib.Path(e["path"]).name for e in spots["CACHE_DIR"]["entries"]}, {"proj", "gone"})

    def test_in_tree_intermediates_are_real_directories_with_links_listed_apart(self):
        spot = [s for s in report.hotspots(self.home, None, 5) if s["label"] == "~/d intermediates"][0]
        self.assertEqual([e["path"] for e in spot["entries"]], [str(self.home / "d" / "proj" / "node_modules")])
        self.assertGreaterEqual(spot["bytes"], 2 * MIB)
        self.assertEqual(
            sorted(l["path"] for l in spot["links"]),
            sorted(str(self.home / "d" / "proj" / n) for n in (".venv", ".worktrees")))

    def test_work_root_by_repository_flags_orphans_and_skips_nested_entries(self):
        wr = report.work_root(str(self.work), self.home / "d")
        self.assertEqual(wr["state"], "available")
        rows = {(e["repo"], e["name"]): e for e in wr["entries"]}
        self.assertEqual(set(rows), {("proj", ".venv"), ("proj", ".worktrees"), ("gone", "target")})
        self.assertFalse(rows[("proj", ".venv")]["orphan"])
        self.assertTrue(rows[("gone", "target")]["orphan"])
        self.assertEqual(wr["entries"][0]["bytes"], max(e["bytes"] for e in wr["entries"]))

    def test_work_root_states(self):
        self.assertEqual(report.work_root(None, self.home / "d")["state"], "unconfigured")
        gone = report.work_root(str(self.base / "unmounted"), self.home / "d")
        self.assertEqual(gone["state"], "unavailable")
        self.assertEqual(gone["entries"], [])

    def test_volumes_from_a_mounts_file(self):
        mounts = self.base / "mounts"
        mounts.write_text(
            f"tmpfs /run tmpfs rw 0 0\n/dev/sda1 {self.base} ext4 rw 0 0\nproc /proc proc rw 0 0\n")
        rows = report.volumes(mounts)
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual((row["mount"], row["device"], row["fstype"]), (str(self.base), "/dev/sda1", "ext4"))
        self.assertGreater(row["size"], 0)
        self.assertEqual(row["percent"], round(100 * row["used"] / row["size"], 1))

    def test_volumes_unescape_mount_paths(self):
        mounts = self.base / "mounts"
        spaced = self.base / "with space"
        spaced.mkdir()
        mounts.write_text(f"/dev/sdb1 {str(spaced).replace(' ', chr(92) + '040')} ext4 rw 0 0\n")
        self.assertEqual(report.volumes(mounts)[0]["mount"], str(spaced))


class ProcTests(unittest.TestCase):
    """A fake /proc: two processes of ours holding inotify fds, one with none, and one
    directory that is not a pid."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.proc = pathlib.Path(tmp.name)
        limits = self.proc / "sys" / "fs" / "inotify"
        limits.mkdir(parents=True)
        (limits / "max_user_watches").write_text("1000\n")
        (limits / "max_user_instances").write_text("128\n")
        self.process(10, "dropbox", {3: 5, 7: 2})
        self.process(20, "editor", {4: 1})
        self.process(30, "shell", {})
        (self.proc / "self").mkdir()

    def process(self, pid, comm, fds):
        p = self.proc / str(pid)
        (p / "fd").mkdir(parents=True)
        (p / "fdinfo").mkdir()
        (p / "comm").write_text(comm + "\n")
        (p / "fd" / "0").symlink_to("/dev/pts/1")
        for fd, watches in fds.items():
            (p / "fd" / str(fd)).symlink_to("anon_inode:inotify")
            body = "pos:\t0\nflags:\t00\n" + "".join(f"inotify wd:{i} ino:1 sdev:1\n" for i in range(watches))
            (p / "fdinfo" / str(fd)).write_text(body)

    def test_counts_watches_and_instances_per_holder(self):
        got = report.inotify(self.proc)
        self.assertEqual((got["max_user_watches"], got["max_user_instances"]), (1000, 128))
        self.assertEqual((got["watches"], got["instances"]), (8, 3))
        self.assertEqual(got["holders"], [
            {"pid": 10, "comm": "dropbox", "watches": 7, "instances": 2},
            {"pid": 20, "comm": "editor", "watches": 1, "instances": 1},
        ])

    def test_other_users_processes_are_not_ours(self):
        with mock.patch("os.getuid", return_value=os.getuid() + 1):
            got = report.inotify(self.proc)
        self.assertEqual(got["holders"], [])
        self.assertEqual(got["watches"], 0)


def fake_systemctl(bin_dir):
    """A systemctl in bin_dir answering `--user show`: one failed service, one active timer."""
    stub = bin_dir / "systemctl"
    stub.write_text(
        "#!/bin/sh\n"
        'case "$3" in\n'
        '  work-link.service) printf "LoadState=loaded\\nActiveState=failed\\nResult=exit-code\\n";;\n'
        '  work-link.timer) printf "LoadState=loaded\\nActiveState=active\\nResult=success\\n";;\n'
        '  *) printf "LoadState=not-found\\nActiveState=inactive\\nResult=success\\n";;\n'
        "esac\n")
    stub.chmod(stub.stat().st_mode | stat.S_IEXEC)


class ServiceTests(unittest.TestCase):
    """systemctl faked on PATH: one failed service, one active timer."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.bin = pathlib.Path(tmp.name)
        fake_systemctl(self.bin)

    def test_reports_each_unit(self):
        with mock.patch.dict(os.environ, {"PATH": str(self.bin)}):
            got = report.services(("work-link.service", "work-link.timer", "nothing.service"))
        self.assertEqual([(s["unit"], s["load"], s["active"], s["result"]) for s in got], [
            ("work-link.service", "loaded", "failed", "exit-code"),
            ("work-link.timer", "loaded", "active", "success"),
            ("nothing.service", "not-found", "inactive", "success"),
        ])

    def test_without_systemctl(self):
        with mock.patch.dict(os.environ, {"PATH": str(self.bin / "empty")}):
            got = report.services(("work-link.service",))
        self.assertEqual(got, [{"unit": "work-link.service", "load": "unavailable", "active": None, "result": None}])


class MainTests(unittest.TestCase):
    """The command over the fakes: section selection, JSON shape, the table."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        base = pathlib.Path(tmp.name)
        self.home = base / "home"
        fill(self.home / ".cache" / "x" / "blob", 1)
        (self.home / "d").mkdir()
        self.proc = base / "proc"
        limits = self.proc / "sys" / "fs" / "inotify"
        limits.mkdir(parents=True)
        (limits / "max_user_watches").write_text("100\n")
        (limits / "max_user_instances").write_text("10\n")
        self.mounts = base / "mounts"
        self.mounts.write_text(f"/dev/sda1 {base} ext4 rw 0 0\n")
        # systemctl is faked ahead of the real PATH, which du still comes from: the services
        # section never reaches the live user bus.
        bin_dir = base / "bin"
        bin_dir.mkdir()
        fake_systemctl(bin_dir)
        self.env = {"WORK_ROOT": str(base / "work"), "CACHE_DIR": str(base / "cache"),
                    "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}

    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.dict(os.environ, self.env), contextlib.redirect_stdout(out):
            code = report.main(["--home", str(self.home), "--proc", str(self.proc), "--mounts", str(self.mounts), *argv])
        return code, out.getvalue()

    def test_json_has_only_the_selected_sections(self):
        code, out = self.run_main("--json", "--section", "volumes", "--section", "inotify")
        self.assertEqual(code, 0)
        got = json.loads(out)
        self.assertEqual(set(got), {"host", "at", "volumes", "inotify"})
        self.assertEqual(got["inotify"]["max_user_watches"], 100)

    def test_table_names_every_section_and_the_storage_states(self):
        code, out = self.run_main("-n", "2")
        self.assertEqual(code, 0)
        for heading in ("volumes", "hot spots", "work-root", "inotify", "services"):
            self.assertIn(heading, out)
        self.assertIn("work-link.service    failed (exit-code)", out)  # from the fake
        self.assertIn("(unavailable)", out)  # WORK_ROOT set to a missing directory
        self.assertIn("CACHE_DIR              absent", out)
        self.assertIn("~/.codex               absent", out)

    def test_n_must_be_positive(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            self.run_main("-n", "0")


class HumanTests(unittest.TestCase):
    def test_units(self):
        self.assertEqual(report.human(None), "-")
        self.assertEqual(report.human(0), "0B")
        self.assertEqual(report.human(1536), "1.5K")
        self.assertEqual(report.human(120 * MIB), "120M")
        self.assertEqual(report.human(3 * 1024 ** 4), "3.0T")
