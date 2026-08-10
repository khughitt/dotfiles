#!/usr/bin/env bash
# nvim/tests/noctalia/glass_sync_test.sh — run from repo root
set -euo pipefail

SYNC="$PWD/bin/noctalia-glass-sync"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export NOCTALIA_GLASS_DIR="$TMP"
CUR="$TMP/nvim-glass/current"

good_candidate() {
  cp nvim/tests/noctalia/fixtures/raw_palette.json "$TMP/nvim-palette.candidate.json"
}

# 1. success: current symlink appears, both files inside, candidate consumed
good_candidate
"$SYNC" --no-signal
[[ -L "$CUR" ]] || { echo "FAIL: current symlink missing"; exit 1; }
[[ -f "$CUR/nvim-palette.json" && -f "$CUR/kitty-glass.conf" ]] || { echo "FAIL: staged files missing"; exit 1; }
[[ ! -f "$TMP/nvim-palette.candidate.json" ]] || { echo "FAIL: candidate left behind"; exit 1; }
grep -q '^transparent_background_colors #1e2030 #2f334d #222436 #272a3f #2c3048 #3b4261$' \
  "$CUR/kitty-glass.conf" || { echo "FAIL: kitty conf wrong"; cat "$CUR/kitty-glass.conf"; exit 1; }

# 2. second success: symlink flips, exactly one version dir remains
first_target=$(readlink "$CUR")
good_candidate
sed -i 's/#82aaff/#83abff/' "$TMP/nvim-palette.candidate.json"
"$SYNC" --no-signal
[[ "$(readlink "$CUR")" != "$first_target" ]] || { echo "FAIL: symlink did not flip"; exit 1; }
grep -q '#83abff' "$CUR/nvim-palette.json" || { echo "FAIL: new palette not promoted"; exit 1; }
ndirs=$(find "$TMP/nvim-glass" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ "$ndirs" == 1 ]] || { echo "FAIL: expected 1 version dir, got $ndirs"; exit 1; }

# helper: run sync expecting failure, assert current untouched
expect_reject() {
  local why=$1
  local before=$(readlink "$CUR")
  if "$SYNC" --no-signal 2>/dev/null; then echo "FAIL: accepted $why"; exit 1; fi
  [[ "$(readlink "$CUR")" == "$before" ]] || { echo "FAIL: current moved on $why"; exit 1; }
}

# 3. missing candidate
expect_reject "missing candidate"

# 4. invalid JSON syntax
echo '{ not json' > "$TMP/nvim-palette.candidate.json"
expect_reject "broken JSON"

# 5. missing accent key (complete-artifact validation, not just glass)
good_candidate
python3 - "$TMP/nvim-palette.candidate.json" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['tertiary']
json.dump(d, open(p, 'w'))
EOF
expect_reject "missing accent key"

# 6. colliding glass tones
good_candidate
sed -i 's/"tab_on": "#222436"/"tab_on": "#1e2030"/' "$TMP/nvim-palette.candidate.json"
expect_reject "glass collision"

# 7. float equal to a registered tone
good_candidate
sed -i 's/"float": "#16161e"/"float": "#3b4261"/' "$TMP/nvim-palette.candidate.json"
expect_reject "registered float"

# 8. float equal to surface
good_candidate
sed -i 's/"float": "#16161e"/"float": "#222436"/' "$TMP/nvim-palette.candidate.json"
expect_reject "float==surface"

# 9. candidate I/O error uses the clean failure path, not a traceback
rm -f "$TMP/nvim-palette.candidate.json"
mkdir "$TMP/nvim-palette.candidate.json"
before=$(readlink "$CUR")
if err=$("$SYNC" --no-signal 2>&1); then
  echo "FAIL: accepted unreadable candidate"
  exit 1
fi
[[ "$(readlink "$CUR")" == "$before" ]] || { echo "FAIL: current moved on candidate I/O error"; exit 1; }
grep -q '^noctalia-glass-sync:' <<<"$err" || { echo "FAIL: missing clean error prefix"; exit 1; }
! grep -q 'Traceback' <<<"$err" || { echo "FAIL: candidate I/O error produced traceback"; exit 1; }

echo "OK glass_sync"
