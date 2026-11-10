# Host CPU budget and agent scopes

Type: guide; document types 1. This guide describes the shell entry points
and host policy for managed agent sessions.

With `HOSTKIT_AGENT_SESSIONS=1` in the host-local shell environment, the
interactive Claude, Codex, agy, pi, OpenCode and Crush commands enter the
host's configured user slice through `host-budget session`. Short aliases
use the same commands. Start a fresh shell after changing the host setting.
The enabled Codex route supplies `--no-daemon` so its local workers inherit
the scope. Existing sessions keep their current placement until relaunched.

Titan's source policy puts managed sessions and budgeted jobs in
`agents.slice` with a combined 24-CPU quota. The unit must be installed and
ready before switching policy or enabling shell routing. A launch failure
reports the missing prerequisite. The unset and zero settings use the
native launch route. Ordinary terminals remain in their existing scopes.

Work aliases live in the private shell configuration. Route the Claude work
alias through the interactive `claude` command while retaining its home
selection. The Codex work aliases already use the interactive command.
Run `just drift` here to compare the installed unit, budget policy and
opt-in block with the host's declared sources.
