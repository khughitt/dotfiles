# Minimal Bash Configuration Design

## Goal

Provide a useful native Bash environment for occasional interactive use without
copying the Zsh setup or adding plugins and dependencies.

## Files

- `bashrc` is the complete interactive configuration. Its first line is
  `# shellcheck shell=bash`, which identifies Bash without an executable-file
  shebang.
- `bash_profile` starts with the same shell directive and sources `~/.bashrc` for
  login shells. A preceding `# shellcheck source=bashrc` annotation lets
  ShellCheck resolve that source.
- `setup.sh` links both files into `$HOME` during the existing `shell` phase.
- `bin/dotfiles-check` adds both root files to its literal `bash_files` array so
  `bash -n` and ShellCheck cover them.
- `bin/dotfiles-health` adds explicit checks for both managed links.
- `tests/setup_and_health.zsh` adds both paths to its dry-run and link assertions.

## Behavior

`bashrc` returns immediately outside an interactive shell, then configures:

- a minimal environment: prepend `~/bin`, `~/.local/bin`, `~/.cargo/bin`, and
  `~/go/bin` to `PATH`, set `EDITOR=nvim`, and set `PAGER=less`;
- history with `ignoreboth:erasedups`, 10,000 in-memory entries, 100,000 on-disk
  entries, append-on-write, and synchronization between active shells after each
  command;
- automatic terminal-size updates;
- Up and Down arrow prefix history search through Readline for both CSI
  (`\e[A`/`\e[B`) and SS3 (`\eOA`/`\eOB`) terminal encodings;
- `Ctrl-S` as a usable terminal key by disabling software flow control when stdin
  is a terminal; and
- the compact native prompt `user@host:path$` (or `#` for root).

`erasedups` deduplicates the current in-memory history only. Concurrent shells can
still append duplicate lines to the history file and read them back, and the last
shell to exit enforces `HISTFILESIZE`. Keeping the in-memory list smaller limits the
per-entry duplicate scan without reducing the retained on-disk history.

The configuration targets Bash 3.2 and newer so it also works with the system Bash
shipped by macOS. It uses only Bash, Readline, and `stty`; missing plugins or shell
fragments cannot affect startup.

## Non-Goals

- No aliases, functions, Zsh fragments, plugin manager, Git-aware prompt, generated
  completion, environment manager, greeting, or local override files.
- No compatibility layer between Bash and Zsh configuration.
- No duplicate of the broader `zshenv` environment. Variables beyond `PATH`,
  `EDITOR`, and `PAGER` remain inherited or use platform defaults.

## Verification

- Check both startup files with `bash -n` and ShellCheck through the repository's
  explicit `bash_files` list.
- Extend the temporary-home setup test to verify both symlink targets and that a
  dry run creates neither.
- Start Bash with `--rcfile`, an isolated `HOME` and history file, and redirected
  job-control warnings; assert the environment, prompt, history options,
  `checkwinsize`, and all four Readline bindings.
- Run the repository's existing check and test commands.
