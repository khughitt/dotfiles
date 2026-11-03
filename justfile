set dotenv-load := false
set positional-arguments
set quiet

tt := "python3 tools/tt"
test_cmd := "python3 tools/test-suite.py full"
resource_alert_cmd := "python3 tools/test-suite.py resource-alert"
check_hygiene_cmd := "just --fmt --check --justfile justfile && tools/check-hygiene && tasks check"
check_code_cmd := "tools/check-code"
ci_remote := "origin"
ci_suite_refs := ""
# Tests read configuration and documentation: retain normal hygiene for every commit.
docs_paths := ""

default:
    @just --list

check-hygiene:
    {{ tt }} check-hygiene -- sh -c '{{ check_hygiene_cmd }}'

check-code:
    {{ tt }} check-code -- sh -c '{{ check_code_cmd }}'

check:
    just check-hygiene
    just check-code

health:
    bin/dotfiles-health --skip-systemd --skip-noctalia-ipc

health-live:
    bin/dotfiles-health --skip-systemd

health-systemd:
    bin/dotfiles-health

preflight:
    bash setup.sh --check

setup-dry-run:
    bash setup.sh --dry-run --link-only --headless

setup-only phases:
    bash setup.sh --dry-run --link-only --headless --only "$1"

secrets:
    bin/dotfiles-secrets-check

test-one +args:
    {{ tt }} test-one -- tools/test-one "$@" 2>&1

# Deliberate component check; this is not a whole-project request.
test-resource-alert:
    {{ tt }} test-resource-alert -- sh -c '{{ resource_alert_cmd }}'

test:
    {{ tt }} test -- sh -c '{{ test_cmd }}'

test-full:
    TT_FORCE=1 just test

gate:
    just check
    just test

verify: check test health

hook-pre-commit:
    {{ tt }} hook-pre-commit -- sh -c '{{ check_hygiene_cmd }}'
    just check-code

hook-pre-commit-docs:
    {{ tt }} hook-pre-commit-docs -- sh -c '{{ check_hygiene_cmd }}'

hook-pre-push:
    {{ tt }} hook-pre-push -- sh -c '{{ check_hygiene_cmd }}'
    just check-code
    just test

# There is no affected selector: both push routes request the same full suite.
hook-pre-push-fast:
    {{ tt }} hook-pre-push-fast -- sh -c '{{ check_hygiene_cmd }}'
    just check-code
    just test
