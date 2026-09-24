# Find high-churn Dropbox directories whose ignored xattr should be set.
function _dropbox_ignore_flux_name_pattern {
  local -a escaped
  local name escaped_name

  for name in "$@"; do
    case "$name" in
      *[!A-Za-z0-9._-]*)
        print -u2 -- "Unsupported directory name: $name"
        return 2
        ;;
    esac

    escaped_name="${name//./\\.}"
    escaped+=("$escaped_name")
  done

  printf '^(%s)$\n' "${(j:|:)escaped}"
}

# Build output names are generic (a repository can commit its dist), so a
# match is marked only when git ignores it and tracks nothing under it.
typeset -ga DROPBOX_IGNORE_FLUX_GUARDED_NAMES=(dist build .svelte-kit)

function _dropbox_ignore_flux_candidates {
  local -a excludes
  while [[ "${1:-}" == --exclude ]]; do
    excludes+=(--exclude "${2:?Missing value for --exclude}")
    shift 2
  done
  local root="${1:?Usage: _dropbox_ignore_flux_candidates [--exclude NAME ...] ROOT [NAME ...]}"
  shift

  local -a names candidates kept
  if [[ $# -gt 0 ]]; then
    names=("$@")
  else
    # Not the bare name worktrees: <repo>/.git/worktrees is marked only by the
    # host that owns its worktrees (work-link). Marking a synced copy here
    # deletes the owner's admin directories through Dropbox.
    names=(node_modules .venv .worktrees .snakemake __pycache__ .pytest_cache .ruff_cache .mypy_cache .uv-cache)
  fi

  local pattern
  pattern=$(_dropbox_ignore_flux_name_pattern "${names[@]}") || return

  local -A name_set
  local name candidate existing skip
  for name in "${names[@]}"; do
    name_set[$name]=1
  done

  while IFS= read -r -d $'\0' candidate; do
    candidate="${candidate%/}"
    [[ -n "${name_set[${candidate:t}]-}" ]] && candidates+=("$candidate")
  done < <(fd -uu -0 -t d --prune "${excludes[@]}" "$pattern" "$root")

  # Sort by byte value, not locale collation. UTF-8 locales ignore leading
  # punctuation when collating, so under en_US.UTF-8 "$root/.venv" collates as
  # "venv" and lands after "$root/src/__pycache__" -- making this function's
  # output depend on the caller's environment, so an interactive run and the
  # systemd unit can disagree. The prune loop below also assumes an ancestor
  # sorts before its descendants, which only byte order guarantees.
  # zsh restores this on return; it is set after the fd call deliberately.
  local LC_COLLATE=C
  for candidate in ${(o)candidates}; do
    skip=false
    for existing in "${kept[@]}"; do
      if [[ "$candidate" == "$existing" || "$candidate" == "$existing"/* ]]; then
        skip=true
        break
      fi
    done

    if [[ "$skip" == "false" ]]; then
      kept+=("$candidate")
    fi
  done

  printf '%s\n' "${kept[@]}"
}

# Why a guarded candidate must stay synced, or nothing when git tracks nothing
# under it and ignores it (tracked content first: check-ignore already calls a
# directory with tracked files unignored, which would hide the reason). Anything git cannot answer for stays synced.
function _dropbox_ignore_flux_guard_refusal {
  local dir="${1:h}" name="${1:t}"
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -- "not in a git work tree"
    return
  }
  [[ -z "$(git -C "$dir" ls-files -- "$name")" ]] || {
    print -- "tracked files inside"
    return
  }
  git -C "$dir" check-ignore -q -- "$name" || print -- "not ignored by git"
}

function _dropbox_ignore_flux_is_ignored {
  local value
  value=$(attr -q -g com.dropbox.ignored "$1" 2>/dev/null) || return 1
  [[ "$value" == "1" ]]
}

function dropbox_ignore_flux {
  local root
  root="$(readlink -f "${HOME}/d")"
  local quiet=false
  local dry_run=false
  local -a names

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root)
        shift
        root="${1:?Missing value for --root}"
        ;;
      --quiet)
        quiet=true
        ;;
      --dry-run)
        dry_run=true
        ;;
      --help)
        cat <<'EOF'
Usage: dropbox_ignore_flux [--root DIR] [--quiet] [--dry-run] [NAME ...]

Set com.dropbox.ignored=1 on top-level high-churn Dropbox directories.
Default names: node_modules .venv .worktrees .snakemake __pycache__
               .pytest_cache .ruff_cache .mypy_cache .uv-cache
               dist build .svelte-kit
dist, build and .svelte-kit are marked only when git ignores the directory
and tracks nothing under it; any other match is reported and left synced.
(<repo>/.git/worktrees is left to work-link, which marks it only on the host
that owns its worktrees.)
EOF
        return 0
        ;;
      --)
        shift
        names+=("$@")
        break
        ;;
      -*)
        print -u2 -- "Unknown option: $1"
        return 2
        ;;
      *)
        names+=("$1")
        ;;
    esac
    shift
  done

  if [[ ! -d "$root" ]]; then
    print -u2 -- "Dropbox root not found: $root"
    return 1
  fi
  command -v fd >/dev/null || {
    print -u2 -- "Missing required command: fd"
    return 127
  }
  command -v attr >/dev/null || {
    print -u2 -- "Missing required command: attr"
    return 127
  }

  if [[ ${#names[@]} -eq 0 ]]; then
    names=(node_modules .venv .worktrees .snakemake __pycache__ .pytest_cache .ruff_cache .mypy_cache .uv-cache
      "${DROPBOX_IGNORE_FLUX_GUARDED_NAMES[@]}")
  fi

  # Two scans, because a scan stops at every match: a guarded name that fails
  # its guard (a tracked build/ of sources) must not hide a node_modules below
  # it. The guarded scan skips the plain names' directories, which are marked
  # whole.
  local -a plain guarded excludes candidates
  local name
  for name in "${names[@]}"; do
    if (( ${DROPBOX_IGNORE_FLUX_GUARDED_NAMES[(Ie)$name]} )); then
      guarded+=("$name")
    else
      plain+=("$name")
      excludes+=(--exclude "$name")
    fi
  done
  (( ${#plain} )) && candidates+=("${(@f)$(_dropbox_ignore_flux_candidates "$root" "${plain[@]}")}")
  (( ${#guarded} )) && candidates+=("${(@f)$(_dropbox_ignore_flux_candidates "${excludes[@]}" "$root" "${guarded[@]}")}")
  candidates=("${(@)candidates:#}")

  local checked=0 ignored=0 updated=0 skipped=0 failed=0 candidate refusal
  for candidate in "${candidates[@]}"; do
    checked=$((checked + 1))

    if _dropbox_ignore_flux_is_ignored "$candidate"; then
      ignored=$((ignored + 1))
      [[ "$quiet" == "true" ]] || print -- "Already ignored: $candidate"
      continue
    fi

    if (( ${DROPBOX_IGNORE_FLUX_GUARDED_NAMES[(Ie)${candidate:t}]} )); then
      refusal=$(_dropbox_ignore_flux_guard_refusal "$candidate")
      if [[ -n "$refusal" ]]; then
        skipped=$((skipped + 1))
        [[ "$quiet" == "true" ]] || print -- "Skipped ($refusal): $candidate"
        continue
      fi
    fi

    if [[ "$dry_run" == "true" ]]; then
      updated=$((updated + 1))
      print -- "Would ignore: $candidate"
      continue
    fi

    if attr -s com.dropbox.ignored -V 1 "$candidate" >/dev/null; then
      updated=$((updated + 1))
      [[ "$quiet" == "true" ]] || print -- "Ignored: $candidate"
    else
      failed=$((failed + 1))
      print -u2 -- "Failed to ignore: $candidate ($(stat -c 'owner=%U:%G, uid=%u, gid=%g, mode=%a' -- "$candidate"))"
    fi
  done

  if [[ "$quiet" != "true" ]]; then
    print -- "Checked: $checked, already ignored: $ignored, updated: $updated, skipped: $skipped, failed: $failed"
  fi

  [[ "$failed" -eq 0 ]]
}
