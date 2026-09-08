---
id: dots-c18dbc
title: Tests create fixture directories inside the real repository
status: todo
priority: 3
size: xs
created: 2026-09-08T22:15:45Z
updated: 2026-09-08T22:15:45Z
depends: []
tags: [testing, hygiene]
---

Found on titan 2026-09-08. tests/setup_and_health.zsh does mktemp -d "${repo_root}/prism/wali-test.XXXXXX" and registers cleanup, but an interrupted run leaks the directory into the working tree; prism/wali-test.PJD9Dw was left behind during this session. It is not only litter: dotfiles-health derives the machine list from prism/*/, so a leaked fixture is reported as a machine. Outcome: fixtures live outside the repository, or the test constructs its prism root under its own tmpdir.
