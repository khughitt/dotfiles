# Minimal Bash Configuration Design

## Goal

Provide a useful native Bash environment for occasional interactive use without
copying the Zsh setup or adding plugins and dependencies.

## Files

- `bashrc` is the complete interactive configuration.
- `bash_profile` sources `~/.bashrc` for login shells.
- `setup.sh` links both files into `$HOME` during the existing `shell` phase.
- Existing setup and health checks cover the two managed links.

## Behavior

`bashrc` returns immediately outside an interactive shell, then configures:

- history with `ignoreboth:erasedups`, 100,000 in-memory and on-disk entries,
  append-on-write, and synchronization between active shells after each command;
- automatic terminal-size updates;
- Up and Down arrow prefix history search through Readline;
- `Ctrl-S` as a usable terminal key by disabling software flow control when stdin
  is a terminal; and
- the compact native prompt `user@host:path$` (or `#` for root).

The configuration targets Bash 3.2 and newer so it also works with the system Bash
shipped by macOS. It uses only Bash, Readline, and `stty`; missing plugins or shell
fragments cannot affect startup.

## Non-Goals

- No aliases, functions, Zsh fragments, plugin manager, Git-aware prompt, generated
  completion, environment manager, greeting, or local override files.
- No compatibility layer between Bash and Zsh configuration.

## Verification

- Check both startup files with `bash -n` and ShellCheck.
- Extend the temporary-home setup test to verify both symlink targets.
- Start an isolated interactive Bash and assert the prompt, history options,
  `checkwinsize`, and Readline bindings.
- Run the repository's existing check and test commands.
