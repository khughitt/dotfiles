#!/usr/bin/env bash
set -euo pipefail

DOTS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$DOTS_HOME"

[[ ! -e nvim.log ]] || { echo 'FAIL: remove existing nvim.log first' >&2; exit 1; }

TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_TMP/runtime" "$TEST_TMP/state" "$TEST_TMP/cache"
export XDG_RUNTIME_DIR="$TEST_TMP/runtime"
export XDG_STATE_HOME="$TEST_TMP/state"
export XDG_CACHE_HOME="$TEST_TMP/cache"

for test in nvim/tests/noctalia/*_test.lua; do
  nvim --clean -l "$test"
done

for test in nvim/tests/noctalia/*_test.sh; do
  "$test"
done

[[ ! -e nvim.log ]] || { echo 'FAIL: tests created nvim.log' >&2; exit 1; }
echo 'OK noctalia suite'
