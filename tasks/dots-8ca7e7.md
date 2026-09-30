---
id: dots-8ca7e7
title: "noctalia fastfetch template uses logo.recache, which fastfetch 2.69 rejects"
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-09-30T18:39:27Z
updated: 2026-09-30T18:39:27Z
depends: []
tags: [noctalia]
source: dots-43b9e5 verification 2026-09-30
agent: opencode/glm-5.3
---

Pre-existing on main, found while verifying dots-43b9e5: test_fastfetch_loads_generated_noctalia_config fails on this host with fastfetch 2.69.0 exiting 221: 'JsonConfig Error (logo.recache): Property logo.recache has been replaced by logo.cache with the value "regen"'. Rename the property in noctalia/templates/fastfetch.jsonc (rendered config parses fine; colors all resolve).
