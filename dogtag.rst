Issues
======

- Property policyset.serverCertSet.2.constraint.params.notBeforeGracePeriod missing value
- typo getSUppor RegistryAdminServlet.java:281


Building
========

::

  $ cd dev
  $ mkdir pki-build
  $ cd pki-build
  $ cmake \
    -DBUILD_PKI_CORE:BOOL=ON \
    -DJAVA_LIB_INSTALL_DIR=/usr/lib/java \
    -DRESTEASY_LIB=/usr/share/java/resteasy \
    ../pki
  $ make [target]

Interesting targets:

- pki-cms-classes
