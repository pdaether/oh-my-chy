# oh-my-chy: shell functions
# Sourced from ~/.bashrc (marked block) after Omarchy's defaults.

# Create a new directory and enter it
mkd() {
  mkdir -p "$@" && cd "$_"
}

# Determine size of a file or total size of a directory
fs() {
  if [[ -n "$*" ]]; then
    du -sh -- "$@"
  else
    du -sh .[^.]* ./*
  fi
}

# Reset current git repository to a clean state
nah() {
  git reset --hard
  git clean -df
  if [[ -d .git/rebase-apply || -d .git/rebase-merge ]]; then
    git rebase --abort
  fi
}

# `tre` is tree with hidden files and color, ignoring common noise, piped into less
tre() {
  tree -aC -I '.git|node_modules|vendor|dist|build|.next' --dirsfirst "$@" | less -FRNX
}

# Syntax-highlight JSON from argument or stdin
json() {
  if [ -t 0 ]; then
    jq . <<<"$*"
  else
    jq .
  fi
}

# Run dig and display the most useful info
digga() {
  dig +nocmd "$1" any +multiline +noall +answer
}

# Create a data URL from a file
dataurl() {
  local mimeType
  mimeType=$(file -b --mime-type "$1")
  [[ $mimeType == text/* ]] && mimeType="${mimeType};charset=utf-8"
  echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# Link a local composer package: composer-link ../path/to/package
composer-link() {
  composer config repositories.local "{\"type\": \"path\", \"url\": \"$1\"}" --file composer.json
}

# cloc for a project, excluding common noise
cloc-project() {
  cloc "${1:-.}" \
    --exclude-dir=node_modules,vendor,dist,build,.git,storage,var,typo3temp,fileadmin,uploads,.vscode,.idea,.next,out,coverage,.nuxt \
    --exclude-ext=lock,map,min.js,min.css \
    --fullpath \
    --not-match-d='(bootstrap/cache|typo3/sysext|typo3/contrib|typo3conf/l10n|public/build|public/typo3conf/l10n|public/fileadmin|public/uploads|resources/blueprints|content|users)'
}

# yazi wrapper: cd the shell to yazi's last directory on exit
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd <"$tmp" || true
  [[ -n $cwd && $cwd != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
