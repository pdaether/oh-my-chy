# oh-my-chy: environment exports
# Sourced from ~/.bashrc (marked block) after Omarchy's defaults.

# Make nvim the default editor
export EDITOR='nvim'

# Persistent REPL history for node
export NODE_REPL_HISTORY=~/.node_history
export NODE_REPL_HISTORY_SIZE='32768'
export NODE_REPL_MODE='sloppy'

# UTF-8 output for Python
export PYTHONIOENCODING='UTF-8'

# Bigger history, no duplicates, ignore commands starting with a space
export HISTSIZE='32768'
export HISTFILESIZE="${HISTSIZE}"
export HISTCONTROL='ignoreboth'

# Don't clear the screen after quitting a manual page
export MANPAGER='less -X'

# GPG in the terminal
[ -t 0 ] && export GPG_TTY="$(tty)"

# Use the systemd OpenSSH agent if nothing else claimed the socket
if [[ -z "${SSH_AUTH_SOCK:-}" && -S "${XDG_RUNTIME_DIR:-}/ssh-agent.socket" ]]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi
