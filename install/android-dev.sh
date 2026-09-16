#!/bin/bash
# Android development toolchain — terminal-only, no root required.
#
# Everything lives in ~/Android/Sdk, owned by the user: Google's SDK
# command-line tools (the `android` CLI; sdkmanager/avdmanager ship alongside
# it), the packages an Expo/React Native build needs (platform-tools, the
# Android 16 / API 36 platform, build-tools, the emulator), one x86_64 system
# image and a matching AVD to run it on. ANDROID_HOME and PATH are exported
# by the stowed bash config; projects pin their own JDK via mise (Gradle
# rejects JDKs newer than it supports, so java@latest alone is not enough).
#
# Idempotent: each piece is only downloaded/created when its marker on disk
# is missing, so reruns fill the gaps and skip the rest.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
API=36 # Android 16 (Baklava) — the platform current Expo SDKs build against
BUILD_TOOLS_VERSION=36.0.0
SYSTEM_IMAGE="system-images;android-$API;google_apis;x86_64"
AVD_NAME="Pixel_7_API_$API"

cli=$ANDROID_HOME/cmdline-tools/latest/bin/android

# The SDK tools are Java programs; mise is where oh-my-chy keeps the JDK
if ! command -v java &>/dev/null; then
  if command -v mise &>/dev/null && mise where java &>/dev/null; then
    export PATH="$(mise where java)/bin:$PATH"
  else
    die "no JDK found — let the dev environment step install one first (mise java)"
  fi
fi

# KVM is the difference between a usable emulator and a slideshow
if [[ -w /dev/kvm ]]; then
  skip "KVM acceleration"
else
  warn "/dev/kvm missing or not writable — the emulator will be very slow; check BIOS virtualization and KVM permissions"
fi

# --- SDK command-line tools --------------------------------------------------

if [[ -x $cli ]]; then
  skip "Android cmdline-tools"
else
  log "Downloading Android SDK command-line tools"
  url=$(curl -s https://dl.google.com/android/repository/repository2-3.xml \
    | grep -o 'commandlinetools-linux-[0-9]*_latest\.zip' | sort -Vu | tail -1 || true)
  [[ -n $url ]] || die "could not resolve the current cmdline-tools download URL"
  tmp=$(mktemp -d)
  curl -sS --fail -o "$tmp/tools.zip" "https://dl.google.com/android/repository/$url" </dev/null
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q "$tmp/tools.zip" -d "$ANDROID_HOME/cmdline-tools"
  # Google ships cmdline-tools/cmdline-tools; the SDK layout expects .../latest
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
  ok "Android cmdline-tools"
fi

# --- SDK packages -------------------------------------------------------------
# `android sdk install` picks the latest version of each package and handles
# license acceptance itself (sdkmanager's separate --licenses step is gone).
# Reruns leave installed packages alone, and the marker check below makes
# each install a no-op once its files exist.

install_package() {
  local pkg=$1 marker=$2
  if compgen -G "$ANDROID_HOME/$marker" >/dev/null; then
    skip "$pkg"
  else
    log "Installing $pkg (this can take a while)"
    "$cli" --sdk="$ANDROID_HOME" sdk install "$pkg" </dev/null \
      && ok "$pkg" \
      || die "installing $pkg failed — run: android --sdk=$ANDROID_HOME sdk install '$pkg'"
  fi
}

install_package "platform-tools" "platform-tools/adb"
install_package "emulator" "emulator/emulator"
install_package "platforms;android-$API" "platforms/android-$API/build.prop"
# The CLI needs an explicit version here — a bare 'build-tools' resolves to nothing
install_package "build-tools;$BUILD_TOOLS_VERSION" "build-tools/*"
install_package "$SYSTEM_IMAGE" "system-images/android-$API/google_apis/x86_64/system.img"

# --- Virtual device ------------------------------------------------------------

if [[ -d $HOME/.android/avd/$AVD_NAME.avd ]]; then
  skip "AVD $AVD_NAME"
else
  log "Creating AVD $AVD_NAME (Pixel 7, API $API)"
  # avdmanager asks about a custom hardware profile; the piped 'no' answers it
  echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
    -n "$AVD_NAME" -k "$SYSTEM_IMAGE" -d pixel_7 \
    && ok "AVD $AVD_NAME" \
    || die "AVD creation failed — run: avdmanager create avd -n $AVD_NAME -k '$SYSTEM_IMAGE' -d pixel_7"
fi

ok "Android toolchain ready — start it with: emulator -avd $AVD_NAME"
