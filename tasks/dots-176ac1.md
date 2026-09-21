---
id: dots-176ac1
title: Parse opencode/opencode.json as JSONC in the noctalia agent themes test
status: doing
priority: 2
size: xs
complexity: low
process: direct
owner: main
created: 2026-09-21T09:50:07Z
updated: 2026-09-21T09:52:42Z
started: 2026-09-21T09:50:13Z
depends: []
tags: []
agent: claude-code/claude-opus-5
---

tests/noctalia_agent_themes_test.py fails at collection with JSONDecodeError since 08f7430 commented out the familiar plugin line with a // comment. opencode itself accepts JSONC in opencode.json (verified with 'opencode debug config' on 2.0.11), so the file is valid for its consumer; the test's strict json.loads is what is wrong. Blocks bin/dotfiles-check and just test on clean main.

## Notes

- 2026-09-21T09:50:13Z (main): started
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-09-21T09:52:42Z (fix/agent-theme-tests): JSONC parse landed on fix/agent-theme-tests. Remaining failure is real: 08f7430 also commented out theme=noctalia in tui.json, so the assertion opencode_tui[theme]==noctalia fails on substance. opencode 2.x reads the theme from both tui.json (legacy) and the new untracked ~/.config/opencode/cli.json (v2 schema; holds theme.name=noctalia, renamed keybinds, sidebar/thinking/diffs/animations). bin/opencode-config-migrate only manages opencode.json+tui.json.
- 2026-09-21T09:52:42Z (fix/agent-theme-tests): parked (waiting on user, decision): Decide: track opencode/cli.json as the 2.x config (extend opencode-config-migrate + its test, assert cli theme.name), or restore theme=noctalia in tui.json and keep the assertion
  provenance: {"harness_session":"claude-code:c0f271e1-a69e-447e-854e-5127749f824c","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
