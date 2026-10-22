---
id: dots-ffaca6
title: Complete icat filenames by substring like other commands
status: done
priority: 3
size: xs
complexity: low
process: direct
owner: fix/icat-completion
created: 2026-10-22T23:17:46Z
updated: 2026-10-22T23:32:03Z
started: 2026-10-22T23:17:51Z
completed: 2026-10-22T23:32:03Z
closed: 2026-10-22T23:32:03Z
depends: []
tags: [kitty]
agent: claude-code/claude-opus-5-5
---

The icat alias expands to 'kitty +kitten icat' during completion, so it uses kitty's _kitty completer. kitten __complete__ filters by prefix itself (compadd -U) and refuses anchor matchers ('r:|=*', 'l:|=* r:|=*') from matcher-list, so 'icat den<TAB>' finds nothing while 'ls den<TAB>' completes. Fix: make icat a shell function with its own zsh completer over image files, so matcher-list applies.

## Notes

- 2026-10-22T23:17:51Z (main): started
  provenance: {"harness_session":"claude-code:10c2a812-d5b6-415a-a14c-4528f00be05b","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T23:18:01Z (fix/icat-completion): resumed
  provenance: {"harness_session":"claude-code:10c2a812-d5b6-415a-a14c-4528f00be05b","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T23:32:03Z (fix/icat-completion): done
  provenance: {"harness_session":"claude-code:10c2a812-d5b6-415a-a14c-4528f00be05b","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
- 2026-10-22T23:32:03Z (fix/icat-completion): icat is a function with an _icat image-file completer (shell/functions.d/media.zsh, registered in zshrc), so matcher-list substring matching applies; tests/icat_completion.zsh drives a zpty shell
  provenance: {"harness_session":"claude-code:10c2a812-d5b6-415a-a14c-4528f00be05b","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
