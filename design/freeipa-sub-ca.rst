..
  Copyright 2014, 2015, 2016 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


{{Feature|version=4.4.0|ticket=4559|author=Ftweedal}}


Overview
========

FreeIPA's usefulness and appeal as a PKI is currently limited by the
fact that there is a single X.509 security domain.  Any certificate
issued by FreeIPA is signed by the single authority, regardless of
purpose.

FreeIPA requires a mechanism to issues certificates with different
certification chains, so that certificates issues for some
particular use (e.g. Puppet, VPN authentication, DNP3) can be
regarded as invalid for other uses.

Dogtag's `lightweight sub-CAs`_ feature will provide the foundation
for supporting multiple sub-CAs in FreeIPA.  This feature will
provide:

- an API for creating and administering sub-CAs *within* a CA
  subsystem instance;

- an augmented certificate request API for directing certificate
  requests to a particular CA or sub-CA within the instance.

FreeIPA will use these APIs to provide facilities for the creation
and administration of sub-CAs, and the issuance of certificates from
those CAs.

.. _lightweight sub-CAs: http://pki.fedoraproject.org/wiki/Lightweight_sub-CAs


Use Cases
=========

User certificates
-----------------

There are many use cases for issuing certificates to user
entities/principals from a sub-CA.  The sub-CA acts as a "scope"
indicating a particular intent or authorization for certificates
issued by the sub-CA, and the sub-CA's signing certificate can be
used to validate certificates issued in that scope (rejecting
others).  Some of these use cases are detailed below.

VPN authentication
^^^^^^^^^^^^^^^^^^

A FreeIPA-based tool could be implemented to request short-lived
user certificates for the purpose of VPN authentication.  It would
be inappropriate to accept as valid any client certificate issued by
the host CA, so a sub-CA specifically for VPN authentication
should be created for this purpose.  The certificate-issuing tool
would direct certificates signing requests to the VPN sub-CA.

A CLI command could be issued to retrieve the VPN CA's signing
certificate, and/or register it in a local security database, and
the user will configure the VPN server to use that CA certificate
for client certificate verification.


Puppet
------

A `blog post`_ about using FreeIPA as an external Puppet PKI
comments that:

  On the downside, there is the issue of security. FreeIPA out of
  the box only supports a single toplevel CA, which means that all
  your certificates (IPA host certs, puppet certs, Website certs,
  etc.) are all in a single security domain - there's no built-in
  way to restrict this access to puppet. Users can't invent certs,
  of course, but any cert with the right hostname can be used to
  authenticate to puppet, because they share the same trust
  hierarchy.

The proposed feature will remove this shortcoming of FreeIPA (which
applies not only to Puppet but in many situations.)

.. _blog post: http://jcape.name/2012/01/16/using-the-freeipa-pki-with-puppet/


Default sub-CAs for host, service and user certificates
-------------------------------------------------------

FreeIPA user Baptiste Agasse requested having separate domains for
host and user certificates by default:

  Hosts in FreeIPA can have an X.509 certificate for the host
  principal; you don't have to create any service on the host to
  request this certificate. If the security domains land in FreeIPA,
  it would be nice to have some default security domains, like one
  that sign hosts certificates by default, and why not another that
  sign user certificates by default.

This use case is not directly addressed by this design but because
this design makes it possible to do what was suggested, it is
included for completeness.


Design
======

Terminology
-----------

*sub-CA*
  A lightweight sub-CA in the Dogtag CA instance, and its
  representation in FreeIPA.

*lightweight CA*
  A lightweight CA in the Dogtag CA instance.  This terminology is
  sometimes used where the topic applies to all lightweight CAs,
  which in the future may include CAs that are not chained to the
  IPA CA.

*top-level CA* or *host CA*
  The top-level CA in the Dogtag CA subsystem, as distinct from
  any of its sub-CAs.  In the FreeIPA context, this is sometimes
  called the *IPA CA*.  It may or may not be a self-signed CA.

*FreeIPA-managed CA*
  A CA or sub-CA that was created by or via FreeIPA and has an
  associated object in the FreeIPA directory, as distinct from a
  CA existing in Dogtag of which FreeIPA has no knowledge.


High-level design considerations
--------------------------------

Nested sub-CAs
^^^^^^^^^^^^^^

Nested sub-CAs (that is, more than a single level of sub-CAs beneath
the primary CA in a Dogtag instance) are not an initial requirement,
however, the schema and other aspects of the FreeIPA feature should
take into account the possibility of nested sub-CAs as a future
requirement.


Externally signed and self-signed lightweight CAs
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Initially all sub-CAs will be children of the host CA, but the
sub-CAs feature should be designed for the possible future
requirement of supporting multiple independent trust chains.
Additional work will be required in Dogtag to support these use
cases.


Externally signed lightweight CAs
'''''''''''''''''''''''''''''''''

We would support partial creation of the CA to generate the key in
the NSSDB and yield a Certificate Signing Request (CSR) for
submission to the external CA.  The signed certificate would then be
imported to complete the process.

Alternatively, we could simply accept a certificate and private
signing key (e.g. in PKCS #12 format).  This approach is not
mutually exclusive with the other - they can both be supported.

The "upstream" root certificate and intermediate CA certificates
would be stored in LDAP for distribution to clients, with the IPA CA
having an ``ipaKeyTrust`` value of ``trusted`` (see `CA certificate
renewal`_).

.. _CA certificate renewal: http://www.freeipa.org/page/V4/CA_certificate_renewal


Self-signed lightweight CAs
'''''''''''''''''''''''''''

In this case, FreeIPA causes Dogtag to generate a new self-signed
(root) CA.  The CA certificate would be stored in LDAP for
distribution to clients, having an ``ipaKeyTrust`` value of
``trusted``.


CA discovery
^^^^^^^^^^^^

Lightweight CAs created directly in Dogtag **will not be
discovered** by FreeIPA.  FreeIPA-managed and non-FreeIPA-managed
CAs can coexist in Dogtag but FreeIPA will not be aware of CAs it
did not create (other than the host authority).


``ca`` plugin
-------------

Lightweight CAs, in addition to having a representation within the
Dogtag deployment, have a representation in the FreeIPA directory,
for several reasons:

- Provides a layer of indirection that can include user-friendly
  names and descriptions for the CA.

- Allows the "friendly name" to be changed in FreeIPA without
  changing anything in Dogtag.

- Provides the opportunity to extend the object with additional
  metadata that pertains only to FreeIPA, as deemed important.

- Provides an object that can be referenced in CA ACLs.

The ``ca`` plugin defines these objects and the CRUD commands for
finding, creating, modifying and deleting lightweight CAs.

The ``ca`` plugin also provides an entry for the host authority, for
consistency and to allow CA ACLs to explicitly reference the IPA CA.
The entry for the host authority is automatically added on
installation or upgrade.


Certificate parameters
^^^^^^^^^^^^^^^^^^^^^^

Keygen parameters
'''''''''''''''''

Initially, 2048-bit RSA keys shall be supported.  Later work will
implement the ability to specify key sizes and types when creating
lightweight CAs.


Subject Distinguished Name
''''''''''''''''''''''''''

The Subject DN is user-specified and used as-is.


Validity
''''''''

The default validity period of the Dogtag ``caCAcert`` profile shall
be used (10 years).

Future work could enable the use of different profiles for
lightweight CA creation and/or allow direct control of the validity
period.


Schema
^^^^^^

CA objects shall be stored in the container ``cn=cas,cn=ca,$SUFFIX``
and shall have the object classes ``ipaCa`` (defined below).
They shall be distinguished by ``cn``.

::

  objectClasses: (2.16.840.1.113730.3.8.21.2.3
    NAME 'ipaCa'
    SUP top STRUCTURAL
    MUST ( cn $ ipaCaId $ ipaCaSubjectDN $ ipaCaIssuerDN )
    MAY description
    X-ORIGIN 'IPA v4.4 Lightweight CAs' )


The ``ipaCaId`` attribute shall store the Dogtag Authority ID of a
lightweight CA::

  attributeTypes: (2.16.840.1.113730.3.8.21.1.6
    NAME 'ipaCaId' DESC 'Dogtag Authority ID'
    EQUALITY caseIgnoreMatch
    ORDERING caseIgnoreOrderingMatch
    SUBSTR caseIgnoreSubstringsMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    X-ORIGIN 'IPA v4.4 Lightweight CAs' )

The ``ipaCaIssuerDN`` attribute shall store the issuer DN of the
CA::

  attributeTypes: (2.16.840.1.113730.3.8.21.1.7
    NAME 'ipaCaIssuerDN' DESC 'Issuer Distinguished Name'
    SUP distinguishedName
    X-ORIGIN 'IPA v4.4 Lightweight CAs' )

The ``ipaCaSubjectDN`` attribute shall store the subject DN of the
CA::

  attributeTypes: (2.16.840.1.113730.3.8.21.1.8
    NAME 'ipaCaSubjectDN' DESC 'Subject Distinguished Name'
    SUP distinguishedName
    X-ORIGIN 'IPA v4.4 Lightweight CAs' )

The ``ipaCaId``, ``ipaCaIssuerDN`` and ``ipaCaSubjectDN`` attributes
shall be immutable.


Permissions
^^^^^^^^^^^

The following new permissions will be added.  Unless stated
otherwise, permissions are initially granted to the *CA
Administrator* role.

``System: Read CAs``
  All principals may search lightweight CAs and read all attributes.
``System: Add CA``
  Add a new lightweight CA.
``System: Delete CA``
  Delete an existing lightweight CA.
``System: Modify CA``
  Modify the name or description of lightweight CAs.


Key replication
---------------

Key replication will be handled by Dogtag's
``ExternalProcessKeyRetriever`` (part of Dogtag), which will be
configured to execute a Python script (part of FreeIPA) that will
retrieve the required key and certificate through Custodia.

This work requires minor changes to FreeIPA's ``CustodiaClient``
implementation to generalise it and make it usable from arbitrary
Python programs.


Authenticating to Custodia
^^^^^^^^^^^^^^^^^^^^^^^^^^

Authenticating to Custodia involves both Kerberos (i.e. the client
must have Kerberos credentials) and Custodia-specific signing keys,
the public parts of which are published in LDAP as
``ipaPublicKeyObject`` objects and associated with client principal
through the ``memberPrincipal`` attribute.

For replica promotion, the Custodia client runs as ``root`` and uses
the host keytab at ``/etc/krb5.keytab``, and Custodia keys stored at
``/etc/ipa/custodia/server.keys``.

``pkiuser`` does not have read access to either of these locations,
so a new service principal shall be created for each Dogtag CA
instance for the purpose of authenticating to Custodia and
retrieving lightweight CA private keys.  Its principal name shall be
``dogtag/<hostname>@REALM``.  Its keytab and
Custodia keys shall be stored with ownership ``pkiuser:pkiuser`` and
mode ``0600`` at ``/etc/pki/pki-tomcat/dogtag.keytab``
and ``/etc/pki/pki-tomcat/dogtag.keys`` respectively.


Custodia store
^^^^^^^^^^^^^^

The existing PKCS #12 Custodia store cannot be used for transporting
lightweight CA signing keys, because if the Custodia client imports
the keys to the destination NSSDB, Dogtag cannot observe them unless
restarted, and Dogtag cannot unpack the PKCS #12 file because the
bare private key would then be resident in the Dogtag process'
memory, which is unacceptable from a security standpoint.  The
solution is transport wrapped keys with the IPA CA's public key, and
Dogtag shall unwrap them direct into its NSSDB using the IPA CA's
private signing key.

A new Custodia store shall be implemented that wraps requested keys
in this manner.  Its relative path shall be ``ca_wrapped`` (cf.
``ca`` for the existing mechanism, which shall continue to be used
for replica promotion).


Renewal
-------

A mechanism must be provided to renew lightweight CA certificates.
A Dogtag REST API shall be provided for renewal of the certificate.
When and how renewal occurs, possible approaches include:

1. No automatic renewal is performed.  Provide the ``ipa ca-renew``
   command to invoke the REST API and renew the sub-CA certificate.
   Renewal need not be performed on the renewal master.

   Implementation of an ``ipa ca-renew`` command is compatible with
   the remaining options; it would allowing a privileged user to
   force renewal of a certificate regardless of the prevailing
   auto-renewal mechanism (if any).

2. Implement a thread in Dogtag that renews lightweight CA
   certificates as the existing certificates approach expiry.  Only
   the renewal master would execute this thread.

   Automatic renewal could be enabled on a per-CA basis.

   The advantage of this approach is that the behaviour has no
   dependency on other components; it can be implemented entirely
   within Dogtag and can be used in standalone Dogtag deployments.

   Disadvantages and caveats of this approach are:

   - New code for tracking certificate expiry must be written,
     duplicating functionality that already exists in Certmonger.

   - The renewal thread must run on only one Dogtag instance (in
     FreeIPA terms: the *renewal master*).  There is precedent with
     CRL generation; ``ipa-csreplica-manager`` would be enhanced to
     manage lightweight CA renewal configuration and an upgrade
     script would be needed to add the required Dogtag configuration
     on the renewal master.

3. Track each lightweight CA certificate in Certmonger on the
   renewal master, and implement a renewal helper for lightweight
   CAs.

   In this scenario, lightweight CA creation must always be
   performed by the renewal master, which will establish tracking,
   and promoting a CA replica to renewal master shall involve
   tracking all FreeIPA-managed lightweight CA certificates.

   The advantage of this approach is the reuse of existing machinery
   in Certmonger for monitoring certificates and triggering renewal
   when needed.

   Disadvantages of this approach are:

   - Proliferation of Certmonger tracking requests; one for each
     FreeIPA-managed lightweight CA.

   - Either lightweight CA creation is restricted to the renewal
     master, or the renewal master must observe the creation of new
     lightweight CAs and start tracking their certificate.

   - Development of new Certmonger renewal helpers solely for
     lightweight CA renewal.


Installation
------------

Set up Dogtag key replication
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The CA installation process shall perform the following new steps:

- Create the ``dogtag/$HOSTNAME`` service principal

- Create Custodia keys for the principal and store them at the
  location declared above.

- Retrieve the keytab for the principal to the location declared
  above.

- Configure Dogtag to use the ``ExternalProcessKeyRetriever`` with
  a Python helper script to do the work of key retrieval.  (This is
  configured in Dogtag's ``CS.cfg``).


Default CAs
^^^^^^^^^^^

``ipa-server-install`` need not initially create any sub-CAs, but
see the "Default sub-CAs" use case for a suggested future direction.

A CA object for the IPA CA will automatically be created, with
``cn=ipa`` and ``description=IPA CA``.

Renaming of the IPA CA shall not be permitted.


Implementation
==============

The initial implementation will deliver the ``ca`` plugin which will
provide for the creation and management of sub-CAs.  The ``caacl``
plugin will be enhanced with the ability to choose the CAs to which
each CA ACL applies.

**Future work** (`#5011`_) will implement GSSAPI authentication and ACL
enforcement in Dogtag and remove ACL enforcement from FreeIPA.  The
FreeIPA framework will use S4U2Proxy to obtain a ticket for Dogtag
on behalf of the bind principal, and the RA Agent priviliges will be
dropped.

.. _#5011: https://fedorahosted.org/freeipa/ticket/5011

Dogtag signing key retrieval
----------------------------

To avoid reimplementing a Custodia client in Java (a substantial
effort), we configure Dogtag's ``ExternalProcessKeyRetriever`` to
execute a Python script that reuses the existing FreeIPA
``CustodiaClient`` class.  The script is part of FreeIPA's codebase
and is installed as ``/usr/libexec/ipa/ipa-pki-retrieve-key``.


Feature Management
==================

UI
--

The web UI must be enhanced to allow the user to indicate which CA a
certificate request should be directed to, and to indicate the CA of
any existing certificate (ideally, a brief representation the entire
certification path).

It will be necessary to support multiple certificates per-principal,
issued from different CAs.

The web UI for retrieving certificates must be extended to include
the ability to download a chained certificate.


CLI
---

CLI commands for creating and adminstering lightweight CAs will be
created, with appropriate ACIs for authorization.

CLI commands that retrieve certificates will be enhanced to add the
capability to retrieve certificate *chains* from the root to the
end-entity certificate.


New commands
^^^^^^^^^^^^

``ipa ca-find``
'''''''''''''''

Search for lightweight CAs.


``ipa ca-show <NAME>``
''''''''''''''''''''''

Show lightweight CA details.


``ipa ca-add <NAME>``
'''''''''''''''''''''

Create a new sub-CA, a direct subordinate of the top-level CA.
(Future work could allow nested sub-CAs).

``name``
  Name of new CA (FreeIPA object only; value is not known to or used
  by Dogtag).

``--description <STR>``
  **Optional** description.

``--subject <DN>``
  Subject DN for new CA.

This command first creates the FreeIPA CA object (to ensure that the
user has permission to do so), then creates the CA in Dogtag.  The
*Authority ID* returned from Dogtag is then saved.  If creation in
Dogtag fails, the newly-added object gets deleted.

See also the discussion above about *public key* parameters and
*validity*.  Additional CA creation parameters in the Dogtag API may
(eventually) be reflected as additional option for this command.


``ipa ca-del <NAME>``
'''''''''''''''''''''

Delete the given certificate authority; both the FreeIPA object and
the Dogtag lightweight CA.

Non-expired certificates of deleted CAs shall be revoked.  This
behaviour shall be implemented in Dogtag as part of the CA deletion
method; no extra behaviour is needed in the IPA framework.

Note: Dogtag has not yet implemented revocation on lightweight CA
deletion.  The associated ticket is
https://fedorahosted.org/pki/ticket/1638.  Until it is implemented,
CA certificate revocation can be performed as an additional manual
step, using existing commands.

Note: Dogtag prohibits the deletion of non-leaf CAs.


``ipa caacl-add-ca NAME``
'''''''''''''''''''''''''

Add CA(s) to the CA ACL.

``--ca=STR``
  CA to add.


``ipa caacl-remove-ca NAME``
''''''''''''''''''''''''''''

Add CA(s) to the CA ACL.

``--ca=STR``
  CA to remove.


Enhanced commands
^^^^^^^^^^^^^^^^^

``ipa caacl-add``
'''''''''''''''''

Added option:

``--cacat=['all']``
  CA category.  Mutually exclusive with CA members added via the
  ``caacl-add-ca`` command.


``ipa caacl-mod NAME``
''''''''''''''''''''''

Added option:

``--cacat=['all']``
  CA category. Mutually exclusive with CA members added via the
  ``caacl-add-ca`` command.


``ipa caacl-find``
''''''''''''''''''

Added option:

``--cacat=['all']``
  Search for CA ACLs with the given CA category.


``ipa cert-request``
''''''''''''''''''''

New options:

``--ca NAME``
  Specify the CA to which to direct the request.  Optional; default
  to the top-level CA.

``--chain``
  Instead of just the newly-issued leaf certificate, retrieve the
  certificate chain ending in the new certificate.

CA ACL enforcement shall be enhanced to take CAs into account.  For
backwards compatibility with CA ACLs defined previously, CA ACLs
that do not have a CA category and have no CAs shall behave as
though the IPA CA alone was specified.


``ipa cert-find``
'''''''''''''''''

The ``ipa cert-find`` command shall allow searching by issuer, via
the following new arguments.

``--issuer <DN>``
  Specify the issuer DN.

``--ca <NAME>``
  Specify a FreeIPA CA name.  The behaviour is the same as if the
  subject DN of the named CA had been specified via ``--issuer``.

If both ``--issuer`` and ``--ca`` are given and the two DNs are
not equal, the result of the search will be empty.


``ipa cert-show``
'''''''''''''''''

The ``ipa cert-show`` command shall have new options for specifying
the issuer of the cert to show (in addition to the existing serial
number argument), and for retrieving the CA chain ending with the
specified certificate.

``--ca <NAME>``
  Specify the issuer of the certificate.  Defaults to the IPA CA.
  If there is no certificate with the specified serial number issued
  by the specified CA, the result is **not found**.

``--chain``
  Request the certificate chain (when saving via ``--out <file>``,
  PEM format is used; this is the format used for the end-entity
  certificate).  By default, the leaf certificate is returned in
  PEM format.


Certmonger
----------

For *service* administration use cases, certificates will be
requested via certmonger, in accordance with the existing use
pattern where ``ipa-getcert`` is used to request, monitor and renew
certificates.

Indicating the target CA
^^^^^^^^^^^^^^^^^^^^^^^^

Certmonger will need to be told which FreeIPA CA to use.  (Note that
this is different from Certmonger's "CA" concept; the ``IPA``
Certmonger CA will be used regardless of which FreeIPA CA is to be
used).

To support this use case, the ``template-issuer`` property shall be
added, and the ``-X`` / ``--issuer`` command line option shall be
added to ``getcert request`` and related commands.

If set, the ``template-issuer`` value shall be propagated to
submission helpers in the ``CERTMONGER_CA_ISSUER`` environment
variable.

The FreeIPA submission helper shall, if the ``CERTMONGER_CA_ISSUER``
environment variable is set, set the ``ca`` argument of the
``cert-request`` method accordingly; otherwise, the ``ca`` argument
shall be omitted.


Certificate chain retreival
^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are numerous certificate chain formats; common formats will be
supported, and an option will be used to select the desired format.
For uncommon formats, administrators will need to retrieve the chain
in one of the supported formats and manually compose what they need.

Common certificate chain formats:

- PEM (sequence of PEM-encoded certificates)
- PKCS #7 (certificate chain object)
- PKCS #12

Apache and nginx expect a sequence of PEM-encoded certificates, so
PEM is a baseline requirement.


Configuration
-------------

FreeIPA must be deployed with the Dogtag RA in order to use these
features.  No other configuration is required.


Upgrade
=======

As part of the upgrade process:

- Dogtag key replication shall be configured using the steps
  described at `Set up Dogtag key replication`_.

- The schema (including Dogtag schema) shall be updated.

- The ``ipa`` CA object shall be created (see `Default CAs`_).


How to Use
==========

Scenario: add a sub-CA that will be used to issue user smart cards.
A profile for this purpose called ``userSmartCard`` is assumed to
exist.

List lightweight CAs::

  % ipa ca-find
  ------------
  1 CA matched
  ------------
    Name: ipa
    Description: IPA CA
    Authority ID: d3e62e89-df27-4a89-bce4-e721042be730
    Subject DN: CN=Certificate Authority,O=IPA.LOCAL 201606201330
    Issuer DN: CN=Certificate Authority,O=IPA.LOCAL 201606201330
  ----------------------------
  Number of entries returned 1
  ----------------------------

Add a new lightweight CA called ``sc``::

  % ipa ca-add sc --subject "CN=Smart Card CA, O=IPA.LOCAL" --desc "Smart Card CA"
  ---------------
  Created CA "sc"
  ---------------
    Name: sc
    Description: Smart Card CA
    Authority ID: 660ad30b-7be4-4909-aa2c-2c7d874c84fd
    Subject DN: CN=Smart Card CA,O=IPA.LOCAL
    Issuer DN: CN=Certificate Authority,O=IPA.LOCAL 201606201330

Add a CA ACL called ``user-sc-userSmartCard`` and through it
associate all users, the ``sc`` CA, and ``userSmartCard`` profile.
users::

  % ipa caacl-add user-sc-userSmartCard --usercat=all
  ------------------------------------
  Added CA ACL "user-sc-userSmartCard"
  ------------------------------------
    ACL name: user-sc-userSmartCard
    Enabled: TRUE
    User category: all

  % ipa caacl-add-ca user-sc-userSmartCard --ca sc
    ACL name: user-sc-userSmartCard
    Enabled: TRUE
    User category: all
    CAs: sc
  -------------------------
  Number of members added 1
  -------------------------

  % ipa caacl-add-profile user-sc-userSmartCard --certprofile userSmartCard
    ACL name: user-sc-userSmartCard
    Enabled: TRUE
    User category: all
    CAs: sc
    Profiles: userSmartCard
  -------------------------
  Number of members added 1
  -------------------------

Now, as a user (``alice``), assuming you already have a CSR for the
key in your smart card, request the certificate, specifying the
``sc`` CA::

  % ipa cert-request --principal alice --ca sc /path/to/csr.req
    Certificate: MIIDmDCCAoCgAwIBAgIBQDANBgkqhkiG9w0BA...
    Subject: CN=alice,O=IPA.LOCAL
    Issuer: CN=Smart Card CA,O=IPA.LOCAL
    Not Before: Fri Jul 15 05:57:04 2016 UTC
    Not After: Mon Jul 16 05:57:04 2018 UTC
    Fingerprint (MD5): 6f:67:ab:4e:0c:3d:37:7e:e6:02:fc:bb:5d:fe:aa:88
    Fingerprint (SHA1): 0d:52:a7:c4:e1:b9:33:56:0e:94:8e:24:8b:2d:85:6e:9d:26:e6:aa
    Serial number: 64
    Serial number (hex): 0x40


Test Plan
=========

[[V4/Sub-CAs/Test_Plan|Sub-CAs V4.4 test plan]]


Dependencies
============

- FreeIPA `Certificate Profiles`_ feature.
- Dogtag >= 10.3.2

.. _Certificate Profiles: http://www.freeipa.org/page/V4/Certificate_Profiles
