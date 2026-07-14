#!/usr/bin/env zsh

typeset -ga _tmp_cleanup_paths=()

cleanup_registered_tmpdirs() {
  local cleanup_path
  for cleanup_path in "${_tmp_cleanup_paths[@]}"; do
    rm -rf -- "$cleanup_path"
  done
}

trap cleanup_registered_tmpdirs EXIT

register_tmp_cleanup() {
  _tmp_cleanup_paths+=("$1")
}
