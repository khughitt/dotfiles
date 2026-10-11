---
id: dots-4b9e1a
title: "SSH to europa by name sometimes resolves link-local IPv6, where the key is refused"
status: doing
priority: 2
size: s
complexity: low
process: direct
owner: main
created: 2026-10-06T11:20:33Z
updated: 2026-10-11T11:28:54Z
started: 2026-10-11T11:28:28Z
depends: []
tags: []
agent: claude-code/claude-fable-5-1
---

Observed 2026-10-05 from titan: 'ssh europa' alternates between success and 'Permission denied (publickey)'. Verbose runs show the successes connect to the Tailscale IPv4 address and the refusals to a link-local fe80:: address on the wireless interface; the same host key answers both, and the refused attempts never appear in europa's sshd journal. 'ssh -4 europa' is reliable. Done: 'ssh europa' succeeds every time from titan without flags, by whichever of these fits: an ssh config Host entry pinning HostName to the tailnet name or AddressFamily inet, a fix to name resolution order (mDNS/LLMNR ahead of Tailscale DNS), or accepting the key on the link-local path; and the cause of the refusal on that path is written down.

## Notes

- 2026-10-11T11:28:28Z (main): started
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:28:54Z (main): root cause: europa's sshd journal on 2026-10-05 and 2026-10-06 records fe80 client connections rejected as not listed in AllowUsers; 10-tailnet.conf intentionally admits only tailnet IPv4/IPv6 sources. Current titan DNS returns the tailnet IPv4 address, so the earlier resolver race is not present today. Recommend HostName europa.tailc3d156.ts.net instead of IPv4-only or weakening AllowUsers; live client config is outside the repo and will be applied only after approval.
