#!/usr/bin/env bash
# =============================================================================
# cornell-tilde Docker Integration Test Suite
#
# Usage:
#   bash tests/ci_integration.sh [IMAGE_TAG]
#
# Optional environment variables:
#   CI_SSH_PORT   – host port mapped to container's SSH  (default: 2222)
#   CI_HTTP_PORT  – host port mapped to container's HTTP (default: 8080)
#
# Requirements: docker, ssh, sshpass, curl, nc, sqlite3 (all available on
# standard GitHub-hosted ubuntu-latest runners after the workflow installs them)
# =============================================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${1:-cornell-tilde:ci}"
CONTAINER="cornell-tilde-ci-$$"
SSH_PORT="${CI_SSH_PORT:-2222}"
HTTP_PORT="${CI_HTTP_PORT:-8080}"

# ---------------------------------------------------------------------------
# Test data
# ---------------------------------------------------------------------------
JOIN_PASSWORD="testjoinpass"
TEST_USER="testuser"
TEST_EMAIL="testuser@cornell.edu"
TEST_NAME="Test User"
TEST_YEAR="2027"
COLLEGE_NUM="2"   # "Engineering (COE)" is item 2 in join_script.py's COLLEGES list

TMPDIR_TEST="$(mktemp -d)"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

section() { echo; echo "===== $* ====="; }
log()     { echo "  $*"; }
pass()    { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail()    { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

# docker exec shorthand
dexec()  { docker exec          "$CONTAINER" "$@"; }
dexecp() { docker exec -i       "$CONTAINER" "$@"; }  # with piped stdin

SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
    -o BatchMode=no
    -o ConnectTimeout=10
)

# SSH as the approved test user using the generated private key
user_ssh() {
    ssh "${SSH_OPTS[@]}" \
        -i "$TMPDIR_TEST/user_key" \
        -p "$SSH_PORT" \
        "${TEST_USER}@localhost" \
        "$@"
}

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() {
    docker stop "$CONTAINER" 2>/dev/null || true
    docker rm   "$CONTAINER" 2>/dev/null || true
    rm -rf      "$TMPDIR_TEST"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Check required tools
# ---------------------------------------------------------------------------
section "Checking required tools"
MISSING=0
for tool in docker ssh sshpass curl nc; do
    if command -v "$tool" >/dev/null 2>&1; then
        log "found: $tool"
    else
        log "MISSING: $tool"
        MISSING=$((MISSING + 1))
    fi
done
[ "$MISSING" -gt 0 ] && { echo "ERROR: install missing tools before running tests"; exit 1; }

# ---------------------------------------------------------------------------
# Build Docker image
# ---------------------------------------------------------------------------
section "Building Docker image: $IMAGE"
docker build -t "$IMAGE" "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Generate the test user's SSH key pair before starting the container so the
# public key is available when we fill in the join application form.
# ---------------------------------------------------------------------------
ssh-keygen -t ed25519 -f "$TMPDIR_TEST/user_key" -N "" -q
TEST_PUBKEY="$(cat "$TMPDIR_TEST/user_key.pub")"

# ---------------------------------------------------------------------------
# Start container
# ---------------------------------------------------------------------------
section "Starting container"
docker run -d \
    --name "$CONTAINER" \
    -p "${SSH_PORT}:22" \
    -p "${HTTP_PORT}:80" \
    -e "JOIN_PASSWORD=${JOIN_PASSWORD}" \
    -e "SITE_DOMAIN=localhost" \
    -e "ADMIN_EMAIL=admin@localhost" \
    "$IMAGE"

# ---------------------------------------------------------------------------
# Wait for HTTP and SSH services
# ---------------------------------------------------------------------------
section "Waiting for services"

log "Waiting for HTTP on port $HTTP_PORT ..."
for i in $(seq 1 60); do
    curl -s -o /dev/null -f "http://localhost:${HTTP_PORT}/" 2>/dev/null && break
    sleep 1
    [ "$i" -eq 60 ] && { echo "ERROR: HTTP not ready after 60 s"; exit 1; }
done
log "HTTP ready"

log "Waiting for SSH on port $SSH_PORT ..."
for i in $(seq 1 60); do
    nc -z localhost "$SSH_PORT" 2>/dev/null && break
    sleep 1
    [ "$i" -eq 60 ] && { echo "ERROR: SSH not ready after 60 s"; exit 1; }
done
log "SSH port open"
sleep 2   # let sshd finish its own initialisation

# =============================================================================
section "TEST 1: Server files and services"
# =============================================================================

# --- Required files ----------------------------------------------------------
REQUIRED_FILES=(
    /opt/cornell-tilde/bin/approve_user.py
    /opt/cornell-tilde/bin/generate_directory.py
    /opt/cornell-tilde/bin/join_script.py
    /opt/cornell-tilde/bin/join_script_wrapper.sh
    /opt/cornell-tilde/bin/submit_application.py
    /opt/cornell-tilde/bin/tilde-admin.sh
    /opt/cornell-tilde/bin/rebuild_directory_when_modified.sh
    /opt/cornell-tilde/lib/cornell_tilde/__init__.py
    /opt/cornell-tilde/lib/cornell_tilde/config.py
    /opt/cornell-tilde/lib/cornell_tilde/db.py
    /opt/cornell-tilde/migrations/1_user-applications_initial-schema.sql
    /opt/cornell-tilde/migrations/2_directory_modified_hooks.sql
    /opt/cornell-tilde/var/cornell_tilde.sqlite3
    /opt/cornell-tilde/templates/directory.html
    /opt/cornell-tilde/templates/user_homepage.html
    /var/www/html/index.html
    /etc/ssh/sshd_config
    /etc/sudoers.d/join_script
)
for f in "${REQUIRED_FILES[@]}"; do
    if dexec test -e "$f" 2>/dev/null; then
        pass "file present: $f"
    else
        fail "file present: $f"
    fi
done

# --- Required admin-tool symlinks --------------------------------------------
REQUIRED_LINKS=(
    /usr/local/sbin/approve_user.py
    /usr/local/sbin/generate_directory.py
    /usr/local/sbin/join_script.py
    /usr/local/sbin/submit_application.py
    /usr/local/sbin/tilde-admin
    /usr/local/sbin/apply-runtime
    /usr/local/sbin/post-deploy
)
for lnk in "${REQUIRED_LINKS[@]}"; do
    if dexec test -L "$lnk" 2>/dev/null; then
        pass "symlink present: $lnk"
    else
        fail "symlink present: $lnk"
    fi
done

# --- File permissions --------------------------------------------------------
declare -A EXPECTED_PERMS=(
    [/opt/cornell-tilde/bin/approve_user.py]=750
    [/opt/cornell-tilde/bin/submit_application.py]=750
    [/opt/cornell-tilde/bin/join_script.py]=750
    [/opt/cornell-tilde/bin/generate_directory.py]=750
    [/opt/cornell-tilde/bin/rebuild_directory_when_modified.sh]=750
    [/opt/cornell-tilde/bin/join_script_wrapper.sh]=755
    [/opt/cornell-tilde/bin/tilde-admin.sh]=755
)
for filepath in "${!EXPECTED_PERMS[@]}"; do
    expected="${EXPECTED_PERMS[$filepath]}"
    actual=$(dexec stat -c '%a' "$filepath" 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        pass "permission $expected: $filepath"
    else
        fail "permission $expected (got $actual): $filepath"
    fi
done

# --- Database group and directory mode ---------------------------------------
DB_GROUP=$(dexec stat -c '%G' /opt/cornell-tilde/var/cornell_tilde.sqlite3 2>/dev/null || true)
if [ "$DB_GROUP" = "cornelltilde-db" ]; then
    pass "database file group is cornelltilde-db"
else
    fail "database file group is cornelltilde-db (got: $DB_GROUP)"
fi

DB_DIR_PERM=$(dexec stat -c '%a' /opt/cornell-tilde/var 2>/dev/null || true)
if [ "$DB_DIR_PERM" = "770" ]; then
    pass "database directory mode is 770"
else
    fail "database directory mode is 770 (got: $DB_DIR_PERM)"
fi

# --- Services running --------------------------------------------------------
if dexec bash -c 'pgrep -x apache2 >/dev/null 2>&1'; then
    pass "apache2 process is running"
else
    fail "apache2 process is running"
fi

if dexec bash -c 'pgrep sshd >/dev/null 2>&1'; then
    pass "sshd process is running"
else
    fail "sshd process is running"
fi

# --- Configuration correctness -----------------------------------------------
if dexec grep -q 'NOPASSWD: /opt/cornell-tilde/bin/submit_application.py' \
        /etc/sudoers.d/join_script 2>/dev/null; then
    pass "join sudoers grants NOPASSWD for submit_application.py only"
else
    fail "join sudoers grants NOPASSWD for submit_application.py only"
fi

if dexec grep -q 'ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh' \
        /etc/ssh/sshd_config 2>/dev/null; then
    pass "sshd_config has ForceCommand for join user"
else
    fail "sshd_config has ForceCommand for join user"
fi

if dexec bash -c 'grep -q "SITE_DOMAIN=localhost" /opt/cornell-tilde/.env' 2>/dev/null; then
    pass ".env written with SITE_DOMAIN=localhost"
else
    fail ".env written with SITE_DOMAIN=localhost"
fi

# --- Database tables ---------------------------------------------------------
TABLES=$(dexec sqlite3 /opt/cornell-tilde/var/cornell_tilde.sqlite3 '.tables' 2>/dev/null || true)
for tbl in users applications directory_modified; do
    if echo "$TABLES" | grep -q "$tbl"; then
        pass "database table exists: $tbl"
    else
        fail "database table exists: $tbl"
    fi
done

# =============================================================================
section "TEST 2: Website accessibility from outside the container"
# =============================================================================
BASE="http://localhost:${HTTP_PORT}"

# Homepage
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/")
if [ "$STATUS" = "200" ]; then
    pass "homepage HTTP 200"
else
    fail "homepage HTTP 200 (got: $STATUS)"
fi

if curl -s "${BASE}/" | grep -q 'tilde@Cornell'; then
    pass "homepage contains 'tilde@Cornell'"
else
    fail "homepage contains 'tilde@Cornell'"
fi

# Directory page
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/directory/")
if [ "$STATUS" = "200" ]; then
    pass "directory page HTTP 200"
else
    fail "directory page HTTP 200 (got: $STATUS)"
fi

# SSH info page (may redirect)
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/ssh/")
if [[ "$STATUS" == 2* ]] || [[ "$STATUS" == 3* ]]; then
    pass "ssh info page accessible (HTTP $STATUS)"
else
    fail "ssh info page accessible (HTTP $STATUS)"
fi

# =============================================================================
section "TEST 3: Simulate user join request via SSH"
# =============================================================================
# join_script.py calls input() for each prompt.  When SSH is established
# without a pseudo-TTY (-T), sys.stdout.isatty() is False, so all
# clear_screen/enter_screen/leave_screen calls are no-ops.  The input()
# calls still read from the piped stdin.
#
# Input sequence matching join_script.py's ask_* functions (one line each):
#   show_intro      : <Enter>
#   ask_email       : email, yes
#   ask_name        : name,  yes
#   ask_username    : user,  yes
#   ask_college     : number, yes
#   ask_grad_year   : year,  yes
#   ask_info        : <blank>, yes (confirm blank)
#   ask_ssh_key     : pubkey, pubkey (confirm)
#   review_application: yes
# ---------------------------------------------------------------------------

JOIN_OUTPUT="$TMPDIR_TEST/join_output.txt"
APP_ID=""

JOIN_INPUT=$(printf '%s\n' \
    "" \
    "$TEST_EMAIL" "yes" \
    "$TEST_NAME"  "yes" \
    "$TEST_USER"  "yes" \
    "$COLLEGE_NUM" "yes" \
    "$TEST_YEAR"  "yes" \
    "" "yes" \
    "$TEST_PUBKEY" \
    "$TEST_PUBKEY" \
    "yes")

sshpass -p "$JOIN_PASSWORD" \
    ssh "${SSH_OPTS[@]}" -T -p "$SSH_PORT" "join@localhost" \
    <<< "$JOIN_INPUT" > "$JOIN_OUTPUT" 2>&1 || true

if grep -q 'Application received successfully' "$JOIN_OUTPUT"; then
    pass "join application submitted via SSH"
    APP_ID=$(grep 'Application ID:' "$JOIN_OUTPUT" \
             | awk '{print $NF}' | tr -d '[:space:]')
    log "Application ID: $APP_ID"
else
    fail "join application submitted via SSH"
    log "--- SSH session output (first 50 lines) ---"
    head -50 "$JOIN_OUTPUT" | sed 's/^/  /'
fi

# Verify application ID format: CT-YY-XXXXXX
if echo "$APP_ID" | grep -qE '^CT-[0-9]{2}-[A-Z0-9]{6}$'; then
    pass "application ID format is correct: $APP_ID"
else
    fail "application ID format is correct (got: '$APP_ID')"
fi

# Verify the application is pending in the database
if dexec sqlite3 /opt/cornell-tilde/var/cornell_tilde.sqlite3 \
        "SELECT status FROM applications WHERE application_id='${APP_ID}';" \
        2>/dev/null | grep -q 'pending'; then
    pass "application recorded as pending in the database"
else
    fail "application recorded as pending in the database"
fi

# =============================================================================
section "TEST 4: Admin approves the application"
# =============================================================================
# Run a non-interactive approval script inside the container.
# This mirrors the logic in approve_user.py (create_user + update_directory +
# mark_handled) without the interactive terminal UI.
# ---------------------------------------------------------------------------

log "Running non-interactive approval script inside the container ..."

APPROVED_USER=$(dexecp python3 - << 'PYEOF'
import sys, subprocess, pathlib, html, os

sys.path.insert(0, '/opt/cornell-tilde/lib')

from cornell_tilde.db import (
    get_pending_applications,
    set_application_status,
    add_user_to_directory,
)
from cornell_tilde.config import USER_HOMEPAGE_TEMPLATE, SITE_URL

apps = get_pending_applications()
if not apps:
    print('ERROR: no pending applications found', file=sys.stderr)
    sys.exit(1)

app      = apps[0]
username = app['preferred_username']
ssh_key  = app['ssh_key']
app_id   = app['application_id']

# Create the Unix account
subprocess.run(
    ['adduser', '--disabled-password', '--gecos', '', username],
    check=True, capture_output=True,
)

# Install the user's SSH public key
home    = pathlib.Path(f'/home/{username}')
ssh_dir = home / '.ssh'
ssh_dir.mkdir(parents=True, exist_ok=True)
(ssh_dir / 'authorized_keys').write_text(
    ssh_key.strip() + '\n', encoding='utf-8'
)

# Create ~/public_html with the default homepage template
pub = home / 'public_html'
pub.mkdir(parents=True, exist_ok=True)

tmpl  = USER_HOMEPAGE_TEMPLATE.read_text(encoding='utf-8')
page  = tmpl.format(
    username=username,
    display_name=html.escape(app.get('name', username), quote=True),
    site_url=SITE_URL,
)
(pub / 'index.html').write_text(page, encoding='utf-8')

# Set permissions (matching approve_user.py → create_user)
subprocess.run(['chown', '-R', f'{username}:{username}', str(home)], check=True)
subprocess.run(['chmod', '711', str(home)],                         check=True)
subprocess.run(['chmod', '700', str(ssh_dir)],                      check=True)
subprocess.run(['chmod', '600', str(ssh_dir / 'authorized_keys')],  check=True)
subprocess.run(['chmod', '755', str(pub)],                          check=True)
subprocess.run(['chmod', '644', str(pub / 'index.html')],           check=True)

# Add to the user directory and mark the application approved
add_user_to_directory(
    username=username,
    name=app.get('name', '') or username,
    email=app.get('email', ''),
    college=app.get('college', ''),
    grad_year=app.get('graduation_year', ''),
    bio='',
    public=True,
)
set_application_status(app_id, 'approved', username)

print(username)
PYEOF
2>/dev/null || true)

if [ "$APPROVED_USER" = "$TEST_USER" ]; then
    pass "user '$TEST_USER' approved and Unix account created"
else
    fail "user approval returned unexpected value (expected '$TEST_USER', got '$APPROVED_USER')"
fi

# Regenerate the HTML directory page so the new member appears in it
dexec bash -c \
    'PYTHONPATH=/opt/cornell-tilde/lib python3 /opt/cornell-tilde/bin/generate_directory.py' \
    2>/dev/null \
    || log "Warning: directory page regeneration returned non-zero"

# Verify application status updated
if dexec sqlite3 /opt/cornell-tilde/var/cornell_tilde.sqlite3 \
        "SELECT status FROM applications WHERE preferred_username='${TEST_USER}';" \
        2>/dev/null | grep -q 'approved'; then
    pass "application status updated to 'approved' in the database"
else
    fail "application status updated to 'approved' in the database"
fi

# Verify Unix account exists
if dexec id "$TEST_USER" >/dev/null 2>&1; then
    pass "Unix account '$TEST_USER' exists"
else
    fail "Unix account '$TEST_USER' exists"
fi

# Verify default homepage was created
if dexec test -f "/home/${TEST_USER}/public_html/index.html" 2>/dev/null; then
    pass "default homepage /home/$TEST_USER/public_html/index.html created"
else
    fail "default homepage /home/$TEST_USER/public_html/index.html created"
fi

# Verify user appears in the directory database
if dexec sqlite3 /opt/cornell-tilde/var/cornell_tilde.sqlite3 \
        "SELECT username FROM users WHERE username='${TEST_USER}';" \
        2>/dev/null | grep -q "$TEST_USER"; then
    pass "user '$TEST_USER' added to the directory database"
else
    fail "user '$TEST_USER' added to the directory database"
fi

# =============================================================================
section "TEST 5: User SSH login – correct file access and webpage edit"
# =============================================================================

# 5a. SSH login succeeds
if user_ssh true 2>/dev/null; then
    pass "SSH login succeeds for $TEST_USER"
else
    fail "SSH login succeeds for $TEST_USER"
fi

# 5b. User can read their own default homepage
PAGE=$(user_ssh 'cat ~/public_html/index.html' 2>/dev/null || true)
if echo "$PAGE" | grep -q 'tilde@Cornell'; then
    pass "$TEST_USER can read ~/public_html/index.html"
else
    fail "$TEST_USER can read ~/public_html/index.html"
fi

# 5c. User CANNOT read the SQLite database
# /opt/cornell-tilde/var/ is 770 root:cornelltilde-db; testuser is not in
# that group, so the directory is inaccessible to them.
if user_ssh 'cat /opt/cornell-tilde/var/cornell_tilde.sqlite3' \
        >/dev/null 2>&1; then
    fail "$TEST_USER cannot read the database (SECURITY VIOLATION)"
else
    pass "$TEST_USER cannot read the database (correctly denied)"
fi

# 5d. User CANNOT read protected library files
# /opt/cornell-tilde/lib/ is 750 root:root; testuser is not in root group.
if user_ssh 'cat /opt/cornell-tilde/lib/cornell_tilde/config.py' \
        >/dev/null 2>&1; then
    fail "$TEST_USER cannot read /opt/cornell-tilde/lib (SECURITY VIOLATION)"
else
    pass "$TEST_USER cannot read /opt/cornell-tilde/lib (correctly denied)"
fi

# 5e. User CANNOT write anywhere outside their home
if user_ssh 'echo pwned > /opt/cornell-tilde/var/pwned' \
        >/dev/null 2>&1; then
    fail "$TEST_USER cannot write to /opt/cornell-tilde/var (SECURITY VIOLATION)"
else
    pass "$TEST_USER cannot write to /opt/cornell-tilde/var (correctly denied)"
fi

# 5f. User CAN modify their own webpage with unique test content
UNIQUE_MARKER="ci-test-$$-$(date +%s)"
MODIFIED_HTML="<html><body><p>Modified by CI: ${UNIQUE_MARKER}</p></body></html>"

if user_ssh 'cat > ~/public_html/index.html' <<< "$MODIFIED_HTML" 2>/dev/null; then
    pass "$TEST_USER can write to ~/public_html/index.html"
else
    fail "$TEST_USER can write to ~/public_html/index.html"
fi

# =============================================================================
section "TEST 6: Modified webpage served correctly from outside the container"
# =============================================================================
USER_URL="${BASE}/~${TEST_USER}/"

STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$USER_URL")
if [ "$STATUS" = "200" ]; then
    pass "user page HTTP 200: $USER_URL"
else
    fail "user page HTTP 200 (got: $STATUS): $USER_URL"
fi

SERVED=$(curl -s "$USER_URL")
if echo "$SERVED" | grep -qF "$UNIQUE_MARKER"; then
    pass "modified content is served correctly (marker found)"
else
    fail "modified content is served correctly (marker '$UNIQUE_MARKER' not in response)"
fi

# Directory page now lists the new member
DIR_PAGE=$(curl -s "${BASE}/directory/")
if echo "$DIR_PAGE" | grep -qF "$TEST_USER"; then
    pass "new member '$TEST_USER' appears in the directory page"
else
    fail "new member '$TEST_USER' appears in the directory page"
fi

# =============================================================================
section "Summary"
# =============================================================================
echo
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
    echo "SOME TESTS FAILED."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
