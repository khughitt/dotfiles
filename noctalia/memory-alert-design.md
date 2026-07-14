# Persistent Memory Pressure Alert

## Summary

Add a local Noctalia plugin that displays a persistent, two-stage memory-pressure alert. The plugin reuses Noctalia's existing `SystemStatService` instead of starting another polling process. It presents an amber warning at 70% memory use and a red critical alert at 85%, and remains visible until memory recovers or the user acknowledges it.

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

Implement a headless local Noctalia plugin with a plugin-owned layer-shell window. The plugin registers with `SystemStatService`, consumes `memPercent`, `memGb`, and `memTotalGb`, and shows a top-center overlay on the active screen.

This is preferable to the alternatives:

- A systemd user service would duplicate `/proc/meminfo` polling and require a separate overlay protocol.
- A standard desktop notification would expire under the current Noctalia notification settings and would make acknowledgement and escalation state awkward to manage.
- Changes to packaged Noctalia files under `/etc/xdg` would be overwritten by package upgrades.

The plugin is installed with the same managed-symlink convention as the existing local Noctalia plugins.

## User Experience

### Warning

When memory use reaches 70%, show a persistent amber banner at the top center of the screen that was active when the warning was raised. The banner reports used, total, and available memory.

Example:

> Memory high — 88 / 125 GiB used · 37 GiB available
>
> Open btop · Dismiss

The warning remains static after its entrance animation.

### Critical alert

When memory use reaches 85%, show or replace the banner with a red critical alert. A warning that was previously dismissed does not suppress this escalation. The critical banner briefly pulses on arrival and then becomes static.

Example:

> Memory critically high — 108 / 125 GiB used · 17 GiB available
>
> Open btop · Dismiss

The pulse is finite so the persistent alert remains noticeable without creating continuous distraction or unnecessary rendering work.

### Actions

- **Open btop** launches the existing terminal-based process monitor.
- **Dismiss** acknowledges the current alert according to the state rules below.

The overlay does not steal keyboard focus and does not reserve compositor space. It uses Noctalia's scale, typography, colors, shadows, and screen geometry.

No alert sound is added.

## State Model

The state reducer receives memory samples and user actions and returns the alert level and visibility. It has three levels: `normal`, `warning`, and `critical`.

Default thresholds are:

- recovery: 65%;
- warning: 70%; and
- critical: 85%.

An episode begins when memory first reaches the warning threshold. It ends only when memory drops below the recovery threshold. This hysteresis prevents repeated alerts around 70%.

Within an active episode:

1. Memory at or above 85% is critical.
2. Memory below 85% remains a warning until it drops below 65%.
3. Dismissing a warning hides it for the current episode.
4. Reaching critical clears the warning acknowledgement and displays the critical alert.
5. If an unacknowledged critical alert later falls below 85% but remains at or above 65%, it downgrades to a visible warning.
6. Dismissing a critical alert hides all alerts for the remainder of the episode.
7. Recovery below 65% hides the overlay, clears acknowledgements, and arms the plugin for the next episode.

If Noctalia starts while memory is already at or above a threshold, the first valid sample begins the corresponding episode and shows the alert.

## Components

### Plugin manifest

`manifest.json` declares a `main` and `settings` entry point, a compatible minimum Noctalia version, and the three default thresholds. The plugin does not add another bar widget.

### State reducer

`logic.js` contains the pure state transition logic. It has no QML, filesystem, or process dependencies. `Main.qml` passes each memory sample and dismissal action to the reducer and applies the returned state.

Keeping the reducer pure makes the acknowledgement and escalation rules deterministic and directly testable.

### Controller

`Main.qml` owns plugin lifecycle and integration:

- validate settings;
- register and unregister the plugin as a `SystemStatService` consumer;
- pass memory samples to the reducer;
- resolve the active screen when an alert first appears or escalates;
- expose the memory values needed by the view;
- handle dismissal; and
- launch btop.

The controller creates no independent timer. Noctalia currently refreshes memory data every five seconds, which is adequate for these early thresholds.

### Alert view

`AlertWindow.qml` owns the layer-shell window and banner presentation. It receives level, memory values, target screen, and action callbacks from the controller. It contains no threshold or acknowledgement logic.

The view uses an overlay layer with exclusion mode ignored. A single shared controller state ensures there is only one logical alert even on a multi-monitor system.

### Settings

`Settings.qml` exposes integer recovery, warning, and critical thresholds. Its controls maintain the invariant:

```text
0 <= recovery < warning < critical <= 100
```

The default values are 65, 70, and 85. Saving invalid settings is prevented by the UI and rejected by the controller.

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
   persistent AlertWindow
            |
            +---> launch btop
```

The display derives available memory as `memTotalGb - memGb`, matching the values already calculated from Linux `MemAvailable` by Noctalia. The plugin does not reinterpret filesystem cache as unavailable memory.

## Failure Handling

- Invalid threshold ordering is a configuration error. The controller emits one Noctalia error toast, logs the invalid values, and does not arm the alert until the configuration becomes valid. It does not silently substitute other thresholds.
- If the active screen cannot be resolved, the controller logs an error and keeps the alert state armed so a later sample can retry display. It does not silently choose an unrelated screen.
- If btop cannot be launched, the plugin shows a Noctalia error toast. Alert state and visibility are unaffected.
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

The existing Noctalia documentation describes enabling the plugin and adjusting its thresholds. Setup health checks verify the managed link without modifying unrelated Noctalia settings.

## Testing

### Automated reducer tests

Node tests cover:

- values immediately below, at, and above each threshold;
- startup above warning and startup above critical;
- hysteresis between 65% and 70%;
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

Temporarily lower the plugin thresholds around the machine's current memory percentage to exercise warning, escalation, dismissal, downgrade, and recovery without allocating large amounts of memory. Restore 65/70/85 after verification.

Confirm that the overlay appears on the active screen, remains visible without focus theft, opens btop, and follows the configured Noctalia scale and theme.

## Out of Scope

- Killing or suspending processes automatically.
- Changing kernel OOM behavior, swap, zram, or cgroup limits.
- Process attribution inside the banner.
- Replacing the existing System Monitor widget.
- Adding alert sounds or repeated notifications.
