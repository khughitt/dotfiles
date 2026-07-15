set dotenv-load := false

default:
    @just --list

check:
    just --fmt --check --justfile justfile
    bin/dotfiles-check

health:
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
    zsh tests/dropbox_ignore_flux.zsh
    zsh tests/history.zsh
    zsh tests/secrets_check.zsh
    zsh tests/setup_and_health.zsh
    zsh tests/dotfiles_check.zsh
    zsh tests/wali.zsh
    zsh tests/justfile.zsh

verify: check test health
