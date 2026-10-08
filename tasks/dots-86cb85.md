---
id: dots-86cb85
title: "work-link: a checkout moved to a different depth shows up as foreign links plus orphan storage; recognise the pair and offer the move"
status: todo
priority: 3
size: s
created: 2026-10-08T14:35:15Z
updated: 2026-10-08T14:35:15Z
depends: []
tags: [work-link]
agent: claude-code
---

Seen 2026-10-08 (ops-3566ce): a checkout moved one level deeper under the scan root kept its relative links at the old depth (reported foreign) while its storage stayed at the old external path (reported orphan, 'no checkout behind it'). The repair was mechanical: move the storage to the new mirrored path, rewrite each link at the new depth, git worktree repair. Converge reports the two halves as unrelated entries; it could match an orphan's path to a foreign link whose text names it and print (or, in a repair mode, perform) that move. Done: such a pair is reported as one moved entry with the exact commands, with a test.
