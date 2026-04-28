#!/bin/bash

PROJECT_ROOT="/opt/cornell-tilde"
DB_PATH="$PROJECT_ROOT/var/cornell_tilde.sqlite3"
WEB_ROOT="/var/www/html"

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
