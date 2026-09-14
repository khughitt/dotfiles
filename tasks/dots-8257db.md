---
id: dots-8257db
title: Move tool caches off the root filesystem to /mnt/ssd2/cache
status: done
priority: 1
size: s
complexity: low
process: direct
owner: cache-dir-ssd2
created: 2026-09-14T11:04:50Z
updated: 2026-09-14T11:11:38Z
started: 2026-09-14T11:04:54Z
completed: 2026-09-14T11:11:38Z
depends: []
tags: [configuration]
model: "claude-opus-5[1m]"
agent: claude-code/claude-opus-5
---

Root is at 93% with ~99G of relocatable or regenerable tool caches under ~/.cache (huggingface 31G, pycache 23G, noctalia wallpapers 12G, yay 9.2G, npm 13G, bun 3.4G, playwright 3.2G, go-build 2.6G, puppeteer 1.3G). zshenv already defines CACHE_DIR as the host-overridable base for tool caches; titan never overrode it. Set CACHE_DIR=/mnt/ssd2/cache in shell/local/titan.env.zsh (same NVMe as root, 1.1T free, already hosts uv-cache and rustup), route HF_HOME, GOCACHE, npm_config_cache, PLAYWRIGHT_BROWSERS_PATH, PUPPETEER_CACHE_DIR, and BUN_INSTALL_CACHE_DIR through CACHE_DIR in zshenv, move the existing data, and delete the caches that regenerate (pycache, yay, go-build). The Noctalia wallpaper cache has no env knob and is symlinked. Verification: env in a fresh shell shows the new paths, df / drops below 60%, just test passes.

## Notes

- 2026-09-14T11:11:38Z (cache-dir-ssd2): Also fixed alongside: user systemd logged ENOSPC on inotify watches; dropbox held 523850/524288 max_user_watches (one per directory under ~/d, ~470k of ~580k are in dropbox-ignored .venv/.worktrees/node_modules/target subtrees). Raised to 2097152 via a new B7 step in the untracked system-tuning/apply-titan.sh (/etc/sysctl.d/96-titan-inotify.conf). Shrinking the tree is ops-515402 / ops-40857b.
- 2026-09-14T11:11:38Z (cache-dir-ssd2): Data moved: huggingface 31G, npm 13G (~/.npm whole dir), bun install cache 3.4G, ms-playwright 3.2G, puppeteer 1.3G, and the Noctalia wallpapers cache 12G (symlinked ~/.cache/noctalia/images/wallpapers -> /mnt/ssd2/cache/noctalia/images/wallpapers since Quickshell has no env knob). Deleted: pycache 23G, yay 9.2G, go-build 2.6G. / went 93% -> 53%. /mnt/ssd2 is DRAM-less QLC (system-tuning B4): fine for these read-heavy caches, not for sustained-write intermediates.
- 2026-09-14T11:11:38Z (cache-dir-ssd2): CACHE_DIR=/mnt/ssd2/cache on titan; zshenv routes HF_HOME, GOCACHE, npm_config_cache, PLAYWRIGHT_BROWSERS_PATH, PUPPETEER_CACHE_DIR, BUN_INSTALL_CACHE_DIR through CACHE_DIR; caches moved or deleted; root at 53%.
