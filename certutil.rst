List certificates in database::

  certutil -d ~/.pki/nssdb -L

Delete a certificate by nickname::

  certutil -d ~/.pki/nssdb -D -n "PKI Administrator for ipa.local"

Import a PKCS #12 certificate and key::

  pk12util -d ~/.pki/nssdb -i <p12 file>

Add a trusted CA signing certificate.  ``C`` indicates that it is a
trusted server CA for that category.  The categories are
``ssl,email,code``.

::

   certutil -d ~/.pki/nssdb -A ca.p7c -n 'CA Signing Certificate' -t CT,c,

Modify certificate trust::

  certutil -d . -M -t "CTu,Cu,Cu" -n <nickname>


Add an end-entity certificate as a trusted peer::

  certutil -d <db> -A -t P,P,P -n 'nickname' -i <cert>
