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

function _dropbox_ignore_flux_candidates {
  local root="${1:?Usage: _dropbox_ignore_flux_candidates ROOT [NAME ...]}"
  shift

  local -a names candidates kept
  if [[ $# -gt 0 ]]; then
    names=("$@")
  else
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
  done < <(fd -Luu -0 -t d --prune "$pattern" "$root")

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

function _dropbox_ignore_flux_is_ignored {
  local value
  value=$(attr -q -g com.dropbox.ignored "$1" 2>/dev/null) || return 1
  [[ "$value" == "1" ]]
}

function dropbox_ignore_flux {
  local root="/mnt/ssd/Dropbox"
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
    names=(node_modules .venv .worktrees .snakemake __pycache__ .pytest_cache .ruff_cache .mypy_cache .uv-cache)
  fi

  local -a candidates
  candidates=("${(@f)$(_dropbox_ignore_flux_candidates "$root" "${names[@]}")}")

  local checked=0 ignored=0 updated=0 failed=0 candidate
  for candidate in "${candidates[@]}"; do
    checked=$((checked + 1))

    if _dropbox_ignore_flux_is_ignored "$candidate"; then
      ignored=$((ignored + 1))
      [[ "$quiet" == "true" ]] || print -- "Already ignored: $candidate"
      continue
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
      print -u2 -- "Failed to ignore: $candidate"
    fi
  done

  if [[ "$quiet" != "true" ]]; then
    print -- "Checked: $checked, already ignored: $ignored, updated: $updated, failed: $failed"
  fi

  [[ "$failed" -eq 0 ]]
}
