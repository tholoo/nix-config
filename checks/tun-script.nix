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
EOF
    bash test-functions.bash

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
