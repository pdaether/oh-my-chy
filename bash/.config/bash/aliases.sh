# oh-my-chy: aliases
# Sourced from ~/.bashrc (marked block) after Omarchy's defaults,
# so these override Omarchy's built-in aliases where they collide.

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'

# Shortcuts
alias docs='cd ~/Documents'
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias p='cd ~/projects'
alias c='cd ~/code'
alias w='cd ~/www'

# Git
alias g='git'
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias lg='lazygit'

# Docker
alias ld='lazydocker'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Listing (eza, overriding Omarchy's ls/lt variants)
alias la='ls -A'
alias l='eza -lg --icons=auto'
alias ll='eza -lag --icons=auto'
alias lt1='eza --tree --level=1 --long --icons=auto --git'
alias lt2='eza --tree --level=2 --long --icons=auto --git'

# Colors
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Enable aliases to be sudo'ed
alias sudo='sudo '

# Re-run last command with sudo
alias pls='sudo $(fc -ln -1)'

# Misc
alias week='date +%V'
alias help='tldr'
alias cl='clear'
alias o='open .'
alias reload='exec "${SHELL}" -l'

# Wayland clipboard
alias copy="tr -d '\n' | wl-copy"
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'

# Update system the Omarchy way
alias update='omarchy update'

# URL-encode strings
alias urlencode='python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))"'

# Intuitive map function, e.g.: find . -name .gitattributes | map dirname
alias map='xargs -n1'

# Copy SSH key / pwd
alias sshkey='wl-copy < ~/.ssh/id_ed25519.pub && echo "Copied SSH key to clipboard"'
alias cwd='pwd && wl-copy <<< "$(pwd)" && echo "Copied to clipboard"'

# Gen a password
alias passgen='openssl rand -base64 30 | tee >(wl-copy) && echo "... was copied to the clipboard."'

# PHP / Laravel development
alias art='php artisan'
alias artx='XDEBUG_CONFIG="start_with_request=1 mode=debug" php artisan'
alias artc='art clear-compiled && art cache:clear && art route:clear && art config:clear && art view:clear && composer du'
alias phpx='XDEBUG_CONFIG="start_with_request=1 mode=debug" php'
alias pestx='XDEBUG_CONFIG="start_with_request=1 mode=debug" ./vendor/bin/pest'
alias plz='php please'

# Node / npm
alias nrd='npm run dev'
alias nrb='npm run build'
alias n='npm run'
alias ni='npm install'
alias deps='composer install && npm ci'

# Tmux
alias tl='tmux ls'
alias tn='tmux new -s'
alias ta='tmux attach'
