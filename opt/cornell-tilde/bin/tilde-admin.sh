#!/bin/bash
set -euo pipefail

PROJECT_NAME="tilde@Cornell"
PROJECT_ROOT="/opt/cornell-tilde"
DB_PATH="$PROJECT_ROOT/var/cornell_tilde.sqlite3"
WEB_ROOT="/var/www/html"
DIRECTORY_OUTPUT="$WEB_ROOT/directory/index.html"
SITE_DOMAIN="cornelltilde.com"

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  . "$PROJECT_ROOT/.env"
  set +a
fi

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
    if systemctl start "$service" && systemctl is-active --quiet "$service"; then
      echo "$service started successfully."
    else
      echo "ERROR: $service failed to start."
    fi
  fi

  if systemctl is-enabled --quiet "$service"; then
    echo "$service is enabled on boot."
  else
    echo "$service is NOT enabled on boot. Enabling..."
    systemctl enable "$service" || echo "ERROR: could not enable $service."
  fi

  echo
}

check_path_unit() {
  local unit="$1"

  echo "--- $unit ---"

  if systemctl is-active --quiet "$unit"; then
    echo "$unit is active."
  else
    echo "$unit is NOT active. Starting..."
    if systemctl start "$unit" && systemctl is-active --quiet "$unit"; then
      echo "$unit started successfully."
    else
      echo "ERROR: $unit failed to start."
    fi
  fi

  if systemctl is-enabled --quiet "$unit"; then
    echo "$unit is enabled on boot."
  else
    echo "$unit is NOT enabled on boot. Enabling..."
    systemctl enable "$unit" || echo "ERROR: could not enable $unit."
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

    echo
    echo -n "Directory modified flag: "
    sqlite3 "$DB_PATH" "SELECT modified FROM directory_modified WHERE id = 1;"
  else
    echo "sqlite3 command not found."
  fi

  echo
}

check_web() {
  echo "--- Web Tests ---"

  echo -n "Home Page:      "
  curl -Is "https://$SITE_DOMAIN" | head -n 1 || true

  echo -n "Directory Page: "
  curl -Is "https://$SITE_DOMAIN/directory/" | head -n 1 || true

  echo -n "SSH Docs Page:  "
  curl -Is "https://$SITE_DOMAIN/ssh/" | head -n 1 || true

  echo
}

check_directory_generation() {
  echo "--- Generated Directory ---"

  if [ -f "$DIRECTORY_OUTPUT" ]; then
    stat -c "Directory page: %n (%s bytes, modified %y)" "$DIRECTORY_OUTPUT" 2>/dev/null \
      || ls -lh "$DIRECTORY_OUTPUT"
  else
    echo "Directory page is missing at $DIRECTORY_OUTPUT"
  fi

  if [ -f "$DB_PATH" ] && command -v sqlite3 >/dev/null 2>&1; then
    local modified
    modified="$(sqlite3 "$DB_PATH" "SELECT modified FROM directory_modified WHERE id = 1;" 2>/dev/null || echo unknown)"

    if [ "$modified" = "1" ]; then
      echo "Directory has pending changes. Starting rebuild service..."

      if systemctl start cornell-tilde-directory.service; then
        modified="$(sqlite3 "$DB_PATH" "SELECT modified FROM directory_modified WHERE id = 1;" 2>/dev/null || echo unknown)"
        echo "Directory modified flag after rebuild: $modified"
      else
        echo "ERROR: directory rebuild service failed."
      fi
    elif [ "$modified" = "0" ]; then
      echo "Directory modified flag is clear."
    else
      echo "Directory modified flag is unknown."
    fi
  fi

  echo
}

check_join_flow() {
  echo "--- Join Flow ---"

  if id join >/dev/null 2>&1; then
    echo "join user exists."
  else
    echo "ERROR: join user is missing."
  fi

  if getent group cornelltilde-db | grep -Eq '(^|,|:)join(,|$)'; then
    echo "ERROR: join user still has direct database group access."
  else
    echo "join user is not in cornelltilde-db."
  fi

  if [ -x "$PROJECT_ROOT/bin/join_script_wrapper.sh" ]; then
    echo "join wrapper is executable."
  else
    echo "ERROR: join wrapper is missing or not executable."
  fi

  if [ -r "$PROJECT_ROOT/bin/join_script.py" ]; then
    echo "join script is readable."
  else
    echo "ERROR: join script is missing or not readable."
  fi

  if [ -x "$PROJECT_ROOT/bin/submit_application.py" ]; then
    echo "submit helper is executable."
  else
    echo "ERROR: submit helper is missing or not executable."
  fi

  if [ -f /etc/sudoers.d/join_script ]; then
    visudo -cf /etc/sudoers.d/join_script >/dev/null \
      && echo "join sudoers file is valid." \
      || echo "ERROR: join sudoers file is invalid."

    if grep -q "NOPASSWD: /opt/cornell-tilde/bin/submit_application.py" /etc/sudoers.d/join_script; then
      echo "join sudoers is limited to the submit helper."
    else
      echo "ERROR: join sudoers is not limited to the submit helper."
    fi
  else
    echo "ERROR: /etc/sudoers.d/join_script is missing."
  fi

  if grep -Rqs "^Match User join" /etc/ssh/sshd_config /etc/ssh/sshd_config.d \
    && grep -Rqs "ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh" /etc/ssh/sshd_config /etc/ssh/sshd_config.d; then
    echo "sshd_config contains the join ForceCommand block."
  else
    echo "ERROR: sshd_config does not contain the expected join ForceCommand block."
  fi

  echo
}

check_tool_links() {
  echo "--- Admin Tool Links ---"

  local paths=(
    "/usr/local/sbin/approve_user.py"
    "/usr/local/sbin/generate_directory.py"
    "/usr/local/sbin/join_script.py"
    "/usr/local/sbin/join_script_wrapper.sh"
    "/usr/local/sbin/submit_application.py"
    "/usr/local/sbin/tilde-admin"
    "/usr/local/sbin/rebuild_directory_when_modified.sh"
    "/usr/local/sbin/apply-runtime"
    "/usr/local/sbin/configure-ssh"
    "/usr/local/sbin/post-deploy"
    "/etc/systemd/system/cornell-tilde-directory.service"
    "/etc/systemd/system/cornell-tilde-directory.path"
  )

  local path
  for path in "${paths[@]}"; do
    if [ -e "$path" ]; then
      echo "OK: $path"
    else
      echo "MISSING: $path"
    fi
  done

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

  if [ "$EUID" -ne 0 ]; then
    echo "Run this with sudo:"
    echo "sudo tilde-admin"
    exit 1
  fi

  print_header

  check_service ssh
  check_service apache2
  check_service fail2ban
  check_service unattended-upgrades
  check_path_unit cornell-tilde-directory.path

  check_firewall
  check_fail2ban
  check_web
  check_database
  check_directory_generation
  check_join_flow
  check_tool_links
  check_system_usage

  echo
  echo "=== Done ==="
}

main "$@"
