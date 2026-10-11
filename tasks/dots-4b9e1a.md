---
id: dots-4b9e1a
title: "SSH to europa by name sometimes resolves link-local IPv6, where the key is refused"
status: done
priority: 2
size: s
complexity: low
process: direct
owner: dots-4b9e1a
created: 2026-10-06T11:20:33Z
updated: 2026-10-11T11:40:09Z
started: 2026-10-11T11:28:28Z
completed: 2026-10-11T11:40:09Z
depends: []
tags: []
agent: claude-code/claude-fable-5-1
---

Observed 2026-10-05 from titan: 'ssh europa' alternates between success and 'Permission denied (publickey)'. Verbose runs show the successes connect to the Tailscale IPv4 address and the refusals to a link-local fe80:: address on the wireless interface; the same host key answers both, and the refused attempts never appear in europa's sshd journal. 'ssh -4 europa' is reliable. Done: 'ssh europa' succeeds every time from titan without flags, by whichever of these fits: an ssh config Host entry pinning HostName to the tailnet name or AddressFamily inet, a fix to name resolution order (mDNS/LLMNR ahead of Tailscale DNS), or accepting the key on the link-local path; and the cause of the refusal on that path is written down.

## Notes

- 2026-10-11T11:28:28Z (main): started
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:28:54Z (main): root cause: europa's sshd journal on 2026-10-05 and 2026-10-06 records fe80 client connections rejected as not listed in AllowUsers; 10-tailnet.conf intentionally admits only tailnet IPv4/IPv6 sources. Current titan DNS returns the tailnet IPv4 address, so the earlier resolver race is not present today. Recommend HostName europa.tailc3d156.ts.net instead of IPv4-only or weakening AllowUsers; live client config is outside the repo and will be applied only after approval.
- 2026-10-11T11:29:38Z (dots-4b9e1a): resumed
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:33:01Z (dots-4b9e1a): candidate: add HostName europa.tailc3d156.ts.net and HostKeyAlias europa to the existing ~/.ssh/config Host europa stanza. The alias preserves the trusted short-name key (hostname-only candidate failed strict checking). Three fresh batch logins passed with strict host-key checking and tailnet source/destination; effective SSH configuration for seven other aliases matches live, including system settings. Prepared original, candidate, and two-line patch under .superpowers/evidence/dots-4b9e1a; live config unchanged. Only documentation is changed in the repository; full suite already passed this session for the same production tree, so no repeat for prose.
- 2026-10-11T11:34:53Z (dots-4b9e1a): review: impl round 1 — verdict: accept; findings: none; reviewer: codex
- 2026-10-11T11:34:53Z (dots-4b9e1a): review disposition: remote historical journal and three strict candidate logins are controller-observed evidence; existing full-suite evidence covers unchanged production tree. Reviewer independently checked original/candidate effective configuration and policy; just check, tasks check, and git diff --check passed. No deferred minor findings.
- 2026-10-11T11:34:53Z (dots-4b9e1a): parked (waiting on user, approval): After user approves the two-line preview in .worktrees/dots-4b9e1a/.superpowers/evidence/dots-4b9e1a/ssh-config.patch, agent compares live ~/.ssh/config to the saved original, applies only HostName and HostKeyAlias in Host europa, verifies fresh plain-alias SSH logins, then closes and locally integrates the task. Live config is unchanged; no host pointers were repointed.
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:37:22Z (dots-4b9e1a): resumed
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:37:22Z (dots-4b9e1a): User approved the live change. Applied only HostName and HostKeyAlias in ~/.ssh/config after byte-comparing it to the reviewed original; saved ~/.ssh/config.before-dots-4b9e1a for restoration. No pointer targets the worktree. User also requested reusable documentation without actual tailnet details; generalize the existing install-guide example.
- 2026-10-11T11:38:46Z (dots-4b9e1a): live verification: ssh -G europa selects the full tailnet name and trusted host-key alias; three fresh logins through the normal live alias passed with strict checking and tailnet endpoints, without -F, -4, or hostname overrides. Reusable client setup and daemon-check examples now use placeholders; actual tailnet names and host addresses are absent from the guide's SSH section.
- 2026-10-11T11:39:51Z (dots-4b9e1a): review: impl round 2 — verdict: accept; findings: none; reviewer: codex
- 2026-10-11T11:39:52Z (dots-4b9e1a): review disposition: live application, original backup, historical journal, and fresh logins are controller-observed and verified; reviewer independently accepted the generic documentation and quoted daemon-check placeholders. No deferred minor findings.
- 2026-10-11T11:40:09Z (dots-4b9e1a): done
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
- 2026-10-11T11:40:09Z (dots-4b9e1a): Applied the approved live Europa HostName and HostKeyAlias settings; three fresh strict logins through the normal alias succeeded on the tailnet without address-family or config overrides. Confirmed the historical fe80 refusals were intentional AllowUsers denials. Added reusable SSH client setup and verification instructions with placeholders only to docs/fresh-install-hardening.md; just check passed and final review accepted with no findings. Previous config retained at ~/.ssh/config.before-dots-4b9e1a.
  provenance: {"harness_session":"codex:01a12aa6-8bbc-7a72-a346-1ff761573875","harness_session_source":"CODEX_THREAD_ID"}
