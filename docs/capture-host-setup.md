# Capture-host sudoers rules

On the Linux capture host, run from the dotfiles checkout:

```sh
sudo bin/install-capture-sudoers "$(id -un)"
```

Pass the capture account's username explicitly when setting up another account.
The installer requires an existing account with a lowercase Unix username and
GNU coreutils and `visudo` (from `sudo`). These grants are host-specific, so
ordinary `setup.sh` runs do not install them.

The installer validates every generated file with `visudo -cf` before installing
any of them under `/etc/sudoers.d`, owned by root with mode `0440`. Before the
rules it installs `bin/gpu-ctl` as `/usr/local/sbin/gpu-ctl`, owned by root
with mode `0755`, so the grant never points at a missing or user-writable file:

| File | Passwordless command as root |
| --- | --- |
| `50-chvt` | `/usr/bin/chvt` (VT switching for the real-TTY capture lane) |
| `50-fb-blank` | `/usr/bin/tee /sys/class/graphics/fb0/blank` (display standby and restore) |
| `50-gpu-ctl` | `/usr/local/sbin/gpu-ctl persistence on\|off`, `fan auto`, `fan 45`–`fan 100` (GPU idle-state probes) |

The `tee` grant allows only that exact file argument. Writing `4` powers down
the display on the reference host with no compositor running; `0` restores it.
`chvt` accepts its normal arguments. None of these commands is executed by the installer.

`gpu-ctl` talks to NVML directly, so unlike `nvidia-settings` it needs no
display. Its writes act on GPU 0 and every fan it reports. `gpu-ctl status`
needs no privilege. `fan auto` hands the fans back to the card's own curve,
which stops them at idle (zero RPM). `fan N` holds them at N%, and the rule
and the helper both refuse anything below 45, the floor above the measured
stall edge that `gpu-fan-curve` uses. In a desktop session `gpu-fan-curve`
re-asserts manual control within its 60 s verify, so a fan change made there
does not last.

Re-running for the same account leaves matching files untouched; GNU
`install -C` repairs changed content, ownership, or permissions, and installs
an edited `bin/gpu-ctl` over the root copy. Running for a different account
replaces every grant with that account's rules.

Check authorization from the capture account without changing the display:

```sh
sudo -n -l /usr/bin/chvt
sudo -n -l /usr/bin/tee /sys/class/graphics/fb0/blank
sudo -n -l /usr/local/sbin/gpu-ctl fan auto
gpu-ctl status          # or /usr/local/sbin/gpu-ctl status
```

To revoke these grants, remove `/etc/sudoers.d/50-chvt`,
`/etc/sudoers.d/50-fb-blank`, `/etc/sudoers.d/50-gpu-ctl` and
`/usr/local/sbin/gpu-ctl` as root.
