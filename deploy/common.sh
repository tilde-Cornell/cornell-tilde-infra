#!/bin/bash

PROJECT_ROOT="/opt/cornell-tilde"
DB_PATH="$PROJECT_ROOT/var/cornell_tilde.sqlite3"
WEB_ROOT="/var/www/html"

deploy_script_dir() {
  local source="${BASH_SOURCE[1]}"

  while [ -L "$source" ]; do
    local dir
    local target

    dir="$(cd -P -- "$(dirname -- "$source")" && pwd)"
    target="$(readlink "$source")"

    if [[ "$target" == /* ]]; then
      source="$target"
    else
      source="$dir/$target"
    fi
  done

  cd -P -- "$(dirname -- "$source")" && pwd
}

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "run with sudo!"
    exit 1
  fi
}

section() {
  echo
  echo "=== $* ==="
}
