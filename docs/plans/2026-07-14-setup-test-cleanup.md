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
- Do not change `setup.sh`, `bin/dotfiles-health`, shell functions under test, or the pre-existing suite-list mismatch between `justfile` and `bin/dotfiles-check`.
- Preserve the user's unrelated `niri/familiar.kdl` and `ghostty/` changes.

---

### Task 1: Centralize temporary-directory cleanup

**Files:**
- Create: `tests/tmp_cleanup.zsh`
- Modify: `tests/setup_and_health.zsh:1-397`
- Modify: `tests/dropbox_ignore_flux.zsh:1-130`
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

- [ ] **Step 4: Source the helper from each harness's own directory**

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

- [ ] **Step 5: Add the process-level timing regression test**

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

Invoke it immediately after the static guard and before the setup tests:

```zsh
test_tmp_cleanup_is_centralized
test_tmp_cleanup_runs_only_at_process_exit
test_setup_dry_run_link_only_does_not_write_home
```

The child's status 17 proves it reached the code after registration, and the parent checks removal only after the child process has exited.

- [ ] **Step 6: Convert every cleanup call site**

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

- [ ] **Step 7: Run the focused harnesses and guard**

Run:

```bash
zsh tests/setup_and_health.zsh
zsh tests/dropbox_ignore_flux.zsh
! rg -n '^[[:space:]]*trap([[:space:]]|$)' \
  tests/setup_and_health.zsh tests/dropbox_ignore_flux.zsh
```

Expected: both harnesses exit 0 and print `setup and health tests passed` and `dropbox_ignore_flux tests passed`; the negated `rg` exits 0 with no matches.

- [ ] **Step 8: Run the full repository verification**

Run:

```bash
just test
just check
git diff --check
git status --short
```

Expected: both Just recipes and `git diff --check` exit 0. `git status --short` lists only the three intended test files plus the user's pre-existing `niri/familiar.kdl` and `ghostty/` changes; it must not show changes to production files.

- [ ] **Step 9: Commit the test-harness fix**

Run:

```bash
git add tests/tmp_cleanup.zsh tests/setup_and_health.zsh tests/dropbox_ignore_flux.zsh
git commit -m "test: make temp cleanup reliable"
```

Expected: one commit containing only the shared cleanup helper and the two harness changes, with no `Co-Authored-By` trailer.
