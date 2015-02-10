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


Sub-CA discovery
^^^^^^^^^^^^^^^^

Sub-CAs could be created in Dogtag directly (i.e. not via FreeIPA).
Whether these sub-CAs should be discovered by FreeIPA and made
available as a FreeIPA sub-CA is an open question.

It may be desirable, or necessary (due to metadata requirements in
FreeIPA) to require that FreeIPA have explicit knowledge of sub-CAs
in order to use them.  In such case, other sub-CAs that have been
created in Dogtag will be ignored by FreeIPA.


Authorization
^^^^^^^^^^^^^

Which FreeIPA users or roles can create and administer FreeIPA
sub-CAs needs to be decided.

How those users or roles map to Dogtag credentials also needs to be
determined.  It may be sufficient to use the existing "CA agent"
credential, or a separate credential or more fine-grained ACIs in
Dogtag could be required.

(*ftweedal*) since all FreeIPA <-> Dogtag communication is currently
done via a single certificate that has administrator privileges on
the CA instance, my initial thought is to continue this system and
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


Service principals
^^^^^^^^^^^^^^^^^^

It should be possible to associate a FreeIPA service principal with
a sub-CA or the top-level CA.  Service certificates will be issued
from the configured CA.


User principals
^^^^^^^^^^^^^^^

It may not make sense to add the ability to assign user principals
to a security domain, because there are many use cases for which a
user may require a certificate, and these use cases may demand
separate security domains, e.g. S/MIME vs VPN vs 802.1X and so on.


User Groups
^^^^^^^^^^^

There are many use cases for user certificates that could apply
simultaneously.  Assuming that each use case is represented by a
single CA, not all use cases will necessarily apply to all users.
Because of this, it might be appropriate to allows users to request
certificates from only those CAs that apply to them.

***Does this make sense, and should it be an initial requirement?***

Users would be associated to CAs through the existing *User Groups*
would be used for this, with the group schema being extended to
support assignment to zero or more CAs.


Certmonger
^^^^^^^^^^

Pursuant to the `Service principals`_ section, ``ipa-getcert`` for a
service principal configured to belong to a non-default security
domain should result in certificates issued by the corresponding
sub-CA.  The behaviour for service principals belonging to the
default security domain shall be unchanged.


Certificate profiles
^^^^^^^^^^^^^^^^^^^^

***This section requires further discussion and refinement.***

Most security domain use cases involve the generation of
certificates for specific purposes.  Therefore, it may be useful to
restrict the certificates that can be issued by a security domain to
a limited number of Dogtag profiles, and/or to default certificate
requests on that CA to a particular profile.

Alternatively, rather than associating a profile (or profiles) to
sub-CAs, it might be better to associate a single sub-CA to each
profile.  Certificates issued within that profile would be issued
from the configure CA.

TODO: are there a use cases for issuing different types of
certificates from a single CA?


Security domain parameters
--------------------------

A security domain has the following parameters:

*Name*
  A "human-friendly" name for the security domain, chosen by an
  administrator.

*Subject Name*
  Subject Name for the corresponding sub-CA certificate.  Could be
  explicit, or derived from the *Name* and the parent CA's Subject
  Name.

*Key algorithms and size*
  The user creating the security domain should be able to specify
  the key algorithms and size (or for elliptic curve keys, the
  curve) for the sub-CA key.


Schema
------

TODO


Install
-------

``ipa-server-install`` need not initially create any sub-CAs.  The
existing behaviour is appropriate and no additional behaviour is
needed.

There is scope creating a security domain for issuing the FreeIPA
server certificates if that is deemed appropriate.


.. The proposed solution.  This may include but is not limited to:
   - new schema
   - syntax of commands
   - logic flow
   - access control considerations


Implementation
==============

.. Any additional requirements or changes discovered during the
   implementation phase.

.. Include any rejected design information in the History section.


Feature Management
==================

UI
--

The web UI must be enhanced to allow the user to indicate which
security domain a certificate request should be directed to, and to
indicate the security domain of any existing certificate (ideally
the entire certification path).

It will be necessary to support multiple certificates per-principal,
issued from different CAs.

The web UI for retrieving certificates must be extended to include
the ability to download a chained certificate.


CLI
---

CLI commands for creating and adminstering sub-CAs will be created,
with appropriate ACIs for authorisation.

CLI commands that retrieve certificates will be enhanced to add the
capability to retrieve certificate *chains* from the root to the
end-entity certificate.


New commands
^^^^^^^^^^^^

``ipa ca-find``
'''''''''''''''

Search for sub-CAs.


``ipa ca-show``
'''''''''''''''

Show sub-CA details.


``ipa ca-add``
''''''''''''''

Create a new sub-CA, a direct subordinate of the top-level CA.
Future work could allow nested sub-CAs.

``--name <string>``
  Friendly name

``--shortname <handle>``
  Server handle, in conformance with Dogtag's requirements

``--profile <profile-id>``
  Associate a profile to the sub-CA.  **TODO:** can be used multiple
  times?

**TODO**: how much control over key parameters should be given to
admin?  We could defualt to the key size and type of the parent CA
and provide an option for admin to specify something different?

``--validity``
  Specify the CA certificate validity.  Something human-friendly
  should be used, e.g. a duration spec that supports ``5y``,
  ``365d``, etc.  **TODO** is there a precendent for this sort of
  duration interpretation in FreeIPA?  If so, be consistent.

  The default validity could be the default validity used by
  ``ipa-server-install``.  **TODO** what is the default duration?

**TODO**: how to associate groups with the CA?


``ipa ca-disable``
''''''''''''''''''

Disable a sub-CA.  The sub-CA will no longer be available for
issuing certificates.


``ipa ca-enable``
'''''''''''''''''

(Re-)enable a sub-CA.


Enhanced commands
^^^^^^^^^^^^^^^^^

``ipa cert-find``
'''''''''''''''''

``--ca <handle>``
  Specify a particular CA to use (omit to specify top-level CA).
  The special handle ``*`` is used to search in all CAs.


``ipa cert-show``
'''''''''''''''''

``--ca <handle>``
  Specify a sub-CA (omit to specify top-level CA).
``--chain``
  Request the certificate chain (when saving via ``--out <file>``,
  PEM format is used; this is the format uesd for the end-entity
  certificate).


``ipa cert-request``
''''''''''''''''''''

``--ca <handle>``
  Specify a sub-CA to which to direct the request.




Certmonger
----------

For *service* administrator use cases, certificate chains will be
delivered via certmonger, in according with the existing use pattern
where ``ipa-getcert`` is used to retrieve and renew certificates.

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

- Dogtag with sub-CA feature (slated for v10.3).


Author
======

Fraser Tweedale

Email
  ftweedal@redhat.com
IRC
  ftweedal
