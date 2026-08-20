set dotenv-load := false

default:
    @just --list

check:
    just --fmt --check --justfile justfile
    bin/dotfiles-check

health:
    bin/dotfiles-health --skip-systemd --skip-noctalia-ipc

health-live:
    bin/dotfiles-health --skip-systemd

health-systemd:
    bin/dotfiles-health

setup-dry-run:
    bash setup.sh --dry-run --link-only --headless

setup-only phases:
    bash setup.sh --dry-run --link-only --headless --only {{ phases }}

secrets:
    bin/dotfiles-secrets-check

test:
    uv run --frozen pytest -q
    zsh tests/dropbox_ignore_flux.zsh
    zsh tests/history.zsh
    zsh tests/secrets_check.zsh
    zsh tests/setup_and_health.zsh
    zsh tests/dotfiles_check.zsh
    zsh tests/wali.zsh
    zsh tests/justfile.zsh
    @command -v lua >/dev/null || { echo 'lua is required for the Noctalia plugin tests' >&2; exit 127; }
    lua noctalia/plugins/wali-panel/plugin_test.lua

verify: check test health
