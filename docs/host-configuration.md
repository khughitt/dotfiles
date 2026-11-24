# Host configuration

Type: guide; document types 1. Each `hosts/<host>/` directory records tuning,
inspection and restoration for that host, and `bin/` carries the host commands that
read it. See [host setup](setup.md) for installing the dotfiles and
[host CPU budget](host-budget.md) for the budget policy and agent scopes.

- `adopted.toml`: the files and blocks whose source of truth is that host directory.
  `just drift` (read-only) compares each with its installed copy and prints `ok`,
  `drift`, `missing`, `unreadable`, or `ambiguous`; `host-drift hosts/titan --diff`
  shows the difference. `host-drift` comes from hostkit. The run also reports each
  include in the global git config whose target is missing on this host.
- `etc/`: adopted whole files under their installed relative path.
- `systemd/user/` and `bin/`: user units and commands installed by copy.
- `blocks/`: adopted blocks of shared files. The installed file carries the block
  between `# >>> <marker> >>>` and `# <<< <marker> <<<`; only the block is tracked
  and compared, and the rest of the file stays out of this repository.
- `budget.toml`: the host's CPU-budget policy, linked to
  `~/.config/hostkit/budget.toml` for `host-budget`.
- `inventory.md`: a Source index mapping each relevant source to the settings it
  affects, then one section per setting: value, mechanism, provenance, persistence,
  previous and default values, and the restoration steps. Every section follows
  [the entry template](../hosts/inventory-entry.md), which
  `tests/test_host_inventory.py` enforces.

Files another repository tracks stay there; the inventory names their owner.
`systemd-sysctl.service` reapplies the adopted sysctl files at boot.

## Installing a source

A person resolves drift one entry at a time; the inventory says how it takes effect.
For example, to install titan's sysctl tuning from the dotfiles checkout:

    sudo install -o root -g root -m 644 hosts/titan/etc/sysctl.d/95-titan-tuning.conf /etc/sysctl.d/95-titan-tuning.conf
    sudo sysctl -p /etc/sysctl.d/95-titan-tuning.conf     # this file only, not --system

For the inotify watch limit, install and apply the later file last:

    sudo install -o root -g root -m 644 hosts/titan/etc/sysctl.d/96-titan-inotify.conf /etc/sysctl.d/96-titan-inotify.conf
    sudo sysctl -p /etc/sysctl.d/96-titan-inotify.conf
    sysctl fs.inotify.max_user_watches                 # expected: 2097152
    just drift

`96-titan-inotify.conf` owns the watch limit; `95-titan-tuning.conf` owns dirty
writeback tuning. See [titan's inventory](../hosts/titan/inventory.md) for
current settings and restoration steps.

Reinsert a block between its markers by hand, then confirm it with `just drift`.

## Running an experiment

One bounded change at a time, with the way back written before the change is made:

1. Capture the effective state (the `Inspect` command of the entry, output saved) and
   the persistent input: for a file, its content, ownership, mode, and symlink target,
   or the fact that it is absent. Captures with sensitive content stay outside Git
   with restricted permissions.
2. Make the one change and record the post-change state the same way.
3. Restore: compare the live state with the recorded post-change state first and stop
   if it differs (someone else edited in between). Undo the exact edit, then restore
   the captured live value through the same applying mechanism, and read it back.
   Removing a file, `daemon-reload`, or re-running `sysctl` is not, by itself,
   proof the runtime value came back. Coupled settings (the dirty writeback pair)
   are restored together. In a shared file only the experiment's block is removed.
   Boot-generated files are regenerated from source with the host's own generator
   and the runtime value checked only after an arranged reboot.
4. Clean up, and run the cleanup again from wherever it stopped: it must finish
   without error and report absence both times.

There is no generic reset-to-defaults command. Historical trials stay in private
records; each current inventory entry says whether its restoration has been validated.

## Checkout-local storage

On a host running hostkit, `work-link --ensure .worktrees` establishes relative
links through a host-local anchor beside the synced root, and excludes the Git
worktree admin directory from sync before creation. Run it before `git worktree add`,
then lock the new worktree with a reason naming its host. `just setup` hydrates
project dependencies and ignored inputs after creation.

The managed names are .worktrees, .venv and target (the latter only beside Cargo.toml).
node_modules stays in-tree because workspace links escape it; keep generated state
ignored by Dropbox after auditing that it holds no tracked or hand-edited files.
A missing relative-link target can be materialized by `work-link` or `just setup`.
A configured but unavailable WORK_ROOT fails visibly; do not replace it with a
synced environment. A real conflicting directory or foreign anchor needs inspection,
not an automatic move. Cross-filesystem migration requires stopped writers.
A checkout outside the synced tree is reported `outside` and remains in-tree.

## Disk report

`disk-report` answers "why is the machine complaining about space" in one call: every
/dev-backed volume with percent and free bytes; the top-N under the hot spots (`~/.cache`,
`$CACHE_DIR`, the `~/.codex` and `~/.claude` session stores, and the `.venv`,
`.worktrees`, `node_modules` and `target` directories still inside `~/d`); `$WORK_ROOT` by
repository with external entries no checkout stands behind marked `orphan`; inotify
watches and instances held by this user's processes against the sysctl limits (the case
where `df` shows free space and user units fail with `ENOSPC`); and the state of
`work-link.service`, whose failure is the drift signal for checkout-local storage. It
measures and never judges: thresholds belong to the caller, so it exits 0 whenever it ran.
`--json` for the Noctalia alert, a table by default; `--section NAME` (repeatable) picks
sections, and `volumes`, `inotify` and `services` together run in under a second where the
size sections take several.

## Display restoration

`display-dim` saves and restores monitor brightness for overnight TTY runs.
It requires `ddcutil` and user access to the monitor's i2c device; host setup is
the owner's action. Run:

    display-dim status       # at session start: shows records needing restoration
    display-dim set 0.25     # before the first quiet run; set alone defaults to 0.25
    display-dim restore      # after the last run, including failed runs

`set` accepts fractions from 0 to 1; quiet runs use 0.15–0.35. It requires exactly
one DDC-capable display. Its original brightness and EDID identity are saved in
`${XDG_STATE_HOME:-$HOME/.local/state}/display-dim/<EDID-hash>.json` before dimming;
repeated calls preserve the first original. Restoration uses EDID rather than a
display number, and removes each record only after a verified successful write.
`status` reads saved records without querying hardware; any record may be left
by an interrupted session and is reported as `restore-needed`.

Exit 2 means invalid input, ambiguous display or unusable state. Exit 3 means DDC
is unavailable or failed: the quiet run may continue undimmed and note the failure.
A rejected brightness read creates no record. A failed write removes a new record
only if readback proves the brightness stayed unchanged; an uncertain write keeps
the record so `restore` can recover. Failed restoration also keeps the record.
With no saved record, `restore` succeeds without calling `ddcutil`.
