#!/usr/bin/env bash
# Watches the SQLite database directory for changes and rebuilds the public
# member directory whenever the directory_modified flag is set.
#
# Uses inotifywait (from inotify-tools) instead of a systemd path unit so
# the watcher can run in Docker and other environments without systemd.
#
# Started as a background daemon by deploy/apply-runtime.sh.

set -uo pipefail

DB="/opt/cornell-tilde/var/cornell_tilde.sqlite3"
DB_DIR="$(dirname "$DB")"
GENERATOR="/opt/cornell-tilde/bin/rebuild_directory_when_modified.sh"
PID_FILE="/run/cornell-tilde-directory-watcher.pid"

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "ERROR: inotifywait not found. Install inotify-tools." >&2
  exit 1
fi

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"; exit 0' EXIT INT TERM

# Wait for the database file to exist before entering the watch loop.
while [ ! -f "$DB" ]; do
  sleep 5
done

while true; do
  if inotifywait -e close_write,modify,moved_to,create -qq "$DB_DIR" 2>/dev/null; then
    "$GENERATOR" || echo "$(date -Is): directory rebuild failed" >&2
  else
    # inotifywait exited unexpectedly; pause before retrying.
    sleep 10
  fi
done
