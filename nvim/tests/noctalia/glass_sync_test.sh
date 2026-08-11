#!/usr/bin/env bash
# nvim/tests/noctalia/glass_sync_test.sh — run from repo root
set -euo pipefail

SYNC="$PWD/bin/noctalia-glass-sync"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export NOCTALIA_GLASS_DIR="$TMP"
CUR="$TMP/nvim-glass/current"
CANDIDATE="$TMP/nvim-palette.candidate.json"
FAKE_BIN="$TMP/fake-bin"
export PKILL_LOG="$TMP/pkill.log"

good_candidate() {
  cp nvim/tests/noctalia/fixtures/raw_palette.json "$CANDIDATE"
}

snapshot_versions() {
  find "$TMP/nvim-glass" -mindepth 1 -maxdepth 1 -type d -name 'v-*' -printf '%f\n' | sort
}

make_fake_pkill() {
  mkdir -p "$FAKE_BIN"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$PKILL_LOG"' \
    'exit "${PKILL_RC:-0}"' > "$FAKE_BIN/pkill"
  chmod +x "$FAKE_BIN/pkill"
  export PATH="$FAKE_BIN:$PATH"
}

expect_reject() {
  local why=$1 before versions candidate_state candidate_copy err
  before=$(readlink "$CUR")
  versions=$(snapshot_versions)
  if [[ -f "$CANDIDATE" ]]; then
    candidate_state=file
    candidate_copy="$TMP/candidate-before"
    cp "$CANDIDATE" "$candidate_copy"
  elif [[ -d "$CANDIDATE" ]]; then
    candidate_state=directory
  else
    candidate_state=missing
  fi
  if err=$("$SYNC" --no-signal 2>&1); then
    echo "FAIL: accepted $why"
    exit 1
  fi
  grep -q '^noctalia-glass-sync:' <<<"$err" || { echo "FAIL: missing clean prefix for $why"; exit 1; }
  ! grep -q 'Traceback' <<<"$err" || { echo "FAIL: traceback for $why"; exit 1; }
  [[ "$(readlink "$CUR")" == "$before" ]] || { echo "FAIL: current moved on $why"; exit 1; }
  [[ "$(snapshot_versions)" == "$versions" ]] || { echo "FAIL: version dirs changed on $why"; exit 1; }
  case "$candidate_state" in
    file) cmp "$candidate_copy" "$CANDIDATE" || { echo "FAIL: candidate changed on $why"; exit 1; } ;;
    directory) [[ -d "$CANDIDATE" ]] || { echo "FAIL: candidate directory changed on $why"; exit 1; } ;;
    missing) [[ ! -e "$CANDIDATE" ]] || { echo "FAIL: missing candidate changed on $why"; exit 1; } ;;
  esac
}

make_fake_pkill

# 1. success: current symlink appears, both files inside, candidate consumed
good_candidate
"$SYNC" --no-signal
[[ -L "$CUR" ]] || { echo "FAIL: current symlink missing"; exit 1; }
target=$(readlink "$CUR")
[[ "$target" == v-* && "$target" != */* ]] || { echo "FAIL: current target is not a sibling v-* dir"; exit 1; }
[[ -f "$CUR/nvim-palette.json" && -f "$CUR/kitty-glass.conf" ]] || { echo "FAIL: staged files missing"; exit 1; }
cmp nvim/tests/noctalia/fixtures/raw_palette.json "$CUR/nvim-palette.json" || { echo "FAIL: palette bytes changed"; exit 1; }
[[ ! -e "$CANDIDATE" ]] || { echo "FAIL: candidate left behind"; exit 1; }
[[ "$(wc -l < "$CUR/kitty-glass.conf")" == 1 ]] || { echo "FAIL: kitty conf has extra lines"; exit 1; }
grep -qx 'transparent_background_colors #1e2030 #2f334d #272a3f #3b4261 #022800@0.72 #3d0100@0.72 #003dbe@0.55' \
  "$CUR/kitty-glass.conf" || { echo "FAIL: kitty conf wrong"; cat "$CUR/kitty-glass.conf"; exit 1; }
[[ ! -e "$PKILL_LOG" ]] || { echo "FAIL: --no-signal invoked pkill"; exit 1; }

# 2. second success: symlink flips, only v-* versions prune, other directories persist
mkdir "$TMP/nvim-glass/keep"
printf 'keep\n' > "$TMP/nvim-glass/keep/marker"
first_target=$target
good_candidate
sed -i 's/#82aaff/#83abff/' "$CANDIDATE"
cp "$CANDIDATE" "$TMP/expected-palette.json"
"$SYNC" --no-signal
target=$(readlink "$CUR")
[[ "$target" != "$first_target" ]] || { echo "FAIL: symlink did not flip"; exit 1; }
[[ "$target" == v-* && "$target" != */* ]] || { echo "FAIL: current target is not a sibling v-* dir"; exit 1; }
cmp "$TMP/expected-palette.json" "$CUR/nvim-palette.json" || { echo "FAIL: new palette bytes changed"; exit 1; }
[[ "$(snapshot_versions | wc -l)" == 1 ]] || { echo "FAIL: expected one v-* dir"; exit 1; }
[[ -f "$TMP/nvim-glass/keep/marker" ]] || { echo "FAIL: non-v-* directory was pruned"; exit 1; }

# 3. missing candidate
expect_reject "missing candidate"

# 4. invalid JSON syntax
echo '{ not json' > "$CANDIDATE"
expect_reject "broken JSON"

# 5. invalid JSON encoding
printf '\xff' > "$CANDIDATE"
expect_reject "invalid JSON encoding"

# 6. missing accent key (complete-artifact validation, not just glass)
good_candidate
python3 - "$CANDIDATE" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d['tertiary']
json.dump(d, open(p, 'w'))
EOF
expect_reject "missing accent key"

# 7. Missing selection foreground is a complete-artifact failure.
good_candidate
python3 - "$CANDIDATE" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['glass'].pop('selection_fg', None)
json.dump(d, open(p, 'w'))
EOF
expect_reject "missing selection foreground"

# 8. colliding registered glass tones
good_candidate
sed -i 's/"cursorline": "#2f334d"/"cursorline": "#1e2030"/' "$CANDIDATE"
expect_reject "glass collision"

# 9. UI aliases must remain explicit
good_candidate
sed -i 's/"tab_on": "#1e2030"/"tab_on": "#222436"/' "$CANDIDATE"
expect_reject "tab_on alias mismatch"

# 10. Claude native diff cell colors are a fixed Kitty interoperability contract
good_candidate
sed -i 's/"diff_added": "#022800"/"diff_added": "#012345"/' "$CANDIDATE"
expect_reject "changed native diff color"

# 11. float equal to a registered tone
good_candidate
sed -i 's/"float": "#16161e"/"float": "#3b4261"/' "$CANDIDATE"
expect_reject "registered float"

# 12. float equal to surface
good_candidate
sed -i 's/"float": "#16161e"/"float": "#222436"/' "$CANDIDATE"
expect_reject "float==surface"

# 13. candidate I/O error uses the clean failure path, not a traceback
rm -f "$CANDIDATE"
mkdir "$CANDIDATE"
expect_reject "unreadable candidate"
rm -r "$CANDIDATE"

# 14. staging failure removes this run's temporary version and preserves prior state
good_candidate
chmod u-w "$TMP/nvim-glass"
expect_reject "unstageable version directory"
chmod u+w "$TMP/nvim-glass"

# 15. signal failure is post-commit: promotion remains visible and candidate is consumed
good_candidate
cp "$CANDIDATE" "$TMP/expected-post-commit.json"
before=$(readlink "$CUR")
if err=$(PKILL_RC=2 "$SYNC" 2>&1); then
  echo "FAIL: accepted failing pkill"
  exit 1
fi
grep -q '^noctalia-glass-sync:' <<<"$err" || { echo "FAIL: missing clean prefix for pkill failure"; exit 1; }
! grep -q 'Traceback' <<<"$err" || { echo "FAIL: traceback for pkill failure"; exit 1; }
[[ "$(readlink "$CUR")" != "$before" ]] || { echo "FAIL: post-commit failure rolled back current"; exit 1; }
cmp "$TMP/expected-post-commit.json" "$CUR/nvim-palette.json" || { echo "FAIL: post-commit palette not promoted"; exit 1; }
[[ ! -e "$CANDIDATE" ]] || { echo "FAIL: post-commit candidate not consumed"; exit 1; }
grep -qx -- '-SIGUSR1 -x kitty' "$PKILL_LOG" || { echo "FAIL: fake pkill did not receive kitty signal"; exit 1; }
! grep -qx -- '-SIGUSR1 -x nvim' "$PKILL_LOG" || { echo "FAIL: pkill continued after failure"; exit 1; }

echo "OK glass_sync"
