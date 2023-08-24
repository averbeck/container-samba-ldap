# Environment Variables

This image uses several environment variables in order to control its behavior.
Several of these variables a required:

* `SAMBA_LDAP_PW`

Password for the LDAP ADMIN DN set in `smb.conf` in order to bind the directory.

* `LDAP_URI`
* `LDAP_HOST`
* `LDAP_PORT`
* `LDAP_DOMAIN`
* `LDAP_BASE`
* `LDAP_BASE_USER`
* `LDAP_BASE_GROUPS`
* `LDAP_BIND`
* `LDAP_BIND_PW`
* `LDAP_TLS_ENABLE`
* `LDAP_TLS_REQCERT`
* `LDAP_TLS_PROTOCOL_MIN`
* `LDAP_TLS_CERT_DIR`
* `LDAP_TLS_CACERT`

More information about the variables, their meaning and their interaction can be found in the file `entrypoint.sh`.
