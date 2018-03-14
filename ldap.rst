TLS client cert authentication
==============================

::

  dnf install -y mozldap-tools

  /usr/lib64/mozldap/ldapsearch -Z \
    -P /etc/pki/pki-tomcat/alias \
    -W $(grep ^internal= /etc/pki/pki-tomcat/password.conf | cut -d = -f 2) \
    -N "subsystemCert cert-pki-ca" \
    -b <search base> <filter>

If ``mozldap-tools`` is not available you can use curl::

  # SSL_DIR=/path/to/nssdb curl -v ldaps://rhel75-0.ipa.local/o=ipaca
