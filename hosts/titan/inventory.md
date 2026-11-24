# Inventory — titan

Current persistent settings and their restoration procedures, using
`hosts/inventory-entry.md`. `tests/test_host_inventory.py` requires each setting
to have every template field and two-way coverage through the Source index below.
See [host configuration](../../docs/host-configuration.md) for inspection,
installation and experiments. Historical sweep/results and trials are privately
preserved in ops’s private records, where this inventory was kept before it moved here.

## Coverage and limits

Values and provenance retain each entry’s Observed date; they are observations,
not fresh live verification. Kernel source citations use tag v7.2, the basis of the
observed kernel. Unknown previous values remain unknown. Before any experiment,
capture effective and persistent inputs through
[Running an experiment](../../docs/host-configuration.md#running-an-experiment).
Each entry states its own restoration validation; a service-class trial does not
validate kernel, boot, device or other classes.

## Source index

| Source | Settings |
| --- | --- |
| /etc/default/grub | Kernel command line additions |
| /etc/docker/daemon.json | Docker data root and runtime |
| /etc/environment | BLAS thread limits |
| /etc/fstab | Mount options |
| /etc/kernel-gate.conf | kernel-gate hook and configuration |
| /etc/mkinitcpio.conf | Initramfs modules and hooks |
| /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json | NVIDIA application profile |
| /etc/pacman.d/hooks/65-kernel-headers-sync.hook | kernel-gate hook and configuration |
| /etc/sysctl.d/90-generic-tuning.conf | Swappiness → NMI watchdog → Kernel pointer restriction |
| /etc/sysctl.d/95-titan-tuning.conf | Dirty writeback thresholds |
| /etc/systemd/system/gpu-fan-curve.service | GPU fan curve service |
| /etc/systemd/system/multi-user.target.wants/docker.service | Docker data root and runtime |
| /etc/systemd/system/multi-user.target.wants/gpu-fan-curve.service | GPU fan curve service |
| /etc/systemd/system/timers.target.wants/fstrim.timer | Periodic TRIM |
| /etc/systemd/system/timers.target.wants/paccache.timer | Package cache cleanup timer |
| /etc/systemd/zram-generator.conf | Compressed swap (zram0) |
| /etc/udev/rules.d/90-audio-usb-nosuspend.rules | USB audio autosuspend (PreSonus 194f:0109) |
| /usr/local/bin/gpu-fan-curve | GPU fan curve service |
| /usr/local/bin/kernel-gate | kernel-gate hook and configuration |
| ~/.config/systemd/user/atoms-recertify.service | atoms-recertify timer |
| ~/.config/systemd/user/atoms-recertify.timer | atoms-recertify timer |
| ~/.config/systemd/user/dropbox.service.d/override.conf | Dropbox user service environment |
| ~/.config/systemd/user/niri.service.d/stop-timeout.conf | niri stop timeout |
| ~/.config/systemd/user/timers.target.wants/atoms-recertify.timer | atoms-recertify timer |
| ~/.local/bin/atoms-recertify | atoms-recertify timer |
| /proc/sys/kernel/sched_rt_runtime_us | Realtime scheduling budget |
| /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor | CPU frequency governor |
| /sys/kernel/mm/transparent_hugepage/enabled | Transparent hugepages |
| /etc/security/limits.d/99-realtime-privileges.conf | Realtime privileges |
| /usr/lib/sysctl.d/10-arch.conf | Virtual memory map count |

## Settings

### Dirty writeback thresholds

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/sysctl.d/95-titan-tuning.conf`
- **Effective value:** `vm.dirty_bytes = 2147483648`, `vm.dirty_background_bytes = 1073741824`; the ratio forms `vm.dirty_ratio` and `vm.dirty_background_ratio` both read `0`
- **Inspect:** `sysctl -n vm.dirty_bytes vm.dirty_background_bytes vm.dirty_ratio vm.dirty_background_ratio`
- **Mechanism:** `systemd-sysctl.service` applies `/etc/sysctl.d/*.conf` at boot (`ExecStart=/usr/lib/systemd/systemd-sysctl`, no drop-ins)
- **Winning source:** `/etc/sysctl.d/95-titan-tuning.conf` is the only source of either key (`/usr/lib/systemd/systemd-sysctl --cat-config`, lines 139–144); nothing lower in precedence sets them
- **Purpose:** bound HDD-flush stalls on a 125 GiB machine, where the 20 % default would allow ~25 GiB of dirty pages (comment in the file; standalone README §B1)
- **Confidence:** traced — the two forms are coupled: setting a byte value makes its ratio read 0 and vice versa (`mm/page-writeback.c` lines 486–516), so this entry is the pair
- **Package owner:** none
- **Tracked source:** `hosts/titan/etc/sysctl.d/95-titan-tuning.conf`
- **Installed matches source:** yes — `just drift` 2026-09-12
- **Persistence:** service-managed — the file is the persistent input, re-applied at every boot by `systemd-sysctl.service`; a runtime `sysctl -w` lasts until the next boot only
- **Previous value:** unknown — nothing captured the live values before the standalone script first ran; the kernel default (below) is the only candidate
- **Vendor default:** `dirty_ratio = 20`, `dirty_background_ratio = 10`, `dirty_bytes = 0`, `dirty_background_bytes = 0` — `mm/page-writeback.c` v7.2 lines 75, 92, 81, 98 (the byte forms start at 0, meaning disabled)
- **Restore:** (1) `sudo rm /etc/sysctl.d/95-titan-tuning.conf` (or edit out the two lines) removes the persistent input; (2) that alone leaves the live pair unchanged — restore the ratio representation, which is the default's active form: `sudo sysctl -w vm.dirty_background_ratio=10 vm.dirty_ratio=20`, in that order; (3) readback: `sysctl -n vm.dirty_bytes vm.dirty_background_bytes` both `0`, `vm.dirty_ratio` `20`, `vm.dirty_background_ratio` `10`; no reboot needed. Prerequisite for any future experiment: capture all four values first, since restoring one form zeroes the other
- **Validation:** not validated — procedure written, not run

### Swappiness

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/sysctl.d/90-generic-tuning.conf`
- **Effective value:** `vm.swappiness = 100`
- **Inspect:** `sysctl -n vm.swappiness`
- **Mechanism:** `systemd-sysctl.service` applies `/etc/sysctl.d/*.conf` at boot
- **Winning source:** `/etc/sysctl.d/90-generic-tuning.conf` line 3 (`--cat-config` line 133); no other source sets the key
- **Purpose:** pair with the zram swap device, where swapping is cheap (standalone README §A4/§A5 rationale); no comment in the file itself
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `hosts/titan/etc/sysctl.d/90-generic-tuning.conf`
- **Installed matches source:** yes — `just drift` 2026-09-12
- **Persistence:** service-managed — re-applied at every boot; `sysctl -w` is runtime-only
- **Previous value:** unknown — not captured before the script ran
- **Vendor default:** `60` — `mm/vmscan.c` v7.2 line 199 (`int vm_swappiness = 60;`)
- **Restore:** (1) remove the line from the file (the file also carries two other settings; remove only this line); (2) `sudo sysctl -w vm.swappiness=60`; (3) readback `sysctl -n vm.swappiness` → `60`; no reboot needed
- **Validation:** not validated — procedure written, not run

### NMI watchdog

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/sysctl.d/90-generic-tuning.conf`
- **Effective value:** `kernel.nmi_watchdog = 0`
- **Inspect:** `sysctl -n kernel.nmi_watchdog`
- **Mechanism:** `systemd-sysctl.service` applies `/etc/sysctl.d/*.conf` at boot
- **Winning source:** `/etc/sysctl.d/90-generic-tuning.conf` line 2 (`--cat-config` line 132); no other source sets the key
- **Purpose:** free the hardlockup detector's reserved performance counter and its periodic interrupt (standalone README §A3); no comment in the file
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `hosts/titan/etc/sysctl.d/90-generic-tuning.conf`
- **Installed matches source:** yes — `just drift` 2026-09-12
- **Persistence:** service-managed — re-applied at every boot; `sysctl -w` is runtime-only
- **Previous value:** unknown — not captured before the script ran
- **Vendor default:** `1` — `kernel/watchdog.c` v7.2 lines 38–48: `WATCHDOG_HARDLOCKUP_DEFAULT` is 1 when `CONFIG_HARDLOCKUP_DETECTOR` is set, and this kernel sets it (`zcat /proc/config.gz`: `CONFIG_HARDLOCKUP_DETECTOR=y`, `CONFIG_HARDLOCKUP_DETECTOR_PERF=y`)
- **Restore:** (1) remove the line from the file; (2) `sudo sysctl -w kernel.nmi_watchdog=1`; (3) readback `sysctl -n kernel.nmi_watchdog` → `1`; no reboot needed
- **Validation:** not validated — procedure written, not run

### Kernel pointer restriction

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/sysctl.d/90-generic-tuning.conf`
- **Effective value:** `kernel.kptr_restrict = 2`
- **Inspect:** `sysctl -n kernel.kptr_restrict`
- **Mechanism:** `systemd-sysctl.service` applies `/etc/sysctl.d/*.conf` at boot
- **Winning source:** `/etc/sysctl.d/90-generic-tuning.conf` line 7 (`--cat-config` line 137); checked 2026-09-12: no file under `/usr/lib/sysctl.d/` sets the key, so there is no lower-precedence value to fall back to
- **Purpose:** hide kernel addresses from every reader, root included; the file's own comment records the trade-off (drop to 1 if a kernel profiler is installed and its symbols come back as bare hex)
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `hosts/titan/etc/sysctl.d/90-generic-tuning.conf`
- **Installed matches source:** yes — `just drift` 2026-09-12
- **Persistence:** service-managed — re-applied at every boot; `sysctl -w` is runtime-only
- **Previous value:** unknown — not captured before the script ran, and no overridden source records one
- **Vendor default:** `0` — `lib/vsprintf.c` v7.2 line 852 (`int kptr_restrict __read_mostly;`, zero-initialised); no Arch config option or `/usr/lib/sysctl.d` file changes it
- **Restore:** (1) remove the line and its comment from the file; (2) `sudo sysctl -w kernel.kptr_restrict=0`; (3) readback `sysctl -n kernel.kptr_restrict` → `0`; no reboot needed. This restores the distribution baseline, not a known previous state
- **Validation:** not validated — procedure written, not run

### Compressed swap (zram0)

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/systemd/zram-generator.conf`
- **Effective value:** `/dev/zram0`, zstd, 16 GiB, active as swap at priority 100 with 0 B used
- **Inspect:** `zramctl --output NAME,ALGORITHM,DISKSIZE,MOUNTPOINT`; `swapon --show`; `systemctl is-active systemd-zram-setup@zram0.service`
- **Mechanism:** `zram-generator` (a systemd generator, `/usr/lib/systemd/system-generators/zram-generator`) reads the file at boot and instantiates `systemd-zram-setup@zram0.service`, whose `ExecStart` creates and enables the device
- **Winning source:** `/etc/systemd/zram-generator.conf` (`[zram0]`, `zram-size = 16384`, `compression-algorithm = zstd`); the generator also reads `/usr/lib/systemd/zram-generator.conf`, `/run/systemd/zram-generator.conf`, and `*.conf.d/` under each, none of which exist here (checked 2026-09-12), and the kernel command line carries no `systemd.zram` option
- **Purpose:** compressed swap that makes `vm.swappiness = 100` cheap (standalone README §A4; dotfiles `docs/fresh-install-hardening.md` §zram)
- **Confidence:** traced
- **Package owner:** none (the generator is `zram-generator 1.2.1-1`)
- **Tracked source:** `systemd/zram-generator.conf`, installed by its hardening doc; not listed in `adopted.toml`
- **Installed matches source:** yes — `cmp` 2026-09-12 against the dotfiles copy
- **Persistence:** boot-generated — the unit exists only because the generator ran at boot; removing the file changes nothing until the next boot or an explicit stop
- **Previous value:** no zram device — the generator creates none without a config file; evidence is the generator's documented behaviour, not a capture
- **Vendor default:** no device — zram-generator 1.2.1-1 ships no configuration file and its manual states "the default configuration doesn't specify any devices" (`zram-generator.conf(5)`, Configuration Directories and Precedence)
- **Restore:** (1) `sudo rm /etc/systemd/zram-generator.conf` (in dotfiles terms: stop installing it); (2) the live device stays until `sudo systemctl stop systemd-zram-setup@zram0.service`, which swaps off and destroys it — only with enough free RAM to absorb whatever is swapped (`swapon --show` USED); (3) readback `swapon --show` without `/dev/zram0`, `zramctl` empty; the next boot regenerates nothing from the absent file
- **Validation:** not validated — procedure written, not run

### USB audio autosuspend (PreSonus 194f:0109)

- **Scope:** device
- **Observed:** 2026-09-12
- **Installed path:** `/etc/udev/rules.d/90-audio-usb-nosuspend.rules`
- **Effective value:** `/sys/bus/usb/devices/1-2/power/control = on` for the Studio 24c (idVendor 194f, idProduct 0109)
- **Inspect:** `for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && [ "$(cat $d/idVendor)" = 194f ] && cat $d/power/control; done`
- **Mechanism:** udev rule on `ACTION=="add"` for the matching USB device writes `power/control=on`; applied at coldplug during boot and again whenever the device is (re)plugged
- **Winning source:** `/etc/udev/rules.d/90-audio-usb-nosuspend.rules`; the packaged `/usr/lib/udev/rules.d/60-autosuspend.rules` only sets `auto` when hwdb marks a device `ID_AUTOSUSPEND=1`, and hwdb has no entry for this device (`udevadm info -q property` shows none)
- **Purpose:** keep the audio interface from USB-autosuspending (comment in the rule; standalone README §B6)
- **Confidence:** traced — with the qualification that the kernel's own default for this device is already `on` (below), so the rule pins a value rather than changing one; whether anything else would flip it to `auto` without the rule is unverified
- **Package owner:** none
- **Tracked source:** `hosts/titan/etc/udev/rules.d/90-audio-usb-nosuspend.rules`
- **Installed matches source:** yes — `just drift` 2026-09-12
- **Persistence:** service-managed — udev re-applies the rule at every boot coldplug and device add; a runtime write to `power/control` lasts until the next add event
- **Previous value:** unknown — not captured before the rule was installed
- **Vendor default:** `on` — the USB core forbids autosuspend for every new non-hub device (`drivers/usb/core/hub.c` v7.2 lines 2668–2671, `usb_disable_autosuspend(udev)`), and `snd-usb-audio` never enables it (`sound/usb/card.c` v7.2 line 1139 enables it only when undoing a quirk); the other non-hub USB devices on this host read `on` too, except the webcam that hwdb marks
- **Restore:** (1) `sudo rm /etc/udev/rules.d/90-audio-usb-nosuspend.rules`; (2) `sudo udevadm control --reload`; (3) the live value persists until the device is re-added — `sudo udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor=194f` re-runs the add rules, or replug; (4) readback via Inspect, expected `on` (the kernel default); no reboot needed
- **Validation:** not validated — procedure written, not run

### BLAS thread limits

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `/etc/environment`, the block between `# >>> system-tuning:blas-threads >>>` and `# <<< system-tuning:blas-threads <<<`
- **Effective value:** `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1`, `NUMEXPR_NUM_THREADS=1` in this login session
- **Inspect:** `printenv OMP_NUM_THREADS OPENBLAS_NUM_THREADS MKL_NUM_THREADS NUMEXPR_NUM_THREADS` in a fresh login shell
- **Mechanism:** `pam_env` reads `/etc/environment` at session open, so every PAM session (login, greetd, ssh, sudo -i) starts with the four variables set. `/etc/environment.d/` is a different mechanism with narrower scope — the systemd user manager only, not PAM sessions — and is not a tidier home for this block
- **Winning source:** the block in `/etc/environment`; dotfiles `shell/local/titan.zsh` once exported `OPENBLAS_NUM_THREADS=16` over it and now carries that line commented out, so nothing overrides the block at shell level
- **Purpose:** default every process to single-threaded BLAS so parallel Python jobs do not each spawn 32 threads; explicit parallelism owns the cores (standalone README §A2). GNU `nproc` honours `OMP_NUM_THREADS`, so it prints 1 in these sessions; `nproc --all` or `host-budget show` give the CPU count. Inside `host-budget run` a job's own values replace these (docs/host-configuration.md)
- **Confidence:** traced for this session; other session types were not sampled
- **Package owner:** `pam 1.7.2-2` owns the file (reported `[modified]`); the block is unowned
- **Tracked source:** `hosts/titan/blocks/environment-blas-threads.conf` (the block only; the rest of the file is not tracked)
- **Installed matches source:** yes — `just drift` 2026-09-12 (block comparison)
- **Persistence:** login-scoped — takes effect at the next PAM session; existing sessions keep whatever they started with
- **Previous value:** variables unset — the installed file outside the block is pam's comment header only, so nothing set them before; evidence is the file, not a capture
- **Vendor default:** variables unset — pam ships `/etc/environment` as the comment header the installed copy still carries; the `pam 1.7.2-2` archive is not in the package cache, so this is read from the installed header rather than compared byte-for-byte (`pacman -Sw pam` would fetch it)
- **Restore:** (1) delete the block, markers included, from `/etc/environment` with an editor (`sudoedit /etc/environment`), leaving the header; (2) log out and in; (3) readback via Inspect: all four unset; no reboot needed
- **Validation:** not validated — procedure written, not run

### Kernel command line additions

- **Scope:** boot
- **Observed:** 2026-09-12
- **Installed path:** `/etc/default/grub`, `GRUB_CMDLINE_LINUX_DEFAULT`
- **Effective value:** `/proc/cmdline` carries `ipv6.disable=1 btusb.enable_autosuspend=0 pcie_aspm=off nvme_core.default_ps_max_latency_us=0` after `quiet`; runtime readbacks: `/sys/module/nvme_core/parameters/default_ps_max_latency_us` = `0`, `/sys/module/btusb/parameters/enable_autosuspend` = `N`, `/proc/sys/net/ipv6` absent (IPv6 never initialised)
- **Inspect:** `cat /proc/cmdline`; `cat /sys/module/nvme_core/parameters/default_ps_max_latency_us /sys/module/btusb/parameters/enable_autosuspend`; `ls /proc/sys/net/ipv6`
- **Mechanism:** boot-generated — `grub-mkconfig -o /boot/grub/grub.cfg` reads `/etc/default/grub` into the menu entries; GRUB 2.14 is the boot loader in use (`bootctl status`: no systemd-boot, no loader entries, EFI variable `GRUB-NEW` first in boot order)
- **Winning source:** `/etc/default/grub` line 6; `GRUB_CMDLINE_LINUX` is empty and `/etc/grub.d/40_custom` adds only a Windows chainload entry
- **Purpose:** the standalone README's "already configured correctly" list: `pcie_aspm=off` and `btusb.enable_autosuspend=0` as audio-dropout fixes, `nvme_core.default_ps_max_latency_us=0` to keep the DRAM-less NVMe out of deep power states, `ipv6.disable=1` undocumented there
- **Confidence:** partial — three of the four parameters have a runtime readback that confirms them; `pcie_aspm=off` has none reachable unprivileged (`/sys/module/pcie_aspm/parameters/policy` still reads `[default]` when ASPM is globally off, and `lspci -vv`'s `LnkCtl: ASPM Disabled` lines need root); the purpose of `ipv6.disable=1` is unrecorded
- **Package owner:** `grub 2:2.14-1` (reported `[modified]`)
- **Tracked source:** none — the boot file is not adopted; this entry records the delta
- **Installed matches source:** n/a
- **Persistence:** boot-generated — changes to `/etc/default/grub` take effect only after regeneration and a reboot; the running command line is fixed for the boot
- **Previous value:** `GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"` — the edited file keeps that line commented out directly beneath the live one, which is how the Arch package ships it; not a capture
- **Vendor default:** `"loglevel=3 quiet"` — read from the commented line in the installed file; the `grub 2:2.14-1` archive is not in the package cache, so not confirmed byte-for-byte (`pacman -Sw grub` would fetch it; then `tar -xOf … etc/default/grub | diff - /etc/default/grub`)
- **Restore:** (1) `sudoedit /etc/default/grub`, set `GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"`; (2) `sudo grub-mkconfig -o /boot/grub/grub.cfg` (the host's own generator; `grep -c 'ipv6.disable' /boot/grub/grub.cfg` → `0` confirms the file); (3) reboot, explicitly arranged; (4) readback `cat /proc/cmdline` without the four parameters, `ls /proc/sys/net/ipv6` present. Per parameter: any one can be removed alone in step 1
- **Validation:** not validated — procedure written, not run

### Initramfs modules and hooks

- **Scope:** boot
- **Observed:** 2026-09-12
- **Installed path:** `/etc/mkinitcpio.conf`
- **Effective value:** `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`; `HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)`
- **Inspect:** `grep -E '^(MODULES|HOOKS)=' /etc/mkinitcpio.conf`; `lsinitcpio -a /boot/initramfs-linux.img | grep -A6 '^Modules'` shows what the built image carries
- **Mechanism:** boot-generated — `mkinitcpio -P` (run by the `mkinitcpio` pacman hooks on every kernel or driver install) builds `/boot/initramfs-linux.img` from the file and `/etc/mkinitcpio.d/linux.preset`
- **Winning source:** `/etc/mkinitcpio.conf`; the preset is the stock one written by the package's install script
- **Purpose:** early KMS for the NVIDIA open driver (the four modules loaded from the initramfs before the display manager); the `keymap` hook is a leftover from before `sd-vconsole` covered it
- **Confidence:** traced for the delta; the purpose of `keymap` alongside `sd-vconsole` is inferred, not recorded anywhere
- **Package owner:** `mkinitcpio 42-1` (reported `[modified]`)
- **Tracked source:** none — not adopted; this entry records the delta
- **Installed matches source:** n/a
- **Persistence:** boot-generated — a change takes effect at the next image build and reboot
- **Previous value:** `MODULES=()` and `HOOKS=(… keyboard sd-vconsole block …)` without `keymap` — `diff /etc/mkinitcpio.conf /etc/mkinitcpio.conf.pacnew` 2026-09-12; the `.pacnew` is the current package version, so this is the vendor value, not a capture of the historical one
- **Vendor default:** `MODULES=()`; `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` — `/etc/mkinitcpio.conf.pacnew` from `mkinitcpio 42-1`, whose archive is also in the package cache
- **Restore:** (1) `sudoedit /etc/mkinitcpio.conf`, set `MODULES=()` and drop `keymap`; (2) `sudo mkinitcpio -P`; (3) reboot, explicitly arranged; (4) readback `lsinitcpio -a /boot/initramfs-linux.img` without the nvidia modules. Removing early KMS changes when the display driver binds; do it only with a fallback image at hand (`initramfs-linux-fallback.img` is rebuilt by the same command)
- **Validation:** not validated — procedure written, not run

### Mount options

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/fstab`
- **Effective value:** `/` `rw,noatime`; `/mnt/ssd`, `/mnt/ssd2`, `/mnt/ssd3`, `/data`, `/mnt/hmcl`, `/mnt/backup`, `/mnt/storage` all `rw,noatime,data=ordered` with `nofail,x-systemd.device-timeout=5s` in the file; `/mnt/arch-old` `rw,relatime,nofail,x-systemd.device-timeout=5s` with `pass=0` (dead drive, deliberate per the file's comment); `/boot/efi` stock vfat options
- **Inspect:** `findmnt -rn -o OPTIONS TARGET` per mount; `grep -v '^#' /etc/fstab | grep .`
- **Mechanism:** boot-generated — `systemd-fstab-generator` turns each line into a `.mount` unit at boot and on `daemon-reload`
- **Winning source:** `/etc/fstab`; no `.mount` units exist under `/etc/systemd/system`
- **Purpose:** `noatime` to avoid access-time writes (standalone README's storage notes); `data=ordered` is ext4's default written out explicitly; `nofail` with a 5 s device timeout so a missing data drive does not block boot
- **Confidence:** traced
- **Package owner:** `filesystem 2025.10.12-1` (reported `[modified]`; the package ships an empty template)
- **Tracked source:** none — not adopted; the file names partitions by UUID, which the publication boundary keeps out of this repository
- **Installed matches source:** n/a
- **Persistence:** boot-generated — the units regenerate at boot and on `systemctl daemon-reload`; a live remount is separate
- **Previous value:** unknown — the file has been hand-maintained since installation (three dated `.bak` copies exist beside it, from 2026-08-06, and are backups of earlier hand edits, not an original)
- **Vendor default:** an empty options column means `defaults` = `rw,suid,dev,exec,auto,nouser,async,relatime` (`mount(8)`); the `filesystem` package ships `/etc/fstab` with no entries
- **Restore:** per mount: (1) `sudoedit /etc/fstab`, replace `noatime` with `relatime` (or drop the option); (2) `sudo systemctl daemon-reload`; (3) `sudo mount -o remount TARGET` — `noatime`/`relatime` accept remount, `data=` does not (needs an unmount or reboot); (4) readback `findmnt -rn -o OPTIONS TARGET`. `nofail` and `x-systemd.device-timeout` only matter at the next boot
- **Validation:** not validated — procedure written, not run

### Docker data root and runtime

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/docker/daemon.json`
- **Effective value:** `data-root` `/var/lib/mindful/data` (a symlink to `/mnt/ssd2/mindful-docker/data`, on the Crucial P2), `storage-driver` `overlay2`, an `nvidia` runtime pointing at `nvidia-container-runtime`; `docker info` reports `DockerRootDir=/mnt/ssd2/mindful-docker/data`, driver `overlay2`
- **Inspect:** `docker info --format '{{.DockerRootDir}} {{.Driver}}'`; `readlink -f /var/lib/mindful/data`
- **Mechanism:** `dockerd` reads the file at start; `docker.service` is enabled (`/etc/systemd/system/multi-user.target.wants/docker.service`) with no drop-ins
- **Winning source:** `/etc/docker/daemon.json`; `docker.service` passes no conflicting flags (`FragmentPath=/usr/lib/systemd/system/docker.service`, `DropInPaths=` empty)
- **Purpose:** keep container storage for the mindful stack off the root filesystem (the path name and dotfiles `systemd/user/mindful-docker.service`); the NVIDIA runtime is for GPU containers
- **Confidence:** traced; the reason the data root sits on the DRAM-less P2 rather than the ADATA the README recommends for scratch is unrecorded
- **Package owner:** none (`docker 1:29.8.0-1` ships no `daemon.json`)
- **Tracked source:** none — a candidate for `hosts/titan/etc/docker/daemon.json` if adopted later; not adopted in this task
- **Installed matches source:** n/a
- **Persistence:** service-managed — read at daemon start; the enablement symlink persists across boots
- **Previous value:** unknown — no earlier copy exists
- **Vendor default:** no file — `dockerd` then uses `/var/lib/docker`, driver auto-selected (`overlay2` on ext4), no extra runtimes (`dockerd` documentation)
- **Restore:** (1) `sudo rm /etc/docker/daemon.json`; (2) `sudo systemctl restart docker.service` — every container and image under the custom root becomes invisible to the daemon until the root is set back, so stop the mindful stack first; (3) readback `docker info --format '{{.DockerRootDir}}'` → `/var/lib/docker`. To disable the service instead: `sudo systemctl disable --now docker.service`, readback `systemctl is-enabled docker.service` → `disabled`
- **Validation:** not validated — procedure written, not run

### NVIDIA application profile

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `/etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json`
- **Effective value:** for processes named `niri`, profile "Limit Free Buffer Pool On Wayland Compositors" sets `GLVidHeapReuseRatio = 0`
- **Inspect:** `cat` the file; consumption: `grep -c 'libnvidia-glcore\|libnvidia-eglcore' /proc/$(pgrep -x niri)/maps` → 6 (the libraries that read profiles are mapped into the running compositor)
- **Mechanism:** the NVIDIA GL/EGL libraries read `/etc/nvidia/nvidia-application-profiles-rc.d/*` at process start and apply matching profiles per process
- **Winning source:** this file; the driver's own profile file `/usr/share/nvidia/nvidia-application-profiles-615.71.09-rc` carries no rule for `niri`
- **Purpose:** cap the per-process video-memory reuse pool the driver keeps for a Wayland compositor (driver key documentation: "the maximum percentage of video memory OpenGL will hold in a per-process pool for later reuse"); the recipe is the `material` project's `docs/wiki/Nvidia.md`
- **Confidence:** partial — the file is read by the mapped libraries, but whether the profile matched and applied is not observable from outside the process; the driver offers no readback of an applied profile
- **Package owner:** none (`nvidia-utils 615.71.09-1` ships the directory's sibling under `/usr/share`)
- **Tracked source:** none; adoption filed as `material-87217c` (the wiki documents writing it by hand)
- **Installed matches source:** n/a — the wiki's JSON is the only reference and matches the installed file's content on 2026-09-12
- **Persistence:** login-scoped — applied at each compositor start; the file persists
- **Previous value:** no profile for `niri` — the directory did not exist before the wiki's recipe created it (the wiki says so)
- **Vendor default:** `GLVidHeapReuseRatio` unset for `niri` — the driver's shipped `nvidia-application-profiles-615.71.09-rc` has no rule for that process name
- **Restore:** (1) `sudo rm /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json`; (2) the running compositor keeps its profile — the change takes effect at the next `niri` start, i.e. next login; (3) readback: the file absent, and no direct runtime readback exists
- **Validation:** not validated — procedure written, not run

### kernel-gate hook and configuration

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/pacman.d/hooks/65-kernel-headers-sync.hook`, `/etc/kernel-gate.conf`, `/usr/local/bin/kernel-gate`
- **Effective value:** a PostTransaction hook on `linux` and `linux-headers` runs `/usr/local/bin/kernel-gate check-sync`; `/etc/kernel-gate.conf` sets `ATOMS_REPO` to the atoms checkout under the home directory
- **Inspect:** `cat /etc/pacman.d/hooks/65-kernel-headers-sync.hook /etc/kernel-gate.conf`; `cmp /usr/local/bin/kernel-gate ~/d/dotfiles/bin/kernel-gate`
- **Mechanism:** pacman runs the hook after any transaction touching the two packages; the executable reads the conf
- **Winning source:** the three installed files; `IgnorePkg` in `/etc/pacman.conf` holds the kernel packages (owned local configuration)
- **Purpose:** keep `linux` and `linux-headers` at the same version so DKMS modules build (hook comment); gate kernel upgrades behind the atoms durability certification (dotfiles `docs/fresh-install-hardening.md` §kernel gate)
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `pacman/hooks/65-kernel-headers-sync.hook`, `pacman/kernel-gate.conf`, `bin/kernel-gate`, installed by the hardening doc's `install` lines
- **Installed matches source:** hook yes, executable yes (`cmp` 2026-09-12); conf **no** — the installed `/etc/kernel-gate.conf` has an older comment header and a literal home path where the tracked copy has `"${HOME}/d/atoms"`; drift to resolve (dots-43c742); not listed in `adopted.toml`
- **Persistence:** service-managed — files persist; the hook runs per transaction
- **Previous value:** no hook, no conf, no executable — dotfiles installs all three; evidence is the hardening doc, not a capture
- **Vendor default:** none of the three files exist (`pacman` ships no hooks under `/etc/pacman.d/hooks`)
- **Restore:** (1) `sudo rm /etc/pacman.d/hooks/65-kernel-headers-sync.hook /etc/kernel-gate.conf /usr/local/bin/kernel-gate`; (2) nothing to reload — pacman reads hooks per transaction; (3) readback `ls /etc/pacman.d/hooks/` empty. `IgnorePkg` stays in `/etc/pacman.conf` and is a separate change
- **Validation:** not validated — procedure written, not run

### GPU fan curve service

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/systemd/system/gpu-fan-curve.service`, `/usr/local/bin/gpu-fan-curve`, enabled via `/etc/systemd/system/multi-user.target.wants/gpu-fan-curve.service`
- **Effective value:** `enabled`, `active`
- **Inspect:** `systemctl is-enabled gpu-fan-curve.service; systemctl is-active gpu-fan-curve.service`; `cmp /etc/systemd/system/gpu-fan-curve.service ~/d/dotfiles/systemd/system/gpu-fan-curve.service; cmp /usr/local/bin/gpu-fan-curve ~/d/dotfiles/bin/gpu-fan-curve`
- **Mechanism:** a local system unit started at boot by `multi-user.target`
- **Winning source:** the local unit file; no vendor unit of that name exists, so `systemd-delta` has nothing to compare
- **Purpose:** drive the RTX 3070's fan curve (dotfiles `docs/fresh-install-hardening.md`, the `gpu-fan-curve` section)
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `systemd/system/gpu-fan-curve.service` and `bin/gpu-fan-curve`
- **Installed matches source:** yes — both `cmp` byte-identical 2026-09-12
- **Persistence:** service-managed — enabled at boot; stopping it lasts until the next boot
- **Previous value:** no service — dotfiles installs it; not a capture
- **Vendor default:** no such unit
- **Restore:** (1) `sudo systemctl disable --now gpu-fan-curve.service`; (2) `sudo rm /etc/systemd/system/gpu-fan-curve.service /usr/local/bin/gpu-fan-curve`; (3) `sudo systemctl daemon-reload`; (4) readback `systemctl cat gpu-fan-curve.service` → "No files found". Fan control then falls back to the driver's own curve
- **Validation:** not validated — procedure written, not run

### Periodic TRIM

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/systemd/system/timers.target.wants/fstrim.timer` (symlink to the packaged unit)
- **Effective value:** `fstrim.timer` `enabled`, `active`, `OnCalendar=weekly`
- **Inspect:** `systemctl is-enabled fstrim.timer; systemctl is-active fstrim.timer; systemctl cat fstrim.timer | grep OnCalendar`
- **Mechanism:** enablement — the `.wants` symlink pulls the packaged timer into `timers.target` at boot
- **Winning source:** the symlink; the unit itself is `util-linux 2.42.3-1`'s, unmodified
- **Purpose:** weekly discard on the four SSDs (standalone README §A1)
- **Confidence:** traced
- **Package owner:** `util-linux 2.42.3-1` owns the unit; the symlink is unowned
- **Tracked source:** none — an enablement, recorded here only
- **Installed matches source:** n/a
- **Persistence:** service-managed — the symlink persists; the timer re-arms at boot
- **Previous value:** disabled — no preset file under `/usr/lib/systemd/system-preset/` names `fstrim`, so the package leaves it disabled; not a capture
- **Vendor default:** disabled (no preset entry)
- **Restore:** (1) `sudo systemctl disable --now fstrim.timer`; (2) readback `systemctl is-enabled fstrim.timer` → `disabled`; no reboot needed
- **Validation:** not validated — procedure written, not run

### Package cache cleanup timer

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/etc/systemd/system/timers.target.wants/paccache.timer` (symlink to the packaged unit)
- **Effective value:** `paccache.timer` `enabled`, `active`, `OnCalendar=weekly`, running `/usr/bin/paccache -r`
- **Inspect:** `systemctl is-enabled paccache.timer; systemctl is-active paccache.timer; systemctl cat paccache.service | grep ExecStart`
- **Mechanism:** enablement — the `.wants` symlink pulls the packaged timer into `timers.target`
- **Winning source:** the symlink; the unit is `pacman-contrib 1.13.1-1`'s, unmodified
- **Purpose:** keep the package cache to three versions per package (standalone README §B5). Side effect that matters to this inventory: it is why the `grub`, `sudo`, and `pam` archives were not in the cache when their vendor defaults were sought
- **Confidence:** traced
- **Package owner:** `pacman-contrib 1.13.1-1` owns the unit; the symlink is unowned
- **Tracked source:** none — an enablement, recorded here only
- **Installed matches source:** n/a
- **Persistence:** service-managed
- **Previous value:** disabled (no preset entry); not a capture
- **Vendor default:** disabled (no preset entry)
- **Restore:** (1) `sudo systemctl disable --now paccache.timer`; (2) readback `systemctl is-enabled paccache.timer` → `disabled`
- **Validation:** not validated — procedure written, not run

### Dropbox user service environment

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `~/.config/systemd/user/dropbox.service.d/override.conf`
- **Effective value:** `Environment=DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` on `dropbox.service` (`systemctl --user show -p Environment`)
- **Inspect:** `systemctl --user show -p DropInPaths -p Environment dropbox.service`
- **Mechanism:** a user-manager drop-in extending the packaged `/usr/lib/systemd/user/dropbox.service`; applied when the unit is loaded
- **Winning source:** the drop-in (`DropInPaths` lists only it)
- **Purpose:** give the Dropbox client a display and a session bus so its tray and notifications work under the compositor; no comment in the file
- **Confidence:** partial — purpose inferred from the variables
- **Package owner:** none (`dropbox` ships the unit, not the drop-in)
- **Tracked source:** none; adoption filed as `dots-6e8782`
- **Installed matches source:** n/a
- **Persistence:** service-managed — read at unit load; a change needs `systemctl --user daemon-reload` and, because a process's environment is fixed at exec, `systemctl --user restart dropbox.service` to take effect
- **Previous value:** no drop-in; not a capture
- **Vendor default:** no drop-in — the packaged unit sets no environment
- **Restore:** (1) `rm ~/.config/systemd/user/dropbox.service.d/override.conf && rmdir ~/.config/systemd/user/dropbox.service.d`; (2) `systemctl --user daemon-reload`; (3) `systemctl --user restart dropbox.service` — required, the running process keeps its environment otherwise; (4) readback `systemctl --user show -p Environment dropbox.service` → empty
- **Validation:** not validated — procedure written, not run

### atoms-recertify timer

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `~/.config/systemd/user/atoms-recertify.timer`, `~/.config/systemd/user/atoms-recertify.service`, enabled via `~/.config/systemd/user/timers.target.wants/atoms-recertify.timer`; the script `~/.local/bin/atoms-recertify`
- **Effective value:** timer `enabled`, `active`, `OnActiveSec=5min`, `OnUnitInactiveSec=6h`; the service runs the script as a oneshot at `Nice=10`, `IOSchedulingClass=idle`, no timeout
- **Inspect:** `systemctl --user cat atoms-recertify.timer atoms-recertify.service`; `systemctl --user is-active atoms-recertify.timer`
- **Mechanism:** user-manager timer and oneshot service, both regular files (not links) under the user unit directory
- **Winning source:** the two unit files
- **Purpose:** after a kernel upgrade, recertify the atoms A8 durability tuple in the background and leave a review branch (the script's header, the atoms `docs/certification/README.md`)
- **Confidence:** traced
- **Package owner:** none
- **Tracked source:** `hosts/titan/systemd/user/atoms-recertify.timer`, `hosts/titan/systemd/user/atoms-recertify.service`, `hosts/titan/bin/atoms-recertify`
- **Installed matches source:** yes — `just drift` 2026-11-05
- **Persistence:** service-managed — enabled in the user manager; re-armed at each user-manager start
- **Previous value:** no units — installed 2026-08-30 per the script header; not a capture
- **Vendor default:** no such units
- **Restore:** (1) `systemctl --user disable --now atoms-recertify.timer`; (2) `rm ~/.config/systemd/user/atoms-recertify.timer ~/.config/systemd/user/atoms-recertify.service`; (3) `systemctl --user daemon-reload`; (4) readback `systemctl --user cat atoms-recertify.timer` → "No files found"
- **Validation:** not validated — procedure written, not run

### niri stop timeout

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `~/.config/systemd/user/niri.service.d/stop-timeout.conf` (symlink to the dotfiles source)
- **Effective value:** `TimeoutStopSec=10s` on `niri.service` (`TimeoutStopUSec=10s`)
- **Inspect:** `systemctl --user show -p TimeoutStopUSec niri.service`; `systemctl --user cat niri.service | grep '^# '`
- **Mechanism:** a user-manager drop-in extending the packaged `/usr/lib/systemd/user/niri.service`
- **Winning source:** the drop-in; the packaged unit sets no stop timeout, so the manager default applied before
- **Purpose:** bound how long logout waits for the compositor to exit; no comment in the file
- **Confidence:** partial — purpose inferred
- **Package owner:** none
- **Tracked source:** `systemd/user/niri.service.d/stop-timeout.conf`
- **Installed matches source:** yes — the installed path is a symlink to it (2026-09-12)
- **Persistence:** service-managed — read at unit load; a change needs `daemon-reload`, and applies to the next stop
- **Previous value:** the user manager's `DefaultTimeoutStopSec` (`systemctl --user show -p DefaultTimeoutStopUSec`, 1min 30s unless `/etc/systemd/user.conf` changes it — it is unmodified); not a capture
- **Vendor default:** unset in the packaged unit → the manager default, 90 s (`systemd-user.conf(5)`)
- **Restore:** (1) `rm ~/.config/systemd/user/niri.service.d/stop-timeout.conf` (in dotfiles terms: stop linking it); (2) `systemctl --user daemon-reload`; (3) readback `systemctl --user show -p TimeoutStopUSec niri.service` → `1min 30s`
- **Validation:** not validated — procedure written, not run

### CPU frequency governor

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** none
- **Effective value:** `schedutil` on all 32 CPUs; driver `acpi-cpufreq`
- **Inspect:** `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c`
- **Mechanism:** kernel default governor selected at build time
- **Winning source:** the kernel configuration: `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y` (`zcat /proc/config.gz`); no `cpupower` unit is installed, and no udev rule, tmpfiles entry, or local unit writes `scaling_governor` (`grep -rn governor /etc/sysctl.d /etc/tmpfiles.d /etc/systemd/system /etc/udev/rules.d` → nothing)
- **Purpose:** not a local setting — the standalone script's `--governor` option was never applied (the README's Part A5 is advisory, and nothing persists a governor)
- **Confidence:** traced
- **Package owner:** n/a (kernel)
- **Tracked source:** none
- **Installed matches source:** n/a
- **Persistence:** runtime-only — the value is the boot default; a `sysfs` write would last until reboot
- **Previous value:** same — no local input has ever changed it
- **Vendor default:** `schedutil` — `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y` in `linux 7.2.2-arch1-1`
- **Restore:** none required — no local input; a future experiment writing `scaling_governor` restores by writing `schedutil` back to every CPU, readback via Inspect
- **Validation:** not validated — no restoration exists to validate

### Transparent hugepages

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** none
- **Effective value:** `enabled` = `[always]`, `defrag` = `[madvise]`
- **Inspect:** `cat /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag`
- **Mechanism:** kernel defaults selected at build time
- **Winning source:** `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y` for `enabled`; `defrag`'s default is `madvise` from `mm/huge_memory.c` v7.2 line 68 (`TRANSPARENT_HUGEPAGE_DEFRAG_REQ_MADV_FLAG` in the initial flags); no local writer (`grep -rn hugepage /etc/sysctl.d /etc/tmpfiles.d /etc/systemd/system` → nothing)
- **Purpose:** not a local setting
- **Confidence:** traced
- **Package owner:** n/a (kernel)
- **Tracked source:** none
- **Installed matches source:** n/a
- **Persistence:** runtime-only — boot defaults; a sysfs write lasts until reboot
- **Previous value:** same — never changed locally
- **Vendor default:** `always` / `madvise` — kernel config and `mm/huge_memory.c` v7.2 line 68
- **Restore:** none required — no local input
- **Validation:** not validated — no restoration exists to validate

### Realtime scheduling budget

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** none
- **Effective value:** `kernel.sched_rt_runtime_us = 1000000`, `kernel.sched_rt_period_us = 1000000`
- **Inspect:** `sysctl -n kernel.sched_rt_runtime_us kernel.sched_rt_period_us`
- **Mechanism:** kernel compiled defaults; no sysctl source sets either key (`/usr/lib/systemd/systemd-sysctl --cat-config`)
- **Winning source:** `kernel/sched/rt.c` v7.2 lines 18 and 24: `int sysctl_sched_rt_period = 1000000;` and `int sysctl_sched_rt_runtime = 1000000;`
- **Purpose:** not a local setting. The discovery report first classified it as an unresolved deviation because older documentation quotes a 950000 µs runtime default; that default no longer applies
- **Confidence:** traced
- **Package owner:** n/a (kernel)
- **Tracked source:** none
- **Installed matches source:** n/a
- **Persistence:** runtime-only — boot defaults
- **Previous value:** same — never changed locally
- **Vendor default:** `1000000` / `1000000` — `kernel/sched/rt.c` v7.2 lines 18, 24
- **Restore:** none required — no local input
- **Validation:** not validated — no restoration exists to validate

### Realtime privileges

- **Scope:** user
- **Observed:** 2026-09-12
- **Installed path:** `/etc/security/limits.d/99-realtime-privileges.conf` (package file, unmodified); the local input is the `realtime` group membership in `/etc/group`
- **Effective value:** `@realtime - rtprio 98`, `@realtime - memlock unlimited`, `@realtime - nice -11`; this login has `ulimit -r` `98` and `ulimit -l` `unlimited`; `id -nG` includes `realtime`
- **Inspect:** `id -nG | tr ' ' '\n' | grep -x realtime`; `ulimit -r -l` in a login shell; `pacman -Qkk realtime-privileges`
- **Mechanism:** `pam_limits` applies the package's limits file to members of the `realtime` group at session open
- **Winning source:** the package file for the limits; group membership for who gets them
- **Purpose:** realtime scheduling and locked memory for PipeWire and the DAW (standalone README, "already configured correctly")
- **Confidence:** traced
- **Package owner:** `realtime-privileges 5-1`, `0 altered files`
- **Tracked source:** none needed — package-owned; the membership is an account-database change recorded here by `id -nG` only
- **Installed matches source:** yes — `pacman -Qkk realtime-privileges` 2026-09-12
- **Persistence:** login-scoped — limits apply at the next session for members of the group
- **Previous value:** not a member of `realtime`; date unknown; not a capture
- **Vendor default:** the package installs the limits file but adds nobody to the group
- **Restore:** (1) `sudo gpasswd -d "$USER" realtime`; (2) log out and in; (3) readback `ulimit -r` → `0`, `id -nG` without `realtime`. Removing the package instead: `sudo pacman -R realtime-privileges`
- **Validation:** not validated — procedure written, not run

### Virtual memory map count

- **Scope:** system
- **Observed:** 2026-09-12
- **Installed path:** `/usr/lib/sysctl.d/10-arch.conf` (package file)
- **Effective value:** `vm.max_map_count = 1048576`
- **Inspect:** `sysctl -n vm.max_map_count`; `/usr/lib/systemd/systemd-sysctl --cat-config | grep -n max_map_count`
- **Mechanism:** `systemd-sysctl.service` applies the package's sysctl file at boot
- **Winning source:** `/usr/lib/sysctl.d/10-arch.conf` line 8, owned by `filesystem 2025.10.12-1`; no `/etc/sysctl.d` file overrides it
- **Purpose:** the distribution's raised default (the file cites the Arch news item on increasing `vm.max_map_count`)
- **Confidence:** traced
- **Package owner:** `filesystem 2025.10.12-1`
- **Tracked source:** none needed — package-owned, unmodified
- **Installed matches source:** yes — package file, not reported modified
- **Persistence:** service-managed — re-applied at every boot by the package file
- **Previous value:** same — never changed locally
- **Vendor default:** `1048576` from the distribution; the kernel's own default is `65530` (`DEFAULT_MAX_MAP_COUNT` in `include/linux/mm.h`), which the distribution file overrides on purpose
- **Restore:** none required — no local input
- **Validation:** not validated — no restoration exists to validate

## inotify watch capacity

Dropbox held 523,850 watches against `fs.inotify.max_user_watches = 524288`
on 2026-09-14 and remained in Starting with a monitor-hierarchy error. During
ops-d6ff04 the user installed an initial increase to `1048576` in
`95-titan-tuning.conf`. A concurrent session (dots-8257db) installed
`96-titan-inotify.conf` with `2097152` through the untracked
`system-tuning/apply-titan.sh`.

The user selected **2097152** on September 14. Ops now owns that value in the
adopted `96-titan-inotify.conf`; the installed file matches byte-for-byte and is
root-owned, mode 644. The tracked `95-titan-tuning.conf` removes its earlier
watch-limit duplicate and retains dirty-writeback tuning. Installation is verified
on September 14: all five entries pass `just drift`, including the cleaned `95` file.
The standalone script is provenance, not the source of truth.

`systemd-sysctl --cat-config` confirms `96` follows `95`, so the persistent limit
is `2097152`; the running limit now also reads back `2097152` (September 14).
Install the cleaned `95` file using the README procedure, then apply `96` using
`sudo sysctl -p /etc/sysctl.d/96-titan-inotify.conf`. Verify
`sysctl fs.inotify.max_user_watches` returns `2097152` and `just drift` passes.
`systemd-sysctl.service` reapplies the installed inputs at boot. No additional
host writes were made during adoption.

Sync recovery is verified on September 14: `dropbox-cli status` reports Up to date
and `dropbox-cli filestatus ~/d/proto` reports up to date.
The original `95` file, before either increase, is preserved under
`~/.local/share/ops/project-move/proto-science-retirement/95-titan-tuning.conf.before`.

To restore the pre-incident limit, first follow the README state-comparison protocol.
Remove the watch-limit setting in `96` and any remaining duplicate in the installed
`95`; preserve the dirty-writeback settings. Then run
`sudo sysctl -w fs.inotify.max_user_watches=524288` and verify the effective value
and persistent inputs. Restoration has not been exercised.
