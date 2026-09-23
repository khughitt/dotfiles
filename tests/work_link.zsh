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
# $HOME/.dropbox-work is the anchor: a link to $WORK, as on a host that sets
# WORK_ROOT.
sandbox() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  export SANDBOX="$tmp"
  export HOME="${tmp}/home"
  export WORK="${tmp}/work"
  export WORK_ROOT="$WORK"
  export WORK_LINK_HOST=host-a
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  mkdir -p "${HOME}/d" "$WORK"
  ln -s "$WORK" "${HOME}/.dropbox-work"   # the anchor beside the scan root, as titan has it
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
  [[ -L "${repo}/.venv" && "$(readlink "${repo}/.venv")" == "../../.dropbox-work/proj/.venv" ]] || fail ".venv not linked: $out"
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
  [[ "$(readlink "${repo}/.venv")" == "../../../../.dropbox-work/group/sub/proj/.venv" ]] || fail "nested rel path"
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
  ln -s "../../.dropbox-work/proj/.worktrees" "${repo}/.worktrees"   # relative, target missing: materialized
  mkdir -p "${repo}/sub"; ln -s /elsewhere "${repo}/sub/.venv"  # foreign
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 ]] || fail "converge with findings must exit non-zero"
  [[ "$out" == *"needs-migration	${repo}/.venv"* ]] || fail "missing needs-migration: $out"
  [[ "$out" == *"conflict	${repo}/target"* ]] || fail "missing conflict: $out"
  [[ "$out" == *"foreign	${repo}/sub/.venv"* ]] || fail "missing foreign: $out"
  [[ "$out" == *"materialized	${repo}/.worktrees"* && -d "${WORK}/proj/.worktrees" ]] || fail "missing materialized: $out"
  [[ -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || fail "converge must not move"
  [[ -d "${repo}/target" && ! -L "${repo}/target" ]] || fail "converge must not resolve a conflict"
}

# node_modules stays in-tree even beside a package.json: npm workspace links
# are relative and would escape the directory if node_modules moved out.
test_node_modules_beside_package_json_is_never_a_candidate() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/node_modules/leftpad"
  touch "${repo}/package.json"
  local out
  out=$(run_work_link "${repo}") || fail "converge must ignore node_modules: $out"
  [[ "$out" != *node_modules* ]] || fail "converge must not mention node_modules: $out"
  out=$(run_work_link --migrate --dry-run "${repo}") || fail "plan must ignore node_modules: $out"
  [[ "$out" != *"move	"*node_modules* ]] || fail "migrate --dry-run must not offer to move node_modules: $out"
}

test_converge_reports_unignored_link() {
  sandbox
  local repo; repo=$(make_repo proj)
  printf '.venv/\ntarget/\n' > "${repo}/.gitignore"   # directory-only patterns
  mkdir -p "${WORK}/proj/.venv" "${repo}/target"; touch "${repo}/Cargo.toml"
  ln -s "../../.dropbox-work/proj/.venv" "${repo}/.venv"
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

# The ignore verdict runs check-ignore with -c core.excludesFile=/dev/null so a
# global excludes file cannot stand in for a repository's own rule. sandbox
# sets GIT_CONFIG_GLOBAL=/dev/null itself, which would hide a dropped flag, so
# this test points GIT_CONFIG_GLOBAL at a real global excludes file instead.
# The repository here has no rule for .venv at all; the global file ignores it
# by the bare name. Without the -c flag, that global rule masks the omission
# and check-ignore succeeds through it (no unignored line); with the flag, it
# is disregarded and the repository's own lack of a rule is caught.
test_check_ignore_disregards_global_excludes_file() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  printf 'target\n' > "${repo}/.gitignore"   # no .venv rule in the repository
  mkdir -p "${repo}/.venv"; touch "${repo}/Cargo.toml"

  local global_ignore="${tmp}/global-gitignore"
  printf '.venv\n' > "$global_ignore"
  local global_config="${tmp}/global-gitconfig"
  printf '[core]\n\texcludesFile = %s\n' "$global_ignore" > "$global_config"

  local out rc=0
  out=$(GIT_CONFIG_GLOBAL="$global_config" run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"unignored	${repo}/.venv"* ]] || \
    fail "the repository's own rule must decide, not a global excludes file: $out"
}

# The verdict is about the link, not the directory: a tracked slash rule that
# is not ours to change (a shared repository) is satisfied by a bare name in
# .git/info/exclude, because once the entry is a symlink the slash rule no
# longer matches and the local rule does. Nested .gitignore files are part of
# the chain the probe copies.
test_info_exclude_bare_rule_satisfies_the_verdict() {
  sandbox
  local repo; repo=$(make_repo proj)
  printf '.venv/\n' > "${repo}/.gitignore"
  mkdir -p "${repo}/.venv" "${repo}/.git/info"
  printf '/.venv\n' > "${repo}/.git/info/exclude"   # anchored: the nested case below is not covered
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"needs-migration	${repo}/.venv"* && "$out" != *unignored* ]] || \
    fail "a bare rule in info/exclude must satisfy the verdict: $out"
  out=$(run_work_link --migrate "${repo}") || fail "migrate with an info/exclude rule: $out"
  [[ -L "${repo}/.venv" && -z "$(git -C "$repo" status --short -- .venv)" ]] || fail "the link must be ignored after the move: $(git -C "$repo" status --short)"

  # A nested checkout directory with its own .gitignore: the chain is copied.
  mkdir -p "${repo}/services/api/.venv"
  printf '.venv/\n' > "${repo}/services/api/.gitignore"
  rc=0; out=$(run_work_link "${repo}") || rc=$?
  [[ "$out" == *"unignored	${repo}/services/api/.venv"*"ends in /"* ]] || fail "nested slash rule must be reported: $out"
  printf '.venv\n' > "${repo}/services/api/.gitignore"
  rc=0; out=$(run_work_link "${repo}") || rc=$?
  [[ "$out" != *unignored* ]] || fail "nested bare rule must satisfy the verdict: $out"
}

# A probe that cannot be built is a refusal: converge reports it and migrate
# leaves the directory in place.
test_failed_ignore_probe_refuses() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv" "${tmp}/shim"
  printf '#!/bin/sh\necho "mktemp: shim failure" >&2\nexit 1\n' > "${tmp}/shim/mktemp"
  chmod +x "${tmp}/shim/mktemp"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"failed	${repo}/.venv	ignore probe failed"* && -d "${repo}/.venv" && ! -L "${repo}/.venv" ]] || \
    fail "a failed probe must refuse and leave the directory: $out"
}

# A fresh clone of a shared repository: its tracked rule is the slash form and
# no local rule exists yet. --ensure adds the bare name to the clone's
# .git/info/exclude before linking, reports it, and leaves a repository whose
# own rules already cover the link alone.
test_ensure_writes_the_local_exclude_when_needed() {
  sandbox
  local repo; repo=$(make_repo proj)
  printf '.venv/\ntarget\n' > "${repo}/.gitignore"   # slash form for .venv; target covered
  git -C "$repo" commit -qam "slash form, not ours to change"
  local out
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure on a slash rule: $out"
  [[ "$out" == "excluded	${repo}/.venv	.venv added to "*$'\n'"created	${repo}/.venv"* ]] || fail "ensure must report the exclude write then the link: $out"
  [[ -L "${repo}/.venv" ]] || fail "ensure must link"
  grep -qx '.venv' "${repo}/.git/info/exclude" || fail "the bare name must be in info/exclude"
  [[ -z "$(git -C "$repo" status --short)" ]] || fail "the link must be ignored: $(git -C "$repo" status --short)"
  out=$(run_work_link "${repo}") || fail "converge must be clean after ensure: $out"

  # Already covered by the repository's own rule: nothing is written.
  out=$(cd "$repo" && "$work_link" --ensure target 2>&1) || fail "ensure target: $out"
  [[ "$out" == "created	"* ]] || fail "a covered name must not be excluded again: $out"
  ! grep -qx 'target' "${repo}/.git/info/exclude" || fail "a covered name must not be written to info/exclude"

  # A second ensure finds the link and writes nothing more.
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure again: $out"
  [[ "$out" == "ok	"* && "$(grep -c '^\.venv$' "${repo}/.git/info/exclude")" == 1 ]] || fail "ensure must be idempotent: $out"
}

test_anchor_states() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${repo}/.venv"
  local anchor="${HOME}/.dropbox-work" out rc

  # No WORK_ROOT: the anchor becomes a real local directory, and converge runs.
  rm "$anchor"
  out=$(WORK_ROOT= run_work_link "${repo}") || true            # exit status on needs-migration is Task 3's
  [[ -d "$anchor" && ! -L "$anchor" ]] || fail "anchor must be a real directory without WORK_ROOT: $out"
  [[ "$out" == "created	${anchor}	-> local directory"* ]] || fail "anchor creation must be reported: $out"
  [[ "$out" == *"needs-migration	${repo}/.venv"* ]] || fail "converge must run without WORK_ROOT: $out"

  # WORK_ROOT set while the anchor is a real directory: refuse, write nothing.
  rc=0; out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *"${anchor}"* && "$out" == *"not a link to WORK_ROOT"* ]] || fail "real anchor with WORK_ROOT must refuse: $out"

  # WORK_ROOT set: the anchor becomes a link to it.
  rmdir "$anchor"
  out=$(run_work_link "${repo}") || true
  [[ -L "$anchor" && "$(readlink -f "$anchor")" == "$(readlink -f "$WORK")" ]] || fail "anchor must link to WORK_ROOT: $out"

  # An anchor pointing elsewhere refuses.
  rm "$anchor"; mkdir -p "${SANDBOX}/other"; ln -s "${SANDBOX}/other" "$anchor"
  rc=0; out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *"not WORK_ROOT"* ]] || fail "anchor elsewhere must refuse: $out"

  # A link anchor while WORK_ROOT is unset refuses.
  rc=0; out=$(WORK_ROOT= run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 ]] || fail "link anchor without WORK_ROOT must refuse: $out"

  # A dangling anchor is unavailable storage.
  rm "$anchor"; ln -s "${SANDBOX}/gone" "$anchor"
  rc=0; out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *dangles* ]] || fail "dangling anchor must refuse: $out"

  # --ensure validates the anchor before the outside branch may drop a link.
  local outside="${SANDBOX}/elsewhere/clone"
  mkdir -p "$outside" && git -C "$outside" init -q
  ln -s "${SANDBOX}/nowhere" "${outside}/.venv"
  rc=0; out=$(cd "$outside" && "$work_link" --ensure .venv 2>&1) || rc=$?
  [[ $rc -eq 1 && -L "${outside}/.venv" ]] || fail "ensure outside must refuse on an invalid anchor before touching the link: $out"

  # WORK_ROOT set but not a directory: every mode refuses and nothing is created.
  rm "$anchor"
  rc=0; out=$(WORK_ROOT="${WORK}/missing" run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *unavailable* ]] || fail "unavailable must refuse: $out"
  [[ ! -e "${WORK}/missing" && ! -e "$anchor" && ! -L "$anchor" ]] || fail "unavailable must create nothing"
  rc=0; out=$(cd "$repo" && WORK_ROOT="${WORK}/missing" "$work_link" --ensure .venv 2>&1) || rc=$?
  [[ $rc -eq 1 ]] || fail "ensure must refuse when unavailable: $out"
}

test_link_text_depth() {
  sandbox
  local a b c
  a=$(make_repo one); b=$(make_repo two/deep); c=$(make_repo g/h/i/four)
  local out
  out=$(cd "$a" && "$work_link" --ensure .venv 2>&1) || fail "ensure one: $out"
  out=$(cd "$b" && "$work_link" --ensure .venv 2>&1) || fail "ensure two: $out"
  out=$(cd "$c" && "$work_link" --ensure .worktrees 2>&1) || fail "ensure four: $out"
  [[ "$(readlink "${a}/.venv")" == "../../.dropbox-work/one/.venv" ]] || fail "depth one: $(readlink "${a}/.venv")"
  [[ "$(readlink "${b}/.venv")" == "../../../.dropbox-work/two/deep/.venv" ]] || fail "depth two: $(readlink "${b}/.venv")"
  [[ "$(readlink "${c}/.worktrees")" == "../../../../../.dropbox-work/g/h/i/four/.worktrees" ]] || fail "depth four: $(readlink "${c}/.worktrees")"
  [[ "$(readlink -f "${c}/.worktrees")" == "$(readlink -f "${WORK}/g/h/i/four/.worktrees")" ]] || fail "depth four must resolve into WORK"
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
  [[ "$out" == materialized* && -d "${WORK}/proj/.venv" ]] || fail "ensure must materialize a link whose target is gone: $out"

  rm "${repo}/.venv"; mkdir -p "${repo}/.venv/real"
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure on a real dir must not fail setup: $out"
  [[ "$out" == needs-migration* && -d "${repo}/.venv/real" ]] || fail "ensure must report and leave a real dir: $out"

  git -C "$repo" worktree add -q .worktrees/wt -b wt
  out=$(cd "${repo}/.worktrees/wt" && "$work_link" --ensure .venv 2>&1) || fail "ensure in worktree: $out"
  [[ "$out" == external* && ! -e "${repo}/.worktrees/wt/.venv" ]] || fail "ensure inside WORK_ROOT must be a no-op: $out"


  # A checkout outside the scan root (a clone under a temp dir) is not covered:
  # setup must still succeed, the entry stays in-tree, a dangling link goes.
  local outside="${SANDBOX}/elsewhere/clone"
  mkdir -p "$outside" && git -C "$outside" init -q
  ln -s "${WORK}/elsewhere/clone/.venv" "${outside}/.venv"
  out=$(cd "$outside" && "$work_link" --ensure .venv .worktrees 2>&1) || fail "ensure outside the scan root must not fail setup: $out"
  [[ "$out" == "outside	${outside}/.venv"*$'\n'"outside	${outside}/.worktrees"* ]] || fail "ensure outside must report every name: $out"
  [[ ! -e "${outside}/.venv" && ! -L "${outside}/.venv" && ! -e "${outside}/.worktrees" && ! -e "${WORK}/elsewhere" ]] || fail "ensure outside must create nothing and drop the dangling link"
}

# A checkout outside the scan root can still carry a link that resolves: a
# `cp -r` of a project under ~/d brings its .venv symlink along, pointing back
# at the original project's external storage. --ensure must refuse rather than
# report `outside`, or the installer that follows writes into that storage.
test_ensure_outside_refuses_a_resolving_link() {
  sandbox
  local outside="${SANDBOX}/elsewhere/clone"
  mkdir -p "$outside" && git -C "$outside" init -q
  mkdir -p "${WORK}/proj/.venv"
  ln -s "${WORK}/proj/.venv" "${outside}/.venv"
  local out rc=0
  out=$(cd "$outside" && "$work_link" --ensure .venv 2>&1) || rc=$?
  [[ $rc -ne 0 ]] || fail "a resolving link from outside the scan root must refuse: $out"
  [[ "$out" == "work-link --ensure: ${outside}/.venv is a link into ${WORK}/proj/.venv from a checkout outside ${HOME}/d; remove it or copy without symlinks" ]] || \
    fail "expected the foreign-link message: $out"
  [[ -L "${outside}/.venv" && "$(readlink "${outside}/.venv")" == "${WORK}/proj/.venv" ]] || fail "the link must be untouched: $out"
  [[ -d "${WORK}/proj/.venv" ]] || fail "the external directory must be untouched: $out"
}

test_converge_materializes_a_synced_link() {
  sandbox
  local repo; repo=$(make_repo proj)
  ln -s "../../.dropbox-work/proj/.venv" "${repo}/.venv"      # arrived from another host
  local out
  out=$(run_work_link --migrate --dry-run "${repo}") || fail "plan: $out"
  [[ "$out" == *"materialize	${repo}/.venv"* && ! -e "${WORK}/proj/.venv" ]] || fail "dry run must only plan: $out"
  out=$(run_work_link "${repo}") || fail "materialize must exit 0: $out"
  [[ "$out" == "materialized	${repo}/.venv	-> "* ]] || fail "expected materialized: $out"
  [[ -d "${WORK}/proj/.venv" && -z "$(ls -A "${WORK}/proj/.venv")" ]] || fail "target must be an empty directory"
  [[ "$(readlink "${repo}/.venv")" == "../../.dropbox-work/proj/.venv" ]] || fail "the link must be untouched"
  out=$(run_work_link "${repo}") || fail "second converge: $out"
  [[ -z "$out" ]] || fail "materialize must be idempotent: $out"
}

test_converge_rewrites_legacy_absolute_link() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${WORK}/proj/.venv/lib"; touch "${WORK}/proj/.venv/lib/x.py"
  ln -s "${WORK}/proj/.venv" "${repo}/.venv"                     # the 2026-09-14 form
  mkdir -p "${repo}/sub"; git -C "${repo}/sub" init -q
  printf '.venv\n' > "${repo}/sub/.gitignore"
  ln -s "${WORK}/proj/sub/.venv" "${repo}/sub/.venv"             # legacy and dangling
  local inode_before; inode_before=$(stat -L -c %i "${repo}/.venv")
  exec {fd}<"${repo}/.venv/lib/x.py"                             # a process holding a file open under it
  local out
  out=$(run_work_link --migrate --dry-run "${repo}") || fail "plan: $out"
  [[ "$out" == *"rewrite	${repo}/.venv"* && "$(readlink "${repo}/.venv")" == "${WORK}/proj/.venv" ]] || fail "dry run must only plan: $out"
  out=$(run_work_link "${repo}") || fail "rewrite must exit 0: $out"
  [[ "$out" == *"rewritten	${repo}/.venv"* ]] || fail "expected rewritten: $out"
  [[ "$(readlink "${repo}/.venv")" == "../../.dropbox-work/proj/.venv" ]] || fail "link text not rewritten: $(readlink "${repo}/.venv")"
  [[ "$(stat -L -c %i "${repo}/.venv")" == "$inode_before" ]] || fail "rewrite must resolve to the same directory"
  read -r -u $fd _ || true; exec {fd}<&-
  [[ "$out" == *"rewritten	${repo}/sub/.venv"* && -d "${WORK}/proj/sub/.venv" ]] || fail "a dangling legacy link is rewritten and materialized: $out"
  ls -A "${repo}" | grep -q 'work-link' && fail "no temporary link may be left behind"
  out=$(run_work_link "${repo}") || fail "second converge: $out"
  [[ -z "$out" ]] || fail "rewrite must be idempotent: $out"

  # Without WORK_ROOT the absolute form means nothing here: it is foreign and untouched.
  ln -sfn "${WORK}/proj/.venv" "${repo}/.venv"
  rm "${HOME}/.dropbox-work"
  local rc=0
  out=$(WORK_ROOT= run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 && "$out" == *"foreign	${repo}/.venv"* && "$(readlink "${repo}/.venv")" == "${WORK}/proj/.venv" ]] || fail "absolute link on another host must be foreign: $out"
}

# One synced tree read by two hosts at the same path, as titan and europa
# see it: host B has none of host A's storage and its own anchor. The
# migrated worktree's recorded path is the same string on both hosts, so only
# the host named in its lock tells host B that it is not its own.
test_two_hosts_share_link_text() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/wt -b wt              # migrated: keeps its in-tree path
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate on host A"
  git -C "$repo" worktree add -q .worktrees/post -b post          # post-link: records the store path
  run_work_link "${repo}" >/dev/null || fail "lock on host A"
  (cd "$repo" && "$work_link" --ensure .venv >/dev/null) || fail "ensure on host A"
  local text; text=$(readlink "${repo}/.venv")
  mv "$WORK" "${WORK}.away"; rm "${HOME}/.dropbox-work"
  local out rc=0
  out=$(WORK_LINK_HOST=host-b WORK_ROOT= run_work_link) || rc=$?
  [[ $rc -eq 0 ]] || fail "host B converge must pass while host A's storage is absent: rc=$rc $out"
  [[ "$out" != *prunable* && "$out" != *unowned* ]] || fail "host A's locked worktrees are neither prunable nor unowned on host B: $out"
  [[ -d "${HOME}/.dropbox-work" && ! -L "${HOME}/.dropbox-work" ]] || fail "host B anchor: $out"
  [[ "$out" == *"materialized	${repo}/.venv"* ]] || fail "host B materializes .venv: $out"
  [[ "$out" == *"materialized	${repo}/.worktrees"* ]] || fail "host B materializes .worktrees: $out"
  [[ "$out" != *rewritten* && "$out" != *relinked* && "$out" != *relocked* ]] || fail "host B must not write links or locks: $out"
  [[ "$(readlink "${repo}/.venv")" == "$text" ]] || fail "link text must be untouched"
  [[ "$(readlink -f "${repo}/.venv")" == "$(readlink -f "${HOME}/.dropbox-work")/proj/.venv" ]] || fail "host B link resolves into its own anchor"
}

# The same missing worktrees on their own host are breakage, whatever form
# their recorded path takes; another host's are skipped; a lock that names no
# host is reported, because nothing says who owns it.
test_missing_locked_worktrees_by_owner() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/pre -b pre
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate"
  git -C "$repo" worktree add -q .worktrees/post -b post
  run_work_link "${repo}" >/dev/null || fail "lock post"
  git -C "$repo" worktree add -q .worktrees/remote -b remote
  git -C "$repo" worktree lock --reason "on WORK_ROOT storage (host: host-b)" .worktrees/remote
  git -C "$repo" worktree add -q .worktrees/other -b other
  git -C "$repo" worktree lock --reason "something else" .worktrees/other
  rm -rf "${WORK}/proj/.worktrees/"{pre,post,remote,other}
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -eq 1 ]] || fail "local breakage must fail converge: $out"
  [[ "$out" == *"prunable	"*"/.worktrees/pre	"* ]] || fail "a migrated local worktree is local breakage: $out"
  [[ "$out" == *"prunable	"*"/.worktrees/post	"* ]] || fail "a post-link local worktree is local breakage: $out"
  [[ "$out" != *"/.worktrees/remote"* ]] || fail "another host's worktree is skipped: $out"
  [[ "$out" == *"unowned	"*"/.worktrees/other	"* ]] || fail "a lock without a host is reported: $out"
}

test_bare_lock_is_restamped_with_host() {
  sandbox
  local repo; repo=$(make_repo proj)
  (cd "$repo" && "$work_link" --ensure .worktrees >/dev/null) || fail "ensure"
  git -C "$repo" worktree add -q .worktrees/wt -b wt
  git -C "$repo" worktree lock --reason "on WORK_ROOT storage" .worktrees/wt
  local out
  out=$(run_work_link "${repo}") || fail "restamp must exit 0: $out"
  [[ "$out" == *"relocked	${repo}/.worktrees/wt	on WORK_ROOT storage (host: host-a)"* ]] || fail "bare lock restamped: $out"
  [[ "$(git -C "$repo" worktree list --porcelain | grep '^locked')" == "locked on WORK_ROOT storage (host: host-a)" ]] || fail "lock reason: $(git -C "$repo" worktree list --porcelain)"
  out=$(run_work_link "${repo}") || fail "second converge: $out"
  [[ -z "$out" ]] || fail "restamp must be idempotent: $out"
}

test_ensure_never_removes_a_link() {
  sandbox
  local repo; repo=$(make_repo proj)
  rm "${HOME}/.dropbox-work"
  ln -s "../../.dropbox-work/proj/target" "${repo}/target"; touch "${repo}/Cargo.toml"
  local out
  out=$(cd "$repo" && WORK_ROOT= "$work_link" --ensure target .venv 2>&1) || fail "ensure without WORK_ROOT: $out"
  [[ "$out" == *"materialized	${repo}/target"* && -L "${repo}/target" && -d "${HOME}/.dropbox-work/proj/target" ]] || fail "ensure must materialize, not remove: $out"
  [[ "$out" == *"created	${repo}/.venv"* && -L "${repo}/.venv" ]] || fail "ensure must link on a host without WORK_ROOT: $out"
}

test_ensure_rewrites_legacy() {
  sandbox
  local repo; repo=$(make_repo proj)
  mkdir -p "${WORK}/proj/.venv"; ln -s "${WORK}/proj/.venv" "${repo}/.venv"
  local out
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure legacy: $out"
  [[ "$out" == "rewritten	${repo}/.venv"* && "$(readlink "${repo}/.venv")" == "../../.dropbox-work/proj/.venv" ]] || fail "ensure must rewrite a legacy link: $out"
}
test_scan_root_behind_symlink() {
  sandbox; local tmp="$SANDBOX"
  mv "${HOME}/d" "${tmp}/real-d" && ln -s "${tmp}/real-d" "${HOME}/d"
  ln -s "$WORK" "${tmp}/.dropbox-work"
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/wt -b wt
  mkdir -p "${repo}/.venv"
  local out
  out=$(run_work_link --migrate "${repo}") || fail "migrate behind symlinked root: $out"
  [[ "$(readlink "${tmp}/real-d/proj/.venv")" == "../../.dropbox-work/proj/.venv" ]] || fail "rel must come from the resolved root"
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
  for cmd in zsh env git realpath readlink mkdir ln rm cp ls du cut head awk sort mktemp; do
    ln -s "$(command -v "$cmd")" "${tmp}/thin/${cmd}"
  done
  local out
  out=$(cd "$repo" && PATH="${tmp}/thin" "$work_link" --ensure .venv 2>&1) || fail "ensure without fd and lsof on PATH: $out"
  [[ "$out" == created* ]] || fail "ensure on the thin PATH: $out"
  rm "${HOME}/.dropbox-work" "${repo}/.venv"
  out=$(cd "$repo" && PATH="${tmp}/thin" WORK_ROOT= "$work_link" --ensure .venv 2>&1) || fail "ensure creating the anchor on the thin PATH: $out"
  [[ -d "${HOME}/.dropbox-work" && "$out" == *"created	${repo}/.venv"* ]] || fail "thin PATH anchor creation: $out"
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

# An external target with no Cargo.toml beside the in-tree path is storage
# nothing claims: it is reported as an orphan, not skipped silently.
test_external_target_without_cargo_toml_is_reported() {
  sandbox
  local repo; repo=$(make_repo proj)     # no Cargo.toml
  mkdir -p "${repo}/data/target" "${WORK}/proj/target/debug" "${WORK}/proj/data/target"
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 ]] || fail "an unclaimed external target must exit non-zero: $out"
  [[ "$out" == *"orphan	${repo}/target"*Cargo.toml* ]] || fail "external target without Cargo.toml must be reported: $out"
  [[ "$out" == *"orphan	${repo}/data/target"*Cargo.toml* ]] || fail "a nested external target without Cargo.toml must be reported: $out"
  [[ "$out" != *needs-migration* ]] || fail "an entry that is not relocatable must not be held for migration: $out"
  [[ -d "${repo}/data/target" && ! -L "${repo}/data/target" ]] || fail "the in-tree directory must stay: $out"
}

# The lock loop's realpath is checked: a failure must be reported and the child
# left unlocked, not skipped as though it resolved to nothing. The shim fails
# only `realpath --` (the lock loop's form); `realpath -e` in the prunable
# check must keep working, or the failure would masquerade as prunable too.
test_realpath_failure_on_a_worktree_is_reported() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  mkdir -p "${tmp}/shim"
  cat > "${tmp}/shim/realpath" <<'EOF'
#!/bin/sh
case " $* " in
  " -- $HOME"/*) echo "realpath: simulated failure" >&2; exit 1 ;;
esac
exec /usr/bin/realpath "$@"
EOF
  chmod +x "${tmp}/shim/realpath"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link --migrate "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"failed	${repo}/.worktrees/old"*"not locked"* && "$out" == *"simulated failure"* ]] || \
    fail "a realpath failure must be reported with the child left unlocked: $out"
  [[ "$out" != *"locked	"* ]] || fail "must not print locked when realpath fails: $out"
}

# A worktree git itself marks prunable (its .git file is gone) still resolves
# as a path: the listing's prunable mark must decide, not path resolution alone.
# A locked worktree is never marked prunable: the lock is the prune protection,
# so the fixture unlocks first.
test_prunable_marked_by_git_is_reported() {
  sandbox
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate"
  git -C "$repo" worktree unlock .worktrees/old
  rm "${repo}/.worktrees/old/.git"
  local out rc=0
  out=$(run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"prunable	${repo}/.worktrees/old"*"git marks it prunable"* ]] || \
    fail "a git-marked prunable worktree must be reported: $out"
}

# A failing `git worktree list` must be reported, not read as an empty listing.
test_failing_worktree_list_is_reported() {
  sandbox; local tmp="$SANDBOX"
  local repo; repo=$(make_repo proj)
  git -C "$repo" worktree add -q .worktrees/old -b old
  run_work_link --migrate "${repo}" >/dev/null || fail "migrate"
  mkdir -p "${tmp}/shim"
  cat > "${tmp}/shim/git" <<'EOF'
#!/bin/sh
case " $* " in
  *" worktree list "*) echo "git: simulated listing failure" >&2; exit 1 ;;
esac
git_real=$(command -v -p git 2>/dev/null || echo /usr/bin/git)
exec "$git_real" "$@"
EOF
  chmod +x "${tmp}/shim/git"
  local out rc=0
  out=$(PATH="${tmp}/shim:$PATH" run_work_link "${repo}") || rc=$?
  [[ $rc -ne 0 && "$out" == *"failed	${repo}/.worktrees"*"worktree list failed in ${repo}"* ]] || \
    fail "a failing worktree listing must be reported: $out"
}

# --root names the scan root under --ensure too: without it the ~/d default
# applies and the same checkout reports `outside`.
test_ensure_honors_root() {
  sandbox; local tmp="$SANDBOX"
  local alt="${tmp}/alt-root"
  local repo="${alt}/proj"
  mkdir -p "$repo" && git -C "$repo" init -q
  local out
  out=$(cd "$repo" && "$work_link" --ensure --root "$alt" .venv 2>&1) || fail "ensure with --root: $out"
  [[ "$out" == *"created	${repo}/.venv	-> ${WORK}/proj/.venv"* && -L "${repo}/.venv" ]] || \
    fail "--root must bring the checkout into scope: $out"
  rm "${repo}/.venv"; rm -rf "${WORK}/proj"
  out=$(cd "$repo" && "$work_link" --ensure .venv 2>&1) || fail "ensure without --root must not fail setup: $out"
  [[ "$out" == "outside	${repo}/.venv"* ]] || fail "the ~/d default must still apply without --root: $out"
  [[ ! -e "${repo}/.venv" && ! -e "${WORK}/proj" ]] || fail "the outside report must create nothing: $out"
}

test_migrate_moves_and_links
test_nested_rel_path
test_converge_relinks_when_intree_absent
test_converge_reports_without_writing
test_node_modules_beside_package_json_is_never_a_candidate
test_converge_reports_unignored_link
test_check_ignore_disregards_global_excludes_file
test_info_exclude_bare_rule_satisfies_the_verdict
test_failed_ignore_probe_refuses
test_ensure_writes_the_local_exclude_when_needed
test_anchor_states
test_link_text_depth
test_migrate_refuses_conflict_and_open_handle
test_dry_run_moves_nothing
test_worktrees_survive_migration_and_get_locked
test_outage_prune_recovery
test_ensure
test_ensure_outside_refuses_a_resolving_link
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
test_external_target_without_cargo_toml_is_reported
test_realpath_failure_on_a_worktree_is_reported
test_prunable_marked_by_git_is_reported
test_failing_worktree_list_is_reported
test_ensure_honors_root
test_converge_materializes_a_synced_link
test_converge_rewrites_legacy_absolute_link
test_two_hosts_share_link_text
test_missing_locked_worktrees_by_owner
test_bare_lock_is_restamped_with_host
test_ensure_never_removes_a_link
test_ensure_rewrites_legacy

print -- "work-link tests passed"
