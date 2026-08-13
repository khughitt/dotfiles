#!/usr/bin/env python3
import hashlib
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIGRATE = ROOT / "bin/opencode-config-migrate"


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def snapshot(root):
    result = {}
    if not os.path.lexists(root):
        return result
    if root.is_symlink():
        return {".": ("link", os.readlink(root))}
    for path in [root, *sorted(root.rglob("*"))]:
        rel = "." if path == root else str(path.relative_to(root))
        if path.is_symlink():
            result[rel] = ("link", os.readlink(path))
        elif path.is_dir():
            result[rel] = ("dir",)
        else:
            result[rel] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
    return result


with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    source = base / "physical/dotfiles/opencode"
    alias_root = base / "home/d"
    local = base / "home/.config/opencode.local"
    config = base / "home/.config/opencode"
    theme = base / "home/.cache/noctalia/nvim-glass/current/opencode-theme.json"
    source.mkdir(parents=True)
    alias_root.parent.mkdir(parents=True)
    alias_root.symlink_to(base / "physical/dotfiles", target_is_directory=True)
    config.parent.mkdir(parents=True)
    config.symlink_to(alias_root / "opencode", target_is_directory=True)
    write(source / "opencode.json", "{}\n")
    write(source / "tui.json", "{}\n")
    write(source / "package.json", "same\n")
    write(source / ".gitignore", "runtime ignore\n")
    write(source / "node_modules/pkg/index.js", "runtime\n")
    write(source / "themes/noctalia.json", "obsolete\n")
    write(local / "package.json", "same\n")
    write(local / "destination-only", "keep\n")

    subprocess.run(
        [MIGRATE, source, source, config, local, theme], check=True, text=True)
    assert config.is_symlink() and config.resolve() == local.resolve()
    assert (local / "opencode.json").resolve() == (source / "opencode.json").resolve()
    assert (local / "tui.json").resolve() == (source / "tui.json").resolve()
    assert os.readlink(local / "themes/noctalia.json") == str(theme)
    assert (local / "node_modules/pkg/index.js").read_text() == "runtime\n"
    assert (local / ".gitignore").read_text() == "runtime ignore\n"
    assert (local / "destination-only").read_text() == "keep\n"
    assert not (source / "package.json").exists()
    assert not (source / ".gitignore").exists()
    assert not (source / "node_modules").exists()
    assert not (source / "themes/noctalia.json").exists()
    assert (source / "opencode.json").is_file()
    assert (source / "tui.json").is_file()

    # Reruns accept the already-active layout.
    subprocess.run(
        [MIGRATE, source, source, config, local, theme], check=True, text=True)

with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    source = base / "repo/opencode"
    local = base / "home/.config/opencode.local"
    config = base / "home/.config/opencode"
    theme = base / "home/.cache/noctalia/nvim-glass/current/opencode-theme.json"
    write(source / "opencode.json", "{}\n")
    write(source / "tui.json", "{}\n")
    write(source / "one", "source one\n")
    write(source / "two", "source two\n")
    write(local / "one", "destination one\n")
    write(local / "two", "destination two\n")
    config.parent.mkdir(parents=True, exist_ok=True)
    config.symlink_to(source, target_is_directory=True)
    before_source = snapshot(source)
    before_local = snapshot(local)
    before_config = snapshot(config)
    result = subprocess.run(
        [MIGRATE, source, source, config, local, theme], text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode != 0
    assert "one" in result.stdout and "two" in result.stdout, result.stdout
    assert snapshot(source) == before_source
    assert snapshot(local) == before_local
    assert snapshot(config) == before_config

print("OK opencode config migration")
