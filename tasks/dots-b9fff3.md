---
id: dots-b9fff3
title: work-link --migrate refuses every entry while a docker container runs
status: doing
priority: 2
size: s
complexity: mid
process: direct
owner: main
created: 2026-09-23T10:23:15Z
updated: 2026-10-08T14:24:00Z
started: 2026-10-08T14:24:00Z
depends: []
tags: [work-link]
agent: "claude-code/claude-opus-5-5[1m]"
---

Found during ops-d099f0 on 2026-09-23: with nexcode containers up, lsof +D prints 'WARNING: can't stat() overlay file system .../mindful-docker/data/overlay2/<id>/merged' for every call; work_link_open_handles treats any lsof warning as an inspection failure, so --migrate and tests/work_link.zsh refuse every entry (baseline main fails the same way). Likely fix: exempt overlay mounts (lsof -e per findmnt -t overlay target) or match only warnings about paths under the inspected directory. ops-d099f0 verified its runs with a PATH wrapper doing the former.

## Notes

- 2026-09-23T10:24:11Z (main): Also nsfs mounts (/run/docker/netns/*) produce the same warning.
- 2026-10-08T14:24:00Z (main): started
  provenance: {"harness_session":"claude-code:cd13df6e-7206-46e3-bd3f-30be99c37559","harness_session_source":"CLAUDE_CODE_SESSION_ID"}
