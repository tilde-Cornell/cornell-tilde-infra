#!/bin/bash
set -euo pipefail

echo "=== tilde@Cornell New Server Install ==="
echo

if [ "$EUID" -ne 0 ]; then
  echo "run with sudo! sudo /deploy/setup.sh"
  exit 1
fi

if [[ ! -v container ]]; then
  read -rsp "Password for join user: " JOIN_PASSWORD
  echo
  read -rp "Server domain (example: cornelltilde.com or dev.cornelltilde.com): " SERVER_DOMAIN
  echo
  read -rp "Admin contact email (example: admin@cornelltilde.com): " ADMIN_EMAIL
  echo

  echo "Server domain: $SERVER_DOMAIN"
  echo "Admin contact email: $ADMIN_EMAIL"
  echo

  echo "=== Installing packages ==="

  sudo apt-get update
  sudo apt-get upgrade -y

  sudo apt-get install -y \
    sudo \
    curl \
    tree \
    rsync \
    acl \
    sqlite3 \
    python3 \
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
fi

echo
echo "=== Creating directories ==="

sudo mkdir -p /opt/cornell-tilde/bin
sudo mkdir -p /opt/cornell-tilde/lib
sudo mkdir -p /opt/cornell-tilde/migrations
sudo mkdir -p /opt/cornell-tilde/systemd
sudo mkdir -p /opt/cornell-tilde/templates
sudo mkdir -p /opt/cornell-tilde/var
sudo mkdir -p /var/www/html

sudo tee /opt/cornell-tilde/.env > /dev/null <<EOC
SITE_DOMAIN=$SERVER_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
EOC

echo
echo "=== Database setup ==="

sudo groupadd -f cornelltilde-db

echo
echo "=== Creating join user if missing ==="

if ! id join >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" join
fi

echo "join:$JOIN_PASSWORD" | sudo chpasswd

echo
echo "=== Writing sudoers file ==="

sudo tee /etc/sudoers.d/join_script > /dev/null <<'EOC'
join ALL=(root) NOPASSWD: /opt/cornell-tilde/bin/submit_application.py
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

$ADMIN_EMAIL
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
echo "=== Applying runtime state ==="

sudo bash /deploy/apply-runtime.sh

echo
sudo bash /deploy/configure-ssh.sh

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
