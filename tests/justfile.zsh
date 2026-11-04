#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"
fixture_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-just.XXXXXX")
register_tmp_cleanup "$fixture_home"

run_just() {
  env -i PATH="$PATH" HOME="$fixture_home" USER=recipe-fixture \
    XDG_CONFIG_HOME="$fixture_home/config" XDG_DATA_HOME="$fixture_home/data" \
    XDG_CACHE_HOME="$fixture_home/cache" XDG_STATE_HOME="$fixture_home/state" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    TT_LOG="$fixture_home/runs.jsonl" \
    just --justfile "${repo_root}/justfile" "$@"
}

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

list_output=$(run_just --list)

for recipe in check check-hygiene check-code gate test-one test-full health health-live health-systemd secrets setup-dry-run setup-only test test-resource-alert; do
  assert_contains "$list_output" "$recipe" "expected just recipe: $recipe"
done

assert_contains "$(run_just --dry-run check 2>&1)" \
  "just check-hygiene" \
  "expected check recipe to request hygiene"
assert_contains "$(run_just --dry-run check 2>&1)" \
  "just check-code" \
  "expected check recipe to request code checks"

assert_equals "$(run_just --dry-run health 2>&1)" \
  "bin/dotfiles-health --skip-systemd --skip-noctalia-ipc" \
  "expected health recipe to run offline-safe health check"
assert_equals "$(run_just --dry-run health-live 2>&1)" \
  "bin/dotfiles-health --skip-systemd" \
  "expected health-live recipe to run live plugin checks"
assert_equals "$(run_just --dry-run health-systemd 2>&1)" \
  "bin/dotfiles-health" \
  "expected health-systemd recipe to run all runtime checks"

assert_contains "$(run_just --dry-run setup-dry-run 2>&1)" \
  "bash setup.sh --dry-run --link-only --headless" \
  "expected setup-dry-run recipe to run safe dry-run setup"

assert_contains "$(run_just --dry-run setup-only shell,systemd 2>&1)" \
  'bash setup.sh --dry-run --link-only --headless --only "$1"' \
  "expected setup-only recipe to run selected safe dry-run setup phases"

assert_contains "$(run_just --dry-run secrets 2>&1)" \
  "bin/dotfiles-secrets-check" \
  "expected secrets recipe to run dotfiles-secrets-check"

test_dry_run=$(run_just --dry-run test 2>&1)
assert_contains "$test_dry_run" "python3 tools/test-suite.py full" \
  "expected test recipe to use the complete recorded inventory"

print -- "justfile tests passed"
