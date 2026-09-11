#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "$label"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  [[ "$actual" == "$expected" ]] || fail "${label}: ${actual}"
}

list_output=$(just --justfile "${repo_root}/justfile" --list)

for recipe in check health health-live health-systemd secrets setup-dry-run setup-only test; do
  assert_contains "$list_output" "$recipe" "expected just recipe: $recipe"
done

assert_contains "$(just --justfile "${repo_root}/justfile" --dry-run check 2>&1)" \
  "bin/dotfiles-check" \
  "expected check recipe to run dotfiles-check"
assert_contains "$(just --justfile "${repo_root}/justfile" --dry-run check 2>&1)" \
  "just --fmt --check --justfile justfile" \
  "expected check recipe to validate justfile formatting"

assert_equals "$(just --justfile "${repo_root}/justfile" --dry-run health 2>&1)" \
  "bin/dotfiles-health --skip-systemd --skip-noctalia-ipc" \
  "expected health recipe to run offline-safe health check"
assert_equals "$(just --justfile "${repo_root}/justfile" --dry-run health-live 2>&1)" \
  "bin/dotfiles-health --skip-systemd" \
  "expected health-live recipe to run live plugin checks"
assert_equals "$(just --justfile "${repo_root}/justfile" --dry-run health-systemd 2>&1)" \
  "bin/dotfiles-health" \
  "expected health-systemd recipe to run all runtime checks"

assert_contains "$(just --justfile "${repo_root}/justfile" --dry-run setup-dry-run 2>&1)" \
  "bash setup.sh --dry-run --link-only --headless" \
  "expected setup-dry-run recipe to run safe dry-run setup"

assert_contains "$(just --justfile "${repo_root}/justfile" --dry-run setup-only shell,systemd 2>&1)" \
  "bash setup.sh --dry-run --link-only --headless --only shell,systemd" \
  "expected setup-only recipe to run selected safe dry-run setup phases"

assert_contains "$(just --justfile "${repo_root}/justfile" --dry-run secrets 2>&1)" \
  "bin/dotfiles-secrets-check" \
  "expected secrets recipe to run dotfiles-secrets-check"

test_dry_run=$(just --justfile "${repo_root}/justfile" --dry-run test 2>&1)
assert_contains "$test_dry_run" "zsh tests/dropbox_ignore_flux.zsh" \
  "expected test recipe to include dropbox_ignore_flux tests"
assert_contains "$test_dry_run" "zsh tests/history.zsh" \
  "expected test recipe to include history tests"
assert_contains "$test_dry_run" "zsh tests/secrets_check.zsh" \
  "expected test recipe to include secret-check tests"
assert_contains "$test_dry_run" "zsh tests/setup_and_health.zsh" \
  "expected test recipe to include setup and health tests"
assert_contains "$test_dry_run" "zsh tests/dotfiles_check.zsh" \
  "expected test recipe to include dotfiles check tests"
assert_contains "$test_dry_run" "uv run --frozen pytest -q" \
  "expected test recipe to include Python tests"

print -- "justfile tests passed"
