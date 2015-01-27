..
  FreeIPA security domains

  Copyright 2014 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


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
for supporting multiple security domains in FreeIPA.  This feature
will provide:

- an API for creating and administering sub-CAs *within* a CA
  subsystem instance;

- an augmented certificate request API for directing certificate
  requests to a particular CA or sub-CA within the instance.

FreeIPA will use these APIs to provide facilities for the creation
and administration of security domains, and the issuance of
certificates in those domains.

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
the "primary" CA, so a security domain specifically for VPN
authentication should be created for this purpose.  The
certificate-issuing tool would direct certificates requests to the
new security domain, and the resultant certificates would be signed
with VPN security domain's signing key.

A CLI command could be issued to retrieve the VPN security domain's
signing certificate, and/or register it in a local security
database, and the user will configure the VPN server to use that CA
certificate for client certificate verification.


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


Default security domains for host, service and user certificates
----------------------------------------------------------------

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

*security domain*
  A CA or sub-CA as represented in FreeIPA, and associated metadata
  (if any).  Each security domain maps to one *sub-CA*.

*default security domain*
  The existing security domain, corresponding to the top-level CA in
  the Dogtag CA subsystem.  This terminology distinguishes it from
  other security domains which correspond to sub-CAs.

*sub-CA*
  A lightweight sub-CA in the Dogtag CA instance.


High-level design considerations
--------------------------------

Nested sub-CAs
^^^^^^^^^^^^^^

Nested sub-CAs (that is, more than a single level of sub-CAs beneath
the primary CA in a Dogtag instance) are not an initial requirement
(nor are they an initial requirement of the sub-CAs feature in
Dogtag).  However, the schema and other aspects of the FreeIPA
feature should take into account the possibility of nested security
domains as a future requirement.


Sub-CA discovery
^^^^^^^^^^^^^^^^

Sub-CAs could be created in Dogtag directly (i.e. not via FreeIPA).
Whether these sub-CAs should be discovered by FreeIPA and made
available as a FreeIPA security domain is an open question.

It may be desirable, or necessary (due to metadata requirements in
FreeIPA) to require that FreeIPA have explicit knowledge of sub-CAs
in order to use them.  In such case, other sub-CAs that have been
created in Dogtag shall be ignored.


Authorization
^^^^^^^^^^^^^

Which FreeIPA users or roles can create and administer FreeIPA
security domains needs to be decided.

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

It must be possible to configure a FreeIPA service to belong to a
security domain other than the default security domain.  Service
certificates will be issued by the corresponding sub-CA.


User principals
^^^^^^^^^^^^^^^

It may not make sense to add the ability to assign user principals
to a security domain, since there are many use cases for which a
user may require a certificate, and these use cases may demand
separate security domains, e.g. S/MIME vs VPN vs 802.1X and so on.

If an imminent use case exists, this capability can be added.
Otherwise it will be left alone.


User Groups
^^^^^^^^^^^

There are many use cases for user certificates that could apply
simultaneously.  Assuming that each use case is represented by a
single security domain, not all use cases will necessarily apply to
all users.  Because of this, it might be appropriate to "assign"
each user to only the security domains that apply to that user.
Only those users assigned to a security domain would be able to
request certificates from that domain.

***Does this make sense, and should it be an initial requirement?***

Users would be associated to security domains through the existing
*User Groups* would be used for this, with the group schema being
extended to support assignment to zero or more security domains.


Certmonger
^^^^^^^^^^

Pursuant to the `Service principals`_ section, ``ipa-getcert`` for a
service principal configured to belong to a non-default security
domain should result in certificates issued by the corresponding
sub-CA.  The behaviour for service principals belonging to the
default security domain shall be unchanged.


PKI profiles
^^^^^^^^^^^^

***This section requires further discussion and refinement.***

Most security domain use cases involve the generation of
certificates for specific purposes.  Therefore, it may be useful to
restrict the certificates that can be issued by a security domain to
a limited number of Dogtag profiles, and/or to default certificate
requests in that security domain to a particular profile.


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

CLI
---

CLI commands for creating and adminstering security domains shall be
created, with appropriate ACIs for authorisation.


Web UI
------

TODO.


Major configuration options and enablement
==========================================

.. Any configuration options? Any commands to enable/disable the
   feature or turn on/off its parts? 


Replication
===========

There should be no special replication considerations.


Updates and Upgrades
====================

As part of the upgrade process:

- The schema will have to be updated.

- Essential security domains (if there ends up being any - there
  might not) will be have to be created, and any essential
  certificates will have to be issued.


Tests
=====

.. Identify any tests associated with this feature including:
   - JUnit
   - Functional
   - Build Time
   - Runtime


Dependencies
============

- Dogtag with sub-CA feature (slated for v10.3).


Packages
========

.. Provide the initial packages that finally included this feature
   (e.g. "pki-core-10.1.0-1")


External Impact
===============

.. Impact on other development teams and components?


History
=======

**ORIGINAL DESIGN DATE**: 2014-10-14

.. Provide the original design date in 'Month DD, YYYY' format (e.g.
   September 5, 2013).

.. Document any design ideas that were rejected during design and
   implementatino of this feature with a brief explanation
   explaining why.

.. Note that this section is meant for documenting the history of
   the design, not the history of changes to the wiki.
