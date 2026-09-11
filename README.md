# oh-my-chy

My personal setup for [Omarchy](https://omarchy.org). One script that turns a fresh Omarchy install into *my* machine: the apps I need, my shell, my git config, my prompt — and it's safe to run again and again whenever I change something.

It stays close to how Omarchy works: bash instead of zsh, Starship for the prompt (wired into Omarchy's theme system), mise for dev runtimes, and Omarchy's own helpers for installing packages. Nothing gets fought with — only extended.

## What you get

- **Apps**: yazi, cloc, nmap and a few other CLI tools Omarchy doesn't ship, plus VS Code
- **Browser**: Brave, installed through Omarchy's browser setup and set as the system default
- **Dev environment**: PHP + Composer + Laravel via Omarchy's dev-env installer, Node.js through mise
- **AI agents**: Codex, Gemini and OpenCode, installed the same way Omarchy's agent picker does it (via mise). OpenCode is the default one — `omarchy-agent` and friends will launch it
- **Bar plugins**: Omarchy shell plugins like [ai-usagebar](https://github.com/akitaonrails/ai-usagebar) (AI plan usage in the bar), installed and enabled through Omarchy's own plugin system
- **Theme**: my own [deep-code](https://github.com/pdaether/omarchy-deep-code-theme) and [deep-code-neon](https://github.com/pdaether/omarchy-deep-code-neon-theme) themes plus two curated ones ([hermtang](https://github.com/AIowa-LLC/awesome-omarchy-themes), perfect-computer), all in `~/.config/omarchy/themes/` — deep-code-neon is the active one
- **Shell**: my aliases, functions and exports layered on top of Omarchy's defaults (`c` still means "go to ~/code" for me)
- **Prompt**: a Starship prompt showing directory, git branch/status, language versions and command duration — in the current Omarchy theme colors, updating live when I switch themes
- **Tmux**: mouse support, status bar on top, my resize keys and a yazi popup, added to Omarchy's config without replacing it
- **SSH agent**: OpenSSH's socket-activated user agent, so key passphrases are asked once and cached for the whole session (terminal, git, VS Code) — Omarchy ships no running agent, it just assumes you'll use 1Password
- **Idle & lock**: the screensaver kicks in after 15 minutes and the system locks after an hour of inactivity, instead of Omarchy's 2.5/5 minute defaults

## Getting started

Clone the repo wherever you like — the installer doesn't care where it lives:

```bash
git clone <repo-url>
cd oh-my-chy
./install.sh
```

That's it. Open a new terminal and everything is in place.

The script can be run as often as you like. Already-done work is skipped, changed pieces are updated in place, and if something of yours would be overwritten it's backed up first (to `~/.local/share/oh-my-chy/backups/<timestamp>/`) rather than lost.

### Skipping parts

Not every machine needs everything. Any step can be left out:

```bash
SKIP_VSCODE=1 ./install.sh    # leave VS Code alone
SKIP_BRAVE=1 ./install.sh     # don't install Brave or change the default browser
SKIP_DEV_ENV=1 ./install.sh   # no PHP/Laravel/Node setup
SKIP_AGENTS=1 ./install.sh    # don't touch Codex/Gemini/OpenCode
SKIP_PLUGINS=1 ./install.sh   # don't install or enable Omarchy plugins
SKIP_THEME=1 ./install.sh     # don't install or switch any themes
SKIP_PKGS=1 ./install.sh      # skip package installation
SKIP_STOW=1 ./install.sh      # skip dotfiles, only do packages + config blocks
SKIP_SSH_AGENT=1 ./install.sh # don't enable the ssh-agent user service
```

## How it's organized

Each dotfile group lives in its own folder, mirroring paths under your home directory so [GNU Stow](https://www.gnu.org/software/stow/) can link them individually:

```
bash/       → ~/.config/bash/{exports,aliases,functions}.sh
git/        → ~/.gitconfig, ~/.gitignore
starship/   → ~/.config/omarchy/themed/starship.toml.tpl
ssh/        → ~/.config/environment.d/10-ssh-agent.conf
yazi/       → ~/.config/yazi/theme.toml

install/pacman.txt       packages to add, one per line
install/plugins.txt      Omarchy shell plugins (<git-url> [aur-pkg|-] [bar-section])
install/tmux-extra.conf  tmux settings merged into Omarchy's tmux.conf
install.sh               the installer, lib/common.sh its helpers
```

## The theme-aware prompt

This one took some digging: Omarchy re-renders every `*.tpl` file in `~/.config/omarchy/themed/` each time you switch themes, filling in placeholders like `{{ accent }}` or `{{ blue }}` with the active palette. My starship template lives there, and `~/.config/starship.toml` just points at the rendered result — so switching from, say, Tokyo Night to Catppuccin recolors the terminal *and* the prompt together. No manual syncing.

## Changing things later

- **New app** → add a line to `install/pacman.txt`, rerun `./install.sh`
- **New plugin** → add `<git-url> [aur-pkg|-] [left|center|right]` to `install/plugins.txt`, rerun `./install.sh`
- **Another theme from the [awesome-omarchy-themes](https://github.com/AIowa-LLC/awesome-omarchy-themes) collection** → add its folder name to `CURATED_THEMES` in `install.sh`, rerun
- **New alias or function** → edit the matching file in `bash/.config/bash/`, open a new terminal. No rerun needed; the files are sourced live
- **New config file** → create a folder that mirrors its path under `$HOME`, add it to `STOW_PACKAGES` in `install.sh`, rerun
- **Tweak tmux** → edit `install/tmux-extra.conf`, rerun, then reload tmux
- **Different idle timings** → change `IDLE_SCREENSAVER_SECONDS` / `IDLE_LOCK_SECONDS` at the top of the idle section in `install.sh`, rerun (seconds)

More details on conventions and testing live in [AGENTS.md](AGENTS.md).

## Coming from the old Ubuntu dotfiles?

A few old friends didn't make the trip, on purpose: nala and apt (it's Arch now), nvm (mise does this better), Oh My Zsh (Starship covers the prompt, bash covers the rest), conky (Omarchy's bar and btop), Valet+ (plain pacman PHP now), xclip (wl-copy — we're on Wayland).
