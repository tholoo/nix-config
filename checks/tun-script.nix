{ pkgs }:

pkgs.runCommand "tun-script-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.gnugrep
    ];
  }
  ''
    set -euo pipefail

    script=${../modules/home/apps/tui/tun/tun.sh}

    bash -n "$script"

    cat > test-functions.bash <<EOF
    set -euo pipefail
    source "$script"

    dns_rules="\$(nft_return_dns_to_daddrs ip 192.168.0.0/16)"
    grep -F 'ip daddr 192.168.0.0/16 udp dport 53 return' <<< "\$dns_rules"
    grep -F 'ip daddr 192.168.0.0/16 tcp dport 53 return' <<< "\$dns_rules"

    bypass_rules="\$(nft_return_daddrs ip 10.0.0.0/8)"
    grep -F 'ip daddr 10.0.0.0/8 return' <<< "\$bypass_rules"

    drop_rules="\$(nft_drop_daddrs ip 10.0.0.2)"
    grep -F 'ip daddr 10.0.0.2 drop' <<< "\$drop_rules"

    cgroup_rules="\$(printf '%s\n' 'user.slice/user-1000.slice/user@1000.service/app.slice/tun-direct.slice' | nft_return_cgroupv2_paths)"
    grep -F 'socket cgroupv2 level 5 "user.slice/user-1000.slice/user@1000.service/app.slice/tun-direct.slice" return' <<< "\$cgroup_rules"

    families="\$(split_ips_by_family 203.0.113.10 2001:db8::10)"
    grep -F 'ip 203.0.113.10' <<< "\$families"
    grep -F 'ip6 2001:db8::10' <<< "\$families"

    cgroup_root="\$(mktemp -d)"
    mkdir -p "\$cgroup_root/user.slice/user-1000.slice/user@1000.service/app.slice/tun-direct.slice"
    CGROUP_ROOT="\$cgroup_root"
    direct_paths="\$(direct_cgroup_paths)"
    grep -F 'user.slice/user-1000.slice/user@1000.service/app.slice/tun-direct.slice' <<< "\$direct_paths"

    proc_root="\$(mktemp -d)"
    mkdir -p "\$proc_root/100" "\$proc_root/101" "\$proc_root/102"
    cat > "\$proc_root/100/cgroup" <<'CGROUP'
0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-throne.scope
CGROUP
    cat > "\$proc_root/101/cgroup" <<'CGROUP'
0::/system.slice/throne-core.service
CGROUP
    cat > "\$proc_root/102/cgroup" <<'CGROUP'
0::
CGROUP
    PROC_ROOT="\$proc_root"
    proxy_paths="\$(proc_cgroupv2_paths 100 101 102 999)"
    grep -F 'user.slice/user-1000.slice/user@1000.service/app.slice/app-throne.scope' <<< "\$proxy_paths"
    grep -F 'system.slice/throne-core.service' <<< "\$proxy_paths"
    if printf '%s\n' "\$proxy_paths" | grep -Fx ""; then
      echo "proc_cgroupv2_paths must not emit the cgroup root as an empty path" >&2
      exit 1
    fi

    proxy_cgroup_rules="\$(printf '%s\n' "\$proxy_paths" | nft_return_cgroupv2_paths)"
    grep -F 'socket cgroupv2 level 5 "user.slice/user-1000.slice/user@1000.service/app.slice/app-throne.scope" return' <<< "\$proxy_cgroup_rules"
    grep -F 'socket cgroupv2 level 2 "system.slice/throne-core.service" return' <<< "\$proxy_cgroup_rules"

    render_drop_rules="\$(nft_drop_daddrs ip 10.0.0.2)"
    render_direct_rules="\$(printf '%s\n' 'user.slice/user-1000.slice/user@1000.service/app.slice/tun-direct.slice' | nft_return_cgroupv2_paths)"
    render_dns_rules="\$(nft_return_dns_to_daddrs ip 192.168.0.0/16)"
    render_local_rules="\$(nft_return_daddrs ip 10.0.0.0/8)"
    render_upstream_rules="\$(nft_return_daddrs ip 185.208.174.230)"
    rendered_table="\$(nft_tun_mark_table "\$render_drop_rules" "\$render_direct_rules" "\$proxy_cgroup_rules" "\$render_dns_rules" "\$render_local_rules" "\$render_upstream_rules")"

    grep -F 'table inet tun_mark {' <<< "\$rendered_table"
    grep -F 'ip daddr 10.0.0.2 drop' <<< "\$rendered_table"
    grep -F 'ip daddr 10.0.0.0/8 return' <<< "\$rendered_table"
    grep -F 'socket cgroupv2 level 2 "system.slice/throne-core.service" return' <<< "\$rendered_table"
    grep -F 'ip daddr 185.208.174.230 return' <<< "\$rendered_table"
    grep -F 'meta mark set 0x1' <<< "\$rendered_table"

    rendered_line_of() {
      grep -nF "\$1" <<< "\$rendered_table" | cut -d: -f1 | head -n1
    }

    rendered_drop_line="\$(rendered_line_of 'ip daddr 10.0.0.2 drop')"
    rendered_local_line="\$(rendered_line_of 'ip daddr 10.0.0.0/8 return')"
    rendered_proxy_line="\$(rendered_line_of 'socket cgroupv2 level 2 "system.slice/throne-core.service" return')"
    rendered_mark_line="\$(rendered_line_of 'meta mark set 0x1')"

    if [[ -z "\$rendered_drop_line" || -z "\$rendered_local_line" || "\$rendered_drop_line" -ge "\$rendered_local_line" ]]; then
      echo "rendered TUN gateway drop must appear before broad local CIDR returns" >&2
      exit 1
    fi
    if [[ -z "\$rendered_proxy_line" || -z "\$rendered_mark_line" || "\$rendered_proxy_line" -ge "\$rendered_mark_line" ]]; then
      echo "rendered proxy cgroup returns must appear before final mark rule" >&2
      exit 1
    fi
EOF
    bash test-functions.bash

    drop_line="$(grep -nF '# drop traffic addressed to the synthetic TUN gateway itself' "$script" | cut -d: -f1 | head -n1)"
    mark_line="$(grep -nF 'meta mark set' "$script" | cut -d: -f1 | head -n1)"
    if [[ -z "$drop_line" || -z "$mark_line" || "$drop_line" -ge "$mark_line" ]]; then
      echo "TUN gateway self-traffic drop must appear before final mark rule" >&2
      exit 1
    fi

    fake_bin="$PWD/fake-bin"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/id" <<'EOF'
    #!/usr/bin/env bash
    if [[ "$1" == "-u" ]]; then
      echo 1000
      exit 0
    fi
    exit 1
EOF
    chmod +x "$fake_bin/id"

    cat > "$fake_bin/runuser" <<'EOF'
    #!/usr/bin/env bash
    printf '%s\n' "$*" >> "$RUNUSER_LOG"
EOF
    chmod +x "$fake_bin/runuser"

    cat > test-systemd.bash <<EOF
    set -euo pipefail
    source "$script"

    export PATH="$fake_bin:$PATH"
    export RUNUSER_LOG="$PWD/runuser.log"
    export SUDO_USER=tholo

    ensure_direct_cgroup_slice
    grep -F -- '-u tholo -- systemd-run --user --slice=tun-direct.slice --unit=tun-direct-keepalive --quiet sleep infinity' "\$RUNUSER_LOG"
    if grep -F -- '--scope' "\$RUNUSER_LOG"; then
      echo "keepalive must be a transient service, not a blocking scope" >&2
      exit 1
    fi

    : > "\$RUNUSER_LOG"
    stop_direct_cgroup_slice
    grep -F -- '-u tholo -- systemctl --user stop tun-direct-keepalive.service' "\$RUNUSER_LOG"
EOF
    bash test-systemd.bash

    if grep -Eq '^[[:space:]]*(udp|tcp) dport 53 return[[:space:]]*$' "$script"; then
      echo "tun.sh must not bypass all public DNS traffic" >&2
      exit 1
    fi

    touch "$out"
  ''
