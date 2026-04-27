#!/bin/bash
set -euo pipefail

PROJECT_NAME="tilde@Cornell"
PROJECT_ROOT="/opt/cornell-tilde"
DB_PATH="$PROJECT_ROOT/var/cornell_tilde.sqlite3"
WEB_ROOT="/var/www/html"
BACKUP_DIR="/var/backups/cornell-tilde"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  ADMIN_USER="$SUDO_USER"
else
  ADMIN_USER="$(logname 2>/dev/null || whoami)"
fi

LOCAL_BACKUP_DIR="/home/$ADMIN_USER/backups"

cd /

print_header() {
  echo "=== $PROJECT_NAME Admin Check ==="
  echo
}

check_service() {
  local service="$1"

  echo "--- $service ---"

  if systemctl is-active --quiet "$service"; then
    echo "$service is running."
  else
    echo "$service is NOT running. Starting..."
    systemctl start "$service"

    if systemctl is-active --quiet "$service"; then
      echo "$service started successfully."
    else
      echo "ERROR: $service failed to start."
    fi
  fi

  if systemctl is-enabled --quiet "$service"; then
    echo "$service is enabled on boot."
  else
    echo "$service is NOT enabled on boot. Enabling..."
    systemctl enable "$service"
  fi

  echo
}

check_database() {
  echo "--- SQLite Database Health ---"

  if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH"
    echo
    return
  fi

  if command -v sqlite3 >/dev/null 2>&1; then
    echo -n "Integrity check: "
    sqlite3 "$DB_PATH" "PRAGMA integrity_check;"

    echo -n "Users: "
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users;"

    echo -n "Applications: "
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM applications;"

    echo "Applications by status:"
    sqlite3 "$DB_PATH" \
      ".mode column" \
      ".headers on" \
      "SELECT status, COUNT(*) AS count FROM applications GROUP BY status ORDER BY status;"

    echo
    echo "Recent pending applications:"
    sqlite3 "$DB_PATH" \
      ".mode column" \
      ".headers on" \
      "SELECT application_id, email, preferred_username, submitted_at FROM applications WHERE status = 'pending' ORDER BY submitted_at LIMIT 10;"
  else
    echo "sqlite3 command not found."
  fi

  echo
}

check_web() {
  echo "--- Web Tests ---"

  echo -n "Home Page:      "
  curl -Is https://cornelltilde.com | head -n 1 || true

  echo -n "Directory Page: "
  curl -Is https://cornelltilde.com/directory/ | head -n 1 || true

  echo -n "SSH Docs Page:  "
  curl -Is https://cornelltilde.com/ssh/ | head -n 1 || true

  echo
}

check_firewall() {
  echo "--- UFW Firewall ---"

  if ufw status | grep -q "Status: active"; then
    echo "UFW is active."
  else
    echo "UFW is NOT active. Enabling..."
    ufw --force enable
  fi

  echo
  echo "--- UFW Rules ---"
  ufw status verbose
  echo
}

check_fail2ban() {
  echo "--- Fail2Ban SSH Jail ---"
  fail2ban-client status sshd || echo "Could not read Fail2Ban sshd status."
  echo
}

check_system_usage() {
  echo "--- Disk Usage ---"
  df -h /
  echo

  echo "--- Project Directory Usage ---"
  du -sh "$PROJECT_ROOT" 2>/dev/null || true
  du -sh "$WEB_ROOT" 2>/dev/null || true
  echo

  echo "--- Home Directory Usage ---"
  du -sh /home/* 2>/dev/null | sort -h || true
  echo

  echo "--- Memory ---"
  free -h
  echo
}

create_backup() {
  local date_stamp
  local target
  local archive
  local local_copy

  date_stamp=$(date +"%Y-%m-%d_%H-%M-%S")
  target="$BACKUP_DIR/backup-$date_stamp"
  archive="$target.tar.gz"

  mkdir -p "$target" 2>/dev/null || true
  mkdir -p "$target"

  echo "=== Creating Backup ==="
  echo
  echo "Saving to:"
  echo "$archive"
  echo

  cp -a "$PROJECT_ROOT" "$target/opt-cornell-tilde"
  cp -a "$WEB_ROOT" "$target/var-www-html"
  cp -a /home "$target/home"
  cp -a /etc/ssh "$target/etc-ssh"
  cp -a /etc/apache2 "$target/etc-apache2"

  cp /etc/passwd "$target/passwd"
  cp /etc/group "$target/group"
  cp /etc/shadow "$target/shadow" 2>/dev/null || true

  tar -czf "$archive" -C "$BACKUP_DIR" "backup-$date_stamp"
  rm -rf "$target"

  find "$BACKUP_DIR" -name "*.tar.gz" -mtime +14 -delete

  mkdir -p "$LOCAL_BACKUP_DIR"
  chown "$ADMIN_USER:$ADMIN_USER" "$LOCAL_BACKUP_DIR"
  chmod 700 "$LOCAL_BACKUP_DIR"

  local_copy="$LOCAL_BACKUP_DIR/$(basename "$archive")"

  cp "$archive" "$local_copy"
  chown "$ADMIN_USER:$ADMIN_USER" "$local_copy"
  chmod 600 "$local_copy"

  if [ -f "$archive" ]; then
    echo
    echo "=== Backup Complete ==="
    echo
    echo "Server archive:"
    echo "$archive"
    echo
    echo "Local-download copy:"
    echo "$local_copy"
    echo
    echo "From your local Mac, run:"
    echo
    echo "scp $ADMIN_USER@cornelltilde.com:~/backups/$(basename "$archive") ."
    echo
  else
    echo
    echo "ERROR: Backup archive was not created."
  fi
}

motd_summary() {
  echo "$PROJECT_NAME status:"
  echo -n "  apache2: "
  systemctl is-active apache2 2>/dev/null || true
  echo -n "  ssh: "
  systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || true
  echo -n "  pending applications: "
  if [ -f "$DB_PATH" ] && command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM applications WHERE status = 'pending';" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
  echo
}

main() {
  if [[ "${1:-}" == "--motd" ]]; then
    motd_summary
    exit 0
  fi

  print_header

  check_service ssh
  check_service apache2
  check_service fail2ban
  check_service unattended-upgrades

  check_firewall
  check_fail2ban
  check_web
  check_database
  check_system_usage

  if [ -t 0 ]; then
    read -p "Create fresh backup now? (y/n): " backup_choice

    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
      create_backup
    else
      echo
      echo "Backup skipped."
    fi
  else
    echo "Non-interactive run detected. Backup prompt skipped."
  fi

  echo
  echo "=== Done ==="
}

main "$@"