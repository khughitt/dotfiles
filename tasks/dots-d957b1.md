---
id: dots-d957b1
title: Extend the Noctalia memory-pressure alert to CPU and disk space
status: todo
priority: 2
size: m
complexity: mid
created: 2026-09-12T16:11:20Z
updated: 2026-09-12T16:34:53Z
depends: []
tags: [quick-add, noctalia]
source: "mindful:thought:8e45d49e001c4e5eb9b00f159dc60e87"
---

Generalize noctalia/plugins/memory-pressure-alert/ from one resource to several: CPU (sustained load or PSI), disk space on the root and data volumes, and whatever else the design doc's threshold model supports. Per-resource thresholds and hysteresis, one alert surface.

The cross-project half (observing CPU/GPU/memory over time, budgets) is ops-71120e; this task is the desktop alert only.

Source: mindful:thought:8e45d49e001c4e5eb9b00f159dc60e87

## Notes

- 2026-09-12T16:34:53Z (main): When generalizing, check whether the plugin takes colours from the material/prism pipeline like the other Noctalia plugins or hardcodes them; dots-6bfb8d (restyle Noctalia) is nearby.
