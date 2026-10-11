# Git indexes in Dropbox

Decision, 2026-10-11 (dots-dbb1ae): keep Git's normal index paths and use
Dropbox's native ignore rules to make indexes local to each host. Git replaces
the index through a lock-file rename, so setting an xattr on the index once
does not protect subsequent writes. A post-index-change hook runs after that
rename and leaves a race with Dropbox. A `GIT_INDEX_FILE` wrapper misses callers
that bypass it, and periodic conflict cleanup leaves the corruption in place.

The `dropbox-ignore` setup phase appends these rules to
`~/d/rules.dropboxignore`, preserving existing rules and adding nothing on a
repeat run when its block is already last:

```text
**/.git/index*
**/.git/sharedindex*
**/.git/next-index-*
```

These cover the main index, locks, conflict copies, split indexes and temporary
partial-commit indexes directly under `.git`. Objects, refs, working files and
other Git metadata keep syncing. Do not use `**/.git/**/index*`: it also matches
refs such as `.git/refs/heads/index-feature`. Submodule indexes need exact paths
added during migration. Worktree admin directories remain managed by
`work-link`; they are already local.

[Dropbox's rules](https://help.dropbox.com/sync/how-to-prevent-files-from-syncing)
are per-device and apply only to newly created files. The rules file itself
does not sync. Every host must run setup. Support was tested on titan's Linux
client 272.4.3798: new indexes and atomic replacements reported `ignored`, a
control working file remained eligible for sync, and staged content survived migration of an
existing index. Verify the same behavior on any other client before rollout.

## Existing checkouts

Do this with both hosts available. Hold Git writers on both hosts until the
clients have restarted and confirmed every index is ignored. A writer during
startup can replace the marked inode before Dropbox observes its attribute,
leaving the previously synced index in circulation.

1. Pause both Dropbox clients with `dropbox-cli stop`. Check that they stopped;
   a disabled systemd unit says nothing about a desktop-launched client.
2. On each host, save every existing index and `sharedindex*` beside its relative
   repository path in a dated directory outside Dropbox. Record each file's
   checksum and `git --no-optional-locks status --porcelain` per checkout. Keep
   conflict copies too: they can contain a different staged snapshot. Refuse
   migration while an index lock exists or a Git writer is active.
3. Inventory submodule admin directories under `.git/modules` on each host.
   Add three root-relative rules per exact admin path to that host's rules file,
   ending in `/index*`, `/sharedindex*` and `/next-index-*`. For example:

   ```text
   /lore/.git/modules/vendor/superpowers/index*
   /lore/.git/modules/vendor/superpowers/sharedindex*
   /lore/.git/modules/vendor/superpowers/next-index-*
   ```

   Repeat this inventory when adding a submodule: setup's defaults cover ordinary
   `.git` roots only. Never put `**` between a module's admin path and its index
   basename: that could hide its refs too.
4. On each host, run:

   ```sh
   bash ~/d/dotfiles/setup.sh --headless --link-only --only dropbox-ignore
   ```

   Mark existing index and split-index files with
   `attr -s com.dropbox.ignored -V 1 <file>`; native rules cover their replacements.
   Confirm their checksums and staged status are unchanged. Never rebuild the
   index from HEAD: that would discard staged changes.
5. Remove only archived index conflict copies. Leave each live index intact.
6. Restart both clients through the chosen launch path. Wait for sync to settle
   and ask `dropbox-cli filestatus <index>`: it must say `ignored`. In a disposable
   checkout, stage a file, replace its staged contents, and check the status
   again. A working-file control must still sync. Recheck the real indexes and
   staged state on both hosts after sync settles.

The xattr removes an existing synced file from Dropbox and other devices;
marking it on both paused hosts first protects each host's own copy. Keep the
outside-Dropbox backups until both hosts pass verification. Recovery copies
the saved index and its split-index files back while Dropbox is stopped, then
reapplies the attributes before restarting it.

Use one launch path on both hosts: Dropbox's native desktop autostart.
The client recreates `~/.config/autostart/dropbox.desktop` when launched, so
`dropbox-cli autostart n` alone does not durably disable it. Disable the competing
systemd startup and stop that instance before starting the desktop client:

```sh
systemctl --user disable --now dropbox.service
dropbox-cli autostart y
dropbox-cli start
```

Use `dropbox-cli stop` followed by `dropbox-cli start` for manual restarts.
`systemctl --user restart dropbox` does not control a desktop-launched instance.
Keep the existing environment drop-ins untouched in case the startup policy
changes later. Confirm there is exactly one daemon with `pgrep -ax dropbox`.
