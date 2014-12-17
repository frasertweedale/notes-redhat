OpenSSL notes
=============

PKCS#10 certificate requests
----------------------------

Generate new key and CSR::

  openssl req -newkey rsa:4096 -keyout key.pem -out req.pem [-nodes]


OCSP
----

Send an OCSP request and print response::

  openssl ocsp -resp_text \
    -url http://ipa-1.ipa.local:8080/ca/ocsp \
    -issuer dev/cert/ipa-1/ca.pem -serial 8

The serial number can be specified in decimal or hex (preceded by
``0x``).


s_client
--------

To use SNI, supply the ``-servername <name>`` argument.

Full example::

  openssl s_client -CAfile ca.pem \
    -connect pussers.frase.id.au:443 \
    -servername pussers.frase.id.au
