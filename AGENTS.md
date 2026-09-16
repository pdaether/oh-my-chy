# oh-my-chy

Patrick's personal Omarchy setup: package delta + dotfiles, applied by an idempotent installer (`install.sh`). Replaces the old Ubuntu dotfiles repo.

## Principles

- **Omarchy-native**: bash (not zsh), Starship prompt via theme templates in `~/.config/omarchy/themed/`, mise for runtimes, `omarchy-pkg-add` / `omarchy-install-dev-env` for packages. Never fight Omarchy's managed files — extend them with marked blocks instead.
- **Idempotent**: `./install.sh` must be safe to run any number of times. Every step either skips when done or replaces its own output in place (`# >>> oh-my-chy >>>` markers, stow links, symlinks).
- **Never clobber**: real files that would conflict with stow links get moved to `~/.local/share/oh-my-chy/backups/<timestamp>/` first.

## Structure

- `install.sh` — orchestrator; steps are banner-commented (no numbers — new steps don't force renumbering) and guarded; optional env-var skips (`SKIP_PKGS`, `SKIP_VSCODE`, `SKIP_BRAVE`, `SKIP_VOXTYPE`, `SKIP_DEV_ENV`, `SKIP_AGENTS`, `SKIP_ANDROID_DEV`, `SKIP_LERD`, `SKIP_PLUGINS`, `SKIP_THEME`, `SKIP_STOW`, `SKIP_SSH_AGENT`)
- `lib/common.sh` — helpers: `log/ok/skip/warn/die`, `backup_path`, `upsert_block`
- `install/pacman.txt` — plain-text package list, one per line, `#` comments allowed; `aur:<name>` entries come from the AUR and install via `omarchy-pkg-aur-add` (yay), the rest via `omarchy-pkg-add`
- `install/plugins.txt` — Omarchy shell plugins, one per line: `<git-url> [aur-dependency|-] [left|center|right]`; the AUR package (if listed) is installed via `omarchy pkg aur add` before the plugin is added/enabled, and an optional bar section pins the widget there via `omarchy plugin enable <id> --section <s>`
- `install/tmux-extra.conf` — tmux settings appended as a marked block to Omarchy's `~/.config/tmux/tmux.conf`
- `install/android-dev.sh` — Android toolchain without root: Google's SDK cmdline-tools (downloaded into `~/Android/Sdk`, deliberately not the AUR `/opt/android-sdk` package with its group permissions), then `android sdk install` for platform-tools, emulator, `platforms;android-36`, `build-tools;36.0.0` (a bare `build-tools` resolves to nothing) and the `google_apis` x86_64 system image, plus a `Pixel_7_API_36` AVD via `avdmanager`. Idempotency is marker-based (each piece is only fetched when its files are missing). `ANDROID_HOME`/PATH are exported by the bash stow, not this script; Gradle needs a project-local mise JDK pin since `java@latest` is too new for the Android Gradle Plugin
- Lerd (https://lerd.sh, Podman-powered local PHP dev environment) follows lerd.sh/getting-started/omarchy: its Arch prerequisites (`podman`, `crun`, `nss`/certutil, `dnsmasq` for NM-only hosts) come from `pacman.txt` so the official installer has nothing to prompt for, `install/lerd.sh` downloads the binary into `~/.local/bin` (update by hand with `lerd update`), and first-time setup is `lerd install --dns managed` (https://`*.test` with mkcert-trusted certs) — lerd's own sudo step, which is why the orchestrator caches sudo in its preflight. Linger is enabled so lerd's user units survive logout, `lerd start`/`lerd doctor` only run when something changed or nothing lerd-owned is active. The script pins `~/.local/bin` into its own PATH first: the official installer would otherwise append an unmarked PATH line to Omarchy's managed `~/.bashrc`. The guide's optional bar widget ships via `plugins.txt`
- Stow packages (each dir mirrors `$HOME` layout): `bash/`, `git/`, `starship/`, `ssh/`, `yazi/`
  - new packages must be added to `STOW_PACKAGES` in `install.sh`
- SSH agent: the socket-activated OpenSSH user unit (`ssh-agent.socket`) is enabled in its own step; the `ssh/` package stows the `environment.d` file exporting `SSH_AUTH_SOCK` for the graphical session (approach of omacom/omarchy#1661 — Omarchy itself assumes a 1Password agent). `~/.ssh/config` is personal and never stowed; the installer only appends `AddKeysToAgent yes` when the option is absent
- Voxtype dictation starts from Omarchy's `omarchy-voxtype-install` menu script (`wtype` + `aur:voxtype-bin` via `pacman.txt`, seed default config only when missing, `voxtype setup systemd`) but runs NVIDIA's **Parakeet TDT 0.6B v3 int8** instead of Whisper: the step switches the binary variant via `sudo voxtype setup onnx --enable`, downloads the model through `/usr/lib/voxtype/voxtype-onnx-avx2` (the default whisper build can neither download parakeet models nor set `parakeet.*` keys), and pins `engine = parakeet`, `parakeet.model = parakeet-tdt-0.6b-v3-int8`, `parakeet.model_type = tdt`. Rationale: Parakeet covers German + English natively and is ~10x faster than Whisper medium (CPU one-pass TDT vs GPU whisper) with built-in punctuation; voxtype's ONNX builds have no Vulkan backend, so the iGPU would idle anyway. The downloaded whisper `medium` model stays on disk as personal fallback. Everything else in `~/.config/voxtype/config.toml` is personal and never overwritten

## Conventions

- Shell files in `bash/.config/bash/*.sh` are sourced by the marked block in `~/.bashrc`; they load after Omarchy's defaults so aliases there intentionally override Omarchy ones (e.g. `c` = cd to ~/code, not opencode)
- Aliases/functions must be bash-compatible (no zsh `compdef`/suffix aliases); Wayland tools only (`wl-copy`, no xclip/pbcopy)
- The starship template may use Omarchy theme placeholders (`{{ accent }}`, `{{ red }}`, …) — never hardcode colors
- AI agents (codex, gemini, opencode) are installed via `mise use -g <name>` like Omarchy's agent picker does; the default is recorded in `~/.config/omarchy/defaults/agent` and must remain `opencode`
- Scripts: `#!/bin/bash`, `set -euo pipefail`, source `lib/common.sh`

## Testing changes

```bash
bash -n install.sh                 # syntax check
tests/stow-idempotency.sh          # clean + repeated Stow regression test
./install.sh                       # run; second run should print mostly "– ... (already done)"
stow --dir=. --target=~ -n -v bash # dry-run preview of a stow package
```

After editing shell files, a new terminal is enough — no rerun required. After editing `install/tmux-extra.conf`, rerun `./install.sh` then reload tmux.
