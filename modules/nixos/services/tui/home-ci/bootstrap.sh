#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Reconcile the generic guest payload on every boot. Private registrations stay
# on the guest disk; updating the host module never re-registers repositories.
install -m 0755 /mnt/home-ci/guest.py /usr/local/sbin/home-ci-guest
install -m 0755 /mnt/home-ci/docker.py /usr/local/bin/docker
install -D -m 0755 /mnt/home-ci/job-start.sh /usr/local/lib/home-ci/job-start.sh
install -m 0600 /mnt/home-ci/guest-settings.json /etc/home-ci.json
install -m 0644 /mnt/home-ci/bootstrap.service /etc/systemd/system/home-ci-bootstrap.service
python3 /usr/local/sbin/home-ci-guest proxy
packages=(
  ca-certificates curl git jq python3 sudo unzip zip zstd gettext
  docker.io docker-buildx docker-compose-v2 libicu74 libssl3t64 libcairo2
  libkrb5-3 zlib1g liblttng-ust1t64
)
package_hash=$(printf '%s\n' "${packages[@]}" | sha256sum)
if [[ ! -f /var/lib/home-ci/bootstrap-ready ]] || [[ $(cat /var/lib/home-ci/bootstrap-ready) != "$package_hash" ]]; then
  dpkg --configure -a
  apt-get -o DPkg::Lock::Timeout=120 -o Acquire::Retries=5 update
  apt-get -o DPkg::Lock::Timeout=120 -o Acquire::Retries=5 install -y "${packages[@]}"
  id ci-runner >/dev/null 2>&1 || useradd --create-home --shell /bin/bash ci-runner
  usermod -aG docker ci-runner
  install -d -m 0750 -o ci-runner -g ci-runner /var/lib/home-ci/runners
  install -d -m 0750 -o ci-runner -g ci-runner /var/cache/home-ci/uv /var/cache/home-ci/python
  printf '%s\n' "$package_hash" > /var/lib/home-ci/bootstrap-ready
fi
python3 /usr/local/sbin/home-ci-guest proxy
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
python3 /usr/local/sbin/home-ci-guest resume
