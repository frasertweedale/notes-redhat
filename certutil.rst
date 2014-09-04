List certificates in database::

  certutil -d ~/.pki/nssdb -L

Delete a certificate by nickname::

  certutil -d ~/.pki/nssdb -D -n "PKI Administrator for ipa.local"

Import a PKCS #12 certificate and key::

  pk12util -d ~/.pki/nssdb -i <p12 file>
