---
id: dots-dbb1ae
title: Git index files under Dropbox produce conflicted copies across hosts and stall sync
status: todo
priority: 2
size: s
complexity: mid
process: direct
created: 2026-10-06T11:20:33Z
updated: 2026-10-08T00:12:17Z
depends: []
tags: []
agent: claude-code/claude-fable-5-1
---

Checkouts under ~/d keep .git in-tree in Dropbox, so two hosts share .git/index by file sync. Observed 2026-10-05/06: '.git/index (europa's conflicted copy …)' and '(titan's conflicted copy …)' in lore, tack and ops; europa's Dropbox sat for twenty minutes 'Uploading 3 files' (three .git/index copies touched by read-only git commands there) while delivering none of the other host's new commits; and a stale index entry showed a file as staged and modified although the tree equalled the commit. The worktree admin directory is already kept out of Dropbox by work-link. Done: a decision recorded on whether the index gets the same treatment (per-host index via GIT_INDEX_FILE or a core.worktree/split layout, a Dropbox ignore attribute on .git/index, or accepting the copies with a periodic sweep), the chosen remedy applied on both hosts, and the existing conflicted copies removed. Related: on europa Dropbox runs from the desktop autostart while its systemd user unit is disabled, so 'systemctl --user restart dropbox' does nothing there; settle one launch path for both hosts.

## Notes

- 2026-10-08T00:12:17Z (main): evidence 2026-10-07 (hq cutover): a plain git status run over ssh on the second host rewrote that host's .git/index while it still held the pre-commit entry; Dropbox carried it back over this host's index a minute after a commit, leaving a phantom MM on the committed file (whole-second mtime marks the Dropbox write). Fixed with git reset -- <path>; polling the other host with git --no-optional-locks status avoided it from then on.
