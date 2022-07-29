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
- pki-cmscore-classes
- pki-ca-classes
- pki-tomcat-classes
- pki-tools-classes


Spawning
========

Minimal ``pkispawn(8)`` configuration file::

  [DEFAULT]
  pki_admin_password=4me2Test
  pki_client_database_password=4me2Test
  pki_client_pkcs12_password=4me2Test
  pki_ds_password=4me2Test

  [CA]
  pki_profiles_in_ldap=True
  pki_ca_signing_subject_dn=cn=CA Signing Certificate 201504231331

Spawn an instance::

  $ pkispawn -s CA -f my.conf


CLI tools
=========

- http://pki.fedoraproject.org/wiki/CLI

Prepare IPA RA NSSDB
--------------------

Recent versions of FreeIPA have IPA RA key and certificate stored
as PEM files instead of in ``/etc/httpd/alias``.  Therefore we need
to prepare an NSSDB for use with ``pki`` CLI tool.

::

  % openssl pkcs12 -export -out ipara.p12 \
    -inkey /var/lib/ipa/ra-agent.key \
    -in <(cat /var/lib/ipa/ra-agent.pem /etc/ipa/ca.crt) \
    -name ipaCert
  % mkdir nssdb
  % certutil -d nssdb -N
  % pk12util -d nssdb -i ipara.p12


profile module
--------------

Common arguments:

- ``-d ~/.pki/nssdb``
- ``-c <cert-db-password>``
- ``-C <certdb-password-file>``
- ``-n "PKI Administrator for ipa.local"``

Example::

  % pki -d /etc/httpd/alias -C /etc/httpd/alias/pwdfile.txt -n ipaCert ...

Show, add and delete profiles::

  % pki ca profile show [--raw] [--outout <filename>] <profileId>
  % pki ca profile add <filename> [--raw]
  % pki ca profile del <profileId>

Invoke an editor to edit a profile::

  % pki ca profile edit <profileId>


Config
======

NSS DB: ``/var/lib/pki/<instance>/conf/alias/``

NSS DB passphrase is stored in
``/var/lib/pki/<instance>/conf/password.conf``, field ``internal``.


Walkthroughs
============

Enrolling a subordinate signing certificate
-------------------------------------------

1. Create a PKCS #10 CSR
2. Enrol using ``caCrossSignedCACert`` profile


Debugging
=========

- Used to set ``JAVA_OPTS`` in ``/etc/pki/<instance-name>/tomcat.conf``.

- With nuxwdog, ``/etc/sysconfig/pki-tomcat`` is the place to set
  ``JAVA_OPTS``.
