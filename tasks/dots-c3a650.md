---
id: dots-c3a650
title: Restore git identity and drop protocol.file.allow in git/config
status: todo
priority: 0
size: xs
complexity: low
process: direct
created: 2026-10-16T16:29:42Z
updated: 2026-10-16T16:29:42Z
depends: []
tags: []
agent: claude-code/claude-opus-5-5
---

A sandboxed test script (HOME overridden, XDG_CONFIG_HOME not) ran git config --global on 2026-10-07 and wrote user.name=t, user.email=t@t and [protocol "file"] allow = always into git/config through ~/.config/git; be55b00 committed it. Restore the real identity and remove the protocol.file override (it disables git's CVE-2022-39253 mitigation).
