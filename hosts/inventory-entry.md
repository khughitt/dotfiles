### <stable name>

- **Scope:** system | user | boot | device
- **Observed:** <YYYY-MM-DD>
- **Installed path:** `/etc/...`, or none
- **Effective value:** <what the system reports now>
- **Inspect:** `<the command whose output is the effective value>`
- **Mechanism:** <what applies the value: systemd-sysctl from sysctl.d, pam_env, udev rule, unit drop-in, kernel command line, ...>
- **Winning source:** <the file or unit that supplies the effective value after precedence; name any lower-precedence source it overrides>
- **Purpose:** <what it is for, with the evidence: script comment, README section, commit, or unknown>
- **Confidence:** traced | partial | unresolved — <what is still unknown>
- **Package owner:** <package version>, or none
- **Tracked source:** `<repository path>`, or none
- **Installed matches source:** yes | no | n/a — <checked how, e.g. just drift 2026-09-13>
- **Persistence:** runtime-only | login-scoped | service-managed | boot-generated | unknown — <activation conditions>
- **Previous value:** <value with evidence and date>, or unknown
- **Vendor default:** <value with package version or kernel source file:line>, or unknown
- **Restore:** <numbered steps for the persistent input and for the effective state; prerequisites; expected readback; whether login, restart, or reboot is required>
- **Validation:** not validated | validated <YYYY-MM-DD> — <how>
