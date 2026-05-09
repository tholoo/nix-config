#!/usr/bin/env bash
set -euo pipefail

TUN_DEV="${TUN_DEV:-tun0}"
TUN_ADDR="${TUN_ADDR:-10.0.0.1/24}"
TUN_GW="${TUN_GW:-10.0.0.2}"

SOCKS_HOST="${SOCKS_HOST:-127.0.0.1}"
SOCKS_PORT="${SOCKS_PORT:-10808}"
SOCKS_URL="socks5://${SOCKS_HOST}:${SOCKS_PORT}"

LOCAL_BYPASS_CIDRS="${LOCAL_BYPASS_CIDRS:-10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32}"
LOCAL_BYPASS_IP6_CIDRS="${LOCAL_BYPASS_IP6_CIDRS:-::1/128 fc00::/7 fe80::/10 ff00::/8}"

MARK_HEX="0x1"
RT_TABLE="100"
RT_PRIO="100"

LOG_FILE="/var/log/tun2socks.log"
DIRECT_CGROUP_SLICE="${DIRECT_CGROUP_SLICE:-tun-direct.slice}"
DIRECT_KEEPALIVE_UNIT="${DIRECT_KEEPALIVE_UNIT:-tun-direct-keepalive}"
CGROUP_ROOT="${CGROUP_ROOT:-/sys/fs/cgroup}"
PROC_ROOT="${PROC_ROOT:-/proc}"

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

        sub(/:[0-9]+$/, "", remote);
        gsub(/^\[/, "", remote); gsub(/\]$/, "", remote);

        if (remote != "" && remote != "127.0.0.1" && remote != "::1") print remote;
      }' \
    | sort -u
}

nft_return_daddrs() {
  local family="$1"
  shift

  local cidr
  for cidr in "$@"; do
    [[ -n "${cidr}" ]] || continue
    printf '    %s daddr %s return\n' "${family}" "${cidr}"
  done
}

nft_drop_daddrs() {
  local family="$1"
  shift

  local cidr
  for cidr in "$@"; do
    [[ -n "${cidr}" ]] || continue
    printf '    %s daddr %s drop\n' "${family}" "${cidr}"
  done
}

nft_return_dns_to_daddrs() {
  local family="$1"
  shift

  local cidr
  for cidr in "$@"; do
    [[ -n "${cidr}" ]] || continue
    printf '    %s daddr %s udp dport 53 return\n' "${family}" "${cidr}"
    printf '    %s daddr %s tcp dport 53 return\n' "${family}" "${cidr}"
  done
}

split_ips_by_family() {
  local ip
  for ip in "$@"; do
    [[ -n "${ip}" ]] || continue
    case "${ip}" in
      *:*) printf 'ip6 %s\n' "${ip}" ;;
      *) printf 'ip %s\n' "${ip}" ;;
    esac
  done
}

main_link_cidrs() {
  local family="$1"
  shift

  ip -o -"${family}" route show table main scope link 2>/dev/null \
    | awk -v tun_dev="${TUN_DEV}" '$0 !~ " dev " tun_dev " " { print $1 }'
}

user_systemctl() {
  local user="${SUDO_USER:-$USER}"
  local uid
  uid="$(id -u "${user}")"

  XDG_RUNTIME_DIR="/run/user/${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
    runuser -u "${user}" -- systemctl --user "$@"
}

user_systemd_run() {
  local user="${SUDO_USER:-$USER}"
  local uid
  uid="$(id -u "${user}")"

  XDG_RUNTIME_DIR="/run/user/${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
    runuser -u "${user}" -- systemd-run --user "$@"
}

ensure_direct_cgroup_slice() {
  user_systemd_run \
    --slice="${DIRECT_CGROUP_SLICE}" \
    --unit="${DIRECT_KEEPALIVE_UNIT}" \
    --quiet \
    sleep infinity >/dev/null 2>&1 || true
}

stop_direct_cgroup_slice() {
  user_systemctl stop "${DIRECT_KEEPALIVE_UNIT}.service" >/dev/null 2>&1 || true
}

direct_cgroup_paths() {
  find "${CGROUP_ROOT}" -type d -name "${DIRECT_CGROUP_SLICE}" 2>/dev/null \
    | sed "s#^${CGROUP_ROOT%/}/##" \
    | sort -u
}

proc_cgroupv2_paths() {
  local pid line path
  for pid in "$@"; do
    [[ -n "${pid}" ]] || continue
    [[ -r "${PROC_ROOT%/}/${pid}/cgroup" ]] || continue

    while IFS= read -r line; do
      case "${line}" in
        0::/*)
          path="${line#0::/}"
          [[ -n "${path}" ]] && printf '%s\n' "${path}"
          ;;
      esac
    done < "${PROC_ROOT%/}/${pid}/cgroup"
  done | sort -u
}

nft_return_cgroupv2_paths() {
  local path level
  while read -r path; do
    [[ -n "${path}" ]] || continue
    level="$(awk -F/ '{ print NF }' <<< "${path}")"
    printf '    socket cgroupv2 level %s "%s" return\n' "${level}" "${path}"
  done
}

nft_tun_mark_table() {
  local tun_self_drop_rules="$1"
  local direct_cgroup_rules="$2"
  local proxy_cgroup_rules="$3"
  local local_dns_bypass_rules="$4"
  local local_bypass_rules="$5"
  local upstream_bypass_rules="$6"

  cat <<NFT
table inet tun_mark {
  chain output {
    type route hook output priority -150; policy accept;

    # loopback untouched
    oifname "lo" return

    # drop traffic addressed to the synthetic TUN gateway itself
${tun_self_drop_rules}

    # commands launched with 'direct' run in this user-systemd slice
${direct_cgroup_rules}

    # traffic emitted by the proxy engine itself must not be recaptured
${proxy_cgroup_rules}

    # LAN DNS stays on the normal LAN route
${local_dns_bypass_rules}

    # local networks, link-local, and multicast stay on the normal LAN route
${local_bypass_rules}

    # exempt Xray upstream IPs to prevent routing loops
${upstream_bypass_rules}

    # mark everything else to go through tun
    meta mark set ${MARK_HEX}
  }
}
NFT
}

is_tun_dev_up() {
  ip link show "${TUN_DEV}" >/dev/null 2>&1 || return 1
  ip link show dev "${TUN_DEV}" | grep -q "state UP"
}

has_tun_addr() {
  ip -brief addr show dev "${TUN_DEV}" 2>/dev/null | grep -q "${TUN_ADDR%/*}"
}

is_tun2socks_running() {
  pgrep -af "tun2socks.*-device ${TUN_DEV}" >/dev/null 2>&1
}

has_nft_table() {
  nft list table inet tun_mark >/dev/null 2>&1
}

has_ip_rule() {
  ip rule show | grep -q "fwmark ${MARK_HEX}.*lookup ${RT_TABLE}"
}

has_table_default_route() {
  ip route show table "${RT_TABLE}" | grep -q "^default via ${TUN_GW} dev ${TUN_DEV}"
}

is_socks_listening() {
  ss -lnt 2>/dev/null | grep -q "127.0.0.1:${SOCKS_PORT}"
}

cmd_status() {
  need ip
  need ss
  need nft
  need pgrep
  need grep

  local active=1

  log "Tunnel status"
  log "============="

  if is_socks_listening; then
    log "[OK]   SOCKS listener is up on 127.0.0.1:${SOCKS_PORT}"
  else
    log "[FAIL] SOCKS listener is not up on 127.0.0.1:${SOCKS_PORT}"
    active=0
  fi

  if is_tun_dev_up; then
    log "[OK]   TUN device ${TUN_DEV} exists and is UP"
  else
    log "[FAIL] TUN device ${TUN_DEV} is missing or DOWN"
    active=0
  fi

  if has_tun_addr; then
    log "[OK]   ${TUN_DEV} has address ${TUN_ADDR}"
  else
    log "[FAIL] ${TUN_DEV} does not have expected address ${TUN_ADDR}"
    active=0
  fi

  if is_tun2socks_running; then
    log "[OK]   tun2socks is running for ${TUN_DEV}"
  else
    log "[FAIL] tun2socks is not running for ${TUN_DEV}"
    active=0
  fi

  if has_nft_table; then
    log "[OK]   nft table inet tun_mark exists"
  else
    log "[FAIL] nft table inet tun_mark is missing"
    active=0
  fi

  if has_ip_rule; then
    log "[OK]   policy rule fwmark ${MARK_HEX} -> table ${RT_TABLE} exists"
  else
    log "[FAIL] policy rule fwmark ${MARK_HEX} -> table ${RT_TABLE} is missing"
    active=0
  fi

  if has_table_default_route; then
    log "[OK]   routing table ${RT_TABLE} has default via ${TUN_GW} dev ${TUN_DEV}"
  else
    log "[FAIL] routing table ${RT_TABLE} does not have expected default route"
    active=0
  fi

  log
  log "Details"
  log "-------"
  ip -brief addr show dev "${TUN_DEV}" 2>/dev/null || true
  ip rule show | grep "lookup ${RT_TABLE}" || true
  ip route show table "${RT_TABLE}" || true

  if has_nft_table; then
    log
    log "nft table inet tun_mark:"
    nft list table inet tun_mark || true
  fi

  if [[ "${active}" -eq 1 ]]; then
    log
    log "Result: ACTIVE"
    exit 0
  else
    log
    log "Result: INACTIVE or PARTIALLY BROKEN"
    exit 1
  fi
}

cmd_on() {
  need ip
  need ss
  need nft
  need tun2socks
  need curl
  need pgrep
  need grep
  need awk
  need sort
  need sed
  need find
  need id
  need runuser
  need systemctl
  need systemd-run

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

  log "[7/8] Policy routing + nft marking (drop: TUN gateway self-traffic; exempt: Throne/Core cgroups, direct command slice, loopback, LAN/link-local/multicast, LAN DNS, Xray upstream IPs)..."
  ip route replace default via "${TUN_GW}" dev "${TUN_DEV}" table "${RT_TABLE}"
  ip rule add fwmark "${MARK_HEX}" lookup "${RT_TABLE}" priority "${RT_PRIO}" 2>/dev/null || true

  ensure_direct_cgroup_slice

  local tun_self_drop_rules direct_cgroup_rules proxy_cgroup_rules local_bypass_rules local_dns_bypass_rules upstream_bypass_rules
  tun_self_drop_rules="$(nft_drop_daddrs ip "${TUN_GW}")"
  direct_cgroup_rules="$(direct_cgroup_paths | nft_return_cgroupv2_paths)"
  if [[ -z "${direct_cgroup_rules}" ]]; then
    log "WARNING: Could not find ${DIRECT_CGROUP_SLICE}; direct/dg command bypass is unavailable."
  fi
  proxy_cgroup_rules="$(proc_cgroupv2_paths ${pids} | nft_return_cgroupv2_paths)"
  if [[ -z "${proxy_cgroup_rules}" ]]; then
    log "WARNING: Could not find SOCKS/Core cgroup paths; relying on upstream IP exemptions only."
  fi

  read -r -a local_bypass_cidrs <<< "${LOCAL_BYPASS_CIDRS}"
  read -r -a local_bypass_ip6_cidrs <<< "${LOCAL_BYPASS_IP6_CIDRS}"
  local_bypass_rules="$(
    nft_return_daddrs ip "${local_bypass_cidrs[@]}"
    main_link_cidrs 4 | while read -r cidr; do nft_return_daddrs ip "${cidr}"; done
    nft_return_daddrs ip6 "${local_bypass_ip6_cidrs[@]}"
    main_link_cidrs 6 | while read -r cidr; do nft_return_daddrs ip6 "${cidr}"; done
  )"
  local_dns_bypass_rules="$(
    nft_return_dns_to_daddrs ip "${local_bypass_cidrs[@]}"
    main_link_cidrs 4 | while read -r cidr; do nft_return_dns_to_daddrs ip "${cidr}"; done
    nft_return_dns_to_daddrs ip6 "${local_bypass_ip6_cidrs[@]}"
    main_link_cidrs 6 | while read -r cidr; do nft_return_dns_to_daddrs ip6 "${cidr}"; done
  )"
  upstream_bypass_rules="$(
    while read -r family ip; do
      [[ -n "${family}" && -n "${ip}" ]] || continue
      nft_return_daddrs "${family}" "${ip}"
    done < <(split_ips_by_family ${remotes})
  )"

  nft list table inet tun_mark >/dev/null 2>&1 && nft delete table inet tun_mark || true
  nft_tun_mark_table \
    "${tun_self_drop_rules}" \
    "${direct_cgroup_rules}" \
    "${proxy_cgroup_rules}" \
    "${local_dns_bypass_rules}" \
    "${local_bypass_rules}" \
    "${upstream_bypass_rules}" \
    | nft -f /dev/stdin

  log "[8/8] Tests..."
  log "checkip (normal):"
  curl -fsS --max-time 10 https://checkip.amazonaws.com
  log "OK: traffic is routed through ${TUN_DEV} -> ${SOCKS_URL} (TUN gateway self-traffic dropped; Throne/Core cgroups + direct command slice + LAN/link-local/multicast + Xray-upstream exempted)."
}

cmd_off() {
  need ip
  need nft
  need id
  need runuser
  need systemctl
  need pkill || true

  log "[1/4] Remove nft rules..."
  nft list table inet tun_mark >/dev/null 2>&1 && nft delete table inet tun_mark || true

  log "[2/4] Remove policy routing..."
  ip rule del fwmark "${MARK_HEX}" lookup "${RT_TABLE}" priority "${RT_PRIO}" 2>/dev/null || true
  ip route flush table "${RT_TABLE}" >/dev/null 2>&1 || true

  log "[3/4] Stop tun2socks and direct keepalive scope..."
  pkill -f "tun2socks.*-device ${TUN_DEV}" >/dev/null 2>&1 || true
  stop_direct_cgroup_slice

  log "[4/4] Remove ${TUN_DEV}..."
  ip link set "${TUN_DEV}" down >/dev/null 2>&1 || true
  ip tuntap del dev "${TUN_DEV}" mode tun >/dev/null 2>&1 || true

  log "OK: tunnel disabled."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    on)     cmd_on ;;
    off)    cmd_off ;;
    status) cmd_status ;;
    *) echo "Usage: sudo $0 on|off|status"; exit 2 ;;
  esac
fi
