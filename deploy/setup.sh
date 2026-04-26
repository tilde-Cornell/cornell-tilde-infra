#!/bin/bash
set -euo pipefail

echo "=== tilde@Cornell New Server Install ==="
echo

if [ "$EUID" -ne 0 ]; then
  echo "run with sudo! sudo /deploy/setup.sh"
  exit 1
fi

read -rsp "Password for join user: " JOIN_PASSWORD
echo
read -rp "Server domain (example: cornelltilde.com or dev.cornelltilde.com): " SERVER_DOMAIN
echo

echo "Server domain: $SERVER_DOMAIN"
echo

echo "=== Installing packages ==="

sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  sudo \
  curl \
  tree \
  rsync \
  acl \
  sqlite3 \
  python3 \
  python3-pip \
  apache2 \
  openssh-server \
  fail2ban \
  ufw \
  certbot \
  python3-certbot-apache \
  unattended-upgrades

echo
echo "=== Enabling services ==="

sudo systemctl enable ssh apache2 fail2ban ufw unattended-upgrades
sudo systemctl start ssh apache2 fail2ban ufw

echo
echo "=== Firewall ==="

sudo ufw allow OpenSSH
sudo ufw allow 22/tcp
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo
echo "=== Creating directories ==="

sudo mkdir -p /opt/cornell-tilde/bin
sudo mkdir -p /opt/cornell-tilde/lib
sudo mkdir -p /opt/cornell-tilde/templates
sudo mkdir -p /opt/cornell-tilde/var
sudo mkdir -p /opt/cornell-tilde/backups
sudo mkdir -p /var/www/html

echo
echo "=== Database setup ==="

sudo groupadd -f cornelltilde-db

sudo touch /opt/cornell-tilde/var/cornell_tilde.sqlite3

sudo chown root:cornelltilde-db /opt/cornell-tilde/var
sudo chmod 770 /opt/cornell-tilde/var

sudo chown root:cornelltilde-db /opt/cornell-tilde/var/cornell_tilde.sqlite3
sudo chmod 660 /opt/cornell-tilde/var/cornell_tilde.sqlite3

sudo PYTHONPATH=/opt/cornell-tilde/lib \
python3 -c "from cornell_tilde.db import init_db; init_db()"

echo
echo "=== Creating join user if missing ==="

if ! id join >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" join
fi

echo "join:$JOIN_PASSWORD" | sudo chpasswd

sudo usermod -aG cornelltilde-db join

echo
echo "=== Writing sudoers file ==="

sudo tee /etc/sudoers.d/join_script > /dev/null <<'EOC'
join ALL=(root) NOPASSWD: /opt/cornell-tilde/bin/join_script.py
EOC

sudo chown root:root /etc/sudoers.d/join_script
sudo chmod 0440 /etc/sudoers.d/join_script
sudo visudo -c

echo
echo "=== Writing MOTD ==="

sudo tee /etc/motd > /dev/null <<EOC
Welcome to tilde@Cornell!

Your personal webpage:
https://$SERVER_DOMAIN/~yourusername

Edit your site:
~/public_html/index.html

User Directory:
https://$SERVER_DOMAIN/directory/

SSH Key Setup:
https://$SERVER_DOMAIN/ssh/

If you need help, have account issues, or notice something broken:

admin@cornelltilde.com
EOC

echo
echo "=== Apache global ServerName ==="

sudo tee /etc/apache2/conf-available/servername.conf > /dev/null <<EOC
ServerName $SERVER_DOMAIN
EOC

sudo a2enconf servername || true

echo

echo "=== Apache custom configuration==="
sudo a2enmod userdir || true

sudo tee /etc/apache2/conf-available/cornell-tilde.conf > /dev/null <<'EOC'
<IfModule mod_userdir.c>
    UserDir public_html
    UserDir disabled root
</IfModule>

<Directory /home/*/public_html>
    AllowOverride None
    Options -Indexes +FollowSymLinks
    Require all granted
</Directory>

ErrorDocument 403 /errors/403.html
ErrorDocument 404 /errors/404.html
EOC

sudo a2enconf cornell-tilde || true

sudo apache2ctl configtest
sudo systemctl reload apache2

echo
echo "=== Permissions ==="

sudo chown -R root:root /opt/cornell-tilde

sudo chmod 755 /opt/cornell-tilde
sudo chmod 700 /opt/cornell-tilde/backups

sudo chmod 750 /opt/cornell-tilde/bin
sudo chmod 750 /opt/cornell-tilde/lib
sudo chmod 750 /opt/cornell-tilde/lib/cornell_tilde
sudo chmod 750 /opt/cornell-tilde/templates

sudo chmod 755 /opt/cornell-tilde/bin/tilde-admin
sudo chmod 755 /opt/cornell-tilde/bin/join_script_wrapper.sh

sudo chmod 750 /opt/cornell-tilde/bin/approve_user.py
sudo chmod 750 /opt/cornell-tilde/bin/generate_directory.py
sudo chmod 750 /opt/cornell-tilde/bin/join_script.py

sudo chown root:cornelltilde-db /opt/cornell-tilde/var
sudo chmod 770 /opt/cornell-tilde/var

sudo chown root:cornelltilde-db /opt/cornell-tilde/var/cornell_tilde.sqlite3
sudo chmod 660 /opt/cornell-tilde/var/cornell_tilde.sqlite3

echo
echo "=== Join ACLs ==="

sudo setfacl -m u:join:--x /opt/cornell-tilde

sudo setfacl -m u:join:r-x /opt/cornell-tilde/bin
sudo setfacl -m u:join:r-x /opt/cornell-tilde/bin/join_script.py
sudo setfacl -m u:join:r-x /opt/cornell-tilde/bin/join_script_wrapper.sh

sudo setfacl -m u:join:r-x /opt/cornell-tilde/lib
sudo setfacl -m u:join:r-x /opt/cornell-tilde/lib/cornell_tilde
sudo setfacl -m u:join:r-- /opt/cornell-tilde/lib/cornell_tilde/*.py

sudo setfacl -m u:join:rwx /opt/cornell-tilde/var
sudo setfacl -m u:join:rw- /opt/cornell-tilde/var/cornell_tilde.sqlite3

echo
echo "=== Site permissions ==="

sudo chown -R root:root /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

echo "!!!!!!!!!!!!!!!!!!!!!"
echo "=== TEMP Symlinks ==="
echo "!!!!!!!!!!!!!!!!!!!!!"

sudo ln -sf /opt/cornell-tilde/bin/approve_user.py /usr/local/sbin/approve_user.py
sudo ln -sf /opt/cornell-tilde/bin/generate_directory.py /usr/local/sbin/generate_directory.py
sudo ln -sf /opt/cornell-tilde/bin/join_script.py /usr/local/sbin/join_script.py
sudo ln -sf /opt/cornell-tilde/bin/join_script_wrapper.sh /usr/local/sbin/join_script_wrapper.sh
sudo ln -sf /opt/cornell-tilde/bin/tilde-admin /usr/local/sbin/tilde-admin

echo
echo "=== Final verification ==="

sudo /usr/local/sbin/generate_directory.py

sudo apache2ctl configtest
sudo sshd -t
sudo visudo -c

sudo PYTHONPATH=/opt/cornell-tilde/lib \
python3 -c "from cornell_tilde.db import get_connection; print('db import works')"

sudo sqlite3 /opt/cornell-tilde/var/cornell_tilde.sqlite3 ".tables"

echo
echo "=== SSH configuration ==="

sudo python3 - <<'PY'
from pathlib import Path

path = Path("/etc/ssh/sshd_config")
text = path.read_text()

lines = text.splitlines()

new_lines = []
inside_join_block = False

for line in lines:
    stripped = line.strip()

    if stripped == "Match User join":
        inside_join_block = True
        continue

    if inside_join_block:
        if stripped.startswith("Match "):
            inside_join_block = False
            new_lines.append(line)
        else:
            continue
    else:
        new_lines.append(line)

text = "\n".join(new_lines) + "\n"

def set_directive(text: str, key: str, value: str) -> str:
    lines = text.splitlines()
    out = []
    found = False

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("#"):
            out.append(line)
            continue

        parts = stripped.split()
        if parts and parts[0] == key:
            if not found:
                out.append(f"{key} {value}")
                found = True
            continue

        out.append(line)

    if not found:
        out.append(f"{key} {value}")

    return "\n".join(out) + "\n"

text = set_directive(text, "PermitRootLogin", "no")
text = set_directive(text, "PasswordAuthentication", "no")
text = set_directive(text, "PermitUserEnvironment", "no")

join_block = """
Match User join
        ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh
        PasswordAuthentication yes
        PubkeyAuthentication no
        PermitTTY yes
        X11Forwarding no
        AllowTcpForwarding no
        AllowAgentForwarding no
        PermitTunnel no
"""

text = text.rstrip() + "\n\n" + join_block.lstrip()
path.write_text(text)
PY

sudo sshd -t
sudo systemctl restart ssh

echo
echo "=== IMPORTANT MANUAL STEPS STILL REQUIRED ==="
echo
echo "1. Run certbot:"
echo
echo "   sudo certbot --apache -d $SERVER_DOMAIN"
echo
echo "2. Test:"
echo
echo "   ssh join@$SERVER_DOMAIN"
echo
echo "=== Install complete ==="
