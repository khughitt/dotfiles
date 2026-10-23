What this change does: Revision `eef3e49aa90f1b976d82b4e57b2007d048015aab` adds the named `index-health` hook for both commit events. It selects the PATH executable first, then the installed fallback, preserves the selected guard’s verdict without retrying, and warns while allowing commits when neither executable is available.

Verdict: **accept**. Findings: **Critical 0, Important 0, Minor 0**. Reviewer: **codex/gpt-6.1-sol**, verified with a fresh `relay model` command.

I checked the frozen configuration and tests against the accepted spec and Task 4 Steps 1–3. The existing identity hook is unchanged. The tests use explicit subprocess environments, fixture-owned HOME and global configuration, and verify repository routing before subsequent fixture writes. They cover both events, PATH precedence, installed fallback, statuses 0/1/2, and missing-installation behavior.

Independent probes on Git 2.56.0 confirmed:

- Including the maintained configuration twice still invokes each named hook exactly once for each event. Guard statuses 0, 1 and 2 propagate unchanged through `git hook run`.
- A real non-fast-forward merge invokes the guard once.
- Real commits receiving guard status 1 or 2 refuse without advancing HEAD or retrying.
- The named override skips index-health while the identity hook still runs once.

All probes used isolated configuration and disposable repositories. Their temporary files were removed. No repository files, task records, live configuration or hooks were changed; nothing was pushed, and no processes remain.

Not checked: I did not repeat the reported full suite or perform live activation. Source acceptance does not establish deployed coverage; activation remains separately gated.
