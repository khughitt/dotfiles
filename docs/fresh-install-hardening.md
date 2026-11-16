# Fresh install: storage and system hardening

Type: guide; document types 1.

This guide collects optional Arch host procedures and their verification/recovery
checks. Select what applies to the hardware; these commands change live system
state and many require root. [Setup](setup.md) covers user links,
[capture setup](capture-host-setup.md) covers capture grants, and
[Mindful runtime](https://github.com/mindful-dev/v6/blob/main/docs/guide/local-deployment.md) covers application activation. Historical
measurements and incident chronology are retained privately, not current host
health claims. Inspect installed package behavior before applying a procedure.

## Packages and services

Install applicable prerequisites:

```sh
pacman -S smartmontools nvme-cli lm_sensors fwupd
```

Arch packages often leave services disabled. Enable only those needed on the host,
after installing their packages and any local unit/executable:

```sh
systemctl enable --now NetworkManager bluetooth docker
systemctl enable --now fstrim.timer paccache.timer smartd
systemctl enable --now linux-modules-cleanup.service gpu-fan-curve.service
```

NetworkManager enables its companion units; do not copy them separately. Inspect
stock presets rather than capturing generated getty/remote-fs/userdbd links.

For the tracked 16 GiB zstd zram configuration:

```sh
install -Dm0644 systemd/zram-generator.conf /etc/systemd/zram-generator.conf
reboot
zramctl
```

Link user units and selected maintenance timers using:

```sh
./setup.sh --link-only --headless --only systemd --enable-user-timers
```

Apply a Noctalia palette once to create the promoted theme; until then committed
fallbacks apply. Enable host-specific units such as `familiar-reap.timer` only
when their referenced project exists (`~/d/familiar` for Familiar). Mindful,
Git-index retention and convergence have separate activation gates; see setup.

## NVMe power management and mounts

For hosts requiring the captured NVMe workaround, place these parameters in
`GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`:

```text
pcie_aspm=off nvme_core.default_ps_max_latency_us=0
```

The latter disables APST; disabling power savings increases idle power. Investigate
controller-drop/reset failures rather than applying it as a universal disk fix.
Inspect drive states with `nvme id-ctrl /dev/nvmeN -H` and
`nvme get-feature /dev/nvmeN -f 0x0c -H`. Regenerate GRUB using the guarded procedure
below, then check the generated parameter and the next boot's `/proc/cmdline`.

In `/etc/fstab`, give nonessential mounts `nofail` and a bounded device timeout:

```text
UUID=...  /mnt/data  ext4  rw,noatime,nofail,x-systemd.device-timeout=5s  0 2
```

Keep pass 2 for those ext4 mounts so present devices still get checked. Only
boot-critical mounts should be required by local-fs.target. The captured policy
uses `noatime`, including on root. Use stable UUIDs and drive-model comments;
device enumeration names can change between boots.

`findmnt --verify` reports current device reachability, not absent-device boot
safety. Inspect generator output as well:

```sh
ls /run/systemd/generator/local-fs.target.requires/
ls /run/systemd/generator/local-fs.target.wants/
```

Required entries must be boot-critical; optional mounts belong in wants.

## SMART monitoring

Enable `fstrim.timer` and `smartd` after configuring actual devices. For
`/etc/smartd.conf`:

- Address devices by stable `/dev/disk/by-id/` paths. Do not combine DEVICESCAN
  with explicit device entries.
- NVMe uses `-d nvme -H -l error -W 0,70,80`; SATA SSD uses `-a -o on -S on`;
  spinners add `-n standby,q` to avoid waking a sleeping disk for polling.
- Captured temperature warning/critical thresholds are NVMe 70/80 °C, SATA SSD
  55/70 °C and HDD 45/55 °C. Check applicability to each device.
- Stagger long self-tests; large HDD tests can take many hours.
- Without an MTA use `-m <nomailer> -M exec <script> -M daily`. The literal
  `<nomailer>` token selects the script without mail delivery.

Provision a root-owned alert script separately. The captured smartd-notify
contract writes both the journal (`logger -t smartd-notify -p daemon.crit`) and
`/var/log/smartd-alerts.log`; desktop notification is only a third, best-effort
sink via the intended user's existing D-Bus session. Check the user bus exists
before invoking notify-send. These host-local files are not installed by setup.

The schedule is an extended regular expression matching test type, month, day,
weekday and hour. A literal range like `01-07` never matches a timestamp. Example:

```text
L/../(0[1-7])/6/03
```

This selects the first Saturday at 03:00 (weekdays 1=Monday through 7=Sunday).
Verify the daemon's interpretation, not just successful parsing:

```sh
smartd -q showtests -c /etc/smartd.conf | grep "type L"
```

Zero scheduled long tests is a failure if a long test was intended.

## GPU fan floor (NVIDIA and Wayland)

The tracked daemon prevents repeated zero-RPM fan cycling on the configured GPU:

```sh
install -m 0755 bin/gpu-fan-curve /usr/local/bin/gpu-fan-curve
install -m 0644 systemd/system/gpu-fan-curve.service /etc/systemd/system/
systemctl enable --now gpu-fan-curve
```

It uses `nvidia-settings` with root and the live Wayland socket/runtime directory;
`DISPLAY` alone is insufficient for this route. It discovers the socket rather
than assuming a stable name. An XNVCtrl client reporting no coolers is not evidence
that the GPU lacks fans. Read actual fan RPM while establishing a safe floor for
new hardware; commanded PWM is not tachometer evidence.

The current curve uses a 45% floor, rising through 55/70% to 100% at 85 °C.
Manual mode owns the entire curve. The daemon restores automatic mode on stop,
signal, unreadable temperature or its 88 °C safety ceiling; ExecStopPost also
attempts restoration. If the Wayland session disappears, driver access can fail,
so verify fan state rather than assuming cleanup succeeded. The separate
[capture helper](capture-host-setup.md) uses NVML and requires its own restoration
trap for a persistent fan hold.

`StartLimitIntervalSec` belongs in the systemd Unit section. Read the applied
value with `systemctl show gpu-fan-curve -p StartLimitIntervalUSec`; ignored keys
can leave the daemon restart behavior different from the intended policy.

## Dual boot and GRUB regeneration

Find the ESP actually containing Microsoft's bootloader; a disk may have several:

```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,UUID
mount -o ro /dev/nvmeXn1pN /mnt/tmp
ls /mnt/tmp/EFI/
```

Use that ESP's filesystem UUID in a static entry in `/etc/grub.d/40_custom`:

```text
menuentry 'Windows' --class windows --class os --id windows {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root <ESP-FS-UUID>
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
```

The stock 40_custom copies its menu body literally after its header; shell
variables do not expand there. A static entry avoids os-prober scanning unrelated
or unreliable disks. This captured boot route assumes Secure Boot disabled;
check `bootctl status` and use the firmware's Windows entry when that assumption
does not hold. Fully shut down Windows before writing an NTFS volume; do not
write one left hibernated by fast startup.

After Windows boots, check `efibootmgr -v` and restore the intended order with
`efibootmgr -o <grub>,<rest>` if necessary. To use UTC for the RTC on both systems,
run as Administrator in Windows:

```text
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

Never regenerate GRUB during a pacman transaction: kernel/initramfs files can be
absent between its remove and install hooks. Wait until `/var/lib/pacman/db.lck`
is absent and the transaction has completed. Keep backups outside `/etc/grub.d`;
every executable there is a generator, including executable backup copies.

Generate to a candidate and validate before installing it over the live menu:

```sh
grub-mkconfig -o /tmp/grub.cfg.new
grub-script-check /tmp/grub.cfg.new
grep -c "menuentry 'Arch Linux" /tmp/grub.cfg.new
```

Require at least one Linux entry and existing paths for every referenced kernel
and initrd. Inspect expected kernel parameters too. Preserve the old menu, then
install the verified candidate into `/boot/grub/grub.cfg`. A syntactically valid
menu alone does not prove it can boot.

## Fallback initramfs

The fallback omits autodetect so it can boot hardware beyond the build-time
selection. In `/etc/mkinitcpio.d/linux.preset`, configure all three lines:

```sh
PRESETS=('default' 'fallback')
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
```

Run `mkinitcpio -P`; a fallback name without an output path is insufficient.
Verify the generated image contents and that fallback is larger than default;
equal sizes can reveal an ineffective autodetect exclusion. NVIDIA modules can
dominate both sizes. Missing-firmware warnings for unused hardware are distinct
from missing firmware for the machine's actual boot path.

GRUB discovers the fallback image separately from its single-user recovery entry;
`GRUB_DISABLE_RECOVERY` does not replace fallback configuration. Inspect the
resulting menu. Recheck custom presets after upgrades: package hook behavior can
restore a customized preset through its pacsave handling, but do not infer that
from a successful upgrade alone.

## Kernel module trees and update gate

`kernel-modules-hook` preserves the running kernel's modules across upgrades so
new modprobe requests still work before reboot. Enable its cleanup unit as well:

```sh
pacman -S kernel-modules-hook
systemctl enable --now linux-modules-cleanup.service
```

Preserved trees are no longer package-owned. The cleanup unit moves nonrunning,
unowned trees to `/usr/lib/modules/.old/`; its tmpfiles rule purges them after
four weeks. Moving them out of DKMS's normal glob avoids redundant builds without
immediately deleting recovery copies. Audit ownership and the running version
before removing anything:

```sh
uname -r
for d in /usr/lib/modules/[0-9]*/; do
    pacman -Qo "$d" >/dev/null 2>&1 || echo "unowned: $d"
done
```

The local gate deliberately pins linux and linux-headers as a pair. Install
root-owned copies; never let a root pacman hook execute a user-writable launcher:

```sh
install -m 0755 bin/kernel-gate /usr/local/bin/kernel-gate
install -m 0644 pacman/hooks/65-kernel-headers-sync.hook /etc/pacman.d/hooks/
install -m 0644 pacman/kernel-gate.conf /etc/kernel-gate.conf
```

Add both packages to IgnorePkg in `/etc/pacman.conf`, preserving other entries:

```text
IgnorePkg = linux linux-headers
```

`kernel-gate status` reports pins and certification; `kernel-gate unlock` first
runs a full system upgrade and then releases the pair. Never substitute
`pacman -Sy linux`, a partial upgrade. IgnorePkg blocks routine -Syu, not an
explicit package installation. Hook 65 checks the pair before DKMS hook 70.
Reinstall the root-owned helper whenever its tracked source changes. Verify
pacman's effective plan with `pacman -Qu linux linux-headers`; available updates
to both pinned packages must be marked ignored.

Certification applies to the exact running kernel, including package rebuilds.
The local atoms-recertify sweep is not shipped here; a new machine can legitimately
report certification unknown until that separate owner supplies the environment.

## Console keymap

[us-tmux.map](../kbd/us-tmux.map) includes the stock us map and supplies xterm Alt
cursor/page sequences for tmux, plus ESC CR for Shift+Enter. This avoids plain
cursor keys and unintended VT switching on those Alt combinations:

```sh
install -Dm0644 kbd/us-tmux.map /usr/share/kbd/keymaps/i386/qwerty/us-tmux.map
sed -i 's/^KEYMAP=.*/KEYMAP=us-tmux/' /etc/vconsole.conf
systemctl restart systemd-vconsole-setup
```

If no KEYMAP line exists, add `KEYMAP=us-tmux`. The map must live under the kbd
search tree; keymap/sd-vconsole initramfs hooks also find it by name. Run
`mkinitcpio -P` if the early-boot keymap must change. Alt+Left/Right no longer switch
VTs; Alt+F<n> still does. The protected console-keymap Zsh test compiles the map
with loadkeys and checks Alt and Shift+Enter without taking the live console.

## Keyring unlock at console login

For a VT login followed by niri, add these optional GNOME keyring PAM entries to
`/etc/pam.d/login` after the corresponding auth/session includes:

```text
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
```

Unlock requires the login keyring's password to match the account password.
Check it with seahorse; an additional locked default keyring can still trigger
prompts. The default-keyring selector should name login. Setup's systemd phase
links a secrets D-Bus override routing activation through the keyring service,
avoiding a second daemon launched beside socket activation. After logging in:

```sh
pgrep -a gnome-keyring
busctl --user get-property org.freedesktop.secrets \
  /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked
```

Require one daemon and `b false`, not merely the presence of the PAM lines.

## SSH from the tailnet

The tracked [sshd drop-in](../ssh/sshd_config.d/10-tailnet.conf) permits public-key
login for its declared user from Tailscale ranges only. Review that username for
the target host. Install client keys before enabling passwordless-only sshd:

```sh
install -m 0700 -d ~/.ssh
echo '<client public key>' >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
install -Dm0644 ssh/sshd_config.d/10-tailnet.conf /etc/ssh/sshd_config.d/10-tailnet.conf
ssh-keygen -A
sshd -t && systemctl enable --now sshd
```

Generate host keys before sshd -t on a fresh host. Client aliases are host-local
and not installed by setup:

```sshconfig
Host <alias>
  HostName <machine>.<tailnet>.ts.net
  HostKeyAlias <already-trusted-host-name>
  User <remote-user>
```

Use the full MagicDNS name from `tailscale status --json`, avoiding link-local
name resolution rejected by AllowUsers. Retain HostKeyAlias only for an existing
trusted identity; on a new client omit it and verify the server fingerprint.
Inspect `ssh -G <alias>` before connecting.

The early-numbered drop-in matters because sshd generally keeps the first value.
AllowUsers restricts sources while listening broadly; binding to a Tailscale
address would race its availability at boot. LAN clients still reach pre-auth
code before rejection. The source restriction relies on Tailscale netfilter
anti-spoofing; verify it is enabled. Do not enable the stock nftables forward-drop
policy blindly on a Docker host. PasswordAuthentication alone is insufficient:
KbdInteractiveAuthentication is off and AuthenticationMethods requires publickey.

Verify the merged daemon configuration for an actual connection:

```sh
sshd -T -C \
  'user=<remote-user>,addr=<client-tailnet-ip>,host=<client-hostname>,laddr=<server-tailnet-ip>,lport=22' \
  | grep -iE '^(allowusers|passwordauth|kbdinteractive|permitrootlogin|authenticationmethods)'
```

From a client, `ssh -o PubkeyAuthentication=no <host>` must fail with publickey
required. A LAN-source login must also fail, with not-listed-in-AllowUsers in the
sshd journal. Retain existing access until these checks establish the new route.

## Audit systemd changes

Use all these views; systemd-delta alone omits wholly local units:

```sh
systemd-delta --no-pager
find /etc/systemd/system -xdev \( -type f -o -type l \) -printf '%p -> %l\n' | sort
systemctl list-unit-files --state=enabled,masked,linked --no-pager
systemctl list-timers --all --no-pager
find ~/.config/systemd/user -xdev \( -type f -o -type l \) -printf '%p -> %l\n' | sort
systemctl --user list-unit-files --state=enabled,masked,linked --no-pager
systemctl --user list-timers --all --no-pager
```

Compare STATE with PRESET to identify local choices. Check `pacman -Qo <unit-file>`
before capturing package-owned files. Recreate package units and generated wants
links through package installation and systemctl enable, rather than copying them.
For every procedure, verify the effective behavior or generated result; a zero
exit status alone is not evidence that the intended host state took effect.
