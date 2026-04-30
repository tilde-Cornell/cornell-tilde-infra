FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo \
        acl \
        sqlite3 \
        python3 \
        python3-dotenv \
        apache2 \
        openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure
RUN mkdir -p \
        /opt/cornell-tilde/bin \
        /opt/cornell-tilde/lib \
        /opt/cornell-tilde/migrations \
        /opt/cornell-tilde/systemd \
        /opt/cornell-tilde/templates \
        /opt/cornell-tilde/var \
        /var/www/html \
        /run/sshd

# Copy project files
COPY opt/cornell-tilde/bin/       /opt/cornell-tilde/bin/
COPY opt/cornell-tilde/lib/       /opt/cornell-tilde/lib/
COPY opt/cornell-tilde/migrations/ /opt/cornell-tilde/migrations/
COPY opt/cornell-tilde/systemd/   /opt/cornell-tilde/systemd/
COPY opt/cornell-tilde/templates/ /opt/cornell-tilde/templates/
COPY var/www/html/                /var/www/html/
COPY deploy/                      /deploy/

# Set permissions matching apply-runtime.sh
RUN chown -R root:root /opt/cornell-tilde /deploy \
    && chmod 755 /opt/cornell-tilde \
    && chmod 750 \
        /opt/cornell-tilde/bin \
        /opt/cornell-tilde/lib \
        /opt/cornell-tilde/migrations \
        /opt/cornell-tilde/systemd \
        /opt/cornell-tilde/templates \
    && chmod 755 \
        /opt/cornell-tilde/bin/tilde-admin.sh \
        /opt/cornell-tilde/bin/join_script_wrapper.sh \
    && chmod 750 \
        /opt/cornell-tilde/bin/approve_user.py \
        /opt/cornell-tilde/bin/generate_directory.py \
        /opt/cornell-tilde/bin/join_script.py \
        /opt/cornell-tilde/bin/submit_application.py \
        /opt/cornell-tilde/bin/rebuild_directory_when_modified.sh \
    && chmod 640 /opt/cornell-tilde/migrations/*.sql \
    && chmod 644 \
        /opt/cornell-tilde/systemd/*.service \
        /opt/cornell-tilde/systemd/*.path \
    && chmod 755 \
        /deploy/apply-runtime.sh \
        /deploy/configure-ssh.sh \
        /deploy/post-deploy.sh \
        /deploy/common.sh

# Set up database group and permissions
RUN groupadd cornelltilde-db \
    && touch /opt/cornell-tilde/var/cornell_tilde.sqlite3 \
    && chown root:cornelltilde-db \
        /opt/cornell-tilde/var \
        /opt/cornell-tilde/var/cornell_tilde.sqlite3 \
    && chmod 770 /opt/cornell-tilde/var \
    && chmod 660 /opt/cornell-tilde/var/cornell_tilde.sqlite3

# Initialize the database
RUN PYTHONPATH=/opt/cornell-tilde/lib python3 \
        -c "from cornell_tilde.db import init_db; init_db()"

# Create the join user
RUN adduser --disabled-password --gecos "" join

# Set up sudoers entry so join can run the submit helper as root
RUN printf 'join ALL=(root) NOPASSWD: /opt/cornell-tilde/bin/submit_application.py\n' \
        > /etc/sudoers.d/join_script \
    && chmod 0440 /etc/sudoers.d/join_script

# Enable Apache modules and write configuration
RUN a2enmod userdir \
    && printf 'ServerName localhost\n' \
        > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && printf '<IfModule mod_userdir.c>\n\
    UserDir public_html\n\
    UserDir disabled root\n\
</IfModule>\n\
\n\
<Directory /home/*/public_html>\n\
    AllowOverride None\n\
    Options -Indexes +FollowSymLinks\n\
    Require all granted\n\
</Directory>\n\
\n\
ErrorDocument 403 /errors/403.html\n\
ErrorDocument 404 /errors/404.html\n' \
        > /etc/apache2/conf-available/cornell-tilde.conf \
    && a2enconf cornell-tilde \
    && chown -R root:root /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} + \
    && find /var/www/html -type f -exec chmod 644 {} +

# Generate SSH host keys and write a clean sshd_config
RUN ssh-keygen -A \
    && printf '%s\n' \
        'Port 22' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        'PermitUserEnvironment no' \
        'UsePAM yes' \
        'PrintMotd no' \
        'AcceptEnv LANG LC_*' \
        'Subsystem sftp /usr/lib/openssh/sftp-server' \
        '' \
        'Match User join' \
        '    ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh' \
        '    PasswordAuthentication yes' \
        '    PubkeyAuthentication no' \
        '    PermitTTY yes' \
        '    X11Forwarding no' \
        '    AllowTcpForwarding no' \
        '    AllowAgentForwarding no' \
        '    PermitTunnel no' \
        > /etc/ssh/sshd_config

# Create symlinks for admin tools and deploy scripts
RUN ln -sf /opt/cornell-tilde/bin/approve_user.py \
        /usr/local/sbin/approve_user.py \
    && ln -sf /opt/cornell-tilde/bin/generate_directory.py \
        /usr/local/sbin/generate_directory.py \
    && ln -sf /opt/cornell-tilde/bin/join_script.py \
        /usr/local/sbin/join_script.py \
    && ln -sf /opt/cornell-tilde/bin/join_script_wrapper.sh \
        /usr/local/sbin/join_script_wrapper.sh \
    && ln -sf /opt/cornell-tilde/bin/submit_application.py \
        /usr/local/sbin/submit_application.py \
    && ln -sf /opt/cornell-tilde/bin/tilde-admin.sh \
        /usr/local/sbin/tilde-admin \
    && ln -sf /opt/cornell-tilde/bin/rebuild_directory_when_modified.sh \
        /usr/local/sbin/rebuild_directory_when_modified.sh \
    && ln -sf /deploy/apply-runtime.sh  /usr/local/sbin/apply-runtime \
    && ln -sf /deploy/configure-ssh.sh  /usr/local/sbin/configure-ssh \
    && ln -sf /deploy/post-deploy.sh    /usr/local/sbin/post-deploy

EXPOSE 22 80

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
