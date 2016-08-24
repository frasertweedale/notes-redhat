TLS client cert authentication
==============================

::

  dnf install -y mozldap-tools

  /usr/lib64/mozldap/ldapsearch -Z \
    -P /etc/pki/pki-tomcat/alias \
    -W $(grep ^internal= /etc/pki/pki-tomcat/password.conf | cut -d = -f 2) \
    -N "subsystemCert cert-pki-ca" \
    -b <search base> <filter>
