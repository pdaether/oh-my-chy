#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
mkdir -p "$HOME"
source "$ROOT/lib/common.sh"

STOW_PACKAGES=(bash git starship ssh yazi)
STOW_FILES=(
  bash/.config/bash/exports.sh
  bash/.config/bash/aliases.sh
  bash/.config/bash/functions.sh
  git/.gitconfig
  git/.gitignore
  starship/.config/omarchy/themed/starship.toml.tpl
  ssh/.config/environment.d/10-ssh-agent.conf
  yazi/.config/yazi/theme.toml
)

stow_once() {
  local f pkg rel

  for f in "${STOW_FILES[@]}"; do
    rel=${f#*/}
    backup_path "$HOME/$rel"
  done

  for pkg in "${STOW_PACKAGES[@]}"; do
    stow --restow --dir="$ROOT" --target="$HOME" "$pkg"
  done

  for f in "${STOW_FILES[@]}"; do
    rel=${f#*/}
    [[ $(readlink -f "$HOME/$rel") == "$ROOT/$f" ]]
  done
}

before=$(for f in "${STOW_FILES[@]}"; do sha256sum "$ROOT/$f"; done)
stow_once
stow_once
after=$(for f in "${STOW_FILES[@]}"; do sha256sum "$ROOT/$f"; done)

[[ $before == "$after" ]]
bash --rcfile "$HOME/.config/bash/aliases.sh" -ic 'alias ll >/dev/null; alias lg >/dev/null' 2>/dev/null

mkdir -p "$TEST_DIR/external"
ln -s "$TEST_DIR/external" "$HOME/external-link"
if (backup_path "$HOME/external-link/missing-file") >/dev/null 2>&1; then
  printf 'backup_path accepted an unmanaged symlinked parent\n' >&2
  exit 1
fi

printf 'stow idempotency test passed\n'
