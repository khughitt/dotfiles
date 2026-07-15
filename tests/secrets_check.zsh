#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-secrets.XXXXXX")
register_tmp_cleanup "$tmp"

set +e
output=$(GITLEAKS_BIN=definitely-missing "${repo_root}/bin/dotfiles-secrets-check" 2>&1)
exit_status=$?
set -e
(( exit_status == 127 )) || fail "missing Gitleaks should return 127, got $exit_status"
[[ "$output" == *'Gitleaks is required'* ]] || fail 'missing-tool error should be explicit'

cat > "${tmp}/gitleaks" <<'EOF'
#!/usr/bin/env zsh
printf '%s\n' "$@" > "$GITLEAKS_ARGS_FILE"
EOF
chmod +x "${tmp}/gitleaks"

GITLEAKS_ARGS_FILE="${tmp}/args" GITLEAKS_BIN="${tmp}/gitleaks" \
  "${repo_root}/bin/dotfiles-secrets-check"
args=$(<"${tmp}/args")
[[ "$args" == *$'git\n'* ]] || fail 'expected git scan mode'
[[ "$args" == *'--redact=100'* ]] || fail 'expected complete redaction'
[[ "$args" == *'--no-banner'* ]] || fail 'expected banner suppression'
[[ "$args" == *"${repo_root}"* ]] || fail 'expected repository root target'

print -- 'secret-check tests passed'
