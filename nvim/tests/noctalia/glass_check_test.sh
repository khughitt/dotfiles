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

# 5. kitty applies the final directive, so duplicates must fail
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
echo 'transparent_background_colors #111111' >> "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: duplicate directive must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 6. current must be the syncer's sibling v-* symlink, not a directory
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
target=$(readlink "$TMP/nvim-glass/current")
rm "$TMP/nvim-glass/current"
mkdir "$TMP/nvim-glass/current"
cp "$TMP/nvim-glass/$target/nvim-palette.json" "$TMP/nvim-glass/current/"
cp "$TMP/nvim-glass/$target/kitty-glass.conf" "$TMP/nvim-glass/current/"
if out=$("$CHECK" 2>&1); then echo "FAIL: directory current must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }
rm -r "$TMP/nvim-glass/current"

# 7. absolute and escaping targets are not sibling version directories
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
target=$(readlink "$TMP/nvim-glass/current")
rm "$TMP/nvim-glass/current"
ln -s "$TMP/nvim-glass/$target" "$TMP/nvim-glass/current"
if out=$("$CHECK" 2>&1); then echo "FAIL: absolute current target must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }
rm "$TMP/nvim-glass/current"
ln -s "../nvim-glass/$target" "$TMP/nvim-glass/current"
if out=$("$CHECK" 2>&1); then echo "FAIL: escaping current target must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 8. malformed palette shape: a clean FAIL: line, never a traceback
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
echo '{"glass": []}' > "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: malformed shape must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 9. aliases that would consume an eighth kitty slot must fail
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
sed -i 's/"tab_on": "#1e2030"/"tab_on": "#222436"/' \
  "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: alias drift must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 10. matching palette/kitty edits still cannot change Claude's native colors
cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
sed -i 's/#022800/#012345/g' "$TMP/nvim-glass/current/nvim-palette.json" \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: changed native diff color must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

echo "OK glass_check"
