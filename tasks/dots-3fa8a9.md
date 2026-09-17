---
id: dots-3fa8a9
title: opencode theme fallback test fails against opencode 2.0.3
status: idea
priority: 2
created: 2026-09-17T11:26:18Z
updated: 2026-09-17T11:26:18Z
depends: []
tags: []
agent: crush
---

tests/opencode_theme_fallback_test.py asserts the 1.18.18 TUI rendering (Ask anything prompt plus the 48;2;10;10;10 background escape); the host now has /usr/bin/opencode v2.0.3 and the probe fails on both dangling and malformed themes, which blocks bin/dotfiles-check and everything after it in just test. Seen on clean main on 2026-09-17 while fixing dots-4f3ff3.
