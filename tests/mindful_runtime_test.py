"""Runtime artifacts operate only on disposable trees and a fake service manager."""
import hashlib
import json
import os
import runpy
import shlex
from pathlib import Path
import shutil
import stat
import signal
import time
import subprocess
import tarfile

import pytest

REPO = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, **kwargs)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def executable(path, text):
    write(path, text).chmod(0o755)
    return path


def git_tree(path):
    run('git', 'init', '-q', str(path), check=True)
    run('git', '-C', str(path), 'add', '.', check=True)
    run('git', '-C', str(path), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
        '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture', check=True)


@pytest.fixture
def checkout(tmp_path):
    root = tmp_path / 'checkout'
    nodes = tmp_path / 'nodes'
    write(nodes / 'src/index.ts', 'export const value = 42;')
    write(nodes / 'dist/index.js', 'export const value = 42;')
    write(nodes / 'package.json', '{"name":"@verifiably/nodes","type":"module","main":"dist/index.js"}')
    git_tree(nodes)
    write(root / '.gitignore', 'node_modules/\npackages/*/dist/\npackages/web/build/\n')
    write(root / 'package.json', '{"name":"mindful-v6-workspace","type":"module"}')
    write(root / 'package-lock.json', '{}')
    write(root / 'packages/mindful/package.json', '{"name":"@mindful/v6","type":"module","main":"dist/index.js"}')
    write(root / 'packages/web/package.json', '{"name":"@mindful/web","type":"module"}')
    write(root / 'packages/web/scripts/serve.mjs', 'await import("../build/index.js");')
    write(root / 'packages/mindful/scripts/check-core-freshness.mjs', 'process.exit(0);')
    write(root / 'packages/mindful/dist/bin.js', 'import {value} from "@mindful/v6"; console.log(value);')
    write(root / 'packages/web/build/index.js', 'import {value} from "@mindful/v6"; console.log(value);')
    write(root / 'packages/mindful/dist/index.js', 'export {value} from "@verifiably/nodes";')
    (root / 'node_modules/@verifiably').mkdir(parents=True)
    (root / 'node_modules/@verifiably/nodes').symlink_to(nodes, target_is_directory=True)
    (root / 'node_modules/@mindful').mkdir()
    (root / 'node_modules/@mindful/v6').symlink_to(root / 'packages/mindful', target_is_directory=True)
    git_tree(root)
    mockbin = tmp_path / 'tools'
    executable(mockbin / 'npm', '#!/bin/sh\nprintf "%s\\n" "$*" >> "$NPM_LOG"\n')
    env = dict(HOME=os.environ["HOME"], PATH=f'{mockbin}:{os.environ["PATH"]}', NPM_LOG=str(tmp_path / 'npm.log'))
    return root, nodes, env


def test_release_is_independent_and_records_provenance(checkout, tmp_path):
    root, nodes, env = checkout
    output = tmp_path / 'release'
    result = run(str(REPO / 'bin/mindful-release'), '--checkout', str(root), '--output', str(output), env=env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / 'npm.log').read_text().splitlines() == ['ci', 'run prepare', 'run build']
    provenance = json.loads((output / 'provenance.json').read_text())
    assert provenance['mind6_revision'] == run('git', '-C', str(root), 'rev-parse', 'HEAD').stdout.strip()
    assert provenance['nodes_revision'] == run('git', '-C', str(nodes), 'rev-parse', 'HEAD').stdout.strip()
    assert provenance['package_lock_sha256'] == hashlib.sha256(b'{}').hexdigest()
    assert provenance['node_version'] == run('node', '--version').stdout.strip()
    assert provenance['built_at'] and provenance['runtime_sha256']['bin/node']
    assert provenance['mind6_dirty'] is False and provenance['nodes_dirty'] is False
    shutil.rmtree(root)
    shutil.rmtree(nodes)
    assert not any(path.is_symlink() for path in output.rglob('*'))
    assert (output / 'node_modules/@verifiably/nodes/dist/index.js').read_text() == 'export const value = 42;'
    assert run(str(output / 'bin/node'), str(output / 'packages/mindful/dist/bin.js')).stdout == '42\n'
    assert run(str(output / 'bin/node'), str(output / 'packages/web/scripts/serve.mjs')).stdout == '42\n'


@pytest.mark.parametrize('problem', ['dirty', 'dirty_nodes', 'stale_nodes', 'exists'])
def test_release_refuses_unreviewed_or_existing_output(checkout, tmp_path, problem):
    root, nodes, env = checkout
    output = tmp_path / 'release'
    if problem == 'dirty':
        write(root / 'unexpected', 'dirty')
    elif problem == 'dirty_nodes':
        write(nodes / 'unexpected', 'dirty')
    elif problem == 'stale_nodes':
        os.utime(nodes / 'src/index.ts', (2000000000, 2000000000))
    else:
        write(output / 'keep', 'previous release')
    result = run(str(REPO / 'bin/mindful-release'), '--checkout', str(root), '--output', str(output), env=env)
    assert result.returncode != 0
    assert not (output / 'provenance.json').exists()
    if problem == 'exists':
        assert (output / 'keep').read_text() == 'previous release'


@pytest.fixture
def backup_case(tmp_path):
    root = tmp_path / 'store'
    for name, value in {'thought/a.md': 'thought\n', '.mindful-history/deleted/1.json': '{"deleted":true}',
                        'config.json': '{"self":"human:test"}', '.nodes-index/cache': 'omit',
                        '.mindful-index/cache': 'omit'}.items():
        write(root / name, value)
    (root / 'thought/relative').symlink_to('./a.md')
    os.link(root / 'thought/a.md', root / 'thought/hardlink')
    release = tmp_path / 'release'
    # A tiny exported lock fixture isolates the cross-repo dependency. Acceptance uses the actual release.
    write(release / 'packages/mindful/package.json', '{"type":"module"}')
    write(release / 'packages/mindful/dist/index.js', '''
import {openSync, closeSync, unlinkSync} from 'node:fs';
export function acquireWriterLock(root, surface) {
  if (surface !== 'cli') throw Error('wrong writer surface');
  const path = root + '/.mindful-index/writer.json';
  const fd = openSync(path, 'wx');
  return {release() { closeSync(fd); unlinkSync(path); if (process.env.RELEASE_FAIL) throw Error('release failed'); }};
}
''')
    mockbin = tmp_path / 'tools'
    executable(mockbin / 'systemctl', '''#!/bin/sh
printf '%s\n' "$*" >> "$SERVICE_LOG"
case "$2" in
show) printf '%s\n' "${SERVICE_STATE:-active}";;
stop) if [ "${STOP_FAIL:-0}" = 1 ]; then echo "stop failed" >&2; exit 1; fi;;
start) if [ "${RESTART_FAIL:-0}" = 1 ]; then echo 'restart failed' >&2; exit 1; fi;;
*) exit 99;;
esac
''')
    env = dict(HOME=os.environ["HOME"], PATH=f'{mockbin}:{os.environ["PATH"]}', SERVICE_LOG=str(tmp_path / 'service.log'))
    output = tmp_path / 'backups'
    command = ['node', str(REPO / 'bin/mindful-backup.mjs'), '--release', str(release), '--root', str(root),
               '--output', str(output), '--service', 'mindful-test.service']
    return root, output, command, env


def test_backup_restore_bytes_attachments_and_previous_archive(backup_case, tmp_path):
    root, output, command, env = backup_case
    attachment = write(tmp_path / 'assets/image.txt', 'attached bytes').parent
    manifest = write(tmp_path / 'attachments.json', json.dumps([{'path': str(attachment), 'name': 'images'}]))
    write(output / 'previous.tar.gz', 'keep old archive')
    result = run(*command, '--attachments', str(manifest), env=env)
    assert result.returncode == 0, result.stderr
    archive = Path(json.loads(result.stdout)['archive'])
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == Path(str(archive) + '.sha256').read_text().split()[0]
    with tarfile.open(archive) as tar:
        tar.extractall(tmp_path / 'restore', filter='data')
    restored = tmp_path / 'restore'
    for name in ['thought/a.md', '.mindful-history/deleted/1.json', 'config.json']:
        assert (restored / 'store' / name).read_bytes() == (root / name).read_bytes()
    assert (restored / 'store/thought/relative').readlink() == Path('a.md')
    assert (restored / 'store/thought/relative').read_bytes() == (root / 'thought/a.md').read_bytes()
    assert (restored / 'store/thought/hardlink').stat().st_ino == (restored / 'store/thought/a.md').stat().st_ino
    assert stat.S_IMODE(archive.stat().st_mode) == 0o600
    assert not (restored / 'store/.nodes-index').exists()
    assert not (restored / 'store/.mindful-index').exists()
    assert (restored / 'attachments/images/image.txt').read_text() == 'attached bytes'
    assert json.loads((restored / 'backup.json').read_text())['attachments'] == [{'path': str(attachment), 'name': 'images'}]
    assert (output / 'previous.tar.gz').read_text() == 'keep old archive'
    assert not (root / '.mindful-index/writer.json').exists()
    assert [line.split()[1] for line in (tmp_path / 'service.log').read_text().splitlines()] == ['show', 'stop', 'start']


@pytest.mark.parametrize('failure', ['archive', 'lock', 'restart', 'archive_and_restart', 'stop', 'release', 'integrity'])
def test_backup_failures_release_lock_and_restore_original_service(backup_case, tmp_path, failure):
    root, output, command, env = backup_case
    write(output / 'previous.tar.gz', 'keep')
    if 'archive' in failure:
        executable(tmp_path / 'tools/tar', '#!/bin/sh\necho "archive failed" >&2\nexit 42\n')
    if failure == 'stop':
        env['STOP_FAIL'] = '1'
    if failure == 'release':
        env['RELEASE_FAIL'] = '1'
    if failure == 'integrity':
        executable(tmp_path / 'tools/gzip', '#!/bin/sh\nif [ "$1" = --test ]; then echo "integrity failed" >&2; exit 1; fi\nexec /usr/bin/gzip "$@"\n')
    if failure == 'lock':
        write(root / '.mindful-index/writer.json', 'other writer')
    if 'restart' in failure:
        env['RESTART_FAIL'] = '1'
    result = run(*command, env=env)
    assert result.returncode != 0
    assert 'start' in (tmp_path / 'service.log').read_text()
    if 'archive' in failure:
        assert 'archive failed' in result.stderr
    if 'restart' in failure:
        assert 'restart failed' in result.stderr
    assert (output / 'previous.tar.gz').read_text() == 'keep'
    assert not list(output.glob('.mindful-backup-*'))
    if failure == 'lock':
        assert (root / '.mindful-index/writer.json').read_text() == 'other writer'
    else:
        assert not (root / '.mindful-index/writer.json').exists()


def test_inactive_service_stays_inactive(backup_case, tmp_path):
    _, _, command, env = backup_case
    env['SERVICE_STATE'] = 'inactive'
    result = run(*command, env=env)
    assert result.returncode == 0, result.stderr
    assert len((tmp_path / 'service.log').read_text().splitlines()) == 1


@pytest.mark.parametrize('names', [['same', 'same'], ['../escape'], ['x/../escape'], ['/absolute']])
def test_attachment_names_refuse_ambiguity_before_stopping_service(backup_case, tmp_path, names):
    _, _, command, env = backup_case
    path = write(tmp_path / 'attachments.json', json.dumps([{'path': str(tmp_path), 'name': name} for name in names]))
    result = run(*command, '--attachments', str(path), env=env)
    assert result.returncode != 0
    assert 'attachment' in result.stderr
    assert not (tmp_path / 'service.log').exists()


def test_release_refuses_insufficient_copy_space(checkout, tmp_path, monkeypatch):
    root, _, _ = checkout
    script = runpy.run_path(str(REPO / 'bin/mindful-release'))
    monkeypatch.setattr(shutil, 'disk_usage', lambda _: shutil._ntuple_diskusage(1, 1, 0))
    # Only npm is external build orchestration; copy/validation/filesystem behavior stays real.
    monkeypatch.setenv('PATH', str(tmp_path / 'tools') + ':' + os.environ['PATH'])
    monkeypatch.setenv('NPM_LOG', str(tmp_path / 'npm.log'))
    with pytest.raises(ValueError, match='insufficient disk space'):
        script['build'](root, tmp_path / 'release')
    assert not (tmp_path / 'release').exists()


def test_launcher_uses_bundled_node_and_explicit_store(tmp_path):
    release = tmp_path / '.local/share/mindful/current'
    executable(release / 'bin/node', '#!/bin/sh\nprintf "%s\n" "$MINDFUL_HOME" "$@"\n')
    env = dict(HOME=str(tmp_path), PATH=os.environ['PATH'])
    result = run(str(REPO / 'bin/mindful'), 'show', 'thought:example', env=env)
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [str(tmp_path / 'd/thoughts'),
        str(release / 'packages/mindful/dist/bin.js'), 'show', 'thought:example']
    env['MINDFUL_HOME'] = str(tmp_path / 'maintenance')
    assert run(str(REPO / 'bin/mindful'), env=env).stdout.splitlines()[0] == env['MINDFUL_HOME']
    shutil.rmtree(release)
    assert run(str(REPO / 'bin/mindful'), env=env).returncode != 0


@pytest.mark.parametrize('signal_number', [signal.SIGTERM, signal.SIGINT])
def test_backup_signal_waits_for_archive_exit_before_unlock_and_restart(backup_case, tmp_path, signal_number):
    root, output, command, env = backup_case
    write(output / 'previous.tar.gz', 'keep')
    marker = tmp_path / 'tar-started'
    ended = tmp_path / 'tar-ended'
    executable(tmp_path / 'tools/tar', f"""#!/usr/bin/env python3
import pathlib, signal, sys, time
marker = pathlib.Path({str(marker)!r})
ended = pathlib.Path({str(ended)!r})
lock = pathlib.Path({str(root / '.mindful-index/writer.json')!r})
def stop(*_):
    ended.write_text('locked' if lock.exists() else 'unlocked too early')
    sys.exit(42)
signal.signal(signal.SIGTERM, stop)
marker.touch()
while True:
    time.sleep(0.05)
""")
    process = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 10
        while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert marker.exists(), 'archive did not start'
        process.send_signal(signal_number)
        _, stderr = process.communicate(timeout=10)
        assert process.returncode != 0, stderr
        assert ended.read_text() == 'locked'
        assert not (root / '.mindful-index/writer.json').exists()
        assert 'start' in (tmp_path / 'service.log').read_text()
        assert (output / 'previous.tar.gz').read_text() == 'keep'
        assert not list(output.glob('.mindful-backup-*'))
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        if marker.exists() and not ended.exists():
            # The failing implementation leaves the child alive; kill only this fixture process.
            subprocess.run(['pkill', '-f', str(tmp_path / 'tools/tar')], check=False)


def test_staged_units_verify_and_web_command_has_canonical_environment(tmp_path):
    if not shutil.which('systemd-analyze'):
        pytest.skip('systemd-analyze is needed to verify Linux user units')
    release = tmp_path / '.local/share/mindful/current'
    executable(release / 'bin/node', '#!/usr/bin/env python3\nimport json, os, sys\nprint(json.dumps({"cwd":os.getcwd(), "args":sys.argv[1:], "host":os.environ["HOST"], "port":os.environ["PORT"], "root":os.environ["MINDFUL_HOME"]}))\n')
    (release / 'packages/web').mkdir(parents=True)
    units = tmp_path / 'units'
    env = dict(PATH=os.environ['PATH'])
    launch = None
    working_directory = None
    for name in ['mindful-web.service', 'mindful-backup.service', 'mindful-backup.timer']:
        contents = (REPO / 'systemd/user' / name).read_text().replace('%h', str(tmp_path))
        write(units / name, contents)
        if name == 'mindful-web.service':
            for line in contents.splitlines():
                if line.startswith('Environment='):
                    key, value = line.removeprefix('Environment=').split('=', 1)
                    env[key] = value
                elif line.startswith('ExecStart='):
                    launch = shlex.split(line.removeprefix('ExecStart='))
                elif line.startswith('WorkingDirectory='):
                    working_directory = line.removeprefix('WorkingDirectory=')
    result = run('systemd-analyze', '--user', 'verify', *map(str, sorted(units.iterdir())))
    assert result.returncode == 0, result.stderr
    assert launch and working_directory
    result = run(*launch, cwd=working_directory, env=env)
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == {'cwd': str(release / 'packages/web'), 'args': ['scripts/serve.mjs'],
        'host': 'localhost', 'port': '3331', 'root': str(tmp_path / 'd/thoughts')}
