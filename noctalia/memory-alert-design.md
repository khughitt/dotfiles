# Persistent Memory Pressure Alert

## Summary

Add a local Noctalia plugin that displays a persistent, two-stage memory-pressure alert. The plugin reuses Noctalia's existing `SystemStatService` instead of starting another polling process. It inherits the System Monitor's warning and critical thresholds so the bar gauge and banner always agree. With the recommended values, it presents an amber warning at 70% memory use and a red critical alert at 85%, and remains visible until memory recovers or the user acknowledges it.

The alert supplements the existing compact System Monitor bar widget. It does not replace that widget or attempt to prevent or kill out-of-memory processes.

## Motivation

The existing compact System Monitor widget changes the memory gauge color at configured thresholds, but its small size makes it easy to overlook. Long-running analysis tasks and code bugs can consume memory quickly enough to cause an OOM event before that color change is noticed.

The alert must therefore:

- be difficult to overlook;
- remain present instead of expiring like a notification;
- provide an early warning and a distinct critical escalation;
- avoid repeated notifications and continuous animation;
- let the user acknowledge an alert without suppressing a later escalation; and
- avoid duplicating Noctalia's memory polling.

## Chosen Approach

Implement a headless local Noctalia plugin with plugin-owned layer-shell windows. The plugin registers with `SystemStatService`, consumes `memPercent`, `memGb`, and `memTotalGb`, and shows the same top-center banner on every connected screen. One shared controller owns the state; the windows are replicated views of that state.

This is preferable to the alternatives:

- A systemd user service would duplicate `/proc/meminfo` polling and require a separate overlay protocol.
- A standard desktop notification would expire under the current Noctalia notification settings and would make acknowledgement and escalation state awkward to manage.
- Changes to packaged Noctalia files under `/etc/xdg` would be overwritten by package upgrades.

The plugin is installed with the managed-symlink convention already used for `wali-panel`.

### Layer-shell feasibility proof

Before finalizing this design, an isolated Quickshell spike dynamically loaded `Main.qml` with the same `Qt.createComponent(...).createObject(...)` mechanism used by `PluginService`. The dynamically instantiated object successfully created a `Variants`-owned overlay `PanelWindow` for the detected screen, and the configuration loaded without a QML or layer-shell creation error. This verifies the plugin-owned window boundary on which the design depends.

## User Experience

### Warning

When memory use reaches the inherited warning threshold, recommended at 70%, show a persistent amber banner at the top center of every connected screen. The banner reports used, total, and available memory.

Example:

> Memory high — 88 / 125 GiB used · 37 GiB available
>
> Open btop · Dismiss

The warning remains static after its entrance animation.

### Critical alert

When memory use reaches the inherited critical threshold, recommended at 85%, show or replace every banner with a red critical alert. A warning that was previously dismissed does not suppress this escalation. The critical banner briefly pulses once when critical state is entered and then becomes static.

Example:

> Memory critically high — 108 / 125 GiB used · 17 GiB available
>
> Open btop · Dismiss

The pulse is finite so the persistent alert remains noticeable without creating continuous distraction or unnecessary rendering work.

### Actions

- **Open btop** runs `ghostty -e btop`. The command is stored as an argument array in `manifest.json` under `metadata.defaultSettings.monitorCommand`, where it can be changed without introducing shell-string parsing.
- **Dismiss** acknowledges the current alert according to the state rules below.

The replicated overlays do not steal keyboard focus and do not reserve compositor space. They use Noctalia's scale, typography, colors, shadows, and screen geometry. Activating an action on any screen updates the single shared state and therefore all windows together.

No alert sound is added.

## State Model

The state reducer receives memory samples and user actions and returns the alert level and visibility. It has three levels: `normal`, `warning`, and `critical`.

The thresholds are:

- warning recovery: a plugin setting, defaulting to 65%;
- warning: inherited from `SystemStatService.memWarningThreshold`, with 70% recommended;
- critical recovery: derived as `max(warning, critical - 5)`, which is 80% with the recommended values; and
- critical: inherited from `SystemStatService.memCriticalThreshold`, with 85% recommended.

An episode begins when memory first reaches the warning threshold. It ends only when memory drops below the warning-recovery threshold. Critical state is separately latched until memory drops below the derived critical-recovery threshold. These two hysteresis bands prevent repeated alerts around either boundary.

Within an active episode:

1. Memory at or above the critical threshold enters critical state.
2. Once entered, critical state remains latched until memory drops below the critical-recovery threshold.
3. After leaving critical state, the episode remains a warning until memory drops below the warning-recovery threshold.
4. Dismissing a warning hides it for the current episode.
5. Reaching critical clears the warning acknowledgement and displays the critical alert.
6. If an unacknowledged critical alert later drops below the critical-recovery threshold but remains at or above the warning-recovery threshold, it downgrades to a visible warning.
7. Dismissing a critical alert hides all alerts for the remainder of the episode.
8. Recovery below the warning-recovery threshold hides every overlay, clears acknowledgements, and arms the plugin for the next episode.

If Noctalia starts while memory is already at or above a threshold, the first valid sample begins the corresponding episode and shows the alert.

## Components

### Plugin manifest

`manifest.json` declares a `main` and `settings` entry point, a compatible minimum Noctalia version, the default warning-recovery threshold, and the `monitorCommand` argument array. The plugin does not add another bar widget.

### State reducer

`logic.js` contains the pure state transition logic. It has no QML, filesystem, or process dependencies. `Main.qml` passes each memory sample and dismissal action to the reducer and applies the returned state.

Keeping the reducer pure makes the acknowledgement and escalation rules deterministic and directly testable.

### Controller

`Main.qml` owns plugin lifecycle and integration:

- validate settings;
- register and unregister the plugin as a `SystemStatService` consumer;
- pass memory samples to the reducer;
- expose the memory values needed by the view;
- handle dismissal; and
- launch `ghostty -e btop` without a shell intermediary.

The controller creates no independent timer. Noctalia currently refreshes memory data every five seconds, which is adequate for these early thresholds.

### Alert view

`AlertWindow.qml` owns one layer-shell window and its banner presentation. `Main.qml` uses `Variants` over `Quickshell.screens` to instantiate one view per connected screen. Each view receives level, memory values, its model screen, and action callbacks from the shared controller. It contains no threshold or acknowledgement logic.

Each view uses an overlay layer with exclusion mode ignored. A single shared controller state ensures there is only one logical alert even though it is visible on every monitor.

### Settings

`Settings.qml` exposes the integer warning-recovery threshold and displays the inherited System Monitor thresholds for context. Warning and critical remain owned by Noctalia at **Settings → System Monitor → Thresholds**. The controls and controller maintain the invariant:

```text
0 <= recovery < warning < critical <= 100
```

The warning-recovery default is 65%. The recommended inherited warning and critical values are 70% and 85%. Saving an invalid recovery value is prevented by the UI and rejected by the controller.

## Data Flow

```text
SystemStatService memory sample
            |
            v
      pure state reducer <--- Dismiss action
            |
            v
   level + visibility state
            |
            v
 AlertWindow on every screen
            |
            +---> launch btop
```

The display derives available memory as `memTotalGb - memGb`. On non-ZFS systems this corresponds to Linux `MemAvailable`. When ZFS ARC is present, Noctalia adjusts `memGb` by subtracting reclaimable ARC above `c_min`; the displayed value is therefore effective available memory after Noctalia's ARC adjustment, not raw `MemAvailable`. The plugin does not perform a second memory interpretation.

`SystemStatService.shouldRun` becomes false while Noctalia's lock screen is active, so memory polling pauses while locked. If memory crosses a threshold during that time, the alert appears on every screen on the first refreshed sample after unlock. The plugin does not claim to alert through the lock screen.

## Failure Handling

- Invalid threshold ordering is a configuration error. The controller emits one Noctalia error toast, logs the invalid values, and does not arm the alert until the configuration becomes valid. It does not silently substitute other thresholds.
- If the configured `monitorCommand` cannot start or exits unsuccessfully during launch, the plugin shows a Noctalia error toast. Alert state and visibility are unaffected.
- Plugin destruction always unregisters from `SystemStatService`.
- A malformed memory sample is ignored with a logged error; it cannot cause a false recovery or acknowledgement reset.

## Installation and Documentation

The plugin lives at:

```text
~/d/dotfiles/noctalia/plugins/memory-pressure-alert/
```

Graphical setup creates the managed link:

```text
~/.config/noctalia/plugins/memory-pressure-alert
  -> ~/d/dotfiles/noctalia/plugins/memory-pressure-alert
```

The existing Noctalia documentation describes enabling the plugin, setting the shared System Monitor thresholds to the recommended 70% and 85%, and adjusting the plugin-specific recovery threshold. `setup.sh` currently manages one local plugin link, `wali-panel`; this work adds the second `ln_s` entry for `memory-pressure-alert`. Setup health checks verify the new managed link without modifying unrelated Noctalia settings.

## Testing

### Automated reducer tests

Node tests cover:

- values immediately below, at, and above each threshold;
- startup above warning and startup above critical;
- hysteresis between 65% and 70%;
- critical hysteresis between 80% and 85%;
- warning dismissal;
- critical escalation after warning dismissal;
- critical-to-warning downgrade when critical was not dismissed;
- critical dismissal for the remainder of an episode;
- recovery clearing all acknowledgements; and
- a new episode after recovery.

### Static and integration checks

- Run `qmllint` against the plugin QML with the Noctalia import path.
- Run the repository's setup and health tests for the new managed link.
- Confirm the plugin registers exactly once and unregisters on reload.

### Manual smoke test

Temporarily lower the shared System Monitor thresholds and plugin recovery threshold around the machine's current memory percentage to exercise warning, escalation, dismissal, downgrade, and recovery without allocating large amounts of memory. Restore the recommended 65/70/85 values after verification.

Confirm that the overlay appears on every connected screen, remains visible without focus theft, opens btop in Ghostty, and follows the configured Noctalia scale and theme. Lock and unlock once with a temporarily low threshold to confirm that a stale locked sample does not fire and the first refreshed post-unlock sample does.

## Out of Scope

- Killing or suspending processes automatically.
- Changing kernel OOM behavior, swap, zram, or cgroup limits.
- Process attribution inside the banner.
- Replacing the existing System Monitor widget.
- Adding alert sounds or repeated notifications.
