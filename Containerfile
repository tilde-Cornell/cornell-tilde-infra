FROM debian:trixie

RUN apt-get update && \
    apt-get install -y systemd\
    systemd-sysv\
    sudo\
    curl \
    tree \
    rsync \
    acl \
    sqlite3 \
    python3 \
    apache2 \
    openssh-server &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./deploy /deploy
COPY ./opt /opt
COPY ./tools /tools
COPY ./var /var

RUN chmod +x /deploy/container/setup-container.sh

RUN echo JOIN_PASSWORD=$JOIN_PASSWORD SERVER_DOMAIN=$SERVER_DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL container=$container >> /deploy/container/systemd/setup-container.env

RUN ln -s /deploy/container/systemd/setup-in-container.service /etc/systemd/system/setup-in-container.service &&\
    systemctl enable ssh apache2

RUN echo "root:$ROOT_PASSWORD" | chpasswd

CMD ["/lib/systemd/systemd"]
