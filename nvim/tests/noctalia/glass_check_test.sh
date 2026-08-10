#!/usr/bin/env bash
# nvim/tests/noctalia/glass_check_test.sh — run from repo root
set -euo pipefail

CHECK="$PWD/bin/noctalia-glass-check"
SYNC="$PWD/bin/noctalia-glass-sync"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export NOCTALIA_GLASS_DIR="$TMP"

# 1. fresh machine (no current symlink at all): OK
"$CHECK" || { echo "FAIL: fresh state must pass"; exit 1; }

# 2. healthy promoted state: OK
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
"$CHECK" || { echo "FAIL: healthy state must pass"; exit 1; }

# 3. partial state (palette missing): FAIL — this is the case the old
#    dotfiles-check guard silently skipped
rm "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: partial state must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 4. desynced tones: FAIL
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
sed -i 's/#1e2030/#111111/' "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 5. malformed palette shape: a clean FAIL: line, never a traceback
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
echo '{"glass": []}' > "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: malformed shape must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

echo "OK glass_check"
