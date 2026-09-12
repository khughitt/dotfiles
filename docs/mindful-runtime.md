# Mindful v6 runtime preparation

Status: prepared tooling; no runtime activation has occurred. The approved
cutover plan lives in `~/d/mindful/v6/docs/plans/2026-09-12-mindful-v6-local-cutover-plan.md`.

Build a clean, reviewed checkout into a new release ID. The builder installs and
builds in that checkout, checks the linked nodes build, and copies dependencies
and the selected Node executable. It refuses dirty sources, insufficient space,
and an existing destination. Read `provenance.json` for both Git revisions,
package-lock hash, Node version, build time, and every copied runtime hash.

```sh
~/d/dotfiles/bin/mindful-release --checkout "$REVIEWED_CHECKOUT" \
  --output "$HOME/.local/share/mindful/releases/$RELEASE_ID"
```

Keep this preparation branch unmerged until cutover: `~/bin/mindful` is already a
symlink into the main Dots checkout, so merging the replacement launcher changes
the active command immediately. The pre-cutover launcher is:

```sh
#!/usr/bin/env bash
exec node "$HOME/d/mindful/v6/packages/mindful/dist/bin.js" "$@"
```

Retain that launcher in the private cutover record, along with the old `current`
target, prior release, service enablement, and existing v3 Compose configuration.
No development-checkout fallback exists in the new launcher. Its default store
is `~/d/thoughts`; explicit `MINDFUL_HOME` supports isolated tests/maintenance.

`setup.sh` links the three new units but never enables them, even with
`--enable-user-timers`. It no longer links `mindful-docker.service` or requires
the v3 database password. It does not remove an existing v3 unit/wants link or
credentials: `~/.config/mindful.env` and the old unit source remain for rollback.
Do not run setup against the live home during preparation.

At the separately approved cutover, while writers are frozen, retain the old
store and launcher, promote the verified candidate store, merge/install the
reviewed launcher and units, and atomically replace `current` using a temporary
symlink and same-directory rename. Stop/disable the old v3 unit and inspect
Compose containers/restart policies without deleting its database storage. Then
start/enable `mindful-web.service` and verify `http://localhost:3331` forms,
loopback listeners, capture, and restart persistence. Health checks reject a
revivable v3 unit after `current` exists and verify the loaded web environment.

## Backups and isolated restore

The backup script stops web only if it was active, acquires the release's
`acquireWriterLock(root, 'cli')`, and archives the entire store except its root
`.nodes-index` and `.mindful-index` projections. Source, native history (including
deleted nodes), config, permissions, symlinks, and hardlinks remain in the archive.
A contending CLI writer fails the backup without breaking its lock. Gzip and tar
integrity checks and SHA-256 precede atomic archive publication; archives are
private (mode 0600). Cleanup removes only this run's incomplete files. Web is
restarted in `finally` if it was originally active, including failed backup
runs; a restart failure is reported alongside the original error. Previous good
backups, including a newly completed archive when restart fails, are retained.
SIGINT/SIGTERM stop and wait for the archive child before releasing the lock and
restarting web. SIGKILL or power loss cannot run cleanup: inspect the service and
writer-lock holder before manual recovery; never remove a live writer's lock.

```sh
release="$HOME/.local/share/mindful/releases/$RELEASE_ID"
"$release/bin/node" ~/d/dotfiles/bin/mindful-backup.mjs \
  --release "$release" --root "$TEMP_STORE" --output "$TEMP_BACKUPS" \
  --service mindful-rehearsal.service --attachments "$ATTACHMENTS_MANIFEST"
```

The optional private JSON attachment manifest is an array of absolute directory
roots and explicit archive names, for example:

```json
[{"path":"/private/example/assets","name":"assets"}]
```

Names are single safe path components, unique across the manifest; parent
traversal is refused. The archive contains `store/`, `attachments/<name>/`, and
`backup.json`, which records every included root. External symlink targets are
preserved as links, not dereferenced: inventory them explicitly as attachment
roots when their bytes need backing up. Stop writers of attachment roots during
the backup; the Mindful lock governs the store alone. Rehearsal acceptance is
blocked until every inventoried attachment root is in this manifest or has a
separately verified backup. Do not enable the timer until that inventory is
recorded. To supply the private manifest to nightly backups, install a reviewed
`mindful-backup.service.d/attachments.conf` that resets `ExecStart=` and repeats
the source unit's command with `--attachments <absolute-manifest-path>` appended.

```sh
cd "$TEMP_BACKUPS"
sha256sum --check "$ARCHIVE_NAME.sha256"
gzip --test "$ARCHIVE_NAME"
mkdir "$RESTORE_DIR"
tar --extract --gzip --file "$ARCHIVE_NAME" --directory "$RESTORE_DIR"
```

Compare all original source/history/config and attachment bytes against the
restored copy before rebuilding indexes there. Never extract over a live store.
The timer runs at 03:00 local time with `Persistent=true`, under
`~/d/mindful/archive/backup/v6`. Enable it only at approved cutover after a real
backup/restore succeeds. Keep all backups; no automatic expiry is implemented.
Nightly backups briefly interrupt writes. HTTP captures during that window fail
to their callers; they are neither queued nor automatically retried.
The backup unit orders after queued web startup for persistent timer catch-up.
It runs the backup script from the live Dots checkout using the release's Node;
editing that script changes nightly backup behavior without a release bump.

On failed cutover acceptance, stop v6 and snapshot every post-activation write
first. Disable the new backup timer, restore the retained store/release/launcher,
and deliberately restore the old v3 service configuration. Reconcile the new-v6
write delta before reopening v3 capture. Never discard a delta during rollback.
