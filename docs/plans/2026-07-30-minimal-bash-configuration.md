# Minimal Bash Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add and activate a small native Bash configuration for occasional interactive use.

**Architecture:** Two root startup files own Bash behavior: `bashrc` configures interactive shells and `bash_profile` sources it for login shells. The existing setup, check, health, and Zsh test harnesses gain explicit entries because each currently uses hardcoded file lists.

**Tech Stack:** Bash 3.2+, GNU Readline, `stty`, Zsh 5.9 test harness, ShellCheck

## Global Constraints

- Support Bash 3.2 and newer, including the system Bash shipped by macOS.
- Use only Bash, Readline, and `stty`; add no plugin, generated completion, or dependency.
- Keep Bash standalone: do not source Zsh fragments or add a Bash/Zsh compatibility layer.
- Set only `PATH`, `EDITOR`, and `PAGER`; leave the broader `zshenv` environment inherited or at platform defaults.
- Preserve the unrelated working-tree edits in `cheatsheets/bitwig` and `opencode/opencode.json`.
- Fail explicitly when a managed startup file is missing; do not add fallback or legacy behavior.

## File Map

- Create `bashrc`: complete interactive Bash configuration.
- Create `bash_profile`: login-shell entry point that directly sources `~/.bashrc`.
- Modify `bin/dotfiles-check`: include both root files in Bash syntax and ShellCheck coverage.
- Modify `setup.sh`: link both root files during the existing `shell` phase.
- Modify `bin/dotfiles-health`: verify both managed home-directory links.
- Modify `tests/setup_and_health.zsh`: cover Bash behavior, dry-run non-mutation, installed links, and health integration.

---

### Task 1: Native Bash startup behavior

**Files:**
- Create: `bashrc`
- Create: `bash_profile`
- Modify: `bin/dotfiles-check:7-19`
- Test: `tests/setup_and_health.zsh:71-81,423-441`

**Interfaces:**
- Consumes: Bash startup variables `$-`, `HOME`, `PATH`, and `HISTFILE`; Readline's `bind`; terminal state from `stty`.
- Produces: root-level `bashrc` and `bash_profile` files that Task 2 installs as `~/.bashrc` and `~/.bash_profile`.

- [ ] **Step 1: Add the failing Bash behavior check**

Insert this function after `run_setup()` in `tests/setup_and_health.zsh`:

```zsh
test_bash_config_is_native_and_minimal() {
  local tmp
  tmp=$(make_tmpdir)
  register_tmp_cleanup "$tmp"
  mkdir -p "${tmp}/home"

  if ! env -i \
      HOME="${tmp}/home" \
      HISTFILE="${tmp}/home/.bash_history" \
      PATH=/usr/bin:/bin \
      TERM=xterm-256color \
      bash --noprofile --rcfile "${repo_root}/bashrc" -i -c '
        set -euo pipefail

        [[ "$PATH" == "$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/usr/bin:/bin" ]]
        [[ "$EDITOR" == nvim ]]
        [[ "$PAGER" == less ]]
        [[ "$HISTCONTROL" == ignoreboth:erasedups ]]
        [[ "$HISTSIZE" == 10000 ]]
        [[ "$HISTFILESIZE" == 100000 ]]
        [[ "$PROMPT_COMMAND" == "history -a; history -n" ]]
        shopt -q histappend
        shopt -q checkwinsize
        [[ "$PS1" == "$1" ]]

        backward=$(bind -q history-search-backward)
        forward=$(bind -q history-search-forward)
        [[ "$backward" == *"$2"* && "$backward" == *"$3"* ]]
        [[ "$forward" == *"$4"* && "$forward" == *"$5"* ]]
      ' bash '\u@\h:\w\$ ' '\eOA' '\e[A' '\eOB' '\e[B' \
      2>/dev/null; then
    fail "bashrc should configure the native interactive environment"
  fi

  if ! env -i HOME="${tmp}/home" PATH=/usr/bin:/bin \
      bash --noprofile --norc -c '
        source "$1"
        [[ "$PATH" == /usr/bin:/bin ]]
        [[ -z "${EDITOR+x}" ]]
        [[ -z "${PAGER+x}" ]]
      ' bash "${repo_root}/bashrc"; then
    fail "bashrc should leave non-interactive shells unchanged"
  fi

  rm -rf "$tmp"
}
```

Invoke it after `test_tmp_cleanup_is_centralized` at the bottom of the file:

```zsh
test_bash_config_is_native_and_minimal
```

- [ ] **Step 2: Run the behavior check to verify it fails**

Run:

```bash
zsh tests/setup_and_health.zsh
```

Expected: FAIL with `bashrc should configure the native interactive environment` because root-level `bashrc` does not exist.

- [ ] **Step 3: Create the minimal startup files**

Create `bashrc` with exactly:

```bash
# shellcheck shell=bash

[[ $- == *i* ]] || return

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
export EDITOR=nvim
export PAGER=less

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=100000
shopt -s histappend checkwinsize
PROMPT_COMMAND='history -a; history -n'

bind '"\e[A": history-search-backward'
bind '"\eOA": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOB": history-search-forward'

[[ -t 0 ]] && stty -ixon

PS1='\u@\h:\w\$ '
```

Create `bash_profile` with exactly:

```bash
# shellcheck shell=bash

# shellcheck source=bashrc
source "$HOME/.bashrc"
```

- [ ] **Step 4: Add both files to the explicit Bash check list**

Add the two root files at the start of `bash_files` in `bin/dotfiles-check`:

```bash
bash_files=(
    bashrc
    bash_profile
    setup.sh
```

- [ ] **Step 5: Verify behavior, syntax, and ShellCheck coverage**

Run:

```bash
zsh tests/setup_and_health.zsh
bin/dotfiles-check
```

Expected: both commands exit 0; the first prints `setup and health tests passed`, and the second prints `dotfiles checks passed` without SC2148 or SC1090.

- [ ] **Step 6: Commit the standalone configuration**

```bash
git add bashrc bash_profile bin/dotfiles-check tests/setup_and_health.zsh
git commit -m "feat: add minimal bash configuration"
```

---

### Task 2: Setup and health integration

**Files:**
- Modify: `setup.sh:355-360`
- Modify: `bin/dotfiles-health:126-130`
- Test: `tests/setup_and_health.zsh:81-120`

**Interfaces:**
- Consumes: Task 1's root-level `bashrc` and `bash_profile`; existing `ln_s <source> <destination>` setup helper and `check_link <destination> <expected>` health helper.
- Produces: managed `~/.bashrc` and `~/.bash_profile` links created by `setup.sh --only shell` and validated by `bin/dotfiles-health`.

- [ ] **Step 1: Add failing setup-link assertions**

In `test_setup_dry_run_link_only_does_not_write_home`, add:

```zsh
  [[ ! -e "${tmp}/home/.bashrc" ]] || fail "dry-run should not create ~/.bashrc"
  [[ ! -e "${tmp}/home/.bash_profile" ]] || fail "dry-run should not create ~/.bash_profile"
```

In `test_setup_link_only_creates_expected_links_without_external_clones`, add:

```zsh
  [[ -L "${tmp}/home/.bashrc" ]] || fail "expected ~/.bashrc symlink"
  [[ "$(readlink "${tmp}/home/.bashrc")" == "${repo_root}/bashrc" ]] || \
    fail "expected ~/.bashrc to point at repo bashrc"
  [[ -L "${tmp}/home/.bash_profile" ]] || fail "expected ~/.bash_profile symlink"
  [[ "$(readlink "${tmp}/home/.bash_profile")" == "${repo_root}/bash_profile" ]] || \
    fail "expected ~/.bash_profile to point at repo bash_profile"
```

- [ ] **Step 2: Run the setup test to verify it fails**

Run:

```bash
zsh tests/setup_and_health.zsh
```

Expected: FAIL with `expected ~/.bashrc symlink` because the shell setup phase does not yet link either Bash file.

- [ ] **Step 3: Install and check both managed links**

Add these lines at the start of `setup_shell_links()` in `setup.sh`:

```bash
    ln_s "${DOTS_HOME}/bashrc" "${HOME}/.bashrc"
    ln_s "${DOTS_HOME}/bash_profile" "${HOME}/.bash_profile"
```

Add these checks before the existing Zsh link checks in `bin/dotfiles-health`:

```bash
check_link "${HOME}/.bashrc" "${DOTS_HOME}/bashrc"
check_link "${HOME}/.bash_profile" "${DOTS_HOME}/bash_profile"
```

- [ ] **Step 4: Verify setup, health, and static checks**

Run:

```bash
zsh tests/setup_and_health.zsh
bin/dotfiles-check
bash setup.sh --dry-run --link-only --headless --only shell
```

Expected: all commands exit 0. The dry run includes planned `.bashrc` and `.bash_profile` links but creates neither file.

- [ ] **Step 5: Commit setup integration**

```bash
git add setup.sh bin/dotfiles-health tests/setup_and_health.zsh
git commit -m "feat: install bash configuration"
```

---

### Task 3: Activate and verify the managed configuration

**Files:**
- Replace with symlinks: `~/.bashrc`, `~/.bash_profile`
- Preserve as backups: `~/.bashrc.bak`, `~/.bash_profile.bak`

**Interfaces:**
- Consumes: Task 2's shell setup phase from the canonical `~/d/dotfiles` checkout.
- Produces: active Bash startup links in `$HOME`; no repository changes.

- [ ] **Step 1: Fail early if activation cannot preserve the current files**

Run from the canonical checkout:

```bash
cd ~/d/dotfiles
test -f ~/.bashrc
test ! -L ~/.bashrc
test -f ~/.bash_profile
test ! -L ~/.bash_profile
test ! -e ~/.bashrc.bak
test ! -e ~/.bash_profile.bak
```

Expected: all commands exit 0. If either backup already exists, stop rather than overwrite it.

- [ ] **Step 2: Activate the Bash configuration through the existing setup path**

```bash
bash setup.sh --link-only --headless --only shell
```

Expected: setup moves the two former regular Bash files to `.bak`, creates the two Bash symlinks, and skips the already-correct Zsh and `.shell` links.

- [ ] **Step 3: Verify the active link targets**

```bash
test "$(readlink ~/.bashrc)" = "$HOME/d/dotfiles/bashrc"
test "$(readlink ~/.bash_profile)" = "$HOME/d/dotfiles/bash_profile"
test -f ~/.bashrc.bak
test -f ~/.bash_profile.bak
```

Expected: all commands exit 0; the previous local files remain recoverable as backups.

- [ ] **Step 4: Run the full repository verification**

```bash
just verify
git status --short
```

Expected: `just verify` exits 0. Git status contains no changes from this feature and still preserves any pre-existing unrelated edits.
