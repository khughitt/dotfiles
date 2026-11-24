"""Tests for hosts/*/bin/atoms-recertify."""
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
RECERTIFY = next((ROOT / "hosts").glob("*/bin/atoms-recertify"))


class AtomsRecertifyTests(unittest.TestCase):
    """hosts/*/bin/atoms-recertify writes certification JSON to records/atoms/docs/certification
    and commits only volume.py on chore/recertify-<kernel> in the atoms repo."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = pathlib.Path(tmp.name).resolve()
        self.home = self.base / "home"
        self.xdg = self.base / "xdg"
        self.bin = self.base / "bin"
        for directory in (self.home, self.home / ".cache", self.xdg, self.bin):
            directory.mkdir(parents=True)
        self.gitconfig = self.home / ".gitconfig"
        self.gitconfig.write_text("[init]\n\tdefaultBranch = main\n", encoding="utf-8")
        self.env = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.xdg),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "GIT_CONFIG_GLOBAL": str(self.gitconfig),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Test User",
            "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test User",
            "GIT_COMMITTER_EMAIL": "test@example.com",
        }
        self.atoms_repo = self.home / "d" / "atoms"
        self.records_repo = self.home / "d" / "records"
        self.records_atoms = self.records_repo / "atoms"
        self._init_repo(self.atoms_repo)
        self._init_repo(self.records_repo)

        volume_py = self.atoms_repo / "python" / "src" / "atoms" / "fs" / "volume.py"
        volume_py.parent.mkdir(parents=True)
        volume_py.write_text(
            'kernel_identifier="7.2.2-arch1-1"\n'
            'certification_ref="docs/certification/2026-09-03-ext4-linux-7.2.2-arch1-1.json"\n',
            encoding="utf-8",
        )
        self._git(self.atoms_repo, "add", "python/src/atoms/fs/volume.py")
        self._git(self.atoms_repo, "commit", "-q", "-m", "initial atoms")

        (self.records_atoms / "docs" / "certification").mkdir(parents=True)
        (self.records_atoms / "docs" / "certification" / ".keep").write_text("", encoding="utf-8")
        (self.records_repo / "unrelated.txt").write_text("before\n", encoding="utf-8")
        self._git(self.records_repo, "add", ".")
        self._git(self.records_repo, "commit", "-q", "-m", "initial records")

        self._write_stub("uname", '#!/bin/sh\necho "7.3.0-arch1-1"\n')
        self._write_stub(
            "file",
            '#!/bin/sh\necho "Linux kernel x86 boot executable bzImage, version 7.3.0-arch1-1 (linux@archlinux)"\n',
        )
        self._write_stub("pgrep", "#!/bin/sh\nexit 1\n")
        self._write_stub("notify-send", "#!/bin/sh\nexit 0\n")
        self._write_tasks_stub({"project": {"records": str(self.records_atoms)}})
        self._write_stub(
            "uv",
            """#!/usr/bin/env python3
import os
import pathlib
import sys

args = sys.argv[1:]
if args[:4] == ["run", "python", "-m", "tools.certify"]:
    sub = args[4]
    if sub in ("build-replay", "check"):
        sys.exit(0)
    if sub == "run":
        idx = args.index("--record")
        rec_dir = pathlib.Path(args[idx + 1])
        (rec_dir / "2026-11-05-ext4-linux-7.3.0-arch1-1.json").write_text('{"ok":true}\\n', encoding="utf-8")
        sys.exit(0)
if args[:2] == ["run", "pytest"]:
    cert_dir = os.environ.get("ATOMS_CERTIFICATION_DIR", "")
    if not cert_dir or not (pathlib.Path(cert_dir) / "2026-11-05-ext4-linux-7.3.0-arch1-1.json").is_file():
        sys.stderr.write(f"missing ATOMS_CERTIFICATION_DIR record: {cert_dir!r}\\n")
        sys.exit(1)
    sys.exit(0)
sys.exit(2)
""",
        )

    def _git(self, repo, *args):
        proc = subprocess.run(
            ["git", "-C", str(repo), *args],
            env=self.env,
            capture_output=True,
            text=True,
            check=True,
        )
        return proc.stdout.strip()

    def _init_repo(self, repo):
        repo.mkdir(parents=True)
        self._git(repo, "init", "-q")
        top = pathlib.Path(self._git(repo, "rev-parse", "--show-toplevel")).resolve()
        git_dir = pathlib.Path(self._git(repo, "rev-parse", "--absolute-git-dir")).resolve()
        self.assertEqual(top, repo.resolve())
        self.assertTrue(git_dir.is_relative_to(repo.resolve()))

    def _write_stub(self, name, content):
        path = self.bin / name
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)

    def _write_tasks_stub(self, payload):
        text = json.dumps(payload)
        self._write_stub(
            "tasks",
            f"#!/bin/sh\nif [ \"$1\" = \"where\" ]; then\n  printf '%s\\n' '{text}'\n  exit 0\nfi\nexit 1\n",
        )

    def test_recertify_writes_record_to_records_repo_and_commits_only_volume_py_in_atoms(self):
        # Stage an unrelated change in the records repository to verify --only leaves it staged
        (self.records_repo / "unrelated.txt").write_text("staged-edit\n", encoding="utf-8")
        self._git(self.records_repo, "add", "unrelated.txt")

        proc = subprocess.run(
            ["bash", str(RECERTIFY)],
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

        atoms_files = self._git(
            self.atoms_repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "chore/recertify-7.3.0-arch1-1"
        ).splitlines()
        self.assertEqual(atoms_files, ["python/src/atoms/fs/volume.py"])
        volume_text = self._git(self.atoms_repo, "show", "chore/recertify-7.3.0-arch1-1:python/src/atoms/fs/volume.py")
        self.assertIn('kernel_identifier="7.3.0-arch1-1"', volume_text)
        self.assertIn('certification_ref="docs/certification/2026-11-05-ext4-linux-7.3.0-arch1-1.json"', volume_text)

        records_files = self._git(
            self.records_repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"
        ).splitlines()
        self.assertEqual(records_files, ["atoms/docs/certification/2026-11-05-ext4-linux-7.3.0-arch1-1.json"])
        staged = self._git(self.records_repo, "diff", "--cached", "--name-only").splitlines()
        self.assertEqual(staged, ["unrelated.txt"])

    def test_recertify_rejects_missing_or_null_records_dir(self):
        for payload in (
            {},
            {"project": {"records": None}},
            {"project": {"records": str(self.base / "missing-dir")}},
        ):
            with self.subTest(payload=payload):
                self._write_tasks_stub(payload)
                proc = subprocess.run(
                    ["bash", str(RECERTIFY)],
                    env=self.env,
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(proc.returncode, 0)
                self.assertIn("could not resolve certification records directory", proc.stdout + proc.stderr)
                self.assertFalse((self.home / ".cache" / "atoms-recert").exists())
