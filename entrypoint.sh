#!/usr/bin/env bash

set -eu

SECRET_FILE="/var/lib/samba/private/secrets.tdb"

# Read settings
: "${SAMBA_LDAP_PW:?"ERROR: Environment variable SAMBA_LDAP_PW not set"}"
: "${LDAP_TLS_ENABLE:="false"}"
if [ "${LDAP_TLS_ENABLE,,}" == "true" ]; then
    : "${LDAP_PORT:="636"}"
    : "${LDAP_TLS_REQCERT:="demand"}"
    : "${LDAP_TLS_PROTOCOL_MIN:="3.4"}"
    : "${LDAP_TLS_CERT_DIR:="/etc/ssl/certs"}"
    : "${LDAP_TLS_CACERT:="${LDAP_TLS_CERT_DIR}/chain.pem"}"
else
    : "${LDAP_PORT:="389"}"
    : "${LDAP_TLS_REQCERT:="never"}"
    : "${LDAP_TLS_PROTOCOL_MIN:=""}"
    : "${LDAP_TLS_CERT_DIR:=""}"
    : "${LDAP_TLS_CACERT:=""}"
fi
if [ -z "${LDAP_URI:-""}" ]; then
    : "${LDAP_HOST:?"ERROR: Environment variable LDAP_URI or LDAP_HOST not set"}"
    if [ "${LDAP_TLS_ENABLE,,}" == "true" ]; then
        LDAP_URI="ldaps://${LDAP_HOST}:${LDAP_PORT}"
    else
        LDAP_URI="ldap://${LDAP_HOST}:${LDAP_PORT}"
    fi
else
    if [ -z "${LDAP_HOST:-""}" ]; then
        LDAP_HOST="${LDAP_URI#*//}"
        LDAP_HOST="${LDAP_HOST%:*}"
    fi
fi
: "${LDAP_DOMAIN:=?"ERROR: Environment variable LDAP_DOMAIN not set"}"
: "${LDAP_BASE:=?"ERROR: Environment variable LDAP_BASE not set"}"
: "${LDAP_BASE_USER:="${LDAP_BASE}"}"
: "${LDAP_BASE_GROUPS:="${LDAP_BASE}"}"
: "${LDAP_BIND:=""}"
: "${LDAP_BIND_PW:=""}"

if [ ! -s /etc/ldap/ldap.conf ]; then
# Generate LDAP config
cat << FILE_END > /etc/ldap/ldap.conf
HOST ${LDAP_HOST}
PORT ${LDAP_PORT}
URI ${LDAP_URI}
BASE ${LDAP_BASE}
TLS_REQCERT ${LDAP_TLS_REQCERT}
TLS_PROTOCOL_${LDAP_TLS_PROTOCOL_MIN}
TLS_CACERT ${LDAP_TLS_CACERT}
FILE_END
fi

if [ ! -s /etc/sssd/sssd.conf ]; then
# Generate SSS config
cat << FILE_END > /etc/sssd/sssd.conf
[sssd]
config_file_version = 2
domains = ${LDAP_DOMAIN}
services = nss,pam

[pam]
offline_credentials_expiration = 60

[nss]
filter_users = root, ldap, named, avahi, haldaemon, dbus, radiusd, news, nscd

[domain/${LDAP_DOMAIN}]
enumerate = True
ignore_group_members = True
cache_credentials = True
ldap_user_member_of = memberOf
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
access_provider = ldap
ldap_schema = rfc2307bis
ldap_id_use_start_tls = False
ldap_uri = ${LDAP_URI}
ldap_search_base = ${LDAP_BASE}
ldap_user_search_base = ${LDAP_BASE_USER}
ldap_group_search_base = ${LDAP_BASE_GROUPS}
ldap_default_bind_dn = ${LDAP_BIND}
ldap_default_authtok = ${LDAP_BIND_PW}
ldap_tls_reqcert = ${LDAP_TLS_REQCERT}
ldap_tls_cacert = ${LDAP_TLS_CACERT}
ldap_tls_cacertdir = ${LDAP_TLS_CERT_DIR}
ldap_search_timeout = 50
ldap_network_timeout = 60
ldap_access_order = filter
ldap_access_filter = (objectClass=posixAccount)
FILE_END
fi

# Set file permissions
if [ "${EUID}" -eq 0 ]; then
    chown 0:0 /etc/ldap/ldap.conf /etc/sssd/sssd.conf || true
    chmod 600 /etc/ldap/ldap.conf /etc/sssd/sssd.conf || true
fi

# Activate SSS
sssd --logger=stderr

# Setup Samba admin DN password
smbpasswd -w "${SAMBA_LDAP_PW}"
if [[ ! -e "${SECRET_FILE}" ]] ; then
    echo "ERROR: ${SECRET_FILE} does not exists"
    exit 10
fi

# Run command
if [[ "$#" -ge 1 && -x $(commad -v "${1}" 2>&-) ]]; then
    exec "$@"
elif [[ "$#" -ge 1 ]]; then
    echo "ERROR: Command not found: ${1}"
    exit 20
elif ps -ef | egrep -v grep | grep -q smbd; then
    echo "Service already running, please restart container to apply changes"
else
    ionice -c 3 smbd --foreground --no-process-group --debug-stdout
fi
