..
  notes:
  delete ca
  certificate renewal for sub-CAs
  changing the chaining
    reuse what honza has done

  certmonger

  - supports retrieving chain
  - add cap to fetch chain in cert plugin in IPA
  - different formats
    - pre-save and post-save command
    - req cert from CA
    - exec pre-save
    - save
    - exec post-save
    - storage: nssdb, pem file
      - need something else?  convert in post-save command

  - dynamically add CA to certmonger

  - add argument to ipa-getcert for specifying subca???
  - wrapper for configuring getcert to know about / use sub-ca

..
  Copyright 2014, 2015 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


{{Admon/important|Work in progress|This design is not complete yet.}}
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
the top-level CA, so a sub-CA specifically for VPN authentication
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

*top-level CA* or *host CA*
  The top-level CA in the Dogtag CA subsystem, as distinct from
  any of its sub-CAs.  It may or may not be a root CA.

*FreeIPA-managed CA*
  A CA or sub-CA that was created by or via FreeIPA and has an
  associated object in the FreeIPA directory, as distinct from a
  CA existing in Dogtag of which FreeIPA has no knowledge.


High-level design considerations
--------------------------------

Nested sub-CAs
^^^^^^^^^^^^^^

Nested sub-CAs (that is, more than a single level of sub-CAs beneath
the primary CA in a Dogtag instance) are not an initial requirement
(nor are they an initial requirement of the sub-CAs feature in
Dogtag).  However, the schema and other aspects of the FreeIPA
feature should take into account the possibility of nested sub-CAs
as a future requirement.


Externally signed and self-signed lightweight CAs
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Initially all sub-CAs will be children of the top-level CA, but the
sub-CAs feature should be designed mindfully of the possible future
requirement of supporting multiple separate trust chains.
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
would be stored in LDAP for distribution to clients, with the root
CA having an ``ipaKeyTrust`` value of ``trusted`` and intermediate
CAs having a value of ``unknown`` (see `CA certificate renewal`_).

.. _CA certificate renewal: http://www.freeipa.org/page/V4/CA_certificate_renewal


Self-signed lightweight CAs
'''''''''''''''''''''''''''

In this case, FreeIPA causes Dogtag to generate a new self-signed
(root) CA.  The CA certificate would be stored in LDAP for
distribution to clients, having an ``ipaKeyTrust`` value of
``trusted``.


Sub-CA discovery
^^^^^^^^^^^^^^^^

Sub-CAs created directly in Dogtag **will not be discovered** by
FreeIPA.  FreeIPA-managed and non-FreeIPA-managed sub-CAs may
coexist in Dogtag but FreeIPA will not be aware of CAs it did not
create.


Sub-CA plugin
-------------

The FreeIPA representation of a sub-CA has the following fields:

*name*
  A "human-friendly" name for the sub-CA.  This name will be used in
  the web UI, CLI and so on.  Required; must be unique.

*shortname*
  The shortname is used to refer to the CA in Dogtag and conforms to
  Dogtag's sub-CA naming requirements.  It may also be used to refer
  to the CA in user-visible interfaces and information, if a shorter
  representation is needed.  Required; must be unique.


Certificate parameters
^^^^^^^^^^^^^^^^^^^^^^

Public key
''''''''''

**TODO** How much control over key parameters should be given for
sub-CA creation?  We could default to the key size and type of the
parent CA and provide an option to specify something different?

Subject Distinguished Name
''''''''''''''''''''''''''

When creating a sub-CA, the subject DN is constructed by copying the
DN of the parent CA, then setting the CN to the *name*.  More
control could be implemented if there is a clear case for it.

Validity
''''''''

The default validity could be the default validity used by
``ipa-server-install``.  **TODO** what is the default duration?

Specify the CA certificate validity.  Something human-friendly
should be used, e.g. a duration spec that supports ``5y``,
``365d``, etc.  **TODO** is there a precendent for this sort of
duration interpretation in FreeIPA?  If so, be consistent.


Permissions
^^^^^^^^^^^

**TODO**


Schema
^^^^^^

CA objects shall be stored in the container
``cn=cas,cn=ca,$SUFFIX``.

**TODO** describe ca object class and new attributes (if any).


Key replication
---------------

Dogtag lightweight CAs provide a pluggable key replication system.
Integrators provide an implementation of the ``KeyRetriever``
interface::

  interface KeyRetriever {
    /**
     * Retrieve the specified signing key from specified host and
     * store in local NSSDB.
     *
     * @return true if the retrieval was successful, otherwise false
     */
    boolean retrieveKey(String nickname, Collection<String> hostname);
  }

For FreeIPA, Dogtag will provide the ``IPACustodiaKeyRetriever``
class, which implements the ``KeyRetriever`` interface.  It invokes
a Python script that performs the retrieval, reusing existing
FreeIPA Custodia client code.

The Python script shall be installed at
``/usr/libexec/pki-ipa-retrieve-key`` and shall be executed as
``pkiuser``.


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
``dogtag-ipa-custodia/<hostname>@REALM``.  Its keytab and
Custodia keys shall be stored with ownership ``pkiuser:pkiuser`` and
mode ``0600`` at ``/etc/pki/pki-tomcat/dogtag-ipa-custodia.keytab``
and ``/etc/pki/pki-tomcat/dogtag-ipa-custodia.keys`` respectively.


``pki-ipa-retrieve-key`` program
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The essence of the ``pki-ipa-retrieve-key`` program is as
follows::

  #!/usr/bin/python

  import ConfigParser
  import sys

  from ipaplatform.paths import paths
  from ipapython.secrets.client import CustodiaClient

  conf = ConfigParser.ConfigParser()
  conf.read(paths.IPA_DEFAULT_CONF)
  hostname = conf.get('global', 'host')
  realm = conf.get('global', 'realm')

  servername = sys.argv[1]
  keyname = "ca/" + sys.argv[2]

  client_keyfile = "/etc/pki/pki-tomcat/dogtag-ipa-custodia.keys"
  client_keytab = "/etc/pki/pki-tomcat/dogtag-ipa-custodia.keytab"

  client = CustodiaClient(
      client=hostname, server=servername, realm=realm,
      ldap_uri="ldaps://" + hostname,
      keyfile=client_keyfile, keytab=client_keytab,
      )

  result = client.fetch_key(keyname, store=True)
  # ... further processing of received keys


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

- Create the ``dogtag-ipa-custodia/$HOSTNAME`` service principal
- Create Custodia keys for the principal and store them at the
  location declared above.
- Retrieve the keytab for the principal to the location declared
  above.
- Make ``IPACustodiaKeyRetriever`` the configured key retriever in
  ``CS.cfg``.


Default CAs
^^^^^^^^^^^

``ipa-server-install`` need not initially create any sub-CAs, but
see the "Default sub-CAs" use case for a suggested future direction.

A CA object for the top-level CA will initially be created, with DN
``cn=.,ou=cas,cn=ca,$SUFFIX``.


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

CLI commands for creating and adminstering sub-CAs will be created,
with appropriate ACIs for authorization.

CLI commands that retrieve certificates will be enhanced to add the
capability to retrieve certificate *chains* from the root to the
end-entity certificate.


New commands
^^^^^^^^^^^^

``ipa ca-find``
'''''''''''''''

Search for sub-CAs.


``ipa ca-show <shortname>``
'''''''''''''''''''''''''''

Show sub-CA details.


``ipa ca-add``
''''''''''''''

Create a new sub-CA, a direct subordinate of the top-level CA.
Future work could allow nested sub-CAs.

``--name <string>``
  Friendly name

``--shortname <shortname>``
  Server handle, in conformance with Dogtag's requirements

See also the discussion above about *public key* parameters and
*validity*.  Whatever is decided will be reflected in additional
arguments to this command.


``ipa ca-del <shortname>``
''''''''''''''''''''''''''

Delete the given certificate authority.  This will remove knowledge
of the CA from the FreeIPA directory but *will not delete the sub-CA
from Dogtag*.  Dogtag will still know about the CA and the
certificates it issued, be able to act at a CRL / OCSP authority for
it, etc.


``ipa caacl-add-ca NAME``
'''''''''''''''''''''''''

Add CA(s) to the CA ACL.  *To be introduced with ca plugin.
Initially, top-level CA is assumed.*

``--ca=STR``
  CA to add.


``ipa caacl-remove-ca NAME``
''''''''''''''''''''''''''''

Add CA(s) to the CA ACL.  *To be introduced with ca plugin.
Initially, top-level CA is assumed.*

``--ca=STR``
  CA to remove.


Enhanced commands
^^^^^^^^^^^^^^^^^

``ipa caacl-add``
'''''''''''''''''

Added option:

``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*


``ipa caacl-mod NAME``
''''''''''''''''''''''

Added option:

``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*


``ipa caacl-find``
''''''''''''''''''

Added option:

``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*


``ipa cert-request``
''''''''''''''''''''

New options:

``ca``
  Specify the CA to which to direct the request.  Optional; default
  to the top-level CA.


``ipa cert-find [shortname]``
'''''''''''''''''''''''''''''

``shortname``
  Optional positional parameter to specify a sub-CA to use (omit to
  specify the top-level CA).  The special shortname ``*`` is used to
  search in all CAs.


``ipa cert-show [shortname]``
'''''''''''''''''''''''''''''

``shortname``
  Optional positional parameter to specify a sub-CA (omit to specify
  the top-level CA).

``--chain``
  Request the certificate chain (when saving via ``--out <file>``,
  PEM format is used; this is the format uesd for the end-entity
  certificate).


Certmonger
----------

For *service* administration use cases, certificate chains will be
delivered via certmonger, in accordance with the existing use
pattern where ``ipa-getcert`` is used to retrieve and renew
certificates.

There are numerous certificate chain formats; common formats will be
supported, and an option will be used to select the desired format.
For uncommon formats, administrators will need to retrieve the chain
in one of the common formats and manually compose what they need.

Common certificate chain formats:

- PEM (sequence of PEM-encoded certificates)
- PKCS #7 (certificate chain object)
- PKCS #12

Apache and nginx expect a sequence of PEM-encoded certificates, so
PEM could be minimal requirement.


Configuration
-------------

FreeIPA must be deployed with the Dogtag RA in order to use these
features.  No other configuration is required.


Upgrade
=======

As part of the upgrade process:

- Dogtag key replication shall be configured using the steps
  described at `Set up Dogtag key replication`_.

- The schema (including Dogtag schema) will be updated.

- Any essential/default sub-CAs will be created, and relevant
  certificates issued.

- ``admin`` will be assigned the *CA Administrator* role.


How to Test
===========

..
  Easy to follow instructions how to test the new feature. FreeIPA
  user needs to be able to follow the steps and demonstrate the new
  features.

  The chapter may be divided in sub-sections per [[#Use_Cases|Use
  Case]].


Test Plan
=========

..
  Test scenarios that will be transformed to test cases for FreeIPA
  [[V3/Integration_testing|Continuous Integration]] during
  implementation or review phase. This can be also link to
  [https://git.fedorahosted.org/cgit/freeipa.git/ source in cgit] with
  the test, if appropriate.


Dependencies
============

- FreeIPA `Certificate Profiles`_ feature.
- Dogtag with sub-CA feature (slated for v10.3).

.. _Certificate Profiles: http://www.freeipa.org/page/V4/Certificate_Profiles
