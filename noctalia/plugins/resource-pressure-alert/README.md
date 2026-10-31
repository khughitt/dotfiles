# Resource Pressure Alert

A native Noctalia v5 plugin (`khughitt/resource-pressure-alert`, API 36 or
newer) for memory, sustained CPU use and scarce disk space. Verified on
Noctalia 5.4.0 with single-output niri. Multi-output replication and hotplug
acceptance are deferred; they are not verified guarantees yet.

The service owns alert episodes and dismissals. The banner has no keyboard
focus, reserves no desktop space, fits below a top bar and scrolls when rows
exceed the output. Resource severity is written in text as well as color;
colors come from Noctalia's current palette. A private niri runtime check
verified the banner is fully covered while locked and returns after unlock.

## Installation and activation

Run from the registered **main checkout after integration**, with separate
approval for live installation/enablement:

```sh
./setup.sh --only noctalia-plugins
just health-live
```

Setup links `$XDG_DATA_HOME/noctalia/plugins/resource-pressure-alert` to
`${DOTS_HOME}/noctalia/plugins/resource-pressure-alert` and enables
`khughitt/resource-pressure-alert`. This phase also handles Wali and Prism.
On the host, `DOTS_HOME` must be the main checkout; never point a host plugin
link into a worktree. Isolated tests use their own fixture tree and HOME.
When Noctalia is down, setup creates links and prints pending enable commands.
Start Noctalia, then run the phase again or enable the id explicitly:

```sh
noctalia msg plugins enable khughitt/resource-pressure-alert
```

The old v4 plugin and both v4 design documents have been removed; git history
keeps them. The new plugin identity has fresh settings: there is no automatic
v4 settings migration or compatibility layer. Configurable `monitorCommand`
is retained as an argument list, default `['ghostty', '-e', 'btop']`.

## Thresholds and recovery

Warning thresholds belong to the plugin. Critical thresholds read the effective
System Monitor settings `ram_pct_critical_threshold`,
`cpu_usage_critical_threshold` and `disk_used_pct_critical_threshold`.
A shared critical value of **0 disables the whole family**, including warning
rows. Cosmetic activity/tint settings never change alert policy: v5 has no
warning-level gauge threshold. The current configuration gives:

| Resource | Warning entry | Critical entry | Recovery |
| --- | --- | --- | --- |
| Memory | At least 80% | At least 90% | Critical downgrades below 85%; episode ends below 65% |
| CPU | None | At least 90% continuously for 300 seconds | Episode ends below 85% |
| Disk | At least 90% used **and** less than 50 GiB available | At least 95% used **and** less than 20 GiB available | Critical downgrades below 90% **or** at least 25 GiB available; episode ends below 85% **or** at least 60 GiB available |

These recovery boundaries follow the configured warnings/criticals when
retuned. CPU pending time resets on any sample below its critical threshold;
a process oscillating around it can avoid an alert. A deliberate full-machine
job lasting five minutes may alert. Either a monotonic or sample wall-clock
gap above nine seconds resets pending CPU time, including suspend gaps.

Disks use native mount discovery and sampling, deduplicated by source. Root
is included; boot/EFI paths and configured `excludedMounts` are excluded.
At the recorded first-enable snapshot, `/data` (615 GiB free), `/mnt/hmcl`
(241 GiB) and `/mnt/storage` (332 GiB) produce **no disk rows**, despite
91–94% usage, because all have more than the 50 GiB warning floor. No rows
appear on first enable unless current entry rules or diagnostics require them.

Dismissal applies to one resource episode for the current plugin session.
Warning dismissal is reset on critical entry; if that critical was not dismissed,
the warning reappears on downgrade. A critical dismissal suppresses the episode
until full recovery. Reloading the plugin clears dismissals; stale clicks cannot
acknowledge a new episode or escalation. There is no global dismiss.

## Sampling and diagnostics

`[system.monitor]` must be enabled. CPU polling must be positive and at most
six seconds. Disk liveness also needs a CPU, memory, network or GPU poll from
one to six seconds; a disk-only monitor has no usable aggregate timestamp.
The plugin never enables monitor groups or changes gauge settings itself.

Missing or stalled sources get a grace period of `max(30 seconds,
2 × effective poll interval + 2 seconds)`. During unavailability, existing
resource rows remain explicitly **last known**, episodes freeze, and CPU pending
time resets. After grace, a source diagnostic appears in the banner and can be
dismissed for that failure episode. Fresh data clears/rearms it. Invalid settings
produce nondismissible configuration diagnostics with a Settings action.

Native freshness is an **aggregate service-liveness guarantee**. Its shared
timestamp can advance while an individual `/proc` read fails and retains a cached
value. Disks have no individual timestamp either. Such per-metric cached failures
cannot be detected with these APIs; a false or late alert remains possible.

Open monitor validates its argv and executable and uses detached native launch.
Validation and native queue rejection errors remain in the banner. Native launch
only confirms queue acceptance, so later exec/program startup errors cannot be
reported here. Captured commands are avoided because their timeout would kill a
long-lived monitor terminal. Open settings uses Noctalia's plugin settings page.

## Development

`just test-resource-alert` runs policy, service and layer harnesses with plain
`lua` (5.5.1 verified), using the Lua/Luau shared subset and injected clocks.
Lua is a test dependency; no Luau CLI is needed. `just test` includes these cases
and the setup/health integration tests. `noctalia plugins lint
noctalia/plugins/resource-pressure-alert` checks the native manifest and settings.
Runtime probe/lock fixtures remain task evidence, outside the shipped plugin.
Do not install or enable worktree code on the live desktop as a test.
