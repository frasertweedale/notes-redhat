OpenSSL notes
=============

PKCS#10 certificate requests
----------------------------

Generate new key and CSR::

  openssl req -newkey rsa:4096 -keyout key.pem -out req.pem [-nodes]

Config file with subjectAltName extension::

  [ req ]
  prompt = no
  encrypt_key = no

  distinguished_name = bogo
  req_extensions = lolsan

  [ bogo ]
  commonName = "bogo.ipa.local"

  [ lolsan ]
  subjectAltName=DNS:lol.ipa.local


OCSP
----

Send an OCSP request and print response::

  openssl ocsp -resp_text \
    -CAfile <trusted-CAs> \
    -url http://ipa-1.ipa.local:8080/ca/ocsp \
    -issuer <issuer-cert> -serial 8

The serial number can be specified in decimal or hex (preceded by
``0x``).


s_client
--------

To use SNI, supply the ``-servername <name>`` argument.

Full example::

  openssl s_client -CAfile ca.pem \
    -connect pussers.frase.id.au:443 \
    -servername pussers.frase.id.au


pkcs12
------

Combine key and certificate PEM files into a PKCS #12 file::

  % openssl pkcs12 -export -out foo.p12 \
    -inkey key.pem \
    -in cert.pem \
    -name "nickname"
  Enter pass phrase for key.pem:
  Enter Export Password:
  Verifying - Enter Export Password:
  %
