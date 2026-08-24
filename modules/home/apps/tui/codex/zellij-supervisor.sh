#!/usr/bin/env bash
set -euo pipefail

real_codex="${CODEX_ZELLIJ_REAL_CODEX:?CODEX_ZELLIJ_REAL_CODEX is not set}"
session_command="${CODEX_ZELLIJ_SESSION_COMMAND:?CODEX_ZELLIJ_SESSION_COMMAND is not set}"
marker='--codex-zellij-resurrect-token'

if [[ "${1:-}" == "$marker" ]]; then
  token="${2:-}"
  if [[ ! "$token" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || (( $# != 2 )); then
    echo 'invalid Codex Zellij resurrection token' >&2
    exit 2
  fi
elif [[ -n "${ZELLIJ:-}" && $# -eq 0 ]]; then
  IFS= read -r token < /proc/sys/kernel/random/uuid
  exec "$0" "$marker" "$token"
else
  exec "$real_codex" "$@"
fi

export CODEX_ZELLIJ_TOKEN="$token"
codex_args=()
if session_id="$("$session_command" lookup "$token")"; then
  codex_args=(resume "$session_id")
fi

# Remain the foreground process-group leader so Zellij serializes the stable
# token. Running Codex synchronously preserves normal terminal signal handling.
set +e
"$real_codex" "${codex_args[@]}"
status=$?
set -e
exit "$status"
