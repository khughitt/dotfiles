#!/usr/bin/env bash
set -euo pipefail

output=$(bin/noctalia-mood-swatches)
[[ $output == *$'\033[48;2;'* ]] || {
  printf 'missing raw truecolor escape in stdout\n' >&2
  exit 1
}
[[ $output != *'^['* ]] || {
  printf 'stdout contains sanitized escape\n' >&2
  exit 1
}

echo "OK mood_swatches"
