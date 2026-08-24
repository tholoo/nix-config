#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-${HOME:?HOME is not set}/.local/state}/codex/zellij-sessions"

valid_token() {
  [[ "$1" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]
}

valid_session_id() {
  [[ ${#1} -le 256 && "$1" =~ ^[[:alnum:]_-]+$ ]]
}

case "${1:-}" in
  record)
    token="${CODEX_ZELLIJ_TOKEN:-}"
    [[ -n "$token" ]] || exit 0
    valid_token "$token" || exit 2

    session_id="$(jq -er '
      .session_id
      | select(type == "string" and length > 0 and length <= 256)
    ')"
    valid_session_id "$session_id" || exit 2

    umask 077
    install -d -m 700 -- "$state_dir"
    temporary_file="$(mktemp "$state_dir/.${token}.XXXXXX")"
    trap 'rm -f -- "$temporary_file"' EXIT
    printf '%s\n' "$session_id" > "$temporary_file"
    mv -f -- "$temporary_file" "$state_dir/$token"
    trap - EXIT
    ;;
  lookup)
    token="${2:-}"
    valid_token "$token" || exit 2
    session_file="$state_dir/$token"
    [[ -f "$session_file" ]] || exit 1
    IFS= read -r session_id < "$session_file"
    valid_session_id "$session_id" || exit 2
    printf '%s\n' "$session_id"
    ;;
  *)
    echo "usage: $0 {record|lookup TOKEN}" >&2
    exit 2
    ;;
esac
