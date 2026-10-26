"""Scoped packing policy must reach Git directories without replacing user files."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def case(tmp_path):
    home = tmp_path / 'home'
    home.mkdir()
    synced = tmp_path / 'sync [a]*? Ω'
    synced.mkdir()
    (home / 'd').symlink_to(synced, target_is_directory=True)
    source = tmp_path / 'source'
    (source / 'git').mkdir(parents=True)
    shutil.copyfile(ROOT / 'git/config', source / 'git/config')
    if (ROOT / 'git/synced-packing').exists():
        shutil.copyfile(ROOT / 'git/synced-packing', source / 'git/synced-packing')
    shutil.copyfile(source / 'git/config', home / '.gitconfig')
    env = dict(PATH=os.defpath, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               GIT_CONFIG_GLOBAL=str(home / '.gitconfig'), GIT_CONFIG_NOSYSTEM='1',
               GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
               GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')

    def helper(mode):
        return subprocess.run([sys.executable, str(ROOT / 'lib/git-packing-policy.py'), mode, str(home), str(source)],
                              env=env, capture_output=True, timeout=5)

    def git(repo, *args, environment=None):
        return subprocess.run(['git', '-C', str(repo), '-c', 'core.hooksPath=/dev/null',
                               '-c', 'hook.identity-check.enabled=false', '-c', 'hook.index-health.enabled=false', *args],
                              env=env if environment is None else environment, capture_output=True, timeout=5)

    def init(path):
        path.mkdir(parents=True)
        (path / '.git/objects').mkdir(parents=True)
        (path / '.git/refs').mkdir()
        (path / '.git/HEAD').write_text('ref: refs/heads/main\n')
        assert Path(git(path, 'rev-parse', '--show-toplevel').stdout.decode().strip()) == path
        assert Path(git(path, 'rev-parse', '--absolute-git-dir').stdout.decode().strip()) == path / '.git'
        assert path.is_relative_to(tmp_path)
        assert git(path, 'init', '-q').returncode == 0
        (path / 'file').write_text('fixture\n')
        assert git(path, 'add', 'file').returncode == 0
        assert git(path, 'commit', '-qm', 'fixture').returncode == 0
        return path

    return home, synced, source, env, helper, git, init


def assert_policy(git, repo, expected=b'false\n'):
    for setting in ('gc.packRefs', 'maintenance.pack-refs.enabled'):
        result = git(repo, 'config', '--type=bool', '--get', setting)
        assert result.stdout == expected, result.stderr
        assert result.returncode == (0 if expected else 1)


def test_main_new_nested_submodule_and_linked_scope(case, tmp_path):
    home, synced, _, _, helper, git, init = case
    main = init(synced / 'main')
    result = helper('write')
    assert result.returncode == 0, result.stderr
    assert_policy(git, main)
    assert_policy(git, init(synced / 'created-later'))
    assert_policy(git, init(synced / 'nested/repo'))
    linked = tmp_path / 'outside-linked'
    assert git(main, 'worktree', 'add', '--detach', str(linked)).returncode == 0
    assert_policy(git, linked)
    assert git(main, '-c', 'protocol.file.allow=always', 'submodule', 'add', str(synced / 'created-later'), 'sub').returncode == 0
    assert_policy(git, main / 'sub')
    assert (home / '.gitconfig-synced').is_file()


def test_canonical_and_symlink_access_and_literal_root(case):
    home, synced, _, _, helper, git, init = case
    repo = init(synced / 'repo')
    result = helper('write')
    assert result.returncode == 0, result.stderr
    assert_policy(git, repo)
    assert_policy(git, home / 'd/repo')
    target = home / '.gitconfig-synced'
    before = target.read_bytes(), target.stat().st_mtime_ns
    assert helper('check').returncode == 0
    assert helper('write').returncode == 0
    assert (target.read_bytes(), target.stat().st_mtime_ns) == before


def test_unrelated_root_excluded(case, tmp_path):
    _, synced, _, _, helper, git, init = case
    assert helper('write').returncode == 0
    assert_policy(git, init(tmp_path / 'elsewhere'), expected=b'')
    assert_policy(git, init(Path(str(synced) + '-sibling') / 'repo'), expected=b'')
    assert_policy(git, init(tmp_path / 'sync aZZ Ω/repo'), expected=b'')


def test_local_override_and_global_bypass(case, tmp_path):
    home, synced, _, _, helper, git, init = case
    repo = init(synced / 'repo')
    assert helper('write').returncode == 0
    assert git(repo, 'config', 'extensions.worktreeConfig', 'true').returncode == 0
    linked = tmp_path / 'linked'
    assert git(repo, 'worktree', 'add', '--detach', str(linked)).returncode == 0
    assert git(linked, 'config', '--worktree', 'gc.packRefs', 'true').returncode == 0
    assert git(linked, 'config', '--type=bool', '--get', 'gc.packRefs').stdout == b'true\n'
    assert helper('check').returncode == 0
    empty = home / 'empty-config'
    empty.touch()
    bypass = dict(PATH=os.defpath, HOME=str(home), GIT_CONFIG_GLOBAL=str(empty), GIT_CONFIG_NOSYSTEM='1')
    assert git(repo, 'config', '--get', 'gc.packRefs', environment=bypass).returncode == 1
    assert git(repo, 'config', 'gc.packRefs', 'true').returncode == 0
    assert git(repo, 'config', '--get', 'gc.packRefs').stdout == b'true\n'
    assert helper('check').returncode == 0


@pytest.mark.parametrize('kind', ['unmarked', 'symlink', 'dangling', 'directory'])
def test_owned_atomic_update_and_refusal(case, tmp_path, kind):
    home, _, _, _, helper, _, _ = case
    target = home / '.gitconfig-synced'
    other = tmp_path / 'other'
    other.write_bytes(b'private user file\n')
    if kind == 'unmarked':
        target.write_bytes(other.read_bytes())
    elif kind in ('symlink', 'dangling'):
        target.symlink_to(other if kind == 'symlink' else tmp_path / 'absent')
    else:
        target.mkdir()
    before = target.lstat()
    assert helper('write').returncode == 1
    assert helper('check').returncode == 1
    after = target.lstat()
    assert (after.st_ino, after.st_mode, after.st_size, after.st_mtime_ns) == (
        before.st_ino, before.st_mode, before.st_size, before.st_mtime_ns)
    assert other.read_bytes() == b'private user file\n'


def test_owned_update_and_render_failure_preserve_previous_bytes(case, tmp_path):
    home, synced, source, _, helper, _, _ = case
    assert helper('write').returncode == 0
    target = home / '.gitconfig-synced'
    original = target.read_bytes()
    moved = tmp_path / 'new root'
    synced.rename(moved)
    assert helper('write').returncode == 1
    assert target.read_bytes() == original
    (home / 'd').unlink()
    (home / 'd').symlink_to(moved)
    assert helper('check').returncode == 1
    assert target.read_bytes() == original
    assert helper('write').returncode == 0
    assert helper('check').returncode == 0
    current = target.read_bytes()
    (source / 'git/synced-packing').write_text('[gc]\npackRefs=true\n')
    assert helper('write').returncode == 1
    assert helper('check').returncode == 1
    assert target.read_bytes() == current


def test_control_path_is_rejected_before_creating_destination(case, tmp_path):
    home, _, _, _, helper, _, _ = case
    bad = tmp_path / 'line\nbreak'
    bad.mkdir()
    (home / 'd').unlink()
    (home / 'd').symlink_to(bad)
    assert helper('write').returncode == 1
    assert not (home / '.gitconfig-synced').exists()
