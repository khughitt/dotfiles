# Capture-host sudoers rules

On the Linux capture host, run from the dotfiles checkout:

```sh
sudo bin/install-capture-sudoers "$(id -un)"
```

Pass the capture account's username explicitly when setting up another account.
The installer requires an existing account with a lowercase Unix username and
GNU coreutils and `visudo` (from `sudo`). These grants are host-specific, so
ordinary `setup.sh` runs do not install them.

The installer validates both generated files with `visudo -cf` before installing
either under `/etc/sudoers.d`, owned by root with mode `0440`:

| File | Passwordless command as root |
| --- | --- |
| `50-chvt` | `/usr/bin/chvt` (VT switching for the real-TTY capture lane) |
| `50-fb-blank` | `/usr/bin/tee /sys/class/graphics/fb0/blank` (display standby and restore) |

The `tee` grant allows only that exact file argument. Writing `4` powers down
the display on the reference host with no compositor running; `0` restores it.
`chvt` accepts its normal arguments. Neither command is executed by the installer.

Re-running for the same account leaves matching files untouched; GNU
`install -C` repairs changed content, ownership, or permissions. Running for a
different account replaces both grants with that account's rules.

Check authorization from the capture account without changing the display:

```sh
sudo -n -l /usr/bin/chvt
sudo -n -l /usr/bin/tee /sys/class/graphics/fb0/blank
```

To revoke these grants, remove `/etc/sudoers.d/50-chvt` and
`/etc/sudoers.d/50-fb-blank` as root.
