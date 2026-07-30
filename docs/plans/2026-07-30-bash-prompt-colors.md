# Bash Prompt Colors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shorten the Bash prompt and distinguish its path and prompt character with standard terminal colors.

**Architecture:** Keep the existing single `PS1` assignment. Update its behavior assertion first, then replace the username/hostname prompt with a cyan working directory, yellow dynamic prompt character, ANSI reset, and trailing space.

**Tech Stack:** Bash 3.2+, standard 16-color ANSI escapes, GNU Readline prompt guards, Zsh test harness

## Global Constraints

- Keep the prompt compatible with Bash 3.2 and newer.
- Use only standard 16-color ANSI codes; add no prompt framework or dependency.
- Remove username and hostname from the prompt.
- Use Readline non-printing guards around every escape sequence.
- Reset terminal attributes before command input.
- Preserve the unrelated working-tree edits in `cheatsheets/bitwig` and `opencode/opencode.json`.

---

### Task 1: Short colored Bash prompt

**Files:**
- Modify: `tests/setup_and_health.zsh:105`
- Modify: `bashrc:22`

**Interfaces:**
- Consumes: Bash prompt escapes `\w` and `\$`, ANSI SGR colors 36 and 33, and Readline guards `\[` and `\]`.
- Produces: `PS1='\[\e[36m\]\w\[\e[33m\]\$\[\e[0m\] '`.

- [ ] **Step 1: Change the behavior check to expect the approved prompt**

In `tests/setup_and_health.zsh`, replace the existing expected prompt argument:

```zsh
      ' bash '\[\e[36m\]\w\[\e[33m\]\$\[\e[0m\] ' '\eOA' '\e[A' '\eOB' '\e[B' \
```

- [ ] **Step 2: Run the behavior check to verify it fails**

Run:

```bash
zsh tests/setup_and_health.zsh
```

Expected: FAIL with `bashrc should configure the native interactive environment` because `bashrc` still includes `\u@\h` and has no colors.

- [ ] **Step 3: Replace the prompt assignment**

In `bashrc`, replace the existing `PS1` assignment with:

```bash
PS1='\[\e[36m\]\w\[\e[33m\]\$\[\e[0m\] '
```

- [ ] **Step 4: Verify the focused behavior and repository**

Run:

```bash
zsh tests/setup_and_health.zsh
just verify
```

Expected: both commands exit 0. The focused test prints `setup and health tests passed`; full verification includes successful Bash syntax, ShellCheck, tests, and health checks.

- [ ] **Step 5: Confirm the active link picks up the change**

Run:

```bash
test "$(readlink ~/.bashrc)" = "$(pwd -P)/bashrc"
```

Expected: exit 0; no activation step is needed because `~/.bashrc` already links to the tracked file.

- [ ] **Step 6: Commit**

```bash
git add bashrc tests/setup_and_health.zsh
git commit -m "feat: color bash prompt"
```
