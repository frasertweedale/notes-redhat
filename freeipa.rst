Resources
=========

- Demo site: https://github.com/frasertweedale/gcaff
- HOWTOs: http://www.freeipa.org/page/HowTos


nssdb
=====

Create new database (will prompt for password)::

  certutil -N -d ~/.pki/nssdb


certmonger
==========

Service certificate
-------------------

First create service in IPA.  Then request certificate::

  $ sudo ipa-getcert request -d ~/.pki/nssdb -P "$NSSDB_PASSWORD" \
    -K srv-1/host.domain \             # Kerberos principal
    -U id-kp-serverAuth  \             # EKU extension
    -n srv-1-vm-foo      \             # nssdb nickname to use
  New signing request "20140525200843" added.

List certificate requests managed by certmonger::

  $ ipa-getcert list -r

List all certificates and requests managed by certmonger::

  $ ipa-getcert list

Top tracking a certificate [request]::

  $ ipa-getcert stop-tracking -i "20140525200843"


Services
========

Add service principal::

  $ ipa service-add serviceName/hostname

Get service keytab (run on client)::

  $ ipa-getkeytab -s foo.example.com -p HTTP/foo.example.com \
    -k /etc/httpd/conf/krb5.keytab -e des-cbc-crc

This resets the secret for the specific principal, thus rendering
invalid any existing keytabs for that principal.

Certificates
------------

::

  $ ipa cert-request --principal=HTTP/web.example.com example.csr

Profiles
--------

See ``freeipa-profiles.rst``.
