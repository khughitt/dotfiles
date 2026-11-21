#!/usr/bin/env bash
# shellcheck disable=SC2034

# Noctalia's generated theme output, as "<path in the tree>:<path under XDG_STATE_HOME>".
# Noctalia writes to fixed paths under ~/.config, and ~/.config/{niri,kitty,zathura}
# are whole-directory symlinks into this tree, which both machines share through Dropbox.
# Routed through per-machine state so one machine's colours never reach the other;
# setup.sh makes the links and dotfiles-health verifies them.
DOTFILES_NOCTALIA_GENERATED=(
    "niri/noctalia.kdl:niri/noctalia.kdl"
    "kitty/themes/noctalia.conf:kitty/noctalia.conf"
    "zathura/noctaliarc:zathura/noctaliarc"
)

# Per-machine state that applications write into this tree through the same
# whole-directory ~/.config symlinks, and that must not cross to the other
# machine: runtime caches, sockets, session databases, installed art. Each is
# marked com.dropbox.ignored, which keeps it on the machine that wrote it.
# A trailing "/" names a directory, which setup.sh creates before marking so the
# mark is in place before the application's first write; a file is marked only
# once it exists. setup.sh marks them; dotfiles-health fails on one left unmarked.
DOTFILES_DROPBOX_IGNORED=(
    "crush/.crush/"
    "familiar/identities.yaml"
    "familiar/themes/"
    "fcitx/cached_layout"
    "fcitx/clipboard/"
    "fcitx/data/"
    "fcitx/dbus/"
    "fcitx/libpinyin/"
    "fcitx/log/"
)

# The Dropbox client creates ~/.dropbox on its first configuration. A host
# without it is not syncing this tree, so the com.dropbox.ignored marks would
# protect nothing and setup and health both skip them. The test is the client's
# own state, not --headless: a headless host can still run Dropbox.
dotfiles_dropbox_present() {
    [[ -d "${HOME}/.dropbox" ]]
}

dotfiles_project_root() {
    local prefix="$1" repo_dir json_out root=""
    case "$prefix" in
        hostkit) repo_dir="hostkit" ;;
        wali) repo_dir="wali" ;;
        prism) repo_dir="prism" ;;
        pressure) repo_dir="noctalia-resource-alert" ;;
        ops) repo_dir="ops" ;;
        fam) repo_dir="familiar" ;;
        look) repo_dir="lookout" ;;
        *) repo_dir="$prefix" ;;
    esac
    if command -v tasks >/dev/null 2>&1; then
        if ! command -v python3 >/dev/null 2>&1; then
            echo "dotfiles_project_root: python3 is required when tasks is installed" >&2
            return 1
        fi
        if ! json_out="$(tasks projects --paths --json)"; then
            echo "dotfiles_project_root: tasks projects --paths --json failed for prefix '${prefix}'" >&2
            return 1
        fi
        if ! root="$(printf '%s' "$json_out" | python3 -c '
import json, sys
prefix = sys.argv[1]
try:
    payload = json.load(sys.stdin)
except Exception as exc:
    sys.stderr.write(f"dotfiles_project_root: invalid JSON from tasks projects --paths --json: {exc}\n")
    sys.exit(2)
if not isinstance(payload, dict) or not isinstance(payload.get("projects"), list):
    sys.stderr.write("dotfiles_project_root: expected {\"projects\": [...]} from tasks projects --paths --json\n")
    sys.exit(2)
for row in payload["projects"]:
    if not isinstance(row, dict):
        sys.stderr.write("dotfiles_project_root: invalid project entry in tasks projects --paths --json\n")
        sys.exit(2)
    if row.get("prefix") == prefix:
        root = row.get("root")
        if not isinstance(root, str) or not root:
            sys.stderr.write(f"dotfiles_project_root: invalid root for prefix {prefix!r}\n")
            sys.exit(2)
        print(root)
        break
' "$prefix")"; then
            return 1
        fi
    fi
    if [[ -n "$root" ]]; then
        printf '%s\n' "$root"
    else
        printf '%s/%s\n' "${WORKTREE_SCAN_ROOT:-${HOME}/d}" "$repo_dir"
    fi
}
