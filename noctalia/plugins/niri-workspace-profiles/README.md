# Niri Workspace Profiles

Horizontal niri workspace strip showing per-profile icon, color, and label.

## Agent status dot

When `showAgentStatus` is enabled (default), each workspace cell shows a status
dot driven by `~/.local/state/ohai/agents.json`, written by `ohai-status` from
the `ohai` repo. See `~/d/software/ohai/README.md` for the writer build and the
Claude Code hook block. Toggle via the plugin's `showAgentStatus` setting;
identity (ring/icon/label) is unaffected.
