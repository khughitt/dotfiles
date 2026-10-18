---
id: dots-1eb173
title: capture-host-setup's sudo -n -l checks also pass through a password-requiring wheel rule
status: todo
priority: 3
size: xs
complexity: low
process: direct
created: 2026-10-18T09:23:53Z
updated: 2026-10-18T09:23:54Z
depends: []
tags: []
source: dots-0e5d83
agent: claude-code/claude-opus-5-5
---

docs/capture-host-setup.md says to check each grant with 'sudo -n -l <command>' (chvt, fb0 tee, gpu-ctl). On a host where the account is also in wheel, sudo -l <command> succeeds for any command the wheel rule allows, so the check passes even when the passwordless rule is missing or narrower. Observed 2026-10-18: 'sudo -n -l /usr/local/sbin/gpu-ctl fan 44' and '... status' both report allowed, while 'sudo -n /usr/local/sbin/gpu-ctl fan 44' is refused with 'a password is required'. A check that isolates the grant: read the NOPASSWD entries in the full 'sudo -n -l' listing, or for gpu-ctl run a refused form such as 'sudo -n /usr/local/sbin/gpu-ctl status', which must fail without running anything.

## Notes

- 2026-10-18T09:23:53Z (main): concerns: dots-0e5d83 defect — its documented sudo -n -l check passes through the wheel rule, so it cannot show the passwordless grant
