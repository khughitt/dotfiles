# Host CPU budget and agent scopes

Type: guide; document types 1. This guide describes the shell entry points
and host policy for managed agent sessions. See [setup](setup.md) for host
installation and [development](development.md) for verification.

With `HOSTKIT_AGENT_SESSIONS=1` in the host-local shell environment, the
interactive Claude, Codex, agy, pi, OpenCode and Crush commands enter the
host's configured user slice through `host-budget session`. Short aliases
use the same commands. Start a fresh shell after changing the host setting.
The enabled Codex route supplies `--no-daemon` so its local workers inherit
the scope. Existing sessions keep their current placement until relaunched.

Claude, Codex and agy started from a terminal also run behind `tint`, inside the
scope when routing is enabled, so task ids show in their project's colour. This
applies only where `tint` is on `PATH` and both standard input and output are a
terminal. A piped or redirected run, or a host without `tint`, starts the
harness directly.

Titan's source policy puts managed sessions and budgeted jobs in
`agents.slice` with a combined 24-CPU quota. The unit must be installed and
ready before switching policy or enabling shell routing. A launch failure
reports the missing prerequisite. The unset and zero settings use the
native launch route. Ordinary terminals remain in their existing scopes.

Each host policy defines three budget profiles. `default` gives short bursts
such as test gates half the host's CPUs. `long` gives a quarter share to runs
expected to take more than about an hour, since other agents keep working
beside them; request it with `host-budget run --profile long`. `quiet` hands
nearly the whole host to a run it was left idle for.

Work aliases live in the private shell configuration. Route the Claude work
alias through the interactive `claude` command while retaining its home
selection. The Codex work aliases already use the interactive command.
Run `just drift` here to compare the installed unit, budget policy and
opt-in block with the host's declared sources.

## Grants

`host-budget show` prints CPUs, load, audio applications, live grants and the
calculated job size; `host-budget run -- COMMAND...` supplies worker and library
limits and runs in the configured lower-weight accounting slice. A grant is fixed
at launch for the life of that command, so a later `show` assesses capacity for a
new launch and does not resize an active run. `env` only prints exports and
registers no grant, so prefer `run`, and inspect `run --dry-run -- ...` before a
new heavy workload. Read CPU capacity with `nproc --all`: ordinary `nproc` honours
`OMP_NUM_THREADS` and can report one on a multicore machine.

The policy file sets per-profile share, reserve and minimum, audio application name
prefixes with their share and reserve override, and the scope's slice, nice and I/O
settings. Required keys and unknown keys are validated; the host file and
`host-budget --help` give values and options. No-scope execution is explicit and
only valid inside the accounting slice.

Grants account host-wide busy CPUs and other jobs, then apply the caller's affinity
ceiling. The audio override applies even to quiet jobs. Thread variables plus CPU
weight prioritize responsiveness; only the slice quota is a hard limit. Missing
policy, accounting, storage or user-manager prerequisites fail with diagnostics;
there is no silent environment-only fallback, and a grant is not an idle-machine
promise. Nothing here authorizes a desktop, audio-engine or host modification.

To verify the managed scopes, read the user manager's effective weight and
quota and the slice cgroup's `cpu.max` and `cpu.stat`. The activation packet kept
in private records holds the ordered activation commands and the single rollback
command, which compares recorded post-state, restores the original files and reads
back the runtime limits.
