#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_bridge="$repo_root/modules/home/apps/tui/codex/zellij-session.sh"
supervisor="$repo_root/modules/home/apps/tui/codex/zellij-supervisor.sh"
test_root="$(mktemp -d)"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/bin" "$test_root/state"
cat > "$test_root/bin/codex-real" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CODEX_CALLS"
if [[ -n "${CODEX_HOLD:-}" ]]; then
  sleep 1
fi
EOF
chmod +x "$test_root/bin/codex-real"

# A zero-argument launch inside Zellij must re-exec the supervisor with a
# generated stable token visible in the process-group leader's command line.
CODEX_CALLS="$test_root/codex-calls" \
  CODEX_HOLD=1 \
  CODEX_ZELLIJ_REAL_CODEX="$test_root/bin/codex-real" \
  CODEX_ZELLIJ_SESSION_COMMAND="$session_bridge" \
  XDG_STATE_HOME="$test_root/state" \
  ZELLIJ='test-session' \
  bash "$supervisor" &
supervisor_pid=$!
sleep 0.1
supervisor_args="$(ps -o args= -p "$supervisor_pid")"
if ! grep -Eq -- '--codex-zellij-resurrect-token [[:xdigit:]-]{36}$' <<< "$supervisor_args"; then
  printf 'stable token missing from supervisor command: %s\n' "$supervisor_args" >&2
  exit 1
fi
wait "$supervisor_pid"
: > "$test_root/codex-calls"

record_session() {
  local token="$1"
  local session_id="$2"

  printf '{"hook_event_name":"SessionStart","session_id":"%s"}\n' "$session_id" | \
    CODEX_ZELLIJ_TOKEN="$token" \
    XDG_STATE_HOME="$test_root/state" \
    bash "$session_bridge" record
}

restore_token() {
  local token="$1"

  CODEX_CALLS="$test_root/codex-calls" \
    CODEX_ZELLIJ_REAL_CODEX="$test_root/bin/codex-real" \
    CODEX_ZELLIJ_SESSION_COMMAND="$session_bridge" \
    XDG_STATE_HOME="$test_root/state" \
    bash "$supervisor" --codex-zellij-resurrect-token "$token"
}

token_one='0198f7a1-1111-4777-8888-123456789abc'
token_two='0198f7a1-2222-4777-8888-123456789abc'
unknown_token='0198f7a1-3333-4777-8888-123456789abc'

# These represent two panes launched from the same working directory. The
# stable launch token, rather than cwd or pane ID, must select the session.
record_session "$token_one" '0198f7a1-aaaa-4777-8888-123456789abc'
record_session "$token_two" '0198f7a1-bbbb-4777-8888-123456789abc'
[[ "$(stat -c %a "$test_root/state/codex/zellij-sessions")" == 700 ]]
[[ "$(stat -c %a "$test_root/state/codex/zellij-sessions/$token_one")" == 600 ]]
restore_token "$token_one"
restore_token "$token_two"
restore_token "$unknown_token"

mapfile -t calls < "$test_root/codex-calls"
[[ "${calls[0]}" == 'resume 0198f7a1-aaaa-4777-8888-123456789abc' ]]
[[ "${calls[1]}" == 'resume 0198f7a1-bbbb-4777-8888-123456789abc' ]]
[[ "${calls[2]}" == '' ]]

# Invalid state must neither escape the state directory nor resume a session.
if CODEX_ZELLIJ_TOKEN='../outside' XDG_STATE_HOME="$test_root/state" \
  bash "$session_bridge" record <<< '{"session_id":"unsafe"}'
then
  echo 'invalid token was accepted' >&2
  exit 1
fi

grep -Fq "command = \"\${managedDir}/zellij-session record\"" \
  "$repo_root/modules/shared/codex-hooks.nix"
grep -Fq 'package = codexPackage;' \
  "$repo_root/modules/home/apps/tui/codex/default.nix"
