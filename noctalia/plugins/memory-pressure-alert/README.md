# Memory Pressure Alert

This headless Noctalia plugin shows a persistent memory warning on every screen.
It reuses Noctalia's System Monitor data and warning/critical thresholds.

## Installation and activation

**Noctalia v5: deployment is deferred.** This repository's current setup uses
v5 and installs only Wali Panel and Prism. Neither ordinary setup nor
`./setup.sh --only noctalia-plugins` installs or enables Memory Pressure Alert.
There is currently no supported installation or activation command for this
plugin on v5; it needs a port before it can be enabled there. See
[the current local-plugin setup](../../noctalia.md#local-v5-plugins).

The retained implementation targets Noctalia v4 (manifest minimum 4.7.7),
Quickshell and its `SystemStatService`/`pluginApi` interfaces. Its original
installation design used a link from
`$XDG_CONFIG_HOME/noctalia/plugins/memory-pressure-alert` (default
`~/.config/noctalia/plugins/memory-pressure-alert`) to this directory, followed
by discovery and enablement in Noctalia's Settings → Plugins. That is historical
v4 guidance, not a deployment route for the current setup. Do not use v5's
`noctalia msg plugins enable` commands with this v4 manifest.

On v4, open Settings → Plugins → Memory Pressure Alert to edit its settings;
the plugin also requests that dialog through:

```sh
qs -c noctalia-shell ipc call plugin openSettings memory-pressure-alert
```

Its manifest supplies `Settings.qml` for warning recovery. Shared warning and
critical thresholds are under Settings → System Monitor → Thresholds. The
process-monitor action additionally requires `ghostty` and `btop` on `PATH`
unless `monitorCommand` is changed. The plugin is headless and needs no bar widget.

## Behavior

- Warning and critical banners remain visible until memory recovers or they are dismissed.
- Dismissing a warning does not suppress a later critical escalation.
- Dismissing a critical alert suppresses the remainder of that episode.
- Warning recovery defaults to 65%.
- Critical recovery is five percentage points below critical, clamped to warning.
- Invalid threshold ordering shows a persistent, non-dismissible error banner.
- Polling pauses on Noctalia's lock screen; a crossing appears after unlock.

Displayed available memory reuses Noctalia's effective value. On ZFS systems,
that includes Noctalia's reclaimable-ARC adjustment rather than reporting raw
Linux `MemAvailable` as though no ARC adjustment occurred.

The plugin does not change Noctalia's current/default 80% warning and 90%
critical thresholds. To alert earlier, set 70% and 85% under Noctalia
Settings → System Monitor → Thresholds. This intentionally changes the bar
gauge colors at the same thresholds.

Open the plugin settings to change warning recovery. The process-monitor action
runs ghostty -e btop.
