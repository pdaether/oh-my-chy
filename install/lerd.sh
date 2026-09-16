#!/bin/bash
# Lerd — Podman-powered local PHP dev environment (https://lerd.sh), installed
# the way lerd.sh/getting-started/omarchy documents it for Omarchy.
#
# The official installer (curl | bash) is only a downloader + prerequisite
# checker around `lerd install`, so this script keeps that shape but stays
# idempotent and Omarchy-native: the Arch packages it would offer to install
# come from install/pacman.txt instead (podman, crun, nss, dnsmasq), and the
# binary lands in ~/.local/bin — nothing in /usr/local. The one root-requiring
# part is `lerd install` itself (managed DNS: https://<name>.test with
# mkcert-trusted certificates, written to /etc + the browser trust store);
# run this through ./install.sh, whose preflight caches sudo for it.
#
# Idempotent: the binary is only downloaded when missing (update by hand with
# `lerd update`), `lerd install` only runs while ~/.config/lerd/config.yaml is
# absent, linger is enabled once, and `lerd start` only fires when nothing of
# lerd's is running yet.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

LERD_BIN="$HOME/.local/bin/lerd"
LERD_CONFIG="$HOME/.config/lerd/config.yaml"
INSTALLER_URL="https://lerd.sh/install.sh"
LERD_CHANGED=0

# The official installer appends an unmarked PATH line to ~/.bashrc whenever
# ~/.local/bin is not in PATH. Omarchy already has it there for login shells;
# mirror that here so its check can't fail and touch the managed bashrc.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# --- Prerequisites — what the Omarchy guide lists for Arch ---------------------

need() {
  command -v "$1" &>/dev/null || die "$1 is missing — part of install/pacman.txt; rerun ./install.sh or: omarchy-pkg-add $1"
}
need podman
need crun
need unzip
command -v certutil &>/dev/null \
  || die "certutil is missing — install nss (install/pacman.txt); mkcert needs it to trust the CA in Chrome/Firefox"

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  ok "systemd-resolved is the DNS resolver"
elif systemctl is-active --quiet NetworkManager 2>/dev/null; then
  # NM without systemd-resolved resolves .test through NM's dnsmasq plugin
  command -v dnsmasq &>/dev/null \
    || die "dnsmasq is missing — NetworkManager's DNS plugin needs it for .test resolution (install/pacman.txt)"
  ok "NetworkManager is the DNS resolver (dnsmasq plugin)"
else
  die "no supported DNS resolver running — lerd needs NetworkManager or systemd-resolved"
fi

rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)
if [[ $rootless == true ]]; then
  skip "podman running rootless"
else
  warn "podman is not running rootless — lerd expects rootless containers; check 'podman info' and the subuid/subgid entries for $USER"
fi

# --- Binary ---------------------------------------------------------------------

if [[ -x $LERD_BIN ]]; then
  skip "lerd binary ($("$LERD_BIN" --version 2>/dev/null | head -1))"
else
  log "Installing lerd via the official installer (DNS mode: managed, https://*.test)"
  tmp=$(mktemp)
  curl -sS --fail --retry 3 "$INSTALLER_URL" -o "$tmp" </dev/null
  [[ -s $tmp ]] || die "downloaded an empty lerd installer from $INSTALLER_URL"
  bash "$tmp" install </dev/null || die "lerd installer failed — run: curl -fsSL $INSTALLER_URL | bash"
  rm -f "$tmp"
  [[ -x $LERD_BIN ]] || die "lerd installer finished but $LERD_BIN is missing"
  LERD_CHANGED=1
  ok "lerd binary installed"
fi

# --- First-time setup: managed DNS, trusted certs, user services ----------------

if [[ -f $LERD_CONFIG ]]; then
  skip "lerd setup (config.yaml)"
else
  log "Running 'lerd install' — managed DNS + mkcert certs (lerd's one sudo step)"
  "$LERD_BIN" install --dns managed </dev/null \
    && { LERD_CHANGED=1; ok "lerd setup complete"; } \
    || die "'lerd install' failed — rerun ./install.sh from a terminal so sudo is cached, or run 'lerd install' by hand"
fi

# --- Linger: keep lerd's user units alive across logout --------------------------

if [[ $(loginctl show-user "$USER" --property=Linger --value 2>/dev/null) == yes ]]; then
  skip "linger enabled"
else
  log "Enabling systemd linger for $USER"
  loginctl enable-linger "$USER" </dev/null \
    && ok "linger enabled" \
    || warn "could not enable linger — run: loginctl enable-linger \$USER"
fi

# --- Start the stack and verify ---------------------------------------------------

lerd_active() {
  systemctl --user list-units --state=active 'lerd-*' --no-legend 2>/dev/null | grep -q . \
    || podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^lerd-'
}

if [[ $LERD_CHANGED == 1 ]] || ! lerd_active; then
  log "Starting the lerd stack"
  "$LERD_BIN" start </dev/null && ok "lerd started" || warn "'lerd start' failed — run it by hand"
  log "Verifying with 'lerd doctor'"
  "$LERD_BIN" doctor </dev/null || warn "'lerd doctor' reported problems — run it by hand for details"
else
  skip "lerd stack (already running)"
fi

ok "Lerd ready — projects serve at https://<name>.test (docs: https://lerd.sh)"
