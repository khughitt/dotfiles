---
id: dots-4b9e1a
title: "SSH to europa by name sometimes resolves link-local IPv6, where the key is refused"
status: todo
priority: 2
size: s
complexity: low
process: direct
created: 2026-10-06T11:20:33Z
updated: 2026-10-06T11:20:33Z
depends: []
tags: []
agent: claude-code/claude-fable-5-1
---

Observed 2026-10-05 from titan: 'ssh europa' alternates between success and 'Permission denied (publickey)'. Verbose runs show the successes connect to the Tailscale IPv4 address and the refusals to a link-local fe80:: address on the wireless interface; the same host key answers both, and the refused attempts never appear in europa's sshd journal. 'ssh -4 europa' is reliable. Done: 'ssh europa' succeeds every time from titan without flags, by whichever of these fits: an ssh config Host entry pinning HostName to the tailnet name or AddressFamily inet, a fix to name resolution order (mDNS/LLMNR ahead of Tailscale DNS), or accepting the key on the link-local path; and the cause of the refusal on that path is written down.
