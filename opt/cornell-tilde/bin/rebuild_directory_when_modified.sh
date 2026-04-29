#!/usr/bin/env bash
set -euo pipefail

DB="/opt/cornell-tilde/var/cornell_tilde.sqlite3"
GENERATOR="/opt/cornell-tilde/bin/generate_directory.py"

if [ ! -f "$DB" ]; then
  exit 0
fi

MODIFIED="$(sqlite3 "$DB" "SELECT modified FROM directory_modified WHERE id = 1;" 2>/dev/null || echo 0)"

if [ "$MODIFIED" = "1" ]; then
  "$GENERATOR"

  sqlite3 "$DB" "
    UPDATE directory_modified
    SET modified = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = 1;
  "
fi