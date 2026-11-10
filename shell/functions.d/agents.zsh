# Route harness commands through the host's configured agent slice when enabled.
function _agent_session {
  local tool=$1 arg
  shift
  case ${HOSTKIT_AGENT_SESSIONS-} in
    (''|0) command "$tool" "$@" ;;
    (1)
      if [[ $tool == codex ]]; then
        local no_daemon=0
        for arg in "$@"; do
          [[ $arg == -- ]] && break
          if [[ $arg == --no-daemon ]]; then
            no_daemon=1
            break
          fi
        done
        (( no_daemon )) || set -- --no-daemon "$@"
      fi
      command host-budget session -- "$tool" "$@"
      ;;
    (*)
      print -u2 -- 'HOSTKIT_AGENT_SESSIONS must be 0 or 1'
      return 2
      ;;
  esac
}

function claude   { _agent_session claude "$@"; }
function codex    { _agent_session codex "$@"; }
function agy      { _agent_session agy "$@"; }
function pi       { _agent_session pi "$@"; }
function opencode { _agent_session opencode "$@"; }
function crush    { _agent_session crush "$@"; }
