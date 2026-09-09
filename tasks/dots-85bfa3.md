---
id: dots-85bfa3
title: The wali-panel manifest contract test still expects the pre-cutover panel height
status: done
priority: 2
size: xs
created: 2026-09-09T09:09:20Z
updated: 2026-09-09T09:24:09Z
depends: []
tags: [testing, noctalia, wali]
---

Found on titan 2026-09-09 while adding the config-leak check. tests/setup_and_health.zsh:test_noctalia_v5_config_contract asserts the wali-panel plugin manifest declares height 798; faa3c31 (photo-first layout) set it to 520 and did not update the assertion, so zsh tests/setup_and_health.zsh has been failing on main since. The test dies before every later test in the file, including the ones added after it. Outcome: the assertion matches the shipped manifest, or the height stops being asserted if the polish pass will keep moving it.

## Notes

- 2026-09-09T09:24:09Z (main): The manifest assertion now matches the shipped height (520 since faa3c31); the file's later tests run again.
