#!/usr/bin/env zsh
# Exercises bin/work-link against temporary trees: a fake ~/d, a fake WORK_ROOT,
# real git repositories and worktrees. HOME and GIT_CONFIG_GLOBAL point away from
# the host so no global excludes or hooks mask a repository's own ignore rules.
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"
work_link="${repo_root}/bin/work-link"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

make_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/work-link.XXXXXX"
}

# A sandbox: $HOME/d is the scan root, $WORK is the storage. Exports HOME,
# WORK_ROOT, SANDBOX (the temp root), and git isolation for the commands that
# follow. Never call it in a subshell: the exports must reach the test.
sandbox() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  export SANDBOX="$tmp"
  export HOME="${tmp}/home"
  export WORK="${tmp}/work"
  export WORK_ROOT="$WORK"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  mkdir -p "${HOME}/d" "$WORK"
}

# A repository at $HOME/d/<rel> with a first commit and bare-name ignore rules.
make_repo() {
  local rel="$1" dir="${HOME}/d/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '.worktrees\n.venv\ntarget\n' > "${dir}/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m init
  print -- "$dir"
}

run_work_link() {
  local out rc=0
  out=$("$work_link" "$@" 2>&1) || rc=$?
  print -- "$out"
  return $rc
}

test_migrate_moves_and_links() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv/lib" "${repo}/target/debug" "${repo}/data/target"
  touch "${repo}/.venv/lib/x.py" "${repo}/target/debug/bin" "${repo}/Cargo.toml"

  local out
  out=$(run_work_link --migrate "${repo}") || fail "migrate exited non-zero: $out"
  [[ -L "${repo}/.venv" && "$(readlink "${repo}/.venv")" == "${WORK}/proj/.venv" ]] || fail ".venv not linked: $out"
  [[ -f "${WORK}/proj/.venv/lib/x.py" ]] || fail ".venv content not moved"
  [[ -L "${repo}/target" && -f "${WORK}/proj/target/debug/bin" ]] || fail "cargo target not moved: $out"
  [[ -d "${repo}/data/target" && ! -L "${repo}/data/target" ]] || fail "target without Cargo.toml must stay"

  out=$(run_work_link "${repo}") || fail "converge after migrate should be clean: $out"
  [[ -z "$out" ]] || fail "converge after migrate should print nothing, got: $out"
}

test_nested_rel_path() {
  sandbox
  local repo; repo=$(make_repo group/sub/proj)
  mkdir -p "${repo}/.venv"
  run_work_link --migrate "${repo}" >/dev/null || fail "nested migrate"
  [[ "$(readlink "${repo}/.venv")" == "${WORK}/group/sub/proj/.venv" ]] || fail "nested rel path"
}

test_converge_relinks_when_intree_absent() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${WORK}/proj/.venv/lib"
  local out
  out=$(run_work_link "${repo}") || fail "relink should exit 0: $out"
  [[ "$out" == relinked* ]] || fail "expected relinked, got: $out"
  [[ -L "${repo}/.venv" && -d "${repo}/.venv/lib" ]] || fail "link not created"
}

test_converge_reports_without_writing() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv" "${WORK}/proj/target/debug" "${repo}/target"
  touch "${repo}/Cargo.toml"
  ln -s "${WORK}/proj/.worktrees" "${repo}/.worktrees"          # dangling
  mkdir -p "${repo}/sub"; ln -s /elsewhere "${repo}/sub/.venv"  # foreign
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 ]] || fail "converge with findings must exit non-zero"
  [[ "$out" == *"needs-migration	${repo}/.venv"* ]] || fail "missing needs-migration: $out"
  [[ "$out" == *"conflict	${repo}/target"* ]] || fail "missing conflict: $out"
  [[ "$out" == *"dangling	${repo}/.worktrees"* ]] || fail "missing dangling: $out"
  [[ "$out" == *"foreign	${repo}/sub/.venv"* ]] || fail "missing foreign: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "converge must not move"
  [[ -d "${repo}/target" && ! -L "${repo}/target" ]] || fail "converge must not resolve a conflict"
}

test_converge_reports_unignored_link() {
  sandbox
  local repo; repo=$(make_repo proj)
  printf '.venv/\ntarget/\n' > "${repo}/.gitignore"   # directory-only patterns
  mkdir -p "${WORK}/proj/.venv" "${repo}/target"; touch "${repo}/Cargo.toml"
  ln -s "${WORK}/proj/.venv" "${repo}/.venv"
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"unignored	${repo}/.venv"* ]] || fail "slash pattern on a link must be reported: $out"
  [[ "$out" == *"unignored	${repo}/target"* ]] || fail "slash pattern on a real directory awaiting migration must be reported: $out"

  # The plan holds it and migrate refuses to move it until the rule is fixed.
  out=$(run_work_link --migrate --dry-run "${repo}") || true
  [[ "$out" == *"held	${repo}/target"* ]] || fail "plan must hold an unignored entry: $out"
  rc=0; out=$(run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && -d "${repo}/target" && ! -L "${repo}/target" ]] || fail "migrate must not move an entry whose link would be untracked: $out"

  printf '.venv\ntarget\n' > "${repo}/.gitignore"
  out=$(run_work_link --migrate "${repo}") || fail "bare patterns must pass: $out"
  [[ -L "${repo}/target" ]] || fail "entry must migrate once the rule is fixed"
}

test_unconfigured_and_unavailable() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv"
  local out
  out=$(WORK_ROOT= run_work_link "${repo}") || fail "unconfigured converge must exit 0: $out"
  [[ "$out" == *unconfigured* && -d "${repo}/.venv" ]] || fail "unconfigured must do nothing: $out"
  local rc=0
  out=$(WORK_ROOT="${WORK}/missing" run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *unavailable* ]] || fail "unavailable must refuse: $out"
  [[ ! -e "${WORK}/missing" ]] || fail "unavailable must not create the root"
  rc=0
  out=$(cd "$repo" && WORK_ROOT="${WORK}/missing" "$work_link" --ensure .venv 2>&1) || rc=$?
  [[ $rc -eq 1 ]] || fail "ensure must refuse when unavailable: $out"
}

test_migrate_refuses_conflict_and_open_handle() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv/a/b" "${WORK}/proj/.venv"; touch "${WORK}/proj/.venv/old"
  mkdir -p "${repo}/.worktrees"
  local out rc=0
  out=$(run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"conflict	${repo}/.venv"* ]] || fail "conflict must be refused: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" && -f "${WORK}/proj/.venv/old" ]] || fail "conflict must move nothing"
  [[ -L "${repo}/.worktrees" ]] || fail "the unconflicted entry must still migrate"

  rm -rf "${WORK}/proj/.venv"
  touch "${repo}/.venv/a/b/open.log"
  sleep 60 < "${repo}/.venv/a/b/open.log" &
  local holder=$!
  rc=0
  out=$(run_work_link --migrate "${repo}") || rc=$?
  kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null || true
  [[ $rc -ne 0 && "$out" == *"busy	${repo}/.venv"* && "$out" == *sleep* ]] || fail "nested open handle must refuse and name the holder: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "busy entry must not move"
}

test_dry_run_moves_nothing() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv" "${WORK}/proj/target"; touch "${repo}/Cargo.toml"
  local out
  out=$(run_work_link --migrate --dry-run "${repo}") || fail "dry run exit: $out"
  [[ "$out" == *"move	${repo}/.venv"* && "$out" == *"relink	${repo}/target"* ]] || fail "plan lines: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" && ! -e "${repo}/target" ]] || fail "dry run wrote something"
}

test_worktrees_survive_migration_and_get_locked() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  local out
  out=$(run_work_link --migrate "${repo}") || fail "migrate with worktree: $out"
  [[ "$out" == *"locked	"*"/.worktrees/old"* ]] || fail "migrated worktree must be locked: $out"
  git -C "$repo" worktree list --porcelain | grep -q '^prunable' && fail "worktree became prunable"
  git -C "${repo}/.worktrees/old" status --short >/dev/null || fail "worktree status through the link"

  # A worktree created after linking records the external path; converge locks it.
  git -C "$repo" worktree add -q .worktrees/new -b new
  git -C "$repo" worktree list --porcelain | grep -q "^worktree ${WORK}/proj/.worktrees/new" || \
    fail "post-link worktree must record the external path"
  out=$(run_work_link "${repo}") || fail "converge after add: $out"
  [[ "$out" == *"locked	${repo}/.worktrees/new"* ]] || fail "post-link worktree must be locked: $out"
  out=$(run_work_link "${repo}") || fail "second converge: $out"
  [[ -z "$out" ]] || fail "locking must be idempotent: $out"
}

test_outage_prune_recovery() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate"
  git -C "$repo" worktree add -q .worktrees/new -b new
  run_work_link "${repo}" >/dev/null || fail "lock new"
  git -C "$repo" worktree add -q .worktrees/control -b control     # left unlocked on purpose

  mv "$WORK" "${WORK}.away"
  git -C "$repo" worktree prune --expire now
  mv "${WORK}.away" "$WORK"

  git -C "${repo}/.worktrees/old" status --short >/dev/null || fail "migrated locked worktree lost"
  git -C "${repo}/.worktrees/new" status --short >/dev/null || fail "post-link locked worktree lost"
  git -C "${repo}/.worktrees/control" status >/dev/null 2>&1 && fail "unlocked control should have been pruned (the lock is what protects)"

  git -C "$repo" worktree remove .worktrees/old 2>/dev/null && fail "locked worktree must refuse remove"
  git -C "$repo" worktree unlock .worktrees/old && git -C "$repo" worktree remove .worktrees/old || fail "unlock then remove"
}

test_ensure() {
  sandbox
  local repo; repo=$(make_repo proj)
  local out
  out=$(cd "$repo" && "$work_link" --ensure .venv .worktrees 2>&1) || fail "ensure: $out"
  [[ -L "${repo}/.venv" && -d "${WORK}/proj/.venv" && -L "${repo}/.worktrees" ]] || fail "ensure must create and link: $out"
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure again: $out"
  [[ "$out" == "ok	"* ]] || fail "ensure on a correct link: $out"

  rm -rf "${WORK}/proj/.venv"
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure dangling: $out"
  [[ "$out" == recreated* && -d "${WORK}/proj/.venv" ]] || fail "ensure must recreate a dangling link: $out"

  rm "${repo}/.venv"; mkdir -p "${repo}/.venv/real"
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure on a real dir must not fail setup: $out"
  [[ "$out" == needs-migration* && -d "${repo}/.venv/real" ]] || fail "ensure must report and leave a real dir: $out"

  git -C "$repo" worktree add -q .worktrees/wt -b wt
  out=$(cd "${repo}/.worktrees/wt" && "$work_link" --ensure .venv 2>&1) || fail "ensure in worktree: $out"
  [[ "$out" == external* && ! -e "${repo}/.worktrees/wt/.venv" ]] || fail "ensure inside WORK_ROOT must be a no-op: $out"

  # Unconfigured host: a synced dangling link is removed, nothing else happens.
  ln -sf /titan/work/proj/target "${repo}/target"
  out=$(cd "$repo" && WORK_ROOT= "$work_link" --ensure target .venv 2>&1) || fail "ensure unconfigured: $out"
  [[ "$out" == removed-dangling* && ! -L "${repo}/target" && -d "${repo}/.venv/real" ]] || fail "unconfigured ensure: $out"

  # A checkout outside the scan root (a clone under a temp dir) is not covered:
  # setup must still succeed, the entry stays in-tree, a dangling link goes.
  local outside="${SANDBOX}/elsewhere/clone"
  mkdir -p "$outside" && git -C "$outside" init -q
  ln -s "${WORK}/elsewhere/clone/.venv" "${outside}/.venv"
  out=$(cd "$outside" && "$work_link" --ensure .venv .worktrees 2>&1) || fail "ensure outside the scan root must not fail setup: $out"
  [[ "$out" == "outside	${outside}/.venv"*$'\n'"outside	${outside}/.worktrees"* ]] || fail "ensure outside must report every name: $out"
  [[ ! -e "${outside}/.venv" && ! -L "${outside}/.venv" && ! -e "${outside}/.worktrees" && ! -e "${WORK}/elsewhere" ]] || fail "ensure outside must create nothing and drop the dangling link"
}

test_scan_root_behind_symlink() {
  sandbox; local tmp="$SANDBOX"
  mv "${HOME}/d" "${tmp}/real-d" && ln -s "${tmp}/real-d" "${HOME}/d"
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/wt -b wt
  mkdir -p "${repo}/.venv"
  local out
  out=$(run_work_link --migrate "${repo}") || fail "migrate behind symlinked root: $out"
  [[ "$(readlink "${tmp}/real-d/proj/.venv")" == "${WORK}/proj/.venv" ]] || fail "rel must come from the resolved root"
  [[ "$out" == *"locked	"*"/.worktrees/wt"* ]] || fail "worktree locked behind symlinked root: $out"
  out=$(run_work_link) || fail "converge over the default root: $out"
  [[ -z "$out" ]] || fail "clean converge over ~/d: $out"
}

test_inspection_failure_refuses_migration() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv/lib"
  mkdir -p "${tmp}/shim"
  cat > "${tmp}/shim/lsof" <<'EOF'
#!/bin/sh
echo "lsof: simulated failure" >&2
exit 2
EOF
  chmod +x "${tmp}/shim/lsof"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"uninspectable	${repo}/.venv"* && "$out" == *"simulated failure"* ]] || fail "inspection failure must refuse and say why: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "uninspectable entry must not move"
  # exit 1 with a warning on stderr is also a failure, not "nothing open"
  cat > "${tmp}/shim/lsof" <<'EOF'
#!/bin/sh
echo "lsof: WARNING: can't stat() something" >&2
exit 1
EOF
  rc=0; out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *uninspectable* && -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "lsof warning must count as inspection failure: $out"
}

test_foreign_worktree_locked_through_its_owner() {
  sandbox
  local a; a=$(make_repo a)
  local b; b=$(make_repo b)
  mkdir -p "${a}/.worktrees"
  git -C "$b" worktree add -q "${a}/.worktrees/b-wt" -b b-wt      # B's worktree parked in A's .worktrees
  ln -s "${b}" "${a}/.worktrees/b-link"                           # a cross-project symlink, not a worktree
  mkdir -p "${a}/.worktrees/plain"                                # a plain directory
  local out
  out=$(run_work_link --migrate "${a}") || fail "migrate A: $out"
  [[ "$out" == *"locked	"*"/a/.worktrees/b-wt"* ]] || fail "foreign worktree must be locked: $out"
  [[ -f "${b}/.git/worktrees/b-wt/locked" ]] || fail "lock must be recorded in the owning repository"
  [[ "$out" != *"b-link"* && "$out" != *"plain"* ]] || fail "symlink and plain dir must be skipped silently: $out"

  mv "$WORK" "${WORK}.away"
  git -C "$b" worktree prune --expire now
  mv "${WORK}.away" "$WORK"
  git -C "${a}/.worktrees/b-wt" status --short >/dev/null || fail "foreign worktree lost to its owner's prune"
}

test_orphan_external_is_reported_and_skipped() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/wt -b wt
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate"
  mkdir -p "${WORK}/gone/.venv"                                   # checkout deleted, external tree left behind
  git -C "$repo" worktree unlock .worktrees/wt                    # so this run has a lock to make after the orphan
  local out rc=0
  out=$(run_work_link) || rc=$?
  [[ $rc -ne 0 && "$out" == *"orphan	${HOME}/d/gone/.venv"* ]] || fail "orphan must be reported: $out"
  [[ "$out" == *"locked	"* ]] || fail "the run must continue past the orphan to lock worktrees: $out"
  [[ ! -e "${HOME}/d/gone" ]] || fail "orphan handling must not create the checkout"
}

test_missing_scope_is_an_error() {
  sandbox
  local out rc=0
  out=$(run_work_link --migrate --dry-run "${HOME}/d/nope") || rc=$?
  [[ $rc -eq 1 && "$out" == *"Not a directory"* ]] || fail "a missing scope must be refused, not scanned as empty: $out"
}

test_ensure_needs_only_git_and_coreutils() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  mkdir -p "${tmp}/thin"
  local cmd
  for cmd in zsh env git realpath readlink mkdir ln rm ls du cut head awk sort mktemp; do
    ln -s "$(command -v "$cmd")" "${tmp}/thin/${cmd}"
  done
  local out
  out=$(cd "$repo" && PATH="${tmp}/thin" "$work_link" --ensure .venv 2>&1) || fail "ensure without fd and lsof on PATH: $out"
  [[ "$out" == created* ]] || fail "ensure on the thin PATH: $out"
  out=$(cd "$repo" && PATH="${tmp}/thin" WORK_ROOT= "$work_link" --ensure .venv 2>&1) || fail "unconfigured ensure on the thin PATH: $out"
}

test_partial_lsof_output_is_an_inspection_failure() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv/lib"; touch "${repo}/.venv/lib/open.log"
  sleep 60 < "${repo}/.venv/lib/open.log" &
  local holder=$!
  mkdir -p "${tmp}/shim"
  # Real handles on stdout, a warning on stderr, exit 0: a walk that did not
  # finish must not be read as a complete answer.
  cat > "${tmp}/shim/lsof" <<'EOF'
#!/bin/sh
echo "lsof: WARNING: can't stat() a subtree" >&2
lsof_real=$(command -v -p lsof 2>/dev/null || echo /usr/bin/lsof)
exec "$lsof_real" "$@"
EOF
  chmod +x "${tmp}/shim/lsof"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null || true
  [[ $rc -ne 0 && "$out" == *"uninspectable	${repo}/.venv"* && "$out" == *"subtree"* ]] || fail "partial lsof output must refuse: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "uninspectable entry must not move"
}

test_scan_failure_fails_every_mode() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv" "${WORK}/proj/target"; touch "${repo}/Cargo.toml"
  git -C "$repo" worktree add -q .worktrees/wt -b wt
  mkdir -p "${tmp}/shim"
  cat > "${tmp}/shim/fd" <<'EOF'
#!/bin/sh
echo "fd: simulated failure" >&2
exit 2
EOF
  chmod +x "${tmp}/shim/fd"
  local mode out rc
  for mode in "" "--migrate --dry-run" "--migrate"; do
    rc=0; out=$(PATH="${tmp}/shim:$PATH" run_work_link ${=mode} "${repo}") || rc=$?
    [[ $rc -ne 0 && "$out" == *"Scan failed"* ]] || fail "mode '${mode}' must fail on a failed scan: rc=$rc $out"
  done
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" && ! -e "${repo}/target" ]] || fail "a failed scan must change nothing"
  # The external-side scan fails on its own: the in-tree side scanned fine.
  cat > "${tmp}/shim/fd" <<'EOF'
#!/bin/sh
case "$*" in *"$WORK_ROOT"*) echo "fd: simulated failure on WORK_ROOT" >&2; exit 2 ;; esac
exec /usr/bin/fd "$@"
EOF
  rc=0; out=$(PATH="${tmp}/shim:$PATH" run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"Scan failed under ${WORK}"* ]] || fail "external-side scan failure must fail: rc=$rc $out"
}

test_root_and_work_root_must_not_nest() {
  sandbox
  local rc=0 out
  out=$(WORK_ROOT="${HOME}/d/work" run_work_link) || rc=$?
  mkdir -p "${HOME}/d/work"
  rc=0; out=$(WORK_ROOT="${HOME}/d/work" run_work_link) || rc=$?
  [[ $rc -eq 1 && "$out" == *nest* ]] || fail "nested WORK_ROOT must refuse: $out"
}

# A failing mv must be reported, not swallowed: work_link_run is invoked as
# `... || return 1`, and in zsh that suppresses ERR_EXIT for the whole call
# tree, so a plain `set -e` inside work_link_move would not have caught this.
test_migrate_reports_failed_move_instead_of_swallowing_it() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv/lib"; touch "${repo}/.venv/lib/x.py"
  mkdir -p "${WORK}/proj"
  chmod a-w "${WORK}/proj"
  local out rc=0
  out=$(run_work_link --migrate "${repo}") || rc=$?
  chmod u+w "${WORK}/proj"
  [[ $rc -ne 0 && "$out" == *"failed	${repo}/.venv"* ]] || fail "failed move must be reported: $out"
  [[ "$out" != *"moved	${repo}/.venv"* ]] || fail "must not print moved when mv fails: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" && -f "${repo}/.venv/lib/x.py" ]] || \
    fail "in-tree directory must stay real with its content intact after a failed move: $out"
}

# A failing `git worktree lock` must be reported, not swallowed.
test_migrate_reports_failed_lock_instead_of_swallowing_it() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  mkdir -p "${tmp}/shim"
  cat > "${tmp}/shim/git" <<'EOF'
#!/bin/sh
case " $* " in
  *" worktree lock "*)
    echo "git: simulated lock failure" >&2
    exit 1
    ;;
esac
git_real=$(command -v -p git 2>/dev/null || echo /usr/bin/git)
exec "$git_real" "$@"
EOF
  chmod +x "${tmp}/shim/git"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"failed	"*"/.worktrees/old"* ]] || fail "failed lock must be reported: $out"
  [[ "$out" != *"locked	"* ]] || fail "must not print locked when git worktree lock fails: $out"
}

# --ensure builds `external` from the raw WORK_ROOT; converge/migrate resolve
# it with readlink -f. A trailing slash must not make them disagree.
test_ensure_then_converge_agree_on_trailing_slash_work_root() {
  sandbox
  local repo; repo=$(make_repo proj)
  local out
  out=$(cd "$repo" && WORK_ROOT="${WORK}/" "$work_link" --ensure .venv 2>&1) || fail "ensure with trailing slash: $out"
  [[ "$(readlink "${repo}/.venv")" != *//* ]] || fail "ensure must not embed a doubled slash in the link target: $out"
  out=$(WORK_ROOT="${WORK}/" run_work_link "${repo}") || fail "converge after ensure with trailing slash must be clean: $out"
  [[ -z "$out" ]] || fail "converge must resolve the same external path ensure created: $out"
}

# Same disagreement, via a WORK_ROOT that is itself a symlink.
test_ensure_then_converge_agree_on_symlinked_work_root() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  local alt="${tmp}/work-alias"
  ln -s "$WORK" "$alt"
  local out
  out=$(cd "$repo" && WORK_ROOT="$alt" "$work_link" --ensure .venv 2>&1) || fail "ensure with symlinked WORK_ROOT: $out"
  out=$(WORK_ROOT="$alt" run_work_link "${repo}") || fail "converge after ensure with symlinked WORK_ROOT must be clean: $out"
  [[ -z "$out" ]] || fail "converge must resolve the same external path ensure created: $out"
}

test_migrate_moves_and_links
test_nested_rel_path
test_converge_relinks_when_intree_absent
test_converge_reports_without_writing
test_converge_reports_unignored_link
test_unconfigured_and_unavailable
test_migrate_refuses_conflict_and_open_handle
test_dry_run_moves_nothing
test_worktrees_survive_migration_and_get_locked
test_outage_prune_recovery
test_ensure
test_root_and_work_root_must_not_nest
test_migrate_reports_failed_move_instead_of_swallowing_it
test_migrate_reports_failed_lock_instead_of_swallowing_it
test_ensure_then_converge_agree_on_trailing_slash_work_root
test_ensure_then_converge_agree_on_symlinked_work_root
test_scan_root_behind_symlink
test_inspection_failure_refuses_migration
test_foreign_worktree_locked_through_its_owner
test_orphan_external_is_reported_and_skipped
test_missing_scope_is_an_error
test_ensure_needs_only_git_and_coreutils
test_partial_lsof_output_is_an_inspection_failure
test_scan_failure_fails_every_mode

print -- "work-link tests passed"
