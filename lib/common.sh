#!/bin/bash
# Shared helpers for oh-my-chy install scripts. Source this, don't run it.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.local/share/oh-my-chy/backups/$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m–\033[0m %s (already done)\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Move a real file/dir out of the way so stow/symlinks can take over.
# Symlinks that already point into this repo are left untouched.
backup_path() {
  local target=$1 resolved parent parent_resolved

  # Refuse paths beneath directory symlinks owned by anything else, even if
  # the final target does not exist yet. Otherwise Stow could write through
  # that symlink and modify files outside the home directory.
  parent=$(dirname "$target")
  while [[ $parent == "$HOME"/* ]]; do
    if [[ -L $parent ]]; then
      parent_resolved=$(readlink -f -- "$parent" 2>/dev/null || true)
      [[ $parent_resolved == "$REPO_DIR"/* ]] \
        || die "cannot safely manage ${target#$HOME/}: parent ${parent#$HOME/} is a symlink outside $REPO_DIR"
    fi
    parent=$(dirname "$parent")
  done

  [[ -e $target || -L $target ]] || return 0

  # Stow can link a parent directory rather than each file. Resolve the whole
  # path so reruns never move files out of this repository through that link.
  resolved=$(readlink -f -- "$target" 2>/dev/null || true)
  if [[ $resolved == "$REPO_DIR"/* ]]; then
    return 0
  fi

  mkdir -p "$BACKUP_DIR/$(dirname "${target#$HOME/}")"
  mv "$target" "$BACKUP_DIR/${target#$HOME/}"
  warn "backed up existing ${target#$HOME/} to $BACKUP_DIR"
}

# Idempotently ensure a marked block exists in a file. If the markers are
# found, the old block is replaced; otherwise the block is appended.
upsert_block() {
  local file=$1 block=$2
  local begin='# >>> oh-my-chy >>>'
  local end='# <<< oh-my-chy <<<'

  [[ -f $file ]] || touch "$file"

  # Remove any existing block, then append the fresh one
  if grep -qF "$begin" "$file"; then
    sed -i "/^$begin$/,/^$end$/d" "$file"
  fi
  printf '\n%s\n%s\n%s\n' "$begin" "$block" "$end" >>"$file"
}
