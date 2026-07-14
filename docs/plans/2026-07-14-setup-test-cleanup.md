# Setup Test Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make temporary-directory cleanup reliable when either zsh test harness exits early from a failing assertion.

**Architecture:** Both harnesses source one `tests/tmp_cleanup.zsh` file from their own script directory. That file installs one process-level `EXIT` trap at source time, while test functions only register paths in a global array; a subprocess regression test covers trap timing and a source scan prevents function-local traps from returning.

**Tech Stack:** zsh, `rg`, Just

## Global Constraints

- Source the helper with `source "${0:A:h}/tmp_cleanup.zsh"`; do not depend on the caller's working directory.
- Install the `EXIT` trap only at the top level of the sourced helper, never inside `register_tmp_cleanup`.
- Keep successful tests' explicit `rm -rf "$tmp"` cleanup and remove their per-function `trap - EXIT` lines.
- Neither `tests/setup_and_health.zsh` nor `tests/dropbox_ignore_flux.zsh` may contain a `trap` command; the shared helper wholly owns traps.
- Every new zsh file must be covered by `zsh -n`. `bin/dotfiles-check` maintains that coverage as a hand-written `zsh_files` array, so `tests/tmp_cleanup.zsh` has to be added to it; nothing globs `tests/`.
- Do not change `setup.sh`, `bin/dotfiles-health`, or shell functions under test. Leave the pre-existing suite-list mismatch alone: `justfile` runs four suites and `bin/dotfiles-check` runs three. Editing the `zsh_files` lint array is not that mismatch and is in scope.
- Preserve the user's unrelated `niri/familiar.kdl` and `ghostty/` changes.

---

### Task 1: Centralize temporary-directory cleanup

**Files:**
- Create: `tests/tmp_cleanup.zsh`
- Modify: `tests/setup_and_health.zsh:1-397`
- Modify: `tests/dropbox_ignore_flux.zsh:1-130`
- Modify: `bin/dotfiles-check:19-38`
- Test: `tests/setup_and_health.zsh`

**Interfaces:**
- Produces: `register_tmp_cleanup(cleanup_path: string)`, which records a directory for removal when the current zsh process exits.
- Produces: `cleanup_registered_tmpdirs()`, the top-level `EXIT` trap handler that removes every registered path.
- Consumes: zsh's `${0:A:h}` path expansion so each harness sources the helper relative to its own file.

- [ ] **Step 1: Add the static regression guard before changing cleanup**

Add this function to `tests/setup_and_health.zsh` after `make_tmpdir`:

```zsh
test_tmp_cleanup_is_centralized() {
  local output exit_status

  set +e
  output=$(
    rg -n '^[[:space:]]*trap([[:space:]]|$)' \
      "${repo_root}/tests/setup_and_health.zsh" \
      "${repo_root}/tests/dropbox_ignore_flux.zsh" 2>&1
  )
  exit_status=$?
  set -e

  if (( exit_status == 0 )); then
    fail "test harnesses should not install traps:
${output}"
  fi
  (( exit_status == 1 )) || fail "failed to scan test harness traps: ${output}"
}
```

Invoke it before every existing test invocation at the bottom of the file:

```zsh
test_tmp_cleanup_is_centralized
test_setup_dry_run_link_only_does_not_write_home
```

- [ ] **Step 2: Run the guard and verify the meaningful red state**

Run:

```bash
zsh tests/setup_and_health.zsh
```

Expected: exit 1 with `FAIL: test harnesses should not install traps:` followed by the existing trap lines from both harnesses. The output must not contain `register_tmp_cleanup: command not found`; the failure demonstrates the live call sites rather than a missing API.

- [ ] **Step 3: Add the shared top-level cleanup helper**

Create `tests/tmp_cleanup.zsh` with exactly this implementation:

```zsh
#!/usr/bin/env zsh

typeset -ga _tmp_cleanup_paths=()

cleanup_registered_tmpdirs() {
  local cleanup_path
  for cleanup_path in "${_tmp_cleanup_paths[@]}"; do
    rm -rf -- "$cleanup_path"
  done
}

trap cleanup_registered_tmpdirs EXIT

register_tmp_cleanup() {
  _tmp_cleanup_paths+=("$1")
}
```

Do not move `trap cleanup_registered_tmpdirs EXIT` into either function. In zsh, a function-scoped `EXIT` trap runs when that function returns.

- [ ] **Step 4: Put the helper under `zsh -n` coverage**

`bin/dotfiles-check` syntax-checks a hand-written list; nothing globs `tests/`, so a new file is linted only if it is listed. Add it to the `zsh_files` array alongside the existing test entries:

```bash
    tests/dropbox_ignore_flux.zsh
    tests/setup_and_health.zsh
    tests/dotfiles_check.zsh
    tests/tmp_cleanup.zsh
```

Do not touch the suite list further down the file; only the lint array changes.

Verify the helper is now parsed:

```bash
rg -n 'tests/tmp_cleanup.zsh' bin/dotfiles-check
bin/dotfiles-check
```

Expected: `rg` finds the new entry, and `bin/dotfiles-check` exits 0 printing `dotfiles checks passed`. It is lint-only — it runs `bash -n`, `shellcheck`, and `zsh -n`, not the test suites — so it passes here even though the Step 1 guard is still red.

- [ ] **Step 5: Source the helper from each harness's own directory**

In `tests/setup_and_health.zsh`, keep `repo_root` and add the source immediately after it:

```zsh
repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"
```

In `tests/dropbox_ignore_flux.zsh`, source the helper before the existing shell-functions source:

```zsh
repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"
source "${repo_root}/shell/functions"
```

- [ ] **Step 6: Add the process-level timing regression test**

Add this function to `tests/setup_and_health.zsh` after `test_tmp_cleanup_is_centralized`:

```zsh
test_tmp_cleanup_runs_only_at_process_exit() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"

  set +e
  output=$(
    zsh -fc '
      set -euo pipefail
      source "$1"

      exercise_cleanup() {
        local tmp="$1"
        register_tmp_cleanup "$tmp"
        [[ -d "$tmp" ]] || {
          print -u2 -- "temporary directory removed during registration"
          exit 91
        }
        print -- registered > "${tmp}/after-register"
        exit 17
      }

      exercise_cleanup "$2"
    ' zsh "${repo_root}/tests/tmp_cleanup.zsh" "$tmp" 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 17 ]] || \
    fail "cleanup subprocess should preserve status 17, got ${exit_status}: ${output}"
  [[ ! -e "$tmp" ]] || fail "cleanup subprocess should remove its registered directory"
  [[ "$output" != *"parameter not set"* ]] || \
    fail "cleanup subprocess referenced an expired local variable: ${output}"
  [[ -z "$output" ]] || fail "cleanup subprocess wrote unexpected output: ${output}"
}
```

Invoke it **before** the static guard, so the invocation list at the bottom of the file reads:

```zsh
test_tmp_cleanup_runs_only_at_process_exit
test_tmp_cleanup_is_centralized
test_setup_dry_run_link_only_does_not_write_home
```

Order matters. `fail` calls `exit 1`, so the first failing test aborts the suite. The guard stays red until Step 8 converts the call sites; if the guard ran first, the timing test added here would never execute and you would never observe it passing.

Run `zsh tests/setup_and_health.zsh` and confirm the timing test runs and passes, and that the run still ends on the guard's red (`FAIL: test harnesses should not install traps:`).

The child's status 17 proves it reached the code after registration, and the parent checks removal only after the child process has exited.

- [ ] **Step 7: Prove the timing test actually catches the regression**

This test exists to detect one specific mistake: an `EXIT` trap installed inside `register_tmp_cleanup`, which in zsh fires when that function returns and deletes the directory before the test body uses it. An earlier version of this regression test passed against exactly that broken helper, so verify non-vacuity rather than assuming it.

Temporarily rewrite `tests/tmp_cleanup.zsh` to the broken form:

```zsh
#!/usr/bin/env zsh

register_tmp_cleanup() {
  local cleanup_path="$1"
  trap "rm -rf -- ${(q)cleanup_path}" EXIT
}
```

Run `zsh tests/setup_and_health.zsh`.

Expected: `test_tmp_cleanup_runs_only_at_process_exit` fails with `cleanup subprocess should preserve status 17, got 91` and the child's message `temporary directory removed during registration`. A status of 17 here means the test is vacuous and must be fixed before continuing.

Then restore `tests/tmp_cleanup.zsh` to the Step 3 implementation and re-run to confirm the timing test passes again.

- [ ] **Step 8: Convert every cleanup call site**

In all 14 temporary-directory tests in `tests/setup_and_health.zsh` and all three in `tests/dropbox_ignore_flux.zsh`, replace this registration:

```zsh
tmp=$(make_tmpdir)
trap 'rm -rf "$tmp"' EXIT
```

with:

```zsh
tmp=$(make_tmpdir)
register_tmp_cleanup "$tmp"
```

Keep each successful test's explicit cleanup:

```zsh
rm -rf "$tmp"
```

Delete the `trap - EXIT` line that currently follows each explicit cleanup. Convert these functions:

- `test_setup_dry_run_link_only_does_not_write_home`
- `test_setup_link_only_creates_expected_links_without_external_clones`
- `test_setup_dry_run_can_enable_user_timers`
- `test_setup_only_runs_selected_phase`
- `test_setup_only_accepts_multiple_phases`
- `test_setup_only_rejects_unknown_phase`
- `test_dotfiles_health_passes_after_link_only_setup`
- `test_dotfiles_health_fails_stale_removed_config_links`
- `test_dotfiles_health_ignores_brave_runtime_symlinks`
- `test_dotfiles_health_ignores_unmanaged_config_symlinks`
- `test_dotfiles_health_fails_broken_managed_config_link`
- `test_dotfiles_health_checks_enabled_user_timer`
- `test_setup_graphical_app_config_links_memory_alert`
- `test_dotfiles_health_fails_wrong_memory_alert_link`
- `test_candidates_keep_only_top_level_matches`
- `test_dropbox_ignore_flux_sets_only_missing_attrs_without_sudo`
- `test_fu_finds_functions_d_modules`

- [ ] **Step 9: Run the focused harnesses and guard**

Run:

```bash
zsh tests/setup_and_health.zsh
zsh tests/dropbox_ignore_flux.zsh
! rg -n '^[[:space:]]*trap([[:space:]]|$)' \
  tests/setup_and_health.zsh tests/dropbox_ignore_flux.zsh
```

Expected: both harnesses exit 0 and print `setup and health tests passed` and `dropbox_ignore_flux tests passed`; the negated `rg` exits 0 with no matches.

- [ ] **Step 10: Run the full repository verification**

Run:

```bash
just test
just check
git diff --check
git status --short
```

Expected: both Just recipes and `git diff --check` exit 0. `git status --short` lists exactly four changed files — `tests/tmp_cleanup.zsh`, `tests/setup_and_health.zsh`, `tests/dropbox_ignore_flux.zsh`, and `bin/dotfiles-check` — plus the user's pre-existing `niri/familiar.kdl` and `ghostty/` changes. It must not show changes to `setup.sh`, `bin/dotfiles-health`, or any shell function under test.

Confirm the `bin/dotfiles-check` diff is the single added `zsh_files` entry and nothing else.

- [ ] **Step 11: Commit the test-harness fix**

Run:

```bash
git add tests/tmp_cleanup.zsh tests/setup_and_health.zsh tests/dropbox_ignore_flux.zsh bin/dotfiles-check
git commit -m "test: make temp cleanup reliable"
```

Expected: one commit containing the shared cleanup helper, the two harness changes, and the one-line lint-coverage addition, with no `Co-Authored-By` trailer.
