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

promote() {
  cp nvim/tests/noctalia/fixtures/raw_palette.json \
    "$TMP/nvim-palette.candidate.json"
  "$SYNC" --no-signal
}

# Old two-consumer generation: FAIL with the migration remedy.
rm "$TMP/nvim-glass/current/opencode-theme.json"
if out=$("$CHECK" 2>&1); then
  echo "FAIL: old generation must fail"
  exit 1
fi
[[ "$out" == FAIL:*"format changed"*"re-render"* ]] || {
  echo "FAIL: missing old-generation remedy: $out"
  exit 1
}

# Malformed OpenCode JSON: clean FAIL, no traceback.
promote
echo '{ broken' > "$TMP/nvim-glass/current/opencode-theme.json"
if out=$("$CHECK" 2>&1); then
  echo "FAIL: malformed OpenCode theme must fail"
  exit 1
fi
[[ "$out" == FAIL:* && "$out" != *Traceback* ]] || {
  echo "FAIL: malformed theme did not use clean failure: $out"
  exit 1
}

# Complete-key and exact-background contracts.
promote
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['theme']['syntaxOperator']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: incomplete OpenCode theme must fail"
  exit 1
fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL line: $out"; exit 1; }

# A missing mapped non-glass palette key must cleanly FAIL, never traceback.
promote
python3 - "$TMP/nvim-glass/current/nvim-palette.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['primary']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: missing mapped palette key must fail"
  exit 1
fi
[[ "$out" == FAIL:* && "$out" != *Traceback* ]] || {
  echo "FAIL: mapped-key failure was not clean: $out"
  exit 1
}

promote
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['theme']['backgroundPanel'] = '#111111'
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: OpenCode background drift must fail"
  exit 1
fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL line: $out"; exit 1; }

promote
sed -i 's/"outline": "#636da6"/"outline": "#3b4261"/' \
  "$TMP/nvim-glass/current/nvim-palette.json"
python3 - "$TMP/nvim-glass/current/opencode-theme.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['theme']['border'] = d['theme']['backgroundMenu']
json.dump(d, open(p, 'w'))
PY
if out=$("$CHECK" 2>&1); then
  echo "FAIL: invisible OpenCode menu border must fail"
  exit 1
fi
[[ "$out" == FAIL:*"border is invisible on backgroundMenu"* ]] || {
  echo "FAIL: wrong invisible-border failure: $out"
  exit 1
}

# 3. generated selection foreground must equal the promoted palette: FAIL
promote
sed -i 's/^selection_foreground .*/selection_foreground #111111/' \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: selection foreground desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 4. generated selection background must equal the promoted palette: FAIL
promote
sed -i 's/^selection_background .*/selection_background #111111/' \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: selection background desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 5. partial state (palette missing): FAIL — this is the case the old
#    dotfiles-check guard silently skipped
promote
rm "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: partial state must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 6. desynced tones: FAIL
promote
sed -i 's/#1e2030/#111111/' "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: desync must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 7. kitty applies the final directive, so duplicates must fail
promote
echo 'transparent_background_colors #111111' >> "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: duplicate directive must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 8. current must be the syncer's sibling v-* symlink, not a directory
promote
target=$(readlink "$TMP/nvim-glass/current")
rm "$TMP/nvim-glass/current"
mkdir "$TMP/nvim-glass/current"
cp "$TMP/nvim-glass/$target/nvim-palette.json" "$TMP/nvim-glass/current/"
cp "$TMP/nvim-glass/$target/kitty-glass.conf" "$TMP/nvim-glass/current/"
if out=$("$CHECK" 2>&1); then echo "FAIL: directory current must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }
rm -r "$TMP/nvim-glass/current"

# 9. absolute and escaping targets are not sibling version directories
promote
target=$(readlink "$TMP/nvim-glass/current")
rm "$TMP/nvim-glass/current"
ln -s "$TMP/nvim-glass/$target" "$TMP/nvim-glass/current"
if out=$("$CHECK" 2>&1); then echo "FAIL: absolute current target must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

promote
target=$(readlink "$TMP/nvim-glass/current")
rm "$TMP/nvim-glass/current"
ln -s "../nvim-glass/$target" "$TMP/nvim-glass/current"
if out=$("$CHECK" 2>&1); then echo "FAIL: escaping current target must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 10. malformed palette shape: a clean FAIL: line, never a traceback
promote
echo '{"glass": []}' > "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: malformed shape must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 11. aliases that would consume an eighth kitty slot must fail
promote
sed -i 's/"tab_on": "#1e2030"/"tab_on": "#222436"/' \
  "$TMP/nvim-glass/current/nvim-palette.json"
if out=$("$CHECK" 2>&1); then echo "FAIL: alias drift must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

# 12. matching palette/kitty edits still cannot change Claude's native colors
promote
sed -i 's/#022800/#012345/g' "$TMP/nvim-glass/current/nvim-palette.json" \
  "$TMP/nvim-glass/current/kitty-glass.conf"
if out=$("$CHECK" 2>&1); then echo "FAIL: changed native diff color must fail"; exit 1; fi
[[ "$out" == FAIL:* ]] || { echo "FAIL: expected FAIL: line, got: $out"; exit 1; }

echo "OK glass_check"
