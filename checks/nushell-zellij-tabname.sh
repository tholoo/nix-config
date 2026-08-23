#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_name="$(basename "$repo_root")"
test_root="$(mktemp -d)"
session_name="codex-zellij-tabname-$$"
cache_dir="/tmp/nushell-zellij-tabname-${session_name}-7"

cleanup() {
  rm -rf "$test_root" "$cache_dir"
}
trap cleanup EXIT

mkdir -p "$test_root/bin" "$cache_dir"
printf '%s' "$repo_name" > "$cache_dir/last_name"
printf '%s' 7 > "$cache_dir/tab_id"

cat > "$test_root/bin/zellij" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == action && "${2-}" == list-panes ]]; then
  printf '%s\n' '[{"id":7,"is_plugin":false,"tab_id":3}]'
  exit 0
fi

printf '%s\n' "$*" >> "$TEST_STATE/calls"
EOF
chmod +x "$test_root/bin/zellij"

cd "$repo_root"
PATH="$test_root/bin:$PATH" \
  TEST_STATE="$test_root" \
  ZELLIJ=0 \
  ZELLIJ_SESSION_NAME="$session_name" \
  ZELLIJ_PANE_ID=7 \
  nu --no-std-lib --config "$repo_root/modules/home/apps/tui/nushell/config.nu" \
    -c 'pwd | ignore'

if ! grep -Fx "action rename-tab-by-id 3 $repo_name" "$test_root/calls"; then
  echo 'expected the current tab (ID 3) to be renamed despite stale cache state' >&2
  exit 1
fi
