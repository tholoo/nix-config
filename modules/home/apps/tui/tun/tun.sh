#!/usr/bin/env bash
set -euo pipefail

TUN_DEV="${TUN_DEV:-tun0}"
TUN_ADDR="${TUN_ADDR:-10.0.0.1/24}"
TUN_GW="${TUN_GW:-10.0.0.2}"

SOCKS_HOST="${SOCKS_HOST:-127.0.0.1}"
SOCKS_PORT="${SOCKS_PORT:-10808}"
SOCKS_URL="socks5://${SOCKS_HOST}:${SOCKS_PORT}"

MARK_HEX="0x1"
RT_TABLE="100"
RT_PRIO="100"

LOG_FILE="/var/log/tun2socks.log"

log(){ printf '%s\n' "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { log "Missing: $1"; exit 1; }; }

detect_socks_pid() {
  ss -lntp 2>/dev/null | awk -v p=":${SOCKS_PORT}" '
    $4 ~ p && $4 ~ /127\.0\.0\.1/ {
      match($0, /pid=([0-9]+)/, m);
      if (m[1] != "") { print m[1]; exit }
    }'
}

# Get all descendant PIDs (Linux /proc based)
desc_pids() {
  local root="$1"
  local out=("$root")
  local changed=1
  while [[ $changed -eq 1 ]]; do
    changed=0
    for p in "${out[@]}"; do
      while read -r c; do
        [[ -z "$c" ]] && continue
        if ! printf '%s\n' "${out[@]}" | grep -qx "$c"; then
          out+=("$c"); changed=1
        fi
      done < <(pgrep -P "$p" 2>/dev/null || true)
    done
  done
  printf '%s\n' "${out[@]}"
}

# Extract remote IPs that the xray process tree is currently connected to (tcp)
xray_remote_ips() {
  local pids="$1"
  # ss format: ESTAB ... users:(("xray",pid=123,...))
  # remote is typically field 5: <ip>:<port> (or [v6]:port)
  ss -ntp 2>/dev/null \
    | awk -v pids="$pids" '
      BEGIN {
        n=split(pids, a, " ");
        for (i=1;i<=n;i++) want[a[i]]=1;
      }
      /users:\(\(/ {
        match($0, /pid=([0-9]+)/, m);
        pid=m[1];
        if (!(pid in want)) next;

        remote=$5;

        # strip port
        sub(/:[0-9]+$/, "", remote);

        # strip [ ] around IPv6
        gsub(/^\[/, "", remote); gsub(/\]$/, "", remote);

        # ignore empty/localhost
        if (remote != "" && remote != "127.0.0.1" && remote != "::1") print remote;
      }' \
    | sort -u
}

cmd_on() {
  need ip
  need ss
  need nft
  need tun2socks
  need curl
  need pgrep
  need awk
  need sort

  log "[1/8] Sanity: SOCKS listening on 127.0.0.1:${SOCKS_PORT}?"
  ss -lnt | grep -q "127.0.0.1:${SOCKS_PORT}" || { log "SOCKS not listening."; exit 1; }

  log "[2/8] Pre-test: verify SOCKS can reach the internet (before changing anything)..."
  if ! curl -fsS --max-time 8 --socks5-hostname "${SOCKS_HOST}:${SOCKS_PORT}" https://checkip.amazonaws.com >/dev/null; then
    log "WARNING: SOCKS pre-test failed. Continuing anyway."
    log "WARNING: If setup later fails or loops, check v2rayN/Xray first."
  fi

  log "[3/8] Detect SOCKS listener PID and Xray process tree..."
  local socks_pid pids pids_space
  socks_pid="$(detect_socks_pid)"
  [[ -n "${socks_pid}" ]] || { log "Cannot detect PID for SOCKS listener."; exit 1; }
  pids="$(desc_pids "${socks_pid}")"
  pids_space="$(printf '%s ' ${pids} | sed 's/[[:space:]]*$//')"
  log "SOCKS listener PID: ${socks_pid}"

  log "[4/8] Discover Xray upstream remote IPs to exempt (prevents routing loop)..."
  local remotes
  remotes="$(xray_remote_ips "${pids_space}" || true)"
  if [[ -z "${remotes}" ]]; then
    log "Could not detect any established upstream IPs. This can happen if Xray is idle."
    log "Open any website through SOCKS once, then re-run. For example:"
    log "  curl --socks5-hostname 127.0.0.1:${SOCKS_PORT} https://example.com >/dev/null"
    exit 1
  fi
  log "Exempt upstream IPs:"
  printf '%s\n' "${remotes}" | sed 's/^/  - /'

  # Build nft set syntax: { ip1, ip2, ... }
  local nft_set
  nft_set="$(printf '%s\n' "${remotes}" | paste -sd, -)"

  log "[5/8] Create/bring up ${TUN_DEV}..."
  if ! ip link show "${TUN_DEV}" >/dev/null 2>&1; then
    ip tuntap add dev "${TUN_DEV}" mode tun user "${SUDO_USER:-$USER}"
  fi
  ip addr replace "${TUN_ADDR}" dev "${TUN_DEV}"
  ip link set "${TUN_DEV}" up

  log "[6/8] Start tun2socks (background)..."
  pkill -f "tun2socks.*-device ${TUN_DEV}" >/dev/null 2>&1 || true
  nohup tun2socks \
    -device "${TUN_DEV}" \
    -proxy "${SOCKS_URL}" \
    -loglevel info \
    >"${LOG_FILE}" 2>&1 &

  log "[7/8] Policy routing + nft marking (exempt: loopback, DNS, Xray upstream IPs)..."
  ip route replace default via "${TUN_GW}" dev "${TUN_DEV}" table "${RT_TABLE}"
  ip rule add fwmark "${MARK_HEX}" lookup "${RT_TABLE}" priority "${RT_PRIO}" 2>/dev/null || true

  nft list table inet tun_mark >/dev/null 2>&1 && nft delete table inet tun_mark || true
  nft -f /dev/stdin <<NFT
table inet tun_mark {
  chain output {
    type route hook output priority -150; policy accept;

    # loopback untouched
    oifname "lo" return

    # exempt DNS so resolver works (UDP associate is commonly unreliable)
    udp dport 53 return
    tcp dport 53 return

    # exempt Xray upstream IPs to prevent routing loops
    ip daddr { ${nft_set} } return

    # mark everything else to go through tun
    meta mark set ${MARK_HEX}
  }
}
NFT

  log "[8/8] Tests..."
  log "checkip (normal):"
  curl -fsS --max-time 10 https://checkip.amazonaws.com
  log "OK: traffic is routed through ${TUN_DEV} -> ${SOCKS_URL} (DNS + Xray-upstream exempted)."
}

cmd_off() {
  need ip
  need nft
  need pkill || true

  log "[1/4] Remove nft rules..."
  nft list table inet tun_mark >/dev/null 2>&1 && nft delete table inet tun_mark || true

  log "[2/4] Remove policy routing..."
  ip rule del fwmark "${MARK_HEX}" lookup "${RT_TABLE}" priority "${RT_PRIO}" 2>/dev/null || true
  ip route flush table "${RT_TABLE}" >/dev/null 2>&1 || true

  log "[3/4] Stop tun2socks..."
  pkill -f "tun2socks.*-device ${TUN_DEV}" >/dev/null 2>&1 || true

  log "[4/4] Remove ${TUN_DEV}..."
  ip link set "${TUN_DEV}" down >/dev/null 2>&1 || true
  ip tuntap del dev "${TUN_DEV}" mode tun >/dev/null 2>&1 || true

  log "OK: tunnel disabled."
}

case "${1:-}" in
  on)  cmd_on ;;
  off) cmd_off ;;
  *) echo "Usage: sudo $0 on|off"; exit 2 ;;
esac
