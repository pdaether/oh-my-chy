#!/bin/bash
# Open the firewall ports KDE Connect needs (used by the OmaConnect bar plugin).
#
# Why these ports: KDE Connect works on the fixed range 1714-1764.
#   * UDP 1714-1764 — device discovery (UDP broadcasts/multicast on the LAN)
#   * TCP 1714-1764 — everything else once paired: notifications, clipboard,
#     files, remote input
# With an active firewall (ufw) and closed ports, phones never show up during
# pairing because their discovery broadcasts are dropped.
#
# Idempotent: each rule is only added if missing.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

PORT_RANGE=1714:1764

if ! command -v ufw &>/dev/null; then
  skip "ufw not installed — nothing to open"
  exit 0
fi

for proto in tcp udp; do
  if sudo -n ufw status | grep -q "${PORT_RANGE}/${proto}"; then
    skip "ufw ${PORT_RANGE}/${proto} (${proto^^}, KDE Connect)"
  else
    log "Opening ufw ${PORT_RANGE}/${proto}"
    sudo -n ufw allow "${PORT_RANGE}/${proto}" comment 'KDE Connect' </dev/null \
      && ok "ufw ${PORT_RANGE}/${proto}" \
      || die "could not add ufw rule ${PORT_RANGE}/${proto}"
  fi
done
