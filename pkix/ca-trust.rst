How to configure CA trust for assorted programs
===============================================

python-requests
---------------

::

  export REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
