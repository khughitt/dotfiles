# Fresh install: storage & system hardening

Changes worth recreating on a clean Arch install. Derived from the 2026-08-06
session that followed an NVMe drive dropping off the PCIe bus, the 2026-08-08
session that added the Windows dual boot and fixed DKMS rebuild time, and the
2026-09-01 session that gated kernel updates.

## Packages

```sh
pacman -S smartmontools nvme-cli lm_sensors fwupd
```

`smartmontools` and `nvme-cli` are the ones that matter — without them there is
no SMART history at all, and no way to tell a dying disk from a noisy log.

## Enabled system services

Arch packages generally install system services disabled. This machine enables
the following non-preset units deliberately:

```sh
systemctl enable --now NetworkManager bluetooth docker
systemctl enable --now fstrim.timer paccache.timer smartd
systemctl enable --now linux-modules-cleanup.service gpu-fan-curve.service
```

Install the relevant packages and the GPU unit before running the whole block.
Enabling NetworkManager also enables its dispatcher and wait-online companions;
do not copy or enable those separately. `getty@.service`, `remote-fs.target`,
and `systemd-userdbd.socket` come from the stock systemd preset.

## zram

The 16 GiB zram device uses zstd. Install the captured generator configuration,
then reboot so the generator can recreate the swap device cleanly:

```sh
install -Dm0644 systemd/zram-generator.conf /etc/systemd/zram-generator.conf
reboot
zramctl
```

## User services

Link the user units and enable the timers that are safe everywhere — Dropbox
maintenance and the kernel-gate nudge:

```sh
./setup.sh --link-only --headless --only systemd --enable-user-timers
```

Apply a Noctalia color scheme once so `~/.cache/noctalia/nvim-glass/current/`
exists; until then nvim and kitty use the committed tokyonight-moon fallbacks.

Enable the host-specific units only after their referenced projects and tools
exist:

```sh
systemctl --user enable --now familiar-reap.timer
```

The Familiar timer expects `%h/d/familiar`. Mindful v6 units are linked without
activation; follow [the runtime runbook](mindful-runtime.md) at the separately
approved cutover. The old Docker unit is retained only for deliberate rollback.

## Kernel parameters

In `/etc/default/grub`, `GRUB_CMDLINE_LINUX_DEFAULT`:

```
pcie_aspm=off nvme_core.default_ps_max_latency_us=0
```

Then `grub-mkconfig -o /boot/grub/grub.cfg` and **verify the parameter actually
reached the generated file** — regeneration can silently no-op:

```sh
grep -o 'nvme_core[^ ]*' /boot/grub/grub.cfg
```

`nvme_core.default_ps_max_latency_us=0` disables APST (Autonomous Power State
Transition). The kernel's default budget is 100 ms, which permits some drives to
park in their deepest sleep state — from which certain models never wake, taking
the whole PCIe link down with them. Cost of disabling is a couple hundred
milliwatts at idle. Symptom it prevents:

```
nvme nvmeN: controller is down; will reset: CSTS=0xffffffff
nvme nvmeN: Disabling device after reset failure: -19
```

Check which power states a drive can actually reach with
`nvme id-ctrl /dev/nvmeN -H | grep ^ps` and
`nvme get-feature /dev/nvmeN -f 0x0c -H`. A drive whose deepest state has a
round-trip latency under 100 ms is the one at risk.

## fstab

Two conventions:

**Every non-essential mount gets `nofail`.** Without it, one dead drive fails
`local-fs.target` and drops the machine to an emergency shell at boot.

```
UUID=...  /mnt/data  ext4  rw,noatime,nofail,x-systemd.device-timeout=5s  0 2
```

Keep `pass 2`. With `nofail`, systemd skips fsck when the device is absent but
still runs it when present, so periodic checking survives.

Only `/` and `/boot/efi` should be required by `local-fs.target`.

**`noatime` on everything**, including `/` — easy to miss on the root entry.

**Comment with drive models, not `/dev/sdX`.** Kernel names shuffle between
boots; a comment saying `nvme1n1p3` when the device is actually `nvme0n1p3` is
worse than no comment.

## SMART monitoring

Enable `fstrim.timer` (weekly TRIM) and `smartd`:

```sh
systemctl enable --now fstrim.timer smartd
```

`/etc/smartd.conf` conventions — see this machine's copy for the full file:

- **Address devices by `/dev/disk/by-id/`**, not `/dev/sdX`.
- **Do not use `DEVICESCAN`** alongside explicit device lines; it silently
  overrides all of them.
- Per-type directives: NVMe gets `-d nvme -H -l error -W 0,70,80`; SATA SSD gets
  `-a -o on -S on`; spinners add `-n standby,q` so polling never spins up a
  sleeping disk.
- Temperature thresholds by device class — NVMe 70/80 °C, SATA SSD 55/70,
  HDD 45/55. A single global threshold is wrong for at least one class.
- **Stagger long self-tests one drive per weekend.** A long test on an 8 TB
  spinner runs ~15 h; several at once will thrash the machine.
- No MTA on a desktop, so use `-m <nomailer> -M exec <script> -M daily`. The
  literal token `<nomailer>` suppresses mail and runs only the script.

### Alert script

`/usr/local/bin/smartd-notify` writes **three independent sinks** so an alert
cannot be lost because nobody was logged in:

1. `logger -t smartd-notify -p daemon.crit` → journal
2. append to `/var/log/smartd-alerts.log`
3. `notify-send` via `runuser -u <user> -- env DBUS_SESSION_BUS_ADDRESS=...`,
   guarded on `/run/user/<uid>/bus` existing, best-effort

Only the third can fail silently, and it is the only one that is a convenience
rather than a record.

## Verification — two traps

Both of these were hit while setting this up. Both look like the opposite of
what they are.

**`findmnt --verify` reports an error on a correct `nofail` config.** Its output
is byte-identical with and without `nofail`; it only checks whether a device is
reachable right now and models nothing about boot behaviour. Verify boot safety
by checking which units the generator emits instead:

```sh
ls /run/systemd/generator/local-fs.target.requires/   # only / and /boot/efi
ls /run/systemd/generator/local-fs.target.wants/      # everything else
```

**`smartd` reports success on a self-test schedule that never runs.** The `-s`
argument is an extended *regular expression* matched against `T/MM/DD/d/HH`, not
a range syntax. `01-07` matches the literal text `01-07`, which no timestamp
ever equals — so the test silently never fires, with a clean parse, a running
daemon and nothing in the logs. Day ranges need character classes:

```
L/../(0[1-7])/6/03      first Saturday, 03:00      (correct)
L/../01-07/6/03         never runs                 (silent no-op)
```

Day-of-week is `1`=Mon … `7`=Sun. Always confirm with:

```sh
smartd -q showtests -c /etc/smartd.conf | grep "type L"
```

`will do 0 tests of type L` means the expression is broken.

## GPU fan floor (NVIDIA + Wayland)

Symptom: the card's zero-RPM mode stops the fans below a threshold, the desktop
idles at exactly that threshold, and the fans start/stop every ~10 s without
ever moving the temperature. Not a failing fan — a limit cycle.

The executable and unit live in `bin/` and `systemd/system/` respectively:

```sh
install -m 0755 bin/gpu-fan-curve                         /usr/local/bin/gpu-fan-curve
install -m 0644 systemd/system/gpu-fan-curve.service      /etc/systemd/system/
systemctl enable --now gpu-fan-curve
```

Four things that are non-obvious:

**`nvfancontrol` does not work on Wayland.** It drives XNVCtrl, which needs a
real NVIDIA X screen; Xwayland does not provide one. It exits 0 and prints no
coolers rather than erroring. Use `nvidia-settings` instead.

**`nvidia-settings` needs `WAYLAND_DISPLAY` + `XDG_RUNTIME_DIR`, and root.**
`DISPLAY` alone fails. Coolbits is an X concept with no Wayland equivalent; the
driver just requires root instead. Discover the socket rather than hardcoding
`wayland-1` — the name changes between sessions.

**Determine the floor by measurement, not by guessing.** Sweep
`[fan:N]/GPUTargetFanSpeed` and read `[fan:N]/GPUCurrentFanSpeedRPM` — real
tachometer data, unlike `nvidia-smi`, which reports only commanded PWM. On this
card 30% never spins, 40% is at the stall edge, and 50%+ is linear at ~42 RPM
per point, so 45% is the lowest sane floor.

**Manual mode is a fixed speed with no automatic ramp**, so the daemon must own
the whole curve and fail safe: revert to automatic on stop (`ExecStopPost`), on
signal (trap), above a temperature ceiling, and on an unreadable temperature.
If the Wayland session disappears first, `nvidia-settings` can no longer reach
the driver; the card returns to automatic control when the driver resets. Keep
the curve more aggressive than stock above ~60 °C so manual mode never trades
away cooling.

Systemd gotcha met here: **`StartLimitIntervalSec` belongs in `[Unit]`, not
`[Service]`.** In `[Service]` systemd logs `Unknown key ... ignoring` and
silently falls back to the default rate limit. Confirm any such key with
`systemctl show <unit> -p StartLimitIntervalUSec` — read the value back, don't
assume the file was honoured.

## Dual boot: Windows in the GRUB menu

Find the ESP that holds the Windows bootloader. A disk that has hosted both
systems can carry **more than one** ESP, and only one of them is Microsoft's:

```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,UUID
mount -o ro /dev/nvmeXn1pN /mnt/tmp && ls /mnt/tmp/EFI/   # want Microsoft/
```

Add a static entry to `/etc/grub.d/40_custom`. That file ends in
`exec tail -n +3 $0`, so everything after line 3 is copied into `grub.cfg`
**verbatim** — no shell expansion, which is why `$menuentry_id_option` would
land as literal text there. Use `--id` instead:

```
menuentry 'Windows 10' --class windows --class os --id windows {
	insmod part_gpt
	insmod fat
	insmod chain
	search --no-floppy --fs-uuid --set=root <ESP-FS-UUID>
	chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
```

Match the ESP by **filesystem UUID**, never by device node — NVMe enumeration
order changes between boots, and on this machine it already has.

**Prefer this over `os-prober`.** os-prober probes every partition on every disk
each time `grub-mkconfig` runs. With a failing drive in the machine that puts
unreliable I/O directly in the path of an operation which must not fail, and it
also invents entries for any other Linux install it happens to find. A static
entry scans nothing.

Requires **Secure Boot disabled** — GRUB chainloading `bootmgfw.efi` is not a
signed boot path. Check with `bootctl status | grep -i 'secure boot'`. If Secure
Boot is ever enabled, boot Windows from the firmware's own entry instead.

Before trusting the NTFS volume, confirm Windows is not hibernated: a
`hiberfil.sys` in the root of the Windows partition means fast startup left the
filesystem dirty. Boot Windows and shut it down fully first.

Two things Windows does once it has booted:

- **It promotes itself in the UEFI boot order**, silently bypassing GRUB. Check
  `efibootmgr -v` and restore with `efibootmgr -o <grub>,<rest>`.
- **It assumes the RTC is local time** while Arch uses UTC, so the clock jumps
  by your offset on every switch. Fix it on the Windows side rather than
  degrading Linux — as Administrator:
  `reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`

### Regenerating grub.cfg — three traps

**Never run `grub-mkconfig` during a pacman transaction.** mkinitcpio's
`60-mkinitcpio-remove.hook` deletes `/boot/vmlinuz-linux`,
`/boot/initramfs-linux.img` and `/etc/mkinitcpio.d/*.preset` at
*PreTransaction*; `90-mkinitcpio-install.hook` restores them at
*PostTransaction*, which on a machine with several DKMS modules can be an hour
later. Regenerate inside that window and `10_linux` finds no kernel, exits 0,
and writes a perfectly valid `grub.cfg` **with no Linux entry in it**. Check
first:

```sh
test -e /var/lib/pacman/db.lck && echo "transaction in flight -- wait"
```

**`grub-mkconfig` executes every executable file in `/etc/grub.d/`.** A backup
copy such as `40_custom.bak` is therefore also a generator, and its output lands
in `grub.cfg`. Keep backups outside that directory.

**Generate to a temp file and validate before installing**, so a bad run cannot
leave an unbootable menu behind:

```sh
grub-mkconfig -o /tmp/grub.cfg.new
grub-script-check /tmp/grub.cfg.new
grep -c "menuentry 'Arch Linux" /tmp/grub.cfg.new     # must be >= 1
```

Also check that every `linux` and `initrd` path the menu references exists — a
config can pass a syntax check and still point at a kernel that is not there.

## Fallback initramfs (recovery boot entry)

A fresh install builds only `initramfs-linux.img`, using the `autodetect` hook —
so it contains drivers for the hardware present *at build time* only. That image
stops booting if the disk moves to another controller, a driver regresses, or the
root device changes. The fallback image skips `autodetect` and carries every
module instead.

In `/etc/mkinitcpio.d/linux.preset`, three lines must be uncommented, not one:

```sh
PRESETS=('default' 'fallback')
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
```

Adding `'fallback'` to `PRESETS` alone builds **nothing**: with neither
`fallback_image` nor `ALL_image` defined, mkinitcpio has no output target for
that preset. Then `mkinitcpio -P`.

GRUB needs no configuration for this — `10_linux` adds the entry purely on
`/boot/initramfs-linux-fallback.img` existing (line 307). It is *independent* of
`GRUB_DISABLE_RECOVERY`, which gates only the separate single-user "recovery
mode" entry (line 329). Setting that to `true` does not cost you the fallback.

**Verify the fallback is larger than the default.** If `-S autodetect` fails to
apply, the build still succeeds and the two images come out the same size — the
only cheap external signal that the recovery image is not actually a recovery
image. On this machine: 220 MB default, 293 MB fallback. Both are inflated by
`MODULES=(nvidia …)` in `mkinitcpio.conf`, which is also why the gap is
proportionally small — the NVIDIA modules dominate both images.

The `Possibly missing firmware for module: qla2xxx / aic94xx / bfa / wd719x`
warnings during a fallback build are expected and harmless: it includes drivers
for hardware you do not have, whose firmware blobs are in packages you have not
installed.

Durability, which is not obvious: the preset is owned by **no** package.
`/usr/share/libalpm/scripts/mkinitcpio` compares it against
`/usr/share/mkinitcpio/hook.preset` on every kernel upgrade. Identical → deleted
and regenerated from the template; **different → moved to `.pacsave` and
restored afterwards.** So customisations survive, but an untouched preset is
silently reset, which is why a machine that never edited it stays at
`('default')` forever.

## Kernel module trees and DKMS rebuild time

`kernel-modules-hook` preserves the **running** kernel's module tree across an
upgrade. Without it, pacman removes `/usr/lib/modules/$(uname -r)` as ordinary
file replacement, and `modprobe` then fails for anything not already loaded
until you reboot — no newly attached USB storage, no unusual filesystems.

The cost is that the rescued tree is **no longer owned by any package**, so
pacman will never remove it. Deletion is delegated to a unit the package ships
but does **not** enable:

```sh
pacman -S kernel-modules-hook
systemctl enable --now linux-modules-cleanup.service   # easy to miss
```

Skip that second line and module trees accumulate permanently, one per kernel
upgrade. This costs more than disk space: `70-dkms-install.hook` builds every
DKMS module against every tree that has a `build/` directory, so five stale
trees means five NVIDIA builds at ~13 minutes each, turning a routine upgrade
into an hour.

Note that installing the hook is what *stops* the pruning people remember as
automatic. Before it, nothing needed enabling — pacman removed the old tree
because it owned the files.

What the unit does at each boot: any `/usr/lib/modules/[0-9]*` that is neither
the running kernel (`%v`) nor pacman-owned is moved to `/usr/lib/modules/.old/`,
and the tmpfiles rule `R! /usr/lib/modules/.old/* - - - 4w` purges that four
weeks later. So enabling it does **not** reclaim space immediately — but the
DKMS saving is immediate, because the hook globs `*/` and skips the dotted
directory. The two stages exist so a bad boot is recoverable.

Audit at any time:

```sh
for d in /usr/lib/modules/[0-9]*/; do
    pacman -Qo "$d" >/dev/null 2>&1 || echo "unowned: $d"
done
```

Anything listed that is not the running kernel is dead weight.

## Gating kernel updates

The section above cuts what a kernel upgrade *costs*. This one cuts how often
one happens.

`atoms` certifies a filesystem durability tuple against an exact `uname -r`, so
any change to the running kernel — including a pkgrel-only rebuild such as
`7.1.8-arch1-2` to `7.1.8-arch1-3` — leaves the tuple uncertified until a full
nine-scenario QEMU sweep re-establishes it. Arch shipped fifteen `linux` bumps
in the ten weeks to 2026-09-01. Certification was effectively continuous.

So the kernel does not move on its own. `linux` and `linux-headers` are pinned,
and released deliberately:

```sh
install -m 0755 bin/kernel-gate                          /usr/local/bin/kernel-gate
install -m 0644 pacman/hooks/65-kernel-headers-sync.hook /etc/pacman.d/hooks/
install -m 0644 pacman/kernel-gate.conf                  /etc/kernel-gate.conf
```

Then add both packages to `IgnorePkg` in `/etc/pacman.conf`, keeping whatever
is already there:

```
IgnorePkg = linux linux-headers
```

After that, `pacman -Syu` upgrades everything else and leaves the kernel alone;
`kernel-gate unlock` takes it when you are ready; `kernel-gate status` reports
what is held and whether the running kernel is still certified.

Five things that are non-obvious:

**The pair is the unit, never one of them.** DKMS builds against the headers,
so a kernel and headers at different versions break every module build on the
machine — here `nvidia-open-dkms` and `virtualbox-host-dkms`. Worse, the
breakage does not surface at the transaction that caused it; it surfaces at the
next boot, as modules that will not load. `IgnorePkg` covers both, `unlock`
takes both in one transaction, and the hook refuses to let them diverge.

**The hook is numbered 65 on purpose.** `70-dkms-install.hook` runs the builds
that a mismatch breaks. A diagnostic numbered above it prints *after* a wall of
build failures, explaining something the reader has already been buried in.

**`IgnorePkg` is not a lock, and does not need to be.** An explicit
`pacman -S linux` still installs, after asking. That is the release path, not a
hole in the gate: `-Syu` is what runs unattended and by habit, and that is what
the pin stops.

**Release with a full `-Syu` first, then take the kernel.** Never `pacman -Sy
linux` — that syncs the databases and installs one package against them, which
is the definition of a partial upgrade. `kernel-gate unlock` does the two steps
in that order for exactly this reason.

**Root runs its own copy, not the `~/bin` symlink.** `bin/` is symlinked into
`$HOME`, and a pacman hook executing a user-writable script would hand root to
anything that can write there. The `install` above makes a root-owned copy;
re-run it whenever `bin/kernel-gate` changes.

Verify by asking pacman what it will actually do, not by reading the config
back:

```sh
pacman -Qu linux linux-headers   # both must say [ignored]
```

A parsed config proves nothing here — `pacman-conf IgnorePkg` will happily echo
a package name that a typo elsewhere has left unenforced.

One deliberate gap: the unattended sweep that follows a release
(`~/.local/bin/atoms-recertify` and its user units) is not tracked here. It
hardcodes an atoms checkout and a repo-specific review workflow, so it is not
general host configuration. A fresh machine gets the gate and reports
`Certified: unknown` until that checkout exists.

## Auditing systemd changes

No single command shows every difference from a fresh Arch install.
`systemd-delta` finds overrides of package units, but not entirely new local
units such as `gpu-fan-curve.service`. Use all four views:

```sh
systemd-delta --no-pager
find /etc/systemd/system -xdev \( -type f -o -type l \) -printf '%p -> %l\n' | sort
systemctl list-unit-files --state=enabled,masked,linked --no-pager
systemctl list-timers --all --no-pager

find ~/.config/systemd/user -xdev \( -type f -o -type l \) -printf '%p -> %l\n' | sort
systemctl --user list-unit-files --state=enabled,masked,linked --no-pager
systemctl --user list-timers --all --no-pager
```

In `list-unit-files`, compare `STATE` with `PRESET`: an enabled unit whose
preset is disabled is a local choice. Use `pacman -Qo <unit-file>` before
capturing anything under `/usr/lib`; package-owned unit contents and generated
`.wants/` symlinks should be recreated by package installation and
`systemctl enable`, not copied into dotfiles.

## General principle

Every trap in this document shares a shape: the command exited zero and the
daemon came up, but the system would not have *done* the thing. `findmnt
--verify` reported an error on a correct config; smartd reported success on a
schedule that never fires; systemd accepted a unit and discarded a key;
`nvfancontrol` exited 0 having found nothing; `grub-mkconfig` exited 0 and wrote
a syntactically valid boot menu that could not boot Linux. Check what the system
will actually do — read the value back, list the generated units, ask the daemon
what it has scheduled, measure the RPM, count the menu entries.
