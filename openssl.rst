OpenSSL notes
=============

OCSP
----

Send an OCSP request and print response::

  openssl ocsp -resp_text \
    -url http://ipa-1.ipa.local:8080/ca/ocsp \
    -issuer dev/cert/ipa-1/ca.pem -serial 8

The serial number can be specified in decimal or hex (preceded by
``0x``).
