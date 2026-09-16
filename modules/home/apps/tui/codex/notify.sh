#!/usr/bin/env bash
set -euo pipefail

payload="${1:-}"
title="Codex"
body="Codex needs attention or finished a turn."
max_body_chars=100

if [[ -z "$payload" && ! -t 0 ]]; then
  payload="$(cat)"
fi

if command -v jq >/dev/null 2>&1 && [[ -n "$payload" ]]; then
  # Internal title generation also emits turn completion. Match the same
  # helper prompt as the dashboard integrations, preserving normal alerts.
  if jq -e '
    .type == "agent-turn-complete" and
    any(."input-messages"[]?; strings |
      startswith("Generate a concise, single-line task title of at most 36 characters"))
  ' <<< "$payload" >/dev/null 2>&1; then
    exit 0
  fi

  event="$(jq -r '.type // .hook_event_name // empty' <<< "$payload" 2>/dev/null || true)"
  msg="$(jq -r '."last-assistant-message" // .last_assistant_message // empty' <<< "$payload" 2>/dev/null || true)"

  case "$event" in
    approval-requested | PermissionRequest)
      title="Codex approval needed"
      body="$(jq -r '.tool_input.description // .tool_input.command // "Codex is waiting for permission."' <<< "$payload" 2>/dev/null || true)"
      ;;
    agent-turn-complete | Stop)
      title="Codex turn complete"
      [[ -n "$msg" ]] && body="$msg"
      ;;
    *)
      [[ -n "$msg" ]] && body="$msg"
      ;;
  esac
fi

if ((${#body} > max_body_chars)); then
  body="${body:0:${max_body_chars}}..."
fi

if command -v notify-send >/dev/null 2>&1 && notify-send --urgency=normal "$title" "$body" >/dev/null 2>&1; then
  exit 0
fi

if command -v dunstify >/dev/null 2>&1 && dunstify "$title" "$body" >/dev/null 2>&1; then
  exit 0
fi

codex_state_dir="${CODEX_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex}"
mkdir -p "$codex_state_dir"
echo "$title: $body" >> "$codex_state_dir/notifications.log"
