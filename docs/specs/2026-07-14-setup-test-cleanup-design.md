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

The problem affects every test using this pattern in
`tests/setup_and_health.zsh`, not only the two memory-alert tests that exposed
it. `tests/dropbox_ignore_flux.zsh` uses the same pattern, but changing that
separate harness is outside this fix.

## Chosen Approach

Add one test-harness helper:

```zsh
register_tmp_cleanup() {
  local cleanup_path="$1"
  trap "rm -rf -- ${(q)cleanup_path}" EXIT
}
```

`${(q)cleanup_path}` is expanded while the helper runs, so the installed trap
contains the safely quoted path value rather than a later reference to a local
variable. The helper deliberately avoids zsh's special `path` array, which is
tied to the command-search `PATH` variable.
Replace every fragile trap in `tests/setup_and_health.zsh` with
`register_tmp_cleanup "$tmp"`.

Successful tests keep their existing explicit `rm -rf "$tmp"` followed by
`trap - EXIT`; the registered trap remains a failure-path fallback.

## Regression Test

Add a focused harness test that:

1. creates a temporary directory;
2. enters a subshell and a nested function with a local path;
3. registers cleanup and exits the subshell with a known nonzero status;
4. verifies that the status is preserved;
5. verifies that the directory was removed; and
6. verifies that stderr does not contain `parameter not set`.

The test must fail before `register_tmp_cleanup` exists, then pass after the
helper and call-site replacements are added. The complete setup/health suite
and repository checks must remain green.

## Scope

- Modify only `tests/setup_and_health.zsh`.
- Do not change `setup.sh`, `bin/dotfiles-health`, production behavior, or the
  separate Dropbox test harness.
- Preserve unrelated `niri/familiar.kdl` and `ghostty/` changes.
