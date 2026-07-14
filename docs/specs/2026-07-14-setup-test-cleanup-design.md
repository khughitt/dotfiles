# Setup Test Cleanup Design

## Problem

`tests/setup_and_health.zsh` registers temporary-directory cleanup with:

```zsh
trap 'rm -rf "$tmp"' EXIT
```

The single quotes defer expansion of `tmp` until process exit. When an assertion
calls `fail`, the test function ends before the EXIT trap runs; under
`set -u`, its function-local `tmp` is then unset. The intended assertion is
followed by `tmp: parameter not set`, and cleanup may be skipped.

The problem affects every test using this pattern, not only the two
memory-alert tests that exposed it. There are 14 affected call sites in
`tests/setup_and_health.zsh` and three more in
`tests/dropbox_ignore_flux.zsh`.

## Chosen Approach

Add a shared `tests/tmp_cleanup.zsh` helper that both harnesses source at shell
top level with `source "${0:A:h}/tmp_cleanup.zsh"`. Resolving the helper from
the harness script's own directory keeps it independent of the caller's
working directory.

```zsh
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

The `EXIT` trap must be installed while the helper file is sourced at shell
top level. In zsh, an `EXIT` trap installed inside `register_tmp_cleanup`
would run as soon as that function returns, deleting the directory before the
test body uses it. The registration function therefore only appends the path
to a global array; one top-level trap owns cleanup for the process.

Replace all 17 fragile traps with `register_tmp_cleanup "$tmp"`. Successful
tests keep their explicit `rm -rf "$tmp"`, while their per-function
`trap - EXIT` lines are removed because cleanup is now owned by the shared
top-level trap. Retaining already-removed paths in the small registry is
intentional: the final `rm -rf` is idempotent, and avoiding unregister logic
keeps the failure path simple.

The helper uses `cleanup_path` rather than `path`; `path` is a special zsh
array tied to the command-search `PATH` variable.

## Regression Test

Add a focused subprocess test that:

1. creates a temporary directory;
2. sources `tests/tmp_cleanup.zsh` at shell top level;
3. enters a nested function with a local path;
4. registers cleanup and immediately asserts that the directory still exists;
5. writes a sentinel after registration, then exits with status 17;
6. verifies from the parent that status 17 is preserved;
7. verifies from the parent that the directory was removed only after the
   child exited; and
8. verifies that stderr does not contain `parameter not set`.

Add a static guard covering both harnesses that fails if either contains any
`trap` line. Cleanup is wholly owned by `tests/tmp_cleanup.zsh`, so the broader
invariant catches reintroduced traps regardless of quoting or variable name.
The test-first red state is the guard reporting the existing trap lines; it is
not a vacuous missing-command failure. The complete setup/health suite and
repository checks must remain green.

## Scope

- Add `tests/tmp_cleanup.zsh`.
- Modify `tests/setup_and_health.zsh` and `tests/dropbox_ignore_flux.zsh`.
- Do not change `setup.sh`, `bin/dotfiles-health`, production behavior, or the
  shell functions under test.
- Preserve unrelated `niri/familiar.kdl` and `ghostty/` changes.
