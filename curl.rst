Client certificate authentication with NSS
------------------------------------------

Note that:

- The ``SSL_DIR`` envvar provides path to the NSSDB
- Argument to ``--cert`` is ``<nickname>:<nssdb_passphrase>``
- User must have appropriate FS permissions on NSSDB

::

  % SSL_DIR=/etc/httpd/alias curl -v \
    --cert ipaCert:$(cat /etc/httpd/alias/pwdfile.txt) \
    https://$(hostname):8443/ca/rest/account/login
