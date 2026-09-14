---
id: dots-d957b1
title: Extend the Noctalia memory-pressure alert to CPU and disk space
status: todo
priority: 2
size: m
complexity: mid
process: planned
created: 2026-09-12T16:11:20Z
updated: 2026-09-14T11:12:47Z
depends: []
tags: [quick-add, noctalia]
source: "mindful:thought:8e45d49e001c4e5eb9b00f159dc60e87"
---

Generalize noctalia/plugins/memory-pressure-alert/ from one resource to several: CPU (sustained load or PSI), disk space on the root and data volumes, and whatever else the design doc's threshold model supports. Per-resource thresholds and hysteresis, one alert surface.

The cross-project half (observing CPU/GPU/memory over time, budgets) is ops-71120e; this task is the desktop alert only.

Source: mindful:thought:8e45d49e001c4e5eb9b00f159dc60e87

## Notes

- 2026-09-12T16:34:53Z (main): When generalizing, check whether the plugin takes colours from the material/prism pipeline like the other Noctalia plugins or hardcodes them; dots-6bfb8d (restyle Noctalia) is nearby.
- 2026-09-14T11:12:47Z (main): Data source for the disk half: ops's disk-report (filed 2026-09-14) can emit JSON for the volumes that matter (/, /mnt/ssd, /data, /mnt/storage, /mnt/hmcl at 91-98%) plus inotify watch usage, so the plugin polls one command instead of parsing df. Dropbox's watch exhaustion (2026-09-14) is a second resource worth a threshold: it silently breaks user units.
- 2026-09-14T11:12:47Z (main): Process planned: no design doc exists for the plugin; generalizing a single-resource hysteresis state machine (episodes, dismissal semantics, recovery thresholds) to several resources with one alert surface is a design, not a bounded edit.
