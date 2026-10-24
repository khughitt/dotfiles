---
id: dots-2ffaaa
title: Remove the obsolete capture-host sudoers grant count
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-24T13:48:52Z
updated: 2026-10-24T13:48:52Z
depends: []
tags: [docs]
source: dots-245e25
agent: codex
---

Why: README.md:84 says capture hosts need two explicit sudoers grants. docs/capture-host-setup.md:19 and bin/install-capture-sudoers:37 list/install three: 50-chvt, 50-fb-blank and 50-gpu-ctl.

Done: delete the obsolete word two, leaving the existing explicit-grants guidance and setup-document link. Preserve all grant details in the dedicated guide; inspect source and use normal documentation checks, without installing grants.
