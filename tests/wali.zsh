#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
source "${0:A:h}/tmp_cleanup.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-wali.XXXXXX")
register_tmp_cleanup "$tmp"
mkdir -p "${tmp}/bin"

cat > "${tmp}/bin/identify" <<'EOF'
#!/usr/bin/env zsh
print -- 'fixture JPEG 2100x1200'
EOF

cat > "${tmp}/bin/magick" <<'EOF'
#!/usr/bin/env zsh
printf '%s\0' "$@" > "$MAGICK_ARGS_FILE"
EOF

cat > "${tmp}/bin/jpegoptim" <<'EOF'
#!/usr/bin/env zsh
exit 0
EOF

cat > "${tmp}/bin/oxipng" <<'EOF'
#!/usr/bin/env zsh
exit 0
EOF

chmod +x "${tmp}/bin/identify" "${tmp}/bin/magick" \
  "${tmp}/bin/jpegoptim" "${tmp}/bin/oxipng"

export PATH="${tmp}/bin:${PATH}"
export MAGICK_ARGS_FILE="${tmp}/magick.args"
export WAYLAND_DISPLAY=
export WALI_FORMAT=jpg

source "${repo_root}/shell/wali"

cd "$tmp"
malicious='$(touch PWNED).jpg'
source_path="${tmp}/${malicious}"
output_path="${tmp}/output file.jpg"
touch -- "$source_path"

_wali_process_image "$source_path" "$output_path" landscape
[[ ! -e "${tmp}/PWNED" ]] || fail 'wallpaper filename executed shell syntax'

typeset -a args
while IFS= read -r -d $'\0' arg; do
  args+=("$arg")
done < "$MAGICK_ARGS_FILE"

[[ "${args[1]}" == "$source_path" ]] || fail 'source path lost its argument boundary'
[[ "${args[-1]}" == "$output_path" ]] || fail 'output path lost its argument boundary'

rm -f "$MAGICK_ARGS_FILE"
set +e
_wali_process_image "$source_path" "$output_path" unsupported >/dev/null 2>&1
exit_status=$?
set -e
(( exit_status != 0 )) || fail 'unknown processing mode should fail'
[[ ! -e "$MAGICK_ARGS_FILE" ]] || fail 'unknown mode should not invoke magick'

set +e
_wali_process_image "$source_path" "$output_path" rotate 45 >/dev/null 2>&1
exit_status=$?
set -e
(( exit_status != 0 )) || fail 'unsupported rotation should fail'
[[ ! -e "$MAGICK_ARGS_FILE" ]] || fail 'invalid rotation should not invoke magick'

mkdir -p "${tmp}/home" "${tmp}/current" "${tmp}/archive/2024/05"
export NOCTALIA_LOG="${tmp}/noctalia.log"
export NOCTALIA_WALLPAPER="${tmp}/current/PXL_20240520_023703962.jpg"
export BACKGROUND_IMG_DIR="${tmp}/archive"
touch "$NOCTALIA_WALLPAPER" \
  "${BACKGROUND_IMG_DIR}/2024/05/PXL_20240520_023703962.jpg"

cat > "${tmp}/bin/noctalia" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$NOCTALIA_LOG"
if [[ "$*" == "msg wallpaper-get" ]]; then
  print -r -- "$NOCTALIA_WALLPAPER"
fi
EOF
chmod +x "${tmp}/bin/noctalia"

cat > "${tmp}/bin/walictl" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$NOCTALIA_LOG"
if [[ "$1" == current ]]; then
  printf '{"ok": true, "id": "PXL_20240520_023703962", "path": "%s", "source_path": "%s"}\n' \
    "$NOCTALIA_WALLPAPER" "$BACKGROUND_IMG_DIR/2024/05/PXL_20240520_023703962.jpg"
fi
EOF
chmod +x "${tmp}/bin/walictl"

HOME="${tmp}/home" WAYLAND_DISPLAY=wayland-1 \
  PATH="${tmp}/bin:$PATH" zsh -f -c '
    set -e
    source "$1/shell/wali"
    [[ "$WALI_BACKEND" == noctalia ]]
    [[ "$(alias wali)" == *"walictl random"* ]]
    ! typeset -f wali_print >/dev/null || exit 1
    ! alias wali_edit_current >/dev/null 2>&1 || exit 1
    ! typeset -f wali_save >/dev/null || exit 1
    ! typeset -f wali_edit_fav >/dev/null || exit 1
    wali_rotate r >/dev/null
  ' zsh "$repo_root"

rg -q -x 'current --json' "$NOCTALIA_LOG" || \
  fail 'wali_rotate did not read the wallpaper from walictl'
(( $(rg -c -x 'current --json' "$NOCTALIA_LOG") == 1 )) || \
  fail 'wali_rotate must read one payload, not one per field'
rg -q -F "msg wallpaper-set ${NOCTALIA_WALLPAPER}" "$NOCTALIA_LOG" || \
  fail 'wali rotate did not reset the v5 wallpaper'
! rg -q -F qs "$NOCTALIA_LOG" || fail 'wali called Quickshell IPC'

print -- 'wali tests passed'
