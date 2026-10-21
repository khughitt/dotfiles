---
id: dots-4b300c
title: Manage github.com's published SSH host keys in known_hosts on every host
status: idea
priority: 2
created: 2026-10-21T18:18:01Z
updated: 2026-10-21T18:18:01Z
depends: []
tags: []
source: hq-c6c847
agent: claude-code/claude-opus-5-5
---

Europa had no github.com known_hosts entry, so noninteractive git over SSH (familiar-theme's pinned source) failed with 'Host key verification failed' and blocked the relay cutover's readiness check. Fixed by hand on 2026-10-21 (Titan's three entries, fingerprints matching GitHub's published keys; backup ~/.ssh/known_hosts.pre-github-2026-10-21 on Europa). Dotfiles could install the published keys declaratively on every host.
