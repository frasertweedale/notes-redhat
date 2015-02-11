..
  notes:
  delete ca
  certificate renewal for sub-CAs
  changing the chaining
    reuse what honza has done
  new role for CA creation/administration
    delegate administration of specific CA
      talk to rcrit

  profiles themselves
    there is no file upload capability in CLI?
    see what ipa cert-request does
    but we will probably just have to copy&paste for now

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


{{Feature|version=4.2.0|ticket=4559}}


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

User certificates for VPN authentication
----------------------------------------

A FreeIPA-based tool could be implemented to request short-lived
user certificates for the purpose of VPN authentication.  It would
be inappropriate to accept as valid any client certificate issued by
the "primary" CA, so a sub-CA specifically for VPN authentication
should be created for this purpose.  The certificate-issuing tool
would direct certificates requests to the new CA, and the resultant
certificates would be signed with VPN CA's signing key.

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


CA administration authorization
-------------------------------

Which FreeIPA users or roles can create and administer FreeIPA
sub-CAs needs to be decided.

How those users or roles map to Dogtag credentials also needs to be
determined.  It may be sufficient to use the existing "CA agent"
credential, or a separate credential or more fine-grained ACIs in
Dogtag could be required.

(*ftweedal*) since all FreeIPA <-> Dogtag communication is currently
done via a single certificate that has administrator privileges on
the CA instance, my initial plan is to continue this system and
control access via FreeIPA ACIs.

Comments from *mkosec* (nested) and *ssorce*::

  Martin Kosek <mkosek@redhat.com> wrote:

    Agent credential is used by FreeIPA web interface, all
    authorization is then done on python framework level. We can add
    more agents and then switch the used certificate, but I wonder how
    to use it in authorization decisions. Apache service will need to
    to have access to all these agents anyway.

  We really need to move to a separate service for agent access, the
  framework is supposed to not have any more power than the user
  that connects to it. By giving the framework direct access to
  credentials we fundamentally change the proposition and erode the
  security properties of the separation.

  We have discussed before a proxy process that pass in commands as
  they come from the framework but assumes agent identity only after
  checking how the framework authenticated to it (via GSSAPI).

    First we need to think how fine grained authorization we want to
    do.

  We need to associate a user to an agent credential via a group, so
  that we can assign the rights via roles.

    I think we will want to be able to for example say that user Foo
    can generate certificates in specified subCA. I am not sure it is
    a good way to go, it would also make such private key distribution
    on IPA replicas + renewal a challenge.

  I do not think we need to start with very fine grained permissions
  initially.

    Right now, we only have "Virtual Operations" concept to authorize
    different operations with Dogtag CA, but it does not distinguish
    between different CAs. We could add a new Virtual Operation for
    every subCA, but it looks clumsy. But the ACI-based mechanism and
    our permission system would still be the easiest way to go, IMHO,
    compared to utilizing PKI agents.

  We need to have a different agent certificate per role, and then
  in the proxy process associate the right agent certificate based
  on what the framework asks and internal checking that the user is
  indeed allowed to do so.

  The framework will select the 'role' to use based on the operation
  to be performed.

  Simo.


CA Administrator role
^^^^^^^^^^^^^^^^^^^^^

A *CA Administrator* role should be created.  ``admin`` will have
this role initially.


Delegation
^^^^^^^^^^

It should be possible (now or in a future iteration) to delegate
administration of a specific sub-CA to a user or group.  (This is
possibly only post-creation of the sub-CA).  The *CA Administrator*
role would still have administrative powers over the sub-CA in
addition to the delegate(s).


Certificate request ACLs
------------------------

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


Schema
^^^^^^

**TODO**


Sub-CA
------

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


Schema
^^^^^^

**TODO**


Installation
------------

``ipa-server-install`` need not initially create any sub-CAs, but
see the "Default sub-CAs" use case.


Implementation
==============

.. Any additional requirements or changes discovered during the
   implementation phase.

.. Include any rejected design information in the History section.


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

Search for sub-CAs.  **TODO** more detail needed.


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


``ipa caacl-add <shortname> <acl>``
'''''''''''''''''''''''''''''''''''

Create a CA ACL object.


``ipa caacl-del <acl>``
'''''''''''''''''''''''

Delete the CA ACL.


``ipa caacl-add-profile <acl> <profileId>``
'''''''''''''''''''''''''''''''''''''''''''

Add a profile to the CA ACL.


``ipa caacl-remove-profile <acl> <profileId>``
''''''''''''''''''''''''''''''''''''''''''''''

Remove the profile from the CA ACL.


``ipa caacl-add-member <acl>``
''''''''''''''''''''''''''''''

``--users``
  Add user(s)
``--hosts``
  Add host(s)
``--services``
  Add service(s)
``--groups``
  Add user group(s)
``--hostgroups``
  Add host group(s)


``ipa caacl-remove-member <acl>``
'''''''''''''''''''''''''''''''''

``--users``
  Remove user(s)
``--hosts``
  Remove host(s)
``--services``
  Remove service(s)
``--groups``
  Remove user group(s)
``--hostgroups``
  Remove host group(s)


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


``ipa cert-request [shortname]``
''''''''''''''''''''''''''''''''

``shortname``
  Optional positional parameter to specify a sub-CA to which to
  direct the request (omit to specify the top-level CA).


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

..
  Any configuration options?
  Any commands to enable/disable the feature or turn on/off its parts?


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


Author
======

Fraser Tweedale

Email
  ftweedal@redhat.com
IRC
  ftweedal
