---
id: dots-3a1f76
title: Age the relocated caches with a tmpfiles timer
status: todo
priority: 2
size: s
complexity: low
process: direct
created: 2026-09-14T11:13:07Z
updated: 2026-09-14T11:13:07Z
depends: []
tags: [configuration]
agent: claude-code/claude-opus-5
---

dots-8257db moved the tool caches to CACHE_DIR=/mnt/ssd2/cache but nothing bounds them; pycache alone had grown to 23G and yay's build cache to 9.2G before the 2026-09-14 cleanup. Follow the ssd3-tmp-clean pattern (systemd/user/ssd3-tmp-clean.{service,timer,tmpfiles.conf}): a tmpfiles age rule for the regenerable trees under CACHE_DIR (pycache, go-build, ms-playwright is not regenerable cheaply — leave it) and a weekly service running the tools' own pruners (uv cache prune, yay -Sc --noconfirm, npm cache verify). Verification: the timer is listed by systemctl --user list-timers, a dry run of systemd-tmpfiles --clean reports the aged paths, and the units pass tests/setup_and_health.zsh.
