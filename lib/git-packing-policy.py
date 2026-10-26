#!/usr/bin/env python3
"""Render and verify the host-local include for synced Git packing defaults."""
import os
from pathlib import Path
import stat
import sys
import tempfile

MARKER = b'# Managed by dotfiles git-packing-policy\n'
POLICY = b'[gc]\n    packRefs = false\n[maintenance "pack-refs"]\n    enabled = false\n'


def quoted(value):
    value.encode('utf-8')
    if any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError('control characters in root/source path are unsupported')
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def render_policy(home: Path, source: Path) -> bytes:
    root = (home / 'd').resolve(strict=True)
    policy = source.resolve(strict=True) / 'git/synced-packing'
    if not root.is_dir():
        raise ValueError('~/d must resolve to a directory')
    if policy.read_bytes() != POLICY:
        raise ValueError('tracked git/synced-packing differs from the required two-setting policy')
    # Git parses config quoting before its gitdir wildmatch pattern.
    pattern = 'gitdir:' + ''.join('\\' + c if c in '\\*?[]' else c for c in str(root)) + '/'
    return MARKER + ('[includeIf ' + quoted(pattern) + ']\n    path = ' + quoted(str(policy)) + '\n').encode('utf-8')


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[0] not in ('write', 'check'):
        print('git-packing-policy: expected write|check <home> <source>', file=sys.stderr)
        return 1
    temporary = None
    try:
        mode, home, source = argv[0], Path(argv[1]).resolve(strict=True), Path(argv[2])
        data = render_policy(home, source)
        target = home / '.gitconfig-synced'
        previous = None
        try:
            info = target.lstat()
        except FileNotFoundError:
            pass
        else:
            if not stat.S_ISREG(info.st_mode):
                raise ValueError('~/.gitconfig-synced must be a regular managed file; refusing replacement')
            with os.fdopen(os.open(target, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as stream:
                previous = stream.read(len(data) + 1)
            if not previous.startswith(MARKER):
                raise ValueError('~/.gitconfig-synced is unowned; refusing replacement')
        if previous == data:
            return 0
        if mode == 'check':
            raise ValueError('~/.gitconfig-synced is missing or stale; run the approved narrow write invocation')
        with tempfile.NamedTemporaryFile(dir=home, prefix='.gitconfig-synced.', delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        return 0
    except (OSError, ValueError, RuntimeError, UnicodeError) as exc:
        reason = str(exc) if isinstance(exc, (ValueError, RuntimeError)) else 'filesystem access failed; inspect ~/d, policy source and ~/.gitconfig-synced'
        print('git-packing-policy: ' + reason[:300], file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
