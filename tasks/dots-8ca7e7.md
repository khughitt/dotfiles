---
id: dots-8ca7e7
title: "noctalia fastfetch template uses logo.recache, which fastfetch 2.69 rejects"
status: done
priority: 3
size: xs
complexity: low
process: direct
owner: fix/fastfetch-logo-cache
created: 2026-09-30T18:39:27Z
updated: 2026-10-06T16:22:37Z
started: 2026-10-06T16:20:15Z
completed: 2026-10-06T16:22:37Z
depends: []
tags: [noctalia]
source: dots-43b9e5 verification 2026-09-30
agent: opencode/glm-5.3
---

Pre-existing on main, found while verifying dots-43b9e5: test_fastfetch_loads_generated_noctalia_config fails on this host with fastfetch 2.69.0 exiting 221: 'JsonConfig Error (logo.recache): Property logo.recache has been replaced by logo.cache with the value "regen"'. Rename the property in noctalia/templates/fastfetch.jsonc (rendered config parses fine; colors all resolve).

## Notes

- 2026-10-06T16:20:15Z (fix/fastfetch-logo-cache): started
- 2026-10-06T16:22:37Z (fix/fastfetch-logo-cache): done
- 2026-10-06T16:22:37Z (fix/fastfetch-logo-cache): Renamed logo.recache to logo.cache (true) in noctalia/templates/fastfetch.jsonc; test_fastfetch_loads_generated_noctalia_config passes with fastfetch 2.69 (97 pytest passed).
