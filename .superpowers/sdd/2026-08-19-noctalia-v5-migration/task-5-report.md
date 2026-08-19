# Task 5 report: route shell Wali wallpaper state through one helper

## Implementation

- Select Noctalia on Wayland by `noctalia` executable availability, before `swww` and `feh`.
- Use native v5 commands for random, get, and set; `_wali_current_wallpaper` is the shared state query for `wali_print` and `wali_rotate`.
- Add a mock Noctalia integration regression with no `.fehbg`.

## Files

- `shell/wali`
- `tests/wali.zsh`

## Regression coverage

The test catches Noctalia falling through to `feh` when its shell is stopped, either consumer reading missing `.fehbg`, and accidental legacy Quickshell IPC use. It verifies the native `wallpaper-get` and `wallpaper-set` calls.

## Verification

- RED: `zsh tests/wali.zsh` failed as expected because `_wali_current_wallpaper` did not exist, then `wali_print` attempted the missing `.fehbg`.
- GREEN: `zsh tests/wali.zsh` passed.
- Full suite: `just test` passed: 25 Python tests and all invoked shell checks.

## Self-review

- Confirmed backend precedence is Noctalia, `swww`, then `feh`, based only on executable availability on Wayland.
- Confirmed both wallpaper consumers call `_wali_current_wallpaper`; no Noctalia fallback or legacy IPC remains.
- Confirmed `git diff --check` is clean.

## Concerns

None.
