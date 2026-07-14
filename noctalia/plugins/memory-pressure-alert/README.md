# Memory Pressure Alert

This headless Noctalia plugin shows a persistent memory warning on every screen.
It reuses Noctalia's System Monitor data and warning/critical thresholds.

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
