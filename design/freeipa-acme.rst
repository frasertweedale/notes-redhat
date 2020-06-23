.. FreeIPA ACME support

Overview
========

*Automated Certificate Management Environment (ACME)* is a protocol
for automated identity verification and issuance of certificates
asserting those identities.  The initial and predominant use case is
for Web PKI, i.e. automated issuance of *domain validated (DV)*
certificates.  Automation enables better security through
shorter-lived certificates, more pervasive security through
automatic deployment of TLS and cost-savings by eliminating
repetitive human effort.

Dogtag PKI has implemented an ACME server.  The purpose of this
design is to use the Dogtag ACME service to support ACME use cases
in FreeIPA.

ACME overview
=============

ACME is defined and extended in the following IETF documents:

- `RFC 8555`_: The main spec, ``dns`` identifier, ``http-01`` and
  ``dns-01`` challenges

- `RFC 8737`_: ``tls-alpn-01`` challenge

- `RFC 8738`_: ``ip`` identifier

- Others already published or being developed by the `ACME working
  group`_

.. _RFC 8555: https://tools.ietf.org/html/rfc8555
.. _RFC 8737: https://tools.ietf.org/html/rfc8737
.. _RFC 8738: https://tools.ietf.org/html/rfc8738
.. _ACME working group: https://datatracker.ietf.org/wg/acme/documents/

ACME currently has two validation challenges defined: DNS (client
creates some DNS records to prove control of a domain) and HTTP
(client creates some HTTP records to prove control of a domain).

ACME clients create accounts on an ACME server by registering a
public key; future messages are authenticated and communications
between server and client are encrypted using the client's key.
There is no specific provision for using ACME with existing
accounts, or creating an ACME account linked to some other account.

An ACME account *orders* a certificate for a set of *identifiers*.
The currently defined identifer types are ``dns`` and ``ip``.  The
server creates *challenges* that they client can use to prove
"control" of the identifiers.  Currently defined challenge types are
``http-01`` (provision an HTTP resource at the location reached via
the identifier), ``dns-01`` (provision a DNS TXT record at the
forward or IP-reverse name) and ``tls-alpn-01`` (TLS-based challenge
using ALPN extension).  After completing challenges, the client
*finalizes* the order and the server issues the certificate.

ACME also defines operations for certificate revocation and account
key rollover.  RFC 8555 does not state whether ACME servers or
clients are required to support these operations.


Use cases (stories)
===================

As a developer I want to use FreeIPA to issue my certificates over
ACME protocol so that I can develop and test using the same protocol
I will utilize in production.

As a system administrator I want the FreeIPA CA to provide an ACME
server so that I can automatically acquire and renew certificates.

As a IT security officer I want the organisation's CA to provide
ACME to reduce costs and barriers to using TLS for all internal
services.


Scope
=====

The motivating (and so far only) use case of ACME is essentially
anonymous clients create accounts, prove "control" of (DNS) names,
then request certificates for those names.  The question that arises
is: how does ACME fit into an enterprise environment where hosts and
services already have identities, can prove those identities to a
CA, and a CA can enforce rules about which identities can be issued
what kinds of certificates?  There is no clear, general answer to
this question at present.

There is also the matter of ACME clients and what features they
support.  They support what has been defined: the ``dns`` identifier
and some or all of the defined challenges (``http-01``, ``dns-01``,
``tls-alpn-01``).  They generally do not support additional layers of
authentication (e.g. GSS-API).  There are specifications in
development for an "authority token" challenge, and challenges for
other kinds of names (e.g. email addresses for S/MIME use case, IP
address certificates, code signing certificates).  But these have
not been finalised.

The conclusion is that people are asking for ACME as it is defined
and in use today, i.e.  anonymous ACME clients using the
aforementioned challenges to prove control of a domain name, and
acquire a certificate for it.  It is the same as what is done out on
the open Internet by Let's Encrypt and others, only behind the
corporate firewall.  The FreeIPA CA is the issuer, and the
prevailing DNS view is used when validating challenges.

Additional authentication and authorisation layers are deferred.  We
can implement them when we have a clear use case.  It would be a
separate design proposal.


Feature management
==================

Initially the only configuration available is to enable or disable
the servicing of requests by the Dogtag ACME service.  This is
accomplished via the ``ipa-acme-manage`` command::

  # enable the service
  ipa-acme-manage enable

  # disable the service
  ipa-acme-manage disable

These commands operate on a per-server basis.  Subsequent work will
enable deployment-wide configuration of the ACME service (by
replicating the configuration over LDAP).  With that change, an
``acme`` plugin for the FreeIPA API will allow users with the
appropriate privileges to control the ACME service.  The
``ipa-acme-manage`` command will be deprecated or removed.  Examples
of what the commands may look like (non-prescriptive)::

  # enable service
  ipa acme-manage --enabled=1

  # enable issuance of wildcard certificates
  ipa acme-manage --wildcard=1

  # set profile to use
  ipa acme-manage --profile=customProfile

  # set CA to use
  ipa acme-manage --ca="ACME sub-CA"

  # set enabled challenges (http-01 enabled, dns-01 disabled)
  ipa acme-manage --challenges=http-01

  # show configuration
  ipa acme-info


Design
======

Overview of Dogtag ACME service
--------------------------------

The Dogtag ACME service is an optional component, implemented as a
Tomcat application.  When deployed it runs as part of the
``pki-tomcatd`` process alongside any other Dogtag subsystems (CA,
KRA).

The implementation supports different *issuer* backends, e.g. Dogtag
(``PKIIssuer``) or a local NSS database (``NSSIssuer``).  The ACME
service manages ACME accounts, orders and challenges and functions
as a *registration authority (RA)* that uses the configured issuer
to issue certificates.

The implementation supports different databases, including LDAP and
PostgreSQL.

Currently only the ``dns`` identifier and ``http-01`` and ``dns-01``
challenges are implemented.  This covers the primary use case and a
large majority of clients.

Apart from issuer and database, there are currently few
configuration options.  These include whether to enable the service
at all (i.e. to service requests, or respond ``503`` to all
requests), and whether to allow wildcard certificates.

The configuration source is configurable but only local file-based
configuration has been implemented.  This means that until a
distributed configuration source is implemented, the Dogtag ACME
service must be configured on a per-server basis.


Design at a glance
------------------

The major aspects of the design are as follows.  Each item is
elaborated in its own subsection.

- Deploy the Dogtag ACME service on all CA replicas

- Configure Dogtag ACME service to use Dogtag CA to issue
  certificates, using a suitable profile provided by FreeIPA.

- Configure Dogtag ACME service to store ACME objects in LDAP under
  ``o=ipaca`` subtree.

- Provide commands to manage the FreeIPA ACME service, including
  enable/disable.

- Update the HTTP configuration to proxy ACME requests to Dogtag.

- Add the ``ipa-ca.$DOMAIN`` DNS name to the FreeIPA HTTP
  certificate to enable ACME clients to use that domain name.


Deploying the ACME service
--------------------------

There are two main options on how to deploy the ACME capability
within a FreeIPA deployment.

1. Deploy ACME service on all CA replicas.  This would mean clients
   could use the established ``ipa-ca.$DOMAIN`` DNS name to access
   the ACME service.  No administrator actions are required to
   configure the ACME service, other than to enable it.  The ACME
   service will be automatically deployed on new CA servers, and on
   existing CA servers upon upgrade.

2. Deploy ACME service on select CA replicas.  Define a new ACME
   server role.  Administrators choose the CA servers on which to
   configure the ACME role.  A new DNS name points to ACME servers
   in the topology (e.g. ``ipa-acme.$DOMAIN``).  Implement behaviour
   to manage this DNS name when using FreeIPA's internal DNS.  The
   requirement to manage this DNS name is imposed on administrators
   when not using FreeIPA's internal DNS.

Option #1 was chosen because it is simplier for administrators and
the implementation is simplier.

Because ACME requires the use of TLS, both options impose the
requirement to add a new DNS name to the FreeIPA HTTP certificate.
See `TLS requirements`_ for details.

In addition to creating the configuration files as described in the
following sections, FreeIPA shall run the following two commands to
create and deploy the Dogtag ACME service instance::

  pki-server acme-create
  pki-server acme-deploy


Database
--------

Configure the Dogtag ACME service to use the ``ou=acme,o=ipaca``
subtree via ``/etc/pki/pki-tomcat/acme/database.conf``::

  class=org.dogtagpki.acme.database.LDAPDatabase
  basedn=ou=acme,o=ipaca
  configFile=/etc/pki/pki-tomcat/ca/CS.cfg

The ``configFile`` directive tells the ``LDAPDatabase`` where to
find database connection settings.

The ACME schema is automatically added in new installations.  See
`Upgrade`_ for upgrade steps.

Create the ACME object heirarchy under ``ou=acme,o=ipaca``::

  dn: ou=nonces,ou=acme,o=ipaca
  objectClass: organizationalUnit
  ou: nonces

  dn: ou=accounts,ou=acme,o=ipaca
  objectClass: organizationalUnit
  ou: accounts

  dn: ou=orders,ou=acme,o=ipaca
  objectClass: organizationalUnit
  ou: orders

  dn: ou=authorizations,ou=acme,o=ipaca
  objectClass: organizationalUnit
  ou: authorizations

  dn: ou=challenges,ou=acme,o=ipaca
  objectClass: organizationalUnit
  ou: challenges


Schema
~~~~~~

::

  attributeTypes: ( acmeExpires-oid NAME 'acmeExpires'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.24
    EQUALITY generalizedTimeMatch
    ORDERING generalizedTimeOrderingMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeValidatedAt-oid NAME 'acmeValidatedAt'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.24
    EQUALITY generalizedTimeMatch
    ORDERING generalizedTimeOrderingMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeStatus-oid NAME 'acmeStatus'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeError-oid NAME 'acmeError'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    SINGLE-VALUE )

  attributeTypes: ( acmeNonceValue-oid NAME 'acmeNonceValue'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeAccountId-oid NAME 'acmeAccountId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeAccountContact-oid NAME 'acmeAccountContact'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch
    SUBSTR caseIgnoreSubstringsMatch )

  attributeTypes: ( acmeAccountKey-oid NAME 'acmeAccountKey'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    SINGLE-VALUE )

  attributeTypes: ( acmeOrderId-oid NAME 'acmeOrderId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeIdentifier-oid NAME 'acmeIdentifier'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch )

  attributeTypes: ( acmeAuthorizationId-oid NAME 'acmeAuthorizationId'
    SUP name )

  attributeTypes: ( acmeAuthorizationWildcard-oid NAME 'acmeAuthorizationWildcard'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.7
    EQUALITY booleanMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeChallengeId-oid NAME 'acmeChallengeId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeToken-oid NAME 'acmeToken'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )

  objectClasses: ( acmeNonce-oid NAME 'acmeNonce'
    STRUCTURAL
    MUST ( acmeNonceValue $ acmeExpires ) )

  objectClasses: ( acmeAccount-oid NAME 'acmeAccount'
    STRUCTURAL
    MUST ( acmeAccountId $ acmeAccountKey $ acmeStatus )
    MAY acmeAccountContact )

  objectClasses: ( acmeOrder-oid NAME 'acmeOrder'
    STRUCTURAL
    MUST ( acmeOrderId $ acmeAccountId $ acmeStatus $ acmeIdentifier $ acmeAuthorizationId )
    MAY ( acmeError $ userCertificate $ acmeExpires ) )

  objectClasses: ( acmeAuthorization-oid NAME 'acmeAuthorization'
    STRUCTURAL
    MUST ( acmeAuthorizationId $ acmeAccountId $ acmeIdentifier $ acmeStatus )
    MAY ( acmeExpires $ acmeAuthorizationWildcard ) )

  objectClasses: ( acmeChallenge-oid NAME 'acmeChallenge'
    ABSTRACT
    MUST ( acmeChallengeId $ acmeAccountId $ acmeAuthorizationId $ acmeStatus )
    MAY ( acmeValidatedAt $ acmeError )

  objectClasses: ( acmeChallengeDns01-oid NAME 'acmeChallengeDns01'
    SUP acmeChallenge
    STRUCTURAL
    MUST acmeToken )



Issuer
------

The template for ``/etc/pki/pki-tomcat/acme/issuer.conf`` is::

  class=org.dogtagpki.acme.issuer.PKIIssuer
  url=https://$FQDN:8443
  profile=acmeServerCert
  username=$USER
  password=$PASSWORD

The ``class`` tells the Dogtag ACME service to use the ``PKIIssuer``
issuer implementation.

``url`` configures ``PKIIssuer`` to use the Dogtag CA on the same
host.

``profile`` tells ``PKIIssuer`` what profile to use.  See `Profile`_
for details of what this profile must contain.

``username`` and ``password`` tell ``PKIIssuer`` how to authenticate
to the Dogtag CA.  ``issuer.conf`` must have ownership
``pkiuser:pkiuser`` and mode ``200``.  See `Authentication to CA`_
for details.


Authentication to CA
~~~~~~~~~~~~~~~~~~~~

The PKI backend must authenticate to Dogtag.  The IPA RA credential
is not suitable because the ``pki-tomcatd`` process cannot access
it.  Furthermore the IPA RA credential is in the wrong format
(Dogtag uses JSS and requires an NSS DB) and we want to eventually
get rid of the IPA RA and use GSS-API proxy authentication for
authentication between the FreeIPA framework and Dogtag.

Remaining options considered were:

1. A shared "ACME RA" Dogtag (not IPA) user account, with password
   authentication (we don't want to introduce any more
   certificates).  The password would be distributed among CA
   replicas via Custodia and must be stored so that only
   ``pki-tomcatd`` can read it.  The account requires permission to issue
   certificates using the configured profile, and to revoke
   certificates issued by it.

2.  A Dogtag user account per server with unique password (avoiding
    need to replicate password securely).  The accounts need the
    same permission as the previous option, which could be achieved
    via a group membership.  The same file readership requirements
    apply.

3.  Implement most of the remainder of the `GSS-API authentication
    to Dogtag`_ effort so that we can use GSS-API authentication
    between the ACME service and the Dogtag CA subsystem.  This is a
    complex (risky) and time-consuming effort.  The upside is that
    it's a big step toward resolving one of the biggest and
    longest-running problems in the FreeIPA architecture.

.. _GSS-API authentication to Dogtag: https://www.freeipa.org/page/V4/Dogtag_GSS-API_Authentication

The chosen option was #2.  Therefore the implementation is required
to:

- Create the ``ACME Agents`` group (once only)

- Add a Dogtag ACL allowing members of ``ACME Agents`` to revoke
  certificates (once only)::

    certServer.ca.certs:execute
      :allow (execute) group="ACME Agents"
      :ACME Agents may execute cert operations

  The ``execute`` permission sounds like it has a large scope but it
  indeed only grants permission to revoke (or unrevoke) a
  certificate.

- For each CA server create the ``acme-$FQDN`` user, with membership
  in ``ACME Agents`` and a unique password (to be written in
  ``issuer.conf``).

Requirements for the certificate profile configuration are described
in `Profile`_.


Profile
~~~~~~~

The ACME profile shall be called ``acmeServerCert``.  As with other
*included profiles* it is defined as a template:
``/usr/share/ipa/profiles/acmeServerCert.cfg``.  The definition is
similar to ``caIPAserviceCert`` but there are a few important
differences:

- Only members of the ``ACME Agents`` group can issue certificates
  using this profile::

    auth.instance_id=SessionAuthentication
    authz.acl=group="$ACME_AGENT_GROUP"   

- The certificate lifetime is 90 days::

    policyset.serverCertSet.7.constraint.params.range=90

- The ``SANToCNDefault`` component is used to populate the Subject
  DN field because some ACME clients create CSRs with an empty
  Subject field::

    policyset.serverCertSet.9.default.class_id=sanToCNDefaultImpl
    policyset.serverCertSet.9.default.name=SAN to CN Default     


Replicated configuration
------------------------

**Not yet implemented.**

Story: *As an administrator, I want to be able to configure and
control the FreeIPA ACME service deployment-wide, so that
configuration is kept consistent without additional effort.*

This will require implementing an LDAP-based *configuration source*
in the Dogtag ACME service.  Because the configuration will be
managed by ordinary FreeIPA users, it may be necessary to store that
configuration in the FreeIPA LDAP database (as opposed to
``o=ipaca``).  Therefore it *might* be necessary for the
configuration source to authenticate to LDAP using a FreeIPA
principal and GSS-API.

An appropriate service princpial already exists: ``dogtag/$FQDN``.
But if GSS-API is required it will be necessary to achieve this via
the *ldapjdk* library.  There does appear to be some GSS-API
ldapbind code in *ldapjdk* but its status is unknown.

The configuration source will either need to execute a persistent
search (preferred) or regularly poll the LDAP configuration object
and look for changes to the configuration.


TLS requirements
----------------

`ACME requires TLS`_.  Therefore we must add the ``ipa-ca.$DOMAIN``
DNS name to the FreeIPA HTTP certificate on each CA server.

To simplify the implementation, we actually add the
``ipa-ca.$DOMAIN`` DNS name to the HTTP certificate on *every IPA
server* whether or not it is a CA replica.  The DNS name does (or is
expected to) only point at CA servers, so this is not an operational
issue.  The security implication (relative to having the name on the
HTTP certs of CA servers) is that HTTP TLS key compromise of an IPA
server that is not a CA server allows it to impersonate
``ipa-ca.$DOMAIN`` and therefore the ACME server.  This is a modest
risk because compromise of that key is already a catastrophe.  The
avoidance of complexity due the fact that IPA servers can acquire
the CA role at any time seems well worth it.

.. _ACME requires TLS: https://tools.ietf.org/html/rfc8555#section-6.1

To implement this change we need to:

- on installation (including ipa-replica-install and ipa-ca-install)
  ensure the HTTP service certificate gets (re)issued to include the
  include the alias.

- on upgrade (existing CA replicas), update the Certmonger tracking
  request for the HTTP service certificate to include the alias,
  then renew the cert.

This change was implemented in https://pagure.io/freeipa/issue/8186.


Scalability
-----------

Pruning expired certificates
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Not yet implemented.**

If ACME is used heavily, lots of short-lived certificates will pile
up in the Dogtag database.  We should implement pruning of expired
certificates, with knobs to enable/disable (DISABLED by default).
This scenario is not ACME-specific and there is an existing ticket:
https://pagure.io/dogtagpki/issue/1750.


Pruning expired ACME objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Not yet implemented.**

The ACME service database stores account, order, authorization and
challenge objects.  The growth of the database will be approximately
linear in the number of orders (certificate requests), unless some
cleanup operations are performed.

Order objects may have an expiry.  Expired orders could be pruned
from the database.  The expiry could be set at (for example) 24
hours while the order is not yet ``valid`` (i.e. before a
certificate is actually issued), and reset when the certificate is
issued to the ``notAfter`` date of the certificate.  The order
therefore expires when it seems the client has "given up", or when
the certificate expires.  It can then be deleted.

Authorization and challenge objects can also expire, and be pruned
in a similar way.

Accounts themselves have no expiry in the data model and semantics
of ACME.  But if needed, accounts could be pruned if they are at
least some minimum age, but have no orders.  This indicates that the
account is inactive (all orders have expired and been removed; an
active ACME client will create new orders to renew the certificates
it manages).

Nonces
~~~~~~

ACME protocol nonces are currently created in the LDAP database.
They are therefore replicated.  The performance impact has not been
measured but rapid additional and deletion of small objects
throughout the protocol steps may be some "low hanging fruit" if
ACME load causes replication issues.

Client behaviour has not been adequately analysed to know whether
restriction of nonces to a single server (e.g. an in-memory cache)
is viable when the ACME server's DNS name points to several servers.


Upgrade
=======

- Update the LDAP schema with the contents of
  ``/usr/share/pki/acme/database/ldap/schema.ldif``.

- Deploy the ACME service using the same subroutine as used during
  installation.  This subroutine must already detect and skip "once
  per deployment" operations that were already completed (e.g.
  creating the LDAP object hierarchy) so there is no special
  consideration of these scenarios during upgrade.


How to use
==========

See `Feature management`_ for a description of administrator
operations.

For the client side, use an ACME client program to create an ACME
account, request certificates and (if required) revoke certificates.
There are many ACME clients and elaborating all the usage scenarios
is out of scope of this document.  But see `Test plan`_ for some
specific scenarios using the *Certbot* and *mod_md* clients.

As a concrete example, here is how you could use *Certbot* to
register an account and acquire a certificate from the FreeIPA
ACME service::

  # certbot --server https://ipa-ca.ipa.local/acme/directory \
    register -m ftweedal@redhat.com --agree-tos --no-eff-email

  # certbot --server http://ipa-ca.ipa.local/acme/directory \
    certonly --standalone --domain $(hostname)


Test plan
=========

ACME clients available on Fedora include *Certbot* (a general
purpose client) and *mod_md* (an Apache httpd module).  These can be
tested independently.

The test setup is a single FreeIPA server with CA role, and a single
client.  All steps in the test scenarios outlined below are on the
client unless stated otherwise.

Enabling ACME service
---------------------

1. [Server] Deploy a server with CA.

2. [Client] Use *Curl* to request ACME directory object and ensure
   ACME service responds 503 (it has not been enabled yet).

3. [Server] ``ipa-acme-manage enable``

4. [Client] Use *Curl* to request ACME directory object again;
   should succeed.


Certbot HTTP challenge
----------------------

1. Register account.

2. Request certificate using ``--standalone`` HTTP server.  Succeeds.


Certbot DNS challenge
-----------------------

**Not yet implemented.**

Assume account already registered (previous test).

1. Request certificate using ``dns-01`` challenge and ``--manual``
   mode with hooks to create/clean up required TXT records.
   Succeeds.


Certbot revocation
------------------

**Not yet implemented.**

Assume account already registered and certificates have been
successfully issued (previous tests).

1. Revoke a certificate.  Succeeds.

2. Confirm via ``ipa cert-show`` command that certificate was
   revoked.


mod_md HTTP challenge
---------------------

1. Add ``httpd`` configuration to use ``mod_md`` for machine's FQDN.

2. Restart ``httpd`` (and wait a few seconds).

3. Gracefuly restart ``htttpd`` (to pick up certificate, assuming
   mod_md was able to acquire one).

4. [Server] Use Curl to retrieve page hosted at client over HTTPS.
   Succeeds.
