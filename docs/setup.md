# Host setup

Type: guide; document types 1.

This guide covers installing the tracked configuration on an owner's host.
For a development worktree use [development](development.md); for system changes
use [hardening](fresh-install-hardening.md). Commands here can change live links,
packages and services. Run them deliberately from the approved main checkout.

## Prerequisites and preview

Clone the repository, inspect its manifests and run `./setup.sh --check`.
That mode reports unmet prerequisites with their fixes without installing them.
Ordinary setup reports preflight findings and continues through selected phases;
read its final failure summary rather than treating a partial setup as complete.

The installation assumes the owner's sibling checkout layout under `~/d`.
Shared commands come from ops, hostkit and tasks; the task registry must exist.
Graphical setup also needs the installed niri-material build, Noctalia v5 and
Prism's dependencies and sink requirements. `prism requirements` names missing
sink capabilities. Familiar and Prism dependencies are checked when their package
manifests exist. Each sibling owns its own installation instructions and source.
A public clone alone supplies configuration, not those installations or private
host state.

```sh
./setup.sh --check
./setup.sh --dry-run --link-only --headless
./setup.sh --dry-run --link-only --headless --only shell,systemd
```

`--dry-run` previews actions; inspect it before the corresponding live invocation.
`--link-only` skips both package installation and external clones.
`--no-packages` and `--no-external-clones` disable those separately.
`--headless` omits desktop setup; `--ubuntu` (`-u`) and `--macos` (`-m`) select
platform variants. This repository's primary target is Arch Linux.

## Phases and refresh

`--only` accepts comma-separated phase names:

```text
preflight external-clones shell graphical-config common-config systemd
kitty lookout app-config noctalia-plugins mime dropbox-ignore tmux packages
```

Without `--only`, setup runs its normal sequence. Link declarations in
[install.toml](../install.toml), [install-linux.toml](../install-linux.toml) and
[install-graphical.toml](../install-graphical.toml) are applied by `hostkit-links`;
[setup.sh](../setup.sh) and [lib](../lib/) define phase behavior.

```sh
./setup.sh --link-only --headless --only shell,systemd
```

The lookout phase requires its sibling checkout, Bun 1.4, Just and `attr`.
Ordinary setup runs that project's `just setup`, links its launcher and checks
`lookout --version`; link-only expects dependencies already installed. Missing
checkouts and failed installs fail the phase. `--only lookout` refreshes it alone.

For Noctalia plugins, run ordinary setup, start or reload Noctalia v5, then run
`./setup.sh --only noctalia-plugins`. This links Wali, Prism and Resource Pressure
Alert from their owning sibling repositories. If Noctalia is running, setup
enables them through IPC; otherwise it prints the enable commands. Resource
Pressure Alert's enable ID is khughitt/resource-pressure-alert. Wali also needs
`walictl` and its config link; Prism needs `prism`. See
[desktop themes](desktop-themes.md) for palette and context behavior.

## State and sync boundaries

Tracked configuration arrives with Git. Ignored files in the synced checkout can
still arrive through Dropbox; ignoring a file in Git does not make it host-local.
Generated theme output belongs under `XDG_STATE_HOME`, linked back into the
configuration. Other high-churn paths need Dropbox's ignored attribute or local
storage links: dependency environments, worktrees, build output, application
caches, Crush sessions and Familiar theme art. The declarations live in
[lib/dotfiles-setup-data.bash](../lib/dotfiles-setup-data.bash).

Whole-directory links such as niri, kitty, zathura and per-host Prism expose
application writes to the synced tree. Real config directories do not have that
property. `bin/dotfiles-health` reports unmanaged paths, misplaced generated files
and missing ignore marks; it does not fix them. Noctalia writes through output
symlinks; `noctalia msg templates-apply` renders themes after setup. Setup asks for
that render when output is empty.

`work-link` keeps worktree administration and declared environments on host
storage. Native Git-index rules and existing-index migration are covered by
[Git indexes in Dropbox](dropbox-git-index.md). Private shell fragments,
credentials and host-specific prerequisites are reproduced separately, never
copied into tracked docs.

## Services and Git policy

`./setup.sh --link-only --headless --only systemd --enable-user-timers` enables
the selected maintenance timers, including Dropbox flux marking and the kernel
gate nudge. It does **not** enable every linked unit. Mindful owns its runtime
installer, six launcher links and rendered web/backup units; dotfiles setup does
not recreate donor links. Use its [runtime rollout guide](https://github.com/mindful-dev/v6/blob/main/docs/guide/local-deployment.md)
and preview the reviewed candidate's installer before applying it. Installing
files, starting web and enabling backup are separate operations.
Git-index retention and convergence timers are also linked but never enabled by
setup. Convergence requires its separately approved rollout after retention;
health reports prepared state and rejects enabled convergence without working
retention. Health does not claim that indexes converged.

The app-config phase generates the host-local `~/.gitconfig-synced` include.
It matches the physical synced root and registered linked worktrees, disabling
implicit ref packing with `gc.packRefs=false` and
`maintenance.pack-refs.enabled=false`. Other maintenance stays enabled. Loose
refs cost disk/enumeration work; explicit packing commands bypass these defaults.
Health checks the generated policy without repairing it. A root move requires
regeneration from the approved main checkout:

```sh
python3 lib/git-packing-policy.py write "$HOME" "$(pwd -P)"
python3 lib/git-packing-policy.py check "$HOME" "$(pwd -P)"
```

The helper refuses unmarked files, symlinks and directories at its destination;
inspect existing user data before resolving a refusal. Local/worktree overrides
remain untouched. Another HOME or GIT_CONFIG_GLOBAL can bypass the include even
when health passes. Retention detects observed packed state but retains a final
race window; consult its owning project's synced Git state runbook for recovery.
This is a host operation, including when only the source policy changed.
Capture sudoers installation is separate: see [capture setup](capture-host-setup.md).
Agent session routing is separate: see [host CPU budget](host-budget.md).

## Verification and recovery

Run `bin/dotfiles-layout-check` and `bin/dotfiles-health` after the authorized
installation. `--skip-systemd` on health keeps the Mindful installation/launcher probe but
omits its runtime inspector and other systemd queries; it is not full host
verification. Installed Mindful state delegates to the exact home launcher using
`mindful runtime check --json` when service checks are enabled. Resolve each
reported prerequisite or phase failure before claiming
setup complete. Inspect an existing file before replacing it with a link; retain
needed local contents outside the tracked tree. Restore the prior link/config
and service state if the selected refresh fails. Do not run this installer from
a development worktree or point installed launchers at one.
