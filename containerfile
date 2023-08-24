FROM ubuntu:22.04

RUN set -ex \
    \
    && apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        iputils-ping \
        ldap-utils \
        libpam-sss \
        nano \
        openssl \
        samba \
        samba-vfs-modules \
        smbclient \
        sssd \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY nsswitch.conf /etc/

RUN set -ex \
    \
    && mkdir -p /etc/ldap \
    && chmod +x /usr/bin/entrypoint.sh

EXPOSE 445

ENTRYPOINT ["entrypoint.sh"]
