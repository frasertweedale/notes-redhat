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
{{Feature|version=4.2.0|ticket=4559|author=Ftweedal}}


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


.. Associated Bugs and Tickets
.. ~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. Provide URLs to all associated bugs and tickets.


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


Design
======

Terminology
-----------

*sub-CA*
  A lightweight sub-CA in the Dogtag CA instance, and its
  representation in FreeIPA.

*top-level CA*
  The top-level CA in the Dogtag CA subsystem, as distinct from
  any of its sub-CAs.  It may or may not be a root CA, but is the
  most "senior" CA used by FreeIPA to issue certificates.


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

We would support partial creation of the CA to generate the key and
a Certificate Signing Request (CSR) for submission to the external
CA.  The signed certificate would then be imported to complete the
process.

The "upstream" root certificate and intermediate CA certificates
would be stored in LDAP for distribution to clients, with the root
CA having an ``ipaKeyTrust`` value of ``trusted`` and intermediate
CAs having a value of ``unknown`` (see `CA certificate renewal`_).

.. _CA certificate renewal: http://www.freeipa.org/page/V4/CA_certificate_renewal


Self-signed lightweight CAs
'''''''''''''''''''''''''''

In this case, FreeIPA causes Dogtag to generate a new self-signed
(root) CA.  The CA certificate would be stored in LDAP for
distribution to clients, having and ``ipaKeyTrust`` value of
``trusted``.


Sub-CA discovery
^^^^^^^^^^^^^^^^

Sub-CAs created directly in Dogtag **will not be discovered** by
FreeIPA.  FreeIPA-created and non-FreeIPA-created sub-CAs can
coexist in Dogtag but FreeIPA will not be aware of CAs it did not
create.


CA ACLs plugin
--------------

Sub-CA use cases involve the issuance of certificates for specific
purposes.  It is necessary to be able to restrict the types of
certificates that can be issued by a sub-CA, and to which entities
(principals).  ACLs will be used to associate profiles, principals
and groups with a CA.  Specifically:

- A CA can have multiple ACLs.

- An ACL can have multiple profiles.

- An ACL can have multiple users, services, hosts, (user) groups and
  hostgroups associated with it.

- The interpretation of the ACL is, "These principals (or groups)
  are permitted to request certificates using these profiles, from
  this CA."

See also the ``ipa caacl-*`` commands in the CLI section below.


Permissions
^^^^^^^^^^^

The following permissions will be created.  All permissions are
intially granted to the *CA Administrator* role.

``System: Read CA ACLs``
  All may read all attributes.

``System: Add CA ACL``
  Add a new CA ACL.

``System: Delete CA ACL``
  Delete an existing CA ACL.

``System: Modify CA ACL``
  Modify the name or description, or enable/disable the CA ACL.

``System: Manage CA ACL membership``
  Manage CA, profile, user, host and service membership.


Schema
^^^^^^

CA ACL objects shall be stored in the container
``cn=caacls,cn=ca,$SUFFIX``.

New attributes are defined for CA and profile membership and
categories ("all CAs / profiles").  The ``ipaCaAcl`` object class
extends ``ipaAssociation`` uses these new attributes as well as
existing member and category attributes.

::

  attributeTypes: (2.16.840.1.113730.3.8.21.1.2
    NAME 'memberCa'
    DESC 'Reference to a CA member'
    SUP distinguishedName
    EQUALITY distinguishedNameMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.12
    X-ORIGIN 'IPA v4.2' )
  attributeTypes: (2.16.840.1.113730.3.8.21.1.3
    NAME 'memberProfile'
    DESC 'Reference to a certificate profile member'
    SUP distinguishedName
    EQUALITY distinguishedNameMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.12
    X-ORIGIN 'IPA v4.2' )
  attributeTypes: (2.16.840.1.113730.3.8.21.1.4
    NAME 'caCategory'
    DESC 'Additional classification for CAs'
    EQUALITY caseIgnoreMatch
    ORDERING caseIgnoreOrderingMatch
    SUBSTR caseIgnoreSubstringsMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    X-ORIGIN 'IPA v4.2' )
  attributeTypes: (2.16.840.1.113730.3.8.21.1.5
    NAME 'profileCategory'
    DESC 'Additional classification for certificate profiles'
    EQUALITY caseIgnoreMatch
    ORDERING caseIgnoreOrderingMatch
    SUBSTR caseIgnoreSubstringsMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    X-ORIGIN 'IPA v4.2' )
  objectClasses: (2.16.840.1.113730.3.8.21.2.2
    NAME 'ipaCaAcl'
    SUP ipaAssociation
    STRUCTURAL
      MUST cn
      MAY
        ( caCategory $ profileCategory $ userCategory $ hostCategory
        $ serviceCategory $ memberCa $ memberProfile $ memberService )
      X-ORIGIN 'IPA v4.2' )


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


Installation
------------

During installation we must create a default CA ACL that grants use
of caIPAserviceCert on the top-level CA to all hosts and services::

  dn: ipauniqueid=autogenerate,cn=caacls,cn=ca,$SUFFIX
  changetype: add
  objectclass: ipaassociation
  objectclass: ipacaacl
  ipauniqueid: autogenerate
  cn: hosts_services_caIPAserviceCert
  ipaenabledflag: TRUE
  memberprofile: cn=caIPAserviceCert,cn=certprofiles,cn=ca,$SUFFIX
  hostcategory: all
  servicecategory: all

``ipa-server-install`` need not initially create any sub-CAs, but
see the "Default sub-CAs" use case for a suggested future direction.

A CA object for the top-level CA will initially be created, with DN
``cn=.,ou=cas,cn=ca,$SUFFIX``.


Implementation
==============

The implementation will be delivered in two phases.

**Phase 1** will deliver the ``caacl`` plugin and enforcement
behaviour.  This will allow full use of the Certificate Profiles
feature (``certprofile`` plugin) even while the ``ca`` plugin is yet
to be implemented.

All actions will apply to the top-level CA; this will be hardcoded
or assumed as necessary.  The schema to support multiple CAs will be
implemented in this phase.


**Phase 2** will deliver the ``ca`` plugin which will provide for
the creation and management of sub-CAs.  The ``caacl`` plugin will
be enhanced with the ability to choose the CAs to which each CA ACL
applies.


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


``ca`` plugin commands
^^^^^^^^^^^^^^^^^^^^^^

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


``ipa ca-disable <shortname>``
''''''''''''''''''''''''''''''

Disable a sub-CA.  The sub-CA will no longer be available for
issuing certificates.


``ipa ca-enable <shortname>``
'''''''''''''''''''''''''''''

(Re-)enable a sub-CA.


``caacl`` plugin commands
^^^^^^^^^^^^^^^^^^^^^^^^^


``ipa caacl-find``
''''''''''''''''''

Search for CA ACLs.

``--name=STR``
  CA ACL name
``--desc=STR``
  Description
``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*
``--profilecat=['all']``
  Profile category.  Mutually exclusive to profile
  members.
``--usercat=['all']``
  User category.  Mutually exclusive with user members.
``--hostcat=['all']``
  Host category.  Mutually exclusive with host members.
``--servicecat=['all']``
  Service category.  Mutually exclusive with service
  members.


``ipa caacl-show NAME``
'''''''''''''''''''''''

Show details of named CA ACL.


``ipa caacl-add NAME``
''''''''''''''''''''''

Create a CA ACL.  New CA ACLs are initially enabled.

``--desc=STR``
  Description
``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*
``--profilecat=['all']``
  Profile category.  Mutually exclusive to profile
  members.
``--usercat=['all']``
  User category.  Mutually exclusive with user members.
``--hostcat=['all']``
  Host category.  Mutually exclusive with host members.
``--servicecat=['all']``
  Service category.  Mutually exclusive with service
  members.


``ipa caacl-mod NAME``
''''''''''''''''''''''

Modify the named CA ACL.

``--desc=STR``
  Description
``--cacat=['all']``
  CA category. Mutually exclusive with CA members. *To be
  introduced with ca plugin.*
``--profilecat=['all']``
  Profile category.  Mutually exclusive to profile
  members.
``--usercat=['all']``
  User category.  Mutually exclusive with user members.
``--hostcat=['all']``
  Host category.  Mutually exclusive with host members.
``--servicecat=['all']``
  Service category.  Mutually exclusive with service
  members.
``--setattr``, ``--addattr``, ``--delattr``
  As per other IPA framework commands.


``ipa caacl-del NAME``
''''''''''''''''''''''

Delete the CA ACL.


``ipa caacl-enable NAME``
'''''''''''''''''''''''''

Enable the named CA ACL.


``ipa caacl-disable NAME``
''''''''''''''''''''''''''

Disabled the named CA ACL.


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


``ipa caacl-add-profile NAME``
''''''''''''''''''''''''''''''

Add profile(s) to the CA ACL.

``--certprofiles=STR``
  Certificate Profiles to add.


``ipa caacl-remove-profile NAME``
'''''''''''''''''''''''''''''''''

Remove profile(s) from the CA ACL.

``--certprofiles=STR``
  Certificate Profiles to remove.


``ipa caacl-add-user NAME``
'''''''''''''''''''''''''''

``--users``
  Add user(s)
``--groups``
  Add user group(s)


``ipa caacl-remove-user NAME``
''''''''''''''''''''''''''''''

``--users``
  Remove user(s)
``--groups``
  Remove user group(s)


``ipa caacl-add-host NAME``
''''''''''''''''''''''''''''''

``--hosts``
  Add host(s)
``--hostgroups``
  Add host group(s)


``ipa caacl-remove-host NAME``
''''''''''''''''''''''''''''''

``--hosts``
  Remove host(s)
``--hostgroups``
  Remove host group(s)


``ipa caacl-add-service NAME``
''''''''''''''''''''''''''''''

``--services``
  Add service(s)


``ipa caacl-remove-service NAME``
'''''''''''''''''''''''''''''''''

``--services``
  Remove service(s)


Enhanced commands
^^^^^^^^^^^^^^^^^

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


``ipa cert-request --ca=CAREF``
''''''''''''''''''''''''''''''''

This command will be modified to enforce CA ACLs.


``ca``
  Option to specify the CA to which to direct the request.
  Optional; default to the top-level CA.


Certmonger
----------

For *service* administrator use cases, certificate chains will be
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

- The schema will be updated.

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
