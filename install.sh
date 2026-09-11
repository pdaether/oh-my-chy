#!/bin/bash
# oh-my-chy — one-shot setup for Omarchy (safe to run repeatedly).
#
# Idempotent by design:
#   * packages are only installed if missing (omarchy-pkg-add, or
#     omarchy-pkg-aur-add for aur: entries in pacman.txt)
#   * stow skips links that are already in place; conflicting real files get
#     backed up to ~/.local/share/oh-my-chy/backups/<timestamp>/
#   * marked blocks in .bashrc / tmux.conf are replaced in place, never duplicated
#
# Optional skips (env vars): SKIP_PKGS=1  SKIP_VSCODE=1  SKIP_BRAVE=1  SKIP_DEV_ENV=1  SKIP_AGENTS=1  SKIP_PLUGINS=1  SKIP_THEME=1  SKIP_STOW=1  SKIP_SSH_AGENT=1

set -euo pipefail

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

if [[ ! -x /usr/bin/omarchy ]]; then
  echo "Error: this machine is not running Omarchy (/usr/bin/omarchy missing)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "oh-my-chy setup starting (repo: $REPO_DIR)"

log "Requesting sudo (kept alive for the run)"
sudo -v

# ---------------------------------------------------------------------------
# Packages (delta vs Omarchy's preinstalled set)
# ---------------------------------------------------------------------------

if [[ ${SKIP_PKGS:-0} == 1 ]]; then
  skip "Packages (SKIP_PKGS=1)"
else
  log "Installing package delta"
  while IFS= read -r line; do
    [[ -z $line || $line == \#* ]] && continue
    # 'aur:<name>' comes from the AUR; everything else is an official-repo package
    pkg=$line helper=omarchy-pkg-add
    if [[ $pkg == aur:* ]]; then
      pkg=${pkg#aur:} helper=omarchy-pkg-aur-add
    fi
    if pacman -Q "$pkg" &>/dev/null; then
      skip "$pkg"
    else
      "$helper" "$pkg" </dev/null && ok "$pkg"
    fi
  done <"$REPO_DIR/install/pacman.txt"
fi

# ---------------------------------------------------------------------------
# VS Code (optional)
# ---------------------------------------------------------------------------

if [[ ${SKIP_VSCODE:-0} == 1 ]]; then
  skip "VS Code (SKIP_VSCODE=1)"
elif command -v code &>/dev/null; then
  skip "VS Code"
else
  log "Installing VS Code via Omarchy"
  omarchy-install-editor-vscode >/dev/null 2>&1 || warn "VS Code installer failed — run 'omarchy install editor vscode' manually"
fi

# ---------------------------------------------------------------------------
# Brave as default browser (optional)
# ---------------------------------------------------------------------------

if [[ ${SKIP_BRAVE:-0} == 1 ]]; then
  skip "Brave (SKIP_BRAVE=1)"
else
  if command -v brave &>/dev/null; then
    skip "Brave browser"
  else
    log "Installing Brave via Omarchy"
    omarchy-install-browser brave </dev/null || warn "Brave installer failed — run 'omarchy install browser brave' manually"
  fi

  if [[ $(omarchy-default-browser) == brave ]]; then
    skip "Brave is already the default browser"
  else
    log "Setting Brave as the default browser"
    omarchy-default-browser brave </dev/null
  fi
fi

# ---------------------------------------------------------------------------
# ChatGPT Desktop — the same package Omarchy's install menu uses
# ---------------------------------------------------------------------------

if pacman -Q openai-codex-desktop &>/dev/null; then
  skip "ChatGPT Desktop"
else
  log "Installing ChatGPT Desktop via Omarchy"
  omarchy-pkg-add openai-codex-desktop </dev/null \
    || warn "ChatGPT install failed — run 'omarchy-pkg-add openai-codex-desktop' manually"
fi

# ---------------------------------------------------------------------------
# Dev environment (PHP/Laravel + Node + Go + Java via mise) — replaces nvm + valet.sh
# ---------------------------------------------------------------------------

if [[ ${SKIP_DEV_ENV:-0} == 1 ]]; then
  skip "Dev environment (SKIP_DEV_ENV=1)"
else
  if command -v php &>/dev/null && command -v composer &>/dev/null && command -v laravel &>/dev/null; then
    skip "PHP/Composer/Laravel toolchain"
  else
    log "Installing PHP + Laravel dev environment (pacman php, composer, xdebug)"
    omarchy-install-dev-env laravel
  fi

  if command -v mise &>/dev/null; then
    log "Ensuring global node@lts via mise (keeps other mise tools untouched)"
    mise use --global node@lts
  fi

  # Go, the same way Omarchy's Install -> Development -> Go does it
  if command -v go &>/dev/null; then
    skip "Go toolchain"
  elif command -v mise &>/dev/null; then
    log "Installing Go via mise"
    mise use --global go@latest </dev/null && ok "go"
  else
    warn "mise missing — run 'omarchy install dev-env go' manually"
  fi

  # Java, the same way Omarchy's Install -> Development -> Java does it
  if mise where java &>/dev/null; then
    skip "Java toolchain"
  elif command -v mise &>/dev/null; then
    log "Installing Java via mise"
    mise use --global java@latest </dev/null && ok "java"
  else
    warn "mise missing — run 'omarchy install dev-env java' manually"
  fi
fi

# ---------------------------------------------------------------------------
# AI coding agents (Codex, Gemini, OpenCode) — mise-managed, the same
#    mechanism 'omarchy default agent' uses, minus the interactive launcher
# ---------------------------------------------------------------------------

if [[ ${SKIP_AGENTS:-0} == 1 ]]; then
  skip "AI agents (SKIP_AGENTS=1)"
else
  log "Installing AI agents via mise"
  for agent_pkg in codex gemini opencode; do
    if mise where "$agent_pkg" &>/dev/null; then
      skip "$agent_pkg"
    else
      mise use -g "$agent_pkg" </dev/null && ok "$agent_pkg"
    fi
  done

  # OpenCode stays the default agent (state file used by omarchy-agent)
  AGENT_FILE="$HOME/.config/omarchy/defaults/agent"
  if [[ $(cat "$AGENT_FILE" 2>/dev/null) == opencode ]]; then
    skip "OpenCode as default agent"
  else
    log "Setting OpenCode as the default agent"
    mkdir -p "$(dirname "$AGENT_FILE")"
    printf 'opencode\n' >"$AGENT_FILE"
  fi
fi

# ---------------------------------------------------------------------------
# Dotfiles via GNU Stow (one package per concern)
# ---------------------------------------------------------------------------

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

if [[ ${SKIP_STOW:-0} == 1 ]]; then
  skip "Stow (SKIP_STOW=1)"
else
  log "Stowing dotfile packages: ${STOW_PACKAGES[*]}"
  command -v stow &>/dev/null || die "stow is not installed but SKIP_STOW was not set"

  # The explicit manifest catches incomplete clones and also includes files
  # such as .gitignore that GNU Stow ignores by default.
  for f in "${STOW_FILES[@]}"; do
    [[ -f $REPO_DIR/$f ]] || die "missing $f; refusing to stow an incomplete dotfile set"
  done

  # Back up any real files that would conflict with our links
  for f in "${STOW_FILES[@]}"; do
    rel=${f#*/}
    backup_path "$HOME/$rel"
  done

  for pkg in "${STOW_PACKAGES[@]}"; do
    stow --restow --dir="$REPO_DIR" --target="$HOME" "$pkg" && ok "stowed $pkg"
  done

  # Do not report success unless every declared file resolves to its source.
  for f in "${STOW_FILES[@]}"; do
    rel=${f#*/}
    [[ $(readlink -f "$HOME/$rel" 2>/dev/null) == "$REPO_DIR/$f" ]] \
      || die "stow did not link ~/$rel to $f"
  done
fi

# ---------------------------------------------------------------------------
# Hook personal shell config into Omarchy's managed ~/.bashrc
# ---------------------------------------------------------------------------

log "Wiring ~/.bashrc to source oh-my-chy shell files"
BASHRC_BLOCK='for _f in ~/.config/bash/exports.sh ~/.config/bash/aliases.sh ~/.config/bash/functions.sh; do
  [[ -r $_f ]] && source "$_f"
done
unset _f'
upsert_block "$HOME/.bashrc" "$BASHRC_BLOCK"
ok "~/.bashrc updated"

if bash --noprofile --rcfile "$HOME/.bashrc" -ic \
  'alias ll >/dev/null && alias lg >/dev/null' </dev/null 2>/dev/null; then
  ok "shell aliases verified"
else
  die "~/.bashrc did not load the ll and lg aliases"
fi

# ---------------------------------------------------------------------------
# Extra tmux settings inside Omarchy's managed tmux.conf
# ---------------------------------------------------------------------------

log "Applying extra tmux settings (marked block)"
upsert_block "$HOME/.config/tmux/tmux.conf" "$(cat "$REPO_DIR/install/tmux-extra.conf")"
ok "tmux config updated"

# ---------------------------------------------------------------------------
# SSH agent: OpenSSH's socket-activated user unit (omacom/omarchy#1661)
#    Omarchy ships no running agent (it assumes a password-manager one such
#    as 1Password). This wires the plain ssh-agent instead: a per-user socket
#    unit starts it on first use, the stowed environment.d file exports
#    SSH_AUTH_SOCK for the whole session, and ~/.ssh/config gets
#    AddKeysToAgent so passphrases are asked once and then cached.
# ---------------------------------------------------------------------------

if [[ ${SKIP_SSH_AGENT:-0} == 1 ]]; then
  skip "SSH agent (SKIP_SSH_AGENT=1)"
else
  AGENT_SOCKET_PATH="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

  if [[ $(systemctl --user is-enabled ssh-agent.socket 2>/dev/null || true) == enabled ]]; then
    skip "ssh-agent user socket"
  else
    log "Enabling the OpenSSH ssh-agent user socket"
    if systemctl --user enable --now ssh-agent.socket </dev/null; then
      ok "ssh-agent.socket enabled (log out/in once so every app picks up SSH_AUTH_SOCK)"
    else
      warn "could not enable ssh-agent.socket — run: systemctl --user enable --now ssh-agent.socket"
    fi
  fi

  # Make the socket visible to apps spawned from the user manager right away,
  # without waiting for the next login
  if [[ $(systemctl --user show-environment 2>/dev/null | awk -F= '$1 == "SSH_AUTH_SOCK" {print $2}') == "$AGENT_SOCKET_PATH" ]]; then
    skip "SSH_AUTH_SOCK in user manager environment"
  else
    systemctl --user set-environment "SSH_AUTH_SOCK=$AGENT_SOCKET_PATH" </dev/null \
      && ok "SSH_AUTH_SOCK exported to the session" \
      || warn "could not set SSH_AUTH_SOCK in the user manager environment"
  fi

  # First-match-wins in ssh_config, so an appended 'Host *' block only fills
  # the gap when the option is not set anywhere else
  if grep -qi 'AddKeysToAgent' "$HOME/.ssh/config" 2>/dev/null; then
    skip "AddKeysToAgent in ~/.ssh/config"
  else
    log "Adding AddKeysToAgent to ~/.ssh/config"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    printf '\n# >>> oh-my-chy >>>\nHost *\n    AddKeysToAgent yes\n# <<< oh-my-chy <<<\n' >>"$HOME/.ssh/config"
    ok "~/.ssh/config updated"
  fi
fi

# ---------------------------------------------------------------------------
# Omarchy shell plugins
#    (install/plugins.txt: <git-url> [aur-dependency|-] [left|center|right])
# ---------------------------------------------------------------------------

plugin_id_from_url() {
  # Resolve a plugin git-url to its installed Omarchy id. Plugins may declare
  # a bare id ('omaconnect') or an owner-prefixed one ('owner.repo'), so match
  # the repo name against the plugin list first. The id can also drop a
  # repo-name 'omarchy-' prefix (jankeesvw/omarchy-text-transform is installed
  # as 'jankeesvw.text-transform'); fall back to owner.repo with the same rule.
  local url=${1%.git}
  url=${url%/}
  local short=${url##*/} match
  short=${short,,}
  local bare=${short#omarchy-}
  match=$(omarchy plugin list 2>/dev/null | awk -v s="$short" -v b="$bare" '
    tolower($1) == s || $1 ~ "\\." s "$" ||
    tolower($1) == b || $1 ~ "\\." b "$" {print $1; exit}')
  if [[ -z $match ]]; then
    local path=${url##*/github.com/}
    local name=${path##*/}
    match="${path%%/*}.${name#omarchy-}"
  fi
  printf '%s\n' "$match"
}

plugin_state() {
  # Prints the state (enabled/disabled) of a plugin id, empty if unknown.
  omarchy plugin list 2>/dev/null | awk -v id="$1" '$1 == id {print $2}'
}

plugin_section() {
  # Prints the bar section (left/center/right) a plugin id currently sits in.
  jq -r --arg id "$1" \
    '.bar.layout | to_entries[] | select(any(.value[]; .id == $id)) | .key' \
    "$HOME/.config/omarchy/shell.json" 2>/dev/null
}

if [[ ${SKIP_PLUGINS:-0} == 1 ]]; then
  skip "Omarchy plugins (SKIP_PLUGINS=1)"
else
  log "Installing Omarchy shell plugins"
  while IFS=' ' read -r url aur_pkg section; do
    [[ -z $url || $url == \#* ]] && continue
    [[ $aur_pkg == "-" || $aur_pkg == "none" ]] && aur_pkg=""

    if [[ -n $aur_pkg ]] && ! pacman -Q "$aur_pkg" &>/dev/null; then
      log "Adding AUR dependency $aur_pkg"
      omarchy pkg aur add "$aur_pkg" </dev/null || warn "could not add $aur_pkg — install it manually"
    fi

    plugin_id="$(plugin_id_from_url "$url")"

    # Make sure the widget sits in the requested bar section
    ensure_section() {
      [[ -z $section ]] && return 0
      if [[ $(plugin_section "$plugin_id") != "$section" ]]; then
        omarchy plugin enable "$plugin_id" --section "$section" </dev/null
      fi
    }

    case "$(plugin_state "$plugin_id")" in
      enabled)
        if ensure_section; then
          skip "$plugin_id"
        else
          ok "$plugin_id moved to $section"
        fi
        ;;
      disabled)
        log "Enabling plugin $plugin_id"
        omarchy plugin enable "$plugin_id" </dev/null && ensure_section && ok "$plugin_id enabled"
        ;;
      *)
        log "Adding plugin from $url"
        if omarchy plugin add "$url" --enable --yes </dev/null; then
          # On a fresh install the id isn't resolvable from the plugin list
          # until now, so re-resolve before pinning the section
          plugin_id="$(plugin_id_from_url "$url")"
          ensure_section && ok "$plugin_id"
        else
          warn "plugin install failed for $url — run 'omarchy plugin add $url --enable' manually"
        fi
        ;;
    esac
  done <"$REPO_DIR/install/plugins.txt"
fi

# ---------------------------------------------------------------------------
# Idle & lock timings in Omarchy's shell.json — screensaver after 15 minutes,
#     auto-lock after an hour (Omarchy defaults: 150s / 300s). The shell
#     hot-reloads shell.json, so no restart is needed.
# ---------------------------------------------------------------------------

IDLE_SCREENSAVER_SECONDS=900 # 15 minutes
IDLE_LOCK_SECONDS=3600       # 1 hour
SHELL_JSON_PATH="$HOME/.config/omarchy/shell.json"

if [[ ! -f $SHELL_JSON_PATH ]]; then
  warn "no ~/.config/omarchy/shell.json — log into Omarchy once, then rerun"
else
  idle_already_set=$(jq -r --argjson s "$IDLE_SCREENSAVER_SECONDS" --argjson l "$IDLE_LOCK_SECONDS" \
    '(.idle.screensaver == $s) and (.idle.lock == $l)' "$SHELL_JSON_PATH" 2>/dev/null)
  if [[ $idle_already_set == true ]]; then
    skip "idle timings (15 min screensaver / 1 h lock)"
  else
    log "Setting idle timings (15 min screensaver, 1 h lock)"
    idle_tmp=$(mktemp "$(dirname "$SHELL_JSON_PATH")/.shell.json.XXXXXX")
    if jq --argjson s "$IDLE_SCREENSAVER_SECONDS" --argjson l "$IDLE_LOCK_SECONDS" \
      '.idle.screensaver = $s | .idle.lock = $l' "$SHELL_JSON_PATH" >"$idle_tmp" \
      && jq empty "$idle_tmp" >/dev/null; then
      chmod --reference="$SHELL_JSON_PATH" "$idle_tmp"
      mv "$idle_tmp" "$SHELL_JSON_PATH"
      ok "idle timings set in shell.json"
    else
      rm -f "$idle_tmp"
      warn "could not update shell.json — set idle.screensaver=$IDLE_SCREENSAVER_SECONDS and idle.lock=$IDLE_LOCK_SECONDS manually"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Firewall: open KDE Connect ports (1714-1764 tcp+udp) — needed by the
#     OmaConnect plugin; see install/firewall.sh for why
# ---------------------------------------------------------------------------

log "Ensuring firewall allows KDE Connect"
"$REPO_DIR/install/firewall.sh"

# ---------------------------------------------------------------------------
# GTK file chooser: show hidden files in open/save dialogs
# ---------------------------------------------------------------------------

if [[ $(gsettings get org.gtk.Settings.FileChooser show-hidden 2>/dev/null) == "true" ]]; then
  skip "hidden files shown in GTK file dialogs"
else
  log "Showing hidden files in GTK file dialogs"
  gsettings set org.gtk.Settings.FileChooser show-hidden true </dev/null \
    && ok "GTK show-hidden enabled" \
    || warn "could not set gsettings key — run 'gsettings set org.gtk.Settings.FileChooser show-hidden true' manually"
fi

# ---------------------------------------------------------------------------
# Omarchy themes: pdaether's deep-code + deep-code-neon (the default), plus
#    hermtang + perfect-computer from the AIowa-LLC/awesome-omarchy-themes
#    collection
# ---------------------------------------------------------------------------

if [[ ${SKIP_THEME:-0} == 1 ]]; then
  skip "Themes (SKIP_THEME=1)"
else
  install_or_update_theme() {
    local repo_url=$1 theme_name=$2
    local theme_dir="$HOME/.config/omarchy/themes/$theme_name"

    if [[ -d $theme_dir/.git ]]; then
      skip "$theme_name theme installed"
      # Normalize the remote to HTTPS so updates don't depend on SSH keys
      git -C "$theme_dir" remote set-url origin "$repo_url"
      if git -C "$theme_dir" pull --ff-only --quiet </dev/null 2>/dev/null; then
        ok "$theme_name theme up to date"
      else
        warn "could not update $theme_name theme (offline?)"
      fi
    else
      log "Installing $theme_name theme from $repo_url"
      git clone --quiet "$repo_url" "$theme_dir" </dev/null && ok "$theme_name theme"
    fi
  }

  install_or_update_theme "https://github.com/pdaether/omarchy-deep-code-theme.git" "deep-code"
  install_or_update_theme "https://github.com/pdaether/omarchy-deep-code-neon-theme.git" "deep-code-neon"

  # These two live as subdirectories of the awesome-omarchy-themes monorepo:
  # keep a shallow clone in the cache and rsync only the wanted themes into
  # place, so the rest of the collection never lands in ~/themes
  CURATED_THEMES_REPO="https://github.com/AIowa-LLC/awesome-omarchy-themes.git"
  CURATED_THEMES=(hermtang perfect-computer)
  CURATED_CACHE="$HOME/.local/share/oh-my-chy/cache/awesome-omarchy-themes"

  if [[ -d $CURATED_CACHE/.git ]]; then
    git -C "$CURATED_CACHE" remote set-url origin "$CURATED_THEMES_REPO"
    if git -C "$CURATED_CACHE" pull --ff-only --depth 1 --quiet </dev/null 2>/dev/null; then
      ok "awesome-omarchy-themes collection up to date"
    else
      warn "could not update awesome-omarchy-themes (offline?)"
    fi
  else
    log "Cloning the awesome-omarchy-themes collection"
    git clone --quiet --depth 1 "$CURATED_THEMES_REPO" "$CURATED_CACHE" </dev/null \
      && ok "awesome-omarchy-themes collection"
  fi

  for curated_theme in "${CURATED_THEMES[@]}"; do
    if [[ -d $CURATED_CACHE/themes/$curated_theme ]]; then
      mkdir -p "$HOME/.config/omarchy/themes"
      rsync -a --delete "$CURATED_CACHE/themes/$curated_theme/" \
        "$HOME/.config/omarchy/themes/$curated_theme/" \
        && ok "$curated_theme theme in sync"
    else
      warn "$curated_theme not found in awesome-omarchy-themes — theme skipped"
    fi
  done

  DEFAULT_THEME_NAME="deep-code-neon"
  CURRENT_THEME_NAME="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
  if [[ $CURRENT_THEME_NAME == "$DEFAULT_THEME_NAME" ]]; then
    skip "deep-code-neon is the active theme"
  else
    log "Setting deep-code-neon as the active theme"
    OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "$DEFAULT_THEME_NAME" </dev/null && ok "deep-code-neon theme applied"
  fi
fi

# ---------------------------------------------------------------------------
# Theme-aware Starship prompt
# ---------------------------------------------------------------------------

log "Rendering themed starship config and linking it"
OMARCHY_THEME_HEADLESS=1 omarchy-theme-refresh || warn "theme refresh failed — prompt colors may be stale"

RENDERED_STARSHIP="$HOME/.local/state/omarchy/current/theme/starship.toml"
STARSHIP_LINK="$HOME/.config/starship.toml"

if [[ ! -f $RENDERED_STARSHIP ]]; then
  warn "no rendered starship.toml found; keeping existing prompt config"
elif [[ $(readlink "$STARSHIP_LINK" 2>/dev/null) == "$RENDERED_STARSHIP" ]]; then
  skip "starship config already linked"
else
  backup_path "$STARSHIP_LINK"
  ln -sfn "$RENDERED_STARSHIP" "$STARSHIP_LINK"
  ok "~/.config/starship.toml -> $RENDERED_STARSHIP"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log "Setup complete."
echo "
Next steps:
  * Open a new terminal (or run: exec \$SHELL -l) for aliases/prompt
  * Reload tmux config with prefix+r, or run: omarchy restart tmux
  * Your prompt follows Omarchy themes automatically (starship template)
Backups of overwritten files (if any): ${BACKUP_DIR:-none}
"
