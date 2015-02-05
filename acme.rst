ACME and Let's Encrypt
======================


Non-trivial use cases
---------------------

* Multiple names:
  https://groups.google.com/a/letsencrypt.org/forum/#!topic/ca-dev/ira3Qv0KvCE


node-acme
=========

Running the node-acme server::

  npm install node-acme
  node server.js

Make sure that the firewall is down::

  sudo firewall-cmd --add-port=8888/tcp


lets-encrypt-preview
====================

First attempt; default Debian 7.8 apache config.

Running in virtual environment::

  # must run in root of repository
  sudo $(which letsencrypt) \
    --domains debian78-0.ipa.local \
    --server acme.ipa.local

Resulted in following output::

  Generating key: /etc/apache2/ssl/key-letsencrypt_6.pem
  Performing the following challenges:
    DVSNI challenge for name debian78-0.ipa.local.
  No vhost exists with servername or alias of: debian78-0.ipa.local
  No _default_:443 vhost exists
  Please specify servernames in the Apache config

Ok, so have to configure a vhost for the domain first.
Would be nice if it could set it up for you from nada.

Added ``ServerName`` directive to
``/etc/apache2/sites-available/default`` and tried again::

  Generating key: /etc/apache2/ssl/key-letsencrypt_7.pem
  Performing the following challenges:
  DVSNI challenge for name debian78-0.ipa.local.
  Created an SSL vhost at
  /etc/apache2/sites-available/default-le-ssl.conf
  Ready for verification...
  Waiting for 3 seconds...
  Received Authorization for debian78-0.ipa.local
  Cleaning up challenges for debian78-0.ipa.local
  Creating CSR: /etc/apache2/certs/csr-letsencrypt.pem
  Preparing and sending CSR...
  Server issued certificate; certificate written to
  /etc/apache2/certs/cert-letsencrypt.pem
  Deploying Certificate to VirtualHost
  /etc/apache2/sites-available/default-le-ssl.conf
  Enabling available site:
  /etc/apache2/sites-available/default-le-ssl.conf
  Redirecting vhost in /etc/apache2/sites-available/default to ssl
  vhost in /etc/apache2/sites-available/default-le-ssl.conf

During this process, was prompted about whether to redirect from
http to https.  Selected yes (why wouldn't you?!)


Resultant Apache config
-----------------------

Original vhost config in ``/etc/apache2/sites-available/`` with symlink
in ``/etc/apache2/sites-enabled/``::

  <VirtualHost *:80>
          ServerName devconf.ipa.local
          DocumentRoot /var/www
  </VirtualHost>


If permanent redirect to secured site was selected, insecure vhost
has following added to config::

  RewriteEngine On
  RewriteRule ^.*$ https://%{SERVER_NAME}%{REQUEST_URI} [L,R=permanent]

New vhost file appears::

  <IfModule mod_ssl.c>
  <VirtualHost *:443>
          ServerName devconf.ipa.local
          DocumentRoot /var/www
  SSLCertificateFile /etc/apache2/certs/cert-letsencrypt_1.pem
  SSLCertificateKeyFile /etc/apache2/ssl/key-letsencrypt_9.pem
  Include /etc/letsencrypt/options-ssl.conf
  </VirtualHost>
  </IfModule>

Notes about contents of ``/etc/letsencrypt/options-ssl.conf``:

- ``SSLProtocol all -SSLv3 -SSLv3``
- Very long ``SSLCipherSuite``
- ``SSLHonorCipherOrder on``
- ``SSLCompression on`` (mitigate CRIME attack)
- ``ServerSignature Off``
- ``AcceptPathInfo Off``


Certificate details
-------------------

node-acme dished up the following certificate::

  -----BEGIN CERTIFICATE-----
  MIIC/DCCAeSgAwIBAgIEkBc+5jANBgkqhkiG9w0BAQUFADAPMQ0wCwYDVQQKEwRB
  Q01FMB4XDTE1MDEyMjA3NDUwN1oXDTE2MDEyMjA3NDUwN1owHzEdMBsGA1UEAxMU
  ZGViaWFuNzgtMC5pcGEubG9jYWwwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
  AoIBAQC0+xGa6V4zogaxMn41HRYsQWw5ecI1u2JNFs9+yhERAl8bREKcdJoL0JrY
  W5kJqqFYXjM3AzbKqILKDR2N/z7bgejtcmnK6fPZs8OsEeIzFnIHjBJKHpiw7Mt1
  O7AJPtg0zJ7jZJejRCROCUXTqqxerYFptJBYvbU6M4MRMZKAxlW5mZAjCMhZlGu3
  Z+BCHrtgHzFyndIsPAeJuUo7qCuzcWR/i2yRLiPZ0FLTnjmlYjdrzmfydZo8WGYy
  8bi4o9Ie53OXrtxZUkSuCzYPu2cAfMvuE6foeo0ZphT75nyjS/LzaXeKnmhzv+RM
  BKQwCMUmT5SjbC511qt6cxzcmHQ9AgMBAAGjUDBOMAkGA1UdEwQCMAAwCwYDVR0P
  BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMB8GA1UdEQQYMBaCFGRlYmlhbjc4
  LTAuaXBhLmxvY2FsMA0GCSqGSIb3DQEBBQUAA4IBAQBt0DDMsfaF3BaaG2mWp7Fk
  Ot01M/DJVzUlAY9Ds7+5SBcGBcP3OajqrQEIgPZ41zNlAXiaKvFQuOtplxHXrPgk
  nwwFzQY3k0e100Lt7RNmgHsYTrAnmF+pIKICbOUDTyFRFxsOPn5LKca+IczPc+9e
  HBKTDkMxSaiYtcVra+ESo4zpcODQQ4MwmrbnEttxv7ah6h/FsPh38oAN++WgNNOU
  GDAgDwghUwN5c3chEyqbcJrAMZ/oc7zfF+nnHjmygGxYEM+VVQ+qMEd9WEXmIGJe
  OLn47hYwfim0GBSt2biNY9nyrzCofhdoo9AZTdol2PMOcb3WHi5PH/N1b1OtxCn8
  -----END CERTIFICATE-----

Notes:

- Serial number is (or can be) negative; violation of RFC 5280.
  https://github.com/letsencrypt/node-acme/issues/11

- No authorityKeyIdentifier extension, which is a violation of RFC
  5280.
  https://github.com/letsencrypt/node-acme/issues/12

- No subjectKeyIdentifier extension, which SHOULD be included.
  https://github.com/letsencrypt/node-acme/issues/13


Future
======

- Additional certificate features

  - additional alternative names

- Additional validation mechanisms?

  -  DNSSEC?

- Support more web servers

- Support other applications

  - Email validation, certificate request, email client
    configuration for S/MIME?

- letsencrypt client can offer to configure additional HTTP security
  mechanisms

  - HTTP Strict Transport Security

  - HTTP Public Key Pinning
    - https://developer.mozilla.org/en-US/docs/Web/Security/Public_Key_Pinning
    - TOFU (trust on first use)

  - Ensure Secure cookies

- Disable HTTP entirely (not just redirect)

- Configure new vhost from nothing (currently requires existing
  vhost)

  - DNS must already be in place
