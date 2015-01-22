ACME and Let's Encrypt
======================


Non-trivial use cases
---------------------

* Multiple names:
  https://groups.google.com/a/letsencrypt.org/forum/#!topic/ca-dev/ira3Qv0KvCE


lets-encrypt-preview
====================

First attempt; default Debian 7.8 apache config.

Running in virtual environment::

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
