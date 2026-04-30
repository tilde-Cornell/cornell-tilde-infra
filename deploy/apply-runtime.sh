#!/bin/bash
set -euo pipefail

source /deploy/common.sh
SCRIPT_DIR="$(deploy_script_dir)"

require_root

section "Creating runtime directories"

mkdir -p \
  "$PROJECT_ROOT/bin" \
  "$PROJECT_ROOT/lib" \
  "$PROJECT_ROOT/migrations" \
  "$PROJECT_ROOT/templates" \
  "$PROJECT_ROOT/var" \
  "$WEB_ROOT"

section "Database setup"

groupadd -f cornelltilde-db
touch "$DB_PATH"

chown root:cornelltilde-db "$PROJECT_ROOT/var" "$DB_PATH"
chmod 770 "$PROJECT_ROOT/var"
chmod 660 "$DB_PATH"

PYTHONPATH="$PROJECT_ROOT/lib" python3 -c "from cornell_tilde.db import init_db; init_db()"

section "Permissions"

chown -R root:root "$PROJECT_ROOT"

chmod 755 "$PROJECT_ROOT"
chmod 750 "$PROJECT_ROOT/bin" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/migrations" "$PROJECT_ROOT/templates"

if [ -d "$PROJECT_ROOT/lib/cornell_tilde" ]; then
  chmod 750 "$PROJECT_ROOT/lib/cornell_tilde"
fi

chmod 755 "$PROJECT_ROOT/bin/tilde-admin.sh" "$PROJECT_ROOT/bin/join_script_wrapper.sh"
chmod 750 \
  "$PROJECT_ROOT/bin/approve_user.py" \
  "$PROJECT_ROOT/bin/generate_directory.py" \
  "$PROJECT_ROOT/bin/join_script.py" \
  "$PROJECT_ROOT/bin/submit_application.py" \
  "$PROJECT_ROOT/bin/rebuild_directory_when_modified.sh" \
  "$PROJECT_ROOT/bin/watch_directory_changes.sh"

chmod 640 "$PROJECT_ROOT"/migrations/*.sql

chown root:cornelltilde-db "$PROJECT_ROOT/var" "$DB_PATH"
chmod 770 "$PROJECT_ROOT/var"
chmod 660 "$DB_PATH"

section "Join ACLs"

if id join >/dev/null 2>&1; then
  if id -nG join | tr ' ' '\n' | grep -qx cornelltilde-db; then
    gpasswd -d join cornelltilde-db || true
  fi

  setfacl -m u:join:--x "$PROJECT_ROOT"

  setfacl -m u:join:r-x "$PROJECT_ROOT/bin"
  setfacl -m u:join:r-x "$PROJECT_ROOT/bin/join_script.py"
  setfacl -m u:join:r-x "$PROJECT_ROOT/bin/join_script_wrapper.sh"
  setfacl -m u:join:r-x "$PROJECT_ROOT/bin/submit_application.py"

  setfacl -m u:join:r-x "$PROJECT_ROOT/lib"
  setfacl -m u:join:r-x "$PROJECT_ROOT/lib/cornell_tilde"
  setfacl -m u:join:r-- "$PROJECT_ROOT"/lib/cornell_tilde/*.py

  setfacl -x u:join "$PROJECT_ROOT/var" 2>/dev/null || true
  setfacl -x u:join "$DB_PATH" 2>/dev/null || true
else
  echo "join user does not exist yet; skipping join ACLs."
fi

section "Join sudoers"

cat > /etc/sudoers.d/join_script <<'EOC'
join ALL=(root) NOPASSWD: /opt/cornell-tilde/bin/submit_application.py
EOC

chown root:root /etc/sudoers.d/join_script
chmod 0440 /etc/sudoers.d/join_script
visudo -cf /etc/sudoers.d/join_script

section "Site permissions"

chown -R root:root "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;

section "Command links"

chmod 755 /deploy/apply-runtime.sh /deploy/configure-ssh.sh /deploy/post-deploy.sh /deploy/common.sh

ln -sf "$PROJECT_ROOT/bin/approve_user.py" /usr/local/sbin/approve_user.py
ln -sf "$PROJECT_ROOT/bin/generate_directory.py" /usr/local/sbin/generate_directory.py
ln -sf "$PROJECT_ROOT/bin/join_script.py" /usr/local/sbin/join_script.py
ln -sf "$PROJECT_ROOT/bin/join_script_wrapper.sh" /usr/local/sbin/join_script_wrapper.sh
ln -sf "$PROJECT_ROOT/bin/submit_application.py" /usr/local/sbin/submit_application.py
ln -sf "$PROJECT_ROOT/bin/tilde-admin.sh" /usr/local/sbin/tilde-admin
ln -sf "$PROJECT_ROOT/bin/rebuild_directory_when_modified.sh" /usr/local/sbin/rebuild_directory_when_modified.sh
ln -sf "$PROJECT_ROOT/bin/watch_directory_changes.sh" /usr/local/sbin/watch_directory_changes
ln -sf /deploy/apply-runtime.sh /usr/local/sbin/apply-runtime
ln -sf /deploy/configure-ssh.sh /usr/local/sbin/configure-ssh
ln -sf /deploy/post-deploy.sh /usr/local/sbin/post-deploy

section "Directory rebuild watcher"

# Stop any existing watcher process before (re)starting.
if [ -f /run/cornell-tilde-directory-watcher.pid ]; then
  old_pid="$(cat /run/cornell-tilde-directory-watcher.pid)"
  if kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null || true
    sleep 1
  fi
  rm -f /run/cornell-tilde-directory-watcher.pid
fi

# Start the inotifywait-based watcher daemon.
nohup "$PROJECT_ROOT/bin/watch_directory_changes.sh" >> /var/log/cornell-tilde-directory.log 2>&1 &
disown
sleep 1

# Trigger an immediate directory rebuild now that the deploy is complete.
sqlite3 "$DB_PATH" "
  UPDATE directory_modified
  SET modified = 1,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = 1;
"

"$PROJECT_ROOT/bin/rebuild_directory_when_modified.sh"

section "Runtime verification"

apache2ctl configtest
sshd -t
visudo -c

PYTHONPATH="$PROJECT_ROOT/lib" python3 -c "from cornell_tilde.db import get_connection; print('db import works')"

sqlite3 "$DB_PATH" ".tables"
sqlite3 "$DB_PATH" "SELECT * FROM directory_modified;"

if [ -f /run/cornell-tilde-directory-watcher.pid ] && kill -0 "$(cat /run/cornell-tilde-directory-watcher.pid)" 2>/dev/null; then
  echo "Directory watcher is running (PID $(cat /run/cornell-tilde-directory-watcher.pid))."
else
  echo "WARNING: Directory watcher is not running."
fi
