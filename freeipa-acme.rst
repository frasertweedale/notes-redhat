FreeIPA ACME support
====================

Discussion
----------

ACME currently has two validation challenges defined: DNS (client
creates some DNS records to prove control of a domain) and HTTP
(client creates some HTTP records to prove control of a domain).

ACME clients create accounts on an ACME server by registering a
public key; future messages are authenticated and communications
between server and client are encrypted using the client's key.
There is no specific provision for using ACME with existing
accounts, or creating an ACME account linked to some other account.

The motivating (and so far only) use case of ACME is essentially
anonymous clients create accounts, prove "control" of (DNS) names,
then request certificates for those names.  Therefore the question
arises: how does ACME fit into an enterprise environment where hosts
and services already have identities, can prove those identities to
a CA, and a CA can enforce rules about which identities can be
issued what kinds of certificates?

I have not yet seen a clear answer to that question.  Nor can I
formulate one (I could make up some ideas, but can't tell if they
actually fit any real use cases).

There is also the question of ACME clients - what do they support.
Of course they only support what has been defined: DNS and HTTP
challenges.  They do not support additional layers of authentication
(e.g. GSS-API).  There are specifications in development for
"authority token" challenges, and challenges for other kinds of
names (e.g. email addresses for S/MIME use case, IP address
certificates, code signing certificates).  But these have not been
finalised.  Customers are asking for ACME now.

So let us infer the simplest use case: anonymous ACME clients using
DNS or HTTP challenges to prove control of a domain name, and
getting a certificate for it.  The same as what is done out on the
open Internet by Let's Encrypt and others, only behind the corporate
firewall.  The IDM CA is the issuer, and the prevailing DNS view is
used when validating challenges.

Additional authentication and authorisation layers are deferred.  We
can implement them when we know what they should be.  If we build
"basic ACME", and customers start using it, then hopefully they will
tell us "we need more control over X".  Then we will have a clearer
picture of what "enterprise ACME" is.


MVP
---

Per the above discussion, I propose that the MVP consists of the
following (expanded in later sections):

- Dogtag ACME service with Dogtag CA backend (authenticated by IPA
  RA) and LDAP database backend.  Endi is implementing this - there
  is a lot of progress already and work continues.

- FreeIPA commands to deploy, enable/disable ACME and configure the
  ACME service (e.g. which challenges to enable, which profile to
  use, etc).

- LDAP configuration of ACME service, so that configuration changes
  are replicated and automatically observed by the ACME service.
  The FreeIPA commands will modify the configuration.

- A FreeIPA-managed certificate profile to be used for ACME service
  certificates.

- Modification to ipa-pki-proxy to expose ACME service on port 443.
  For all CA replicas, add ``ipa-ca.$DOMAIN`` alias to HTTP
  certificate.  (Note, this is required by the ACME RFC 8555 but
  some clients including certbot do work on plain HTTP.
  Nevertheless the RFC is crystal clear).

Additionally, although not a strict preprequisite, to address
scalability with many short-lived certificates, we should consider
as a high priority:

- Expired certificate pruning
  https://projects.engineering.redhat.com/browse/FREEIPA-3050

- Pruning of stale/expired ACME orders and accounts


ACME certificate profile
------------------------

We need to define the certificate profile for use with ACME.  With
the ACME service acting as an RA and validating the names in the
request, the amount of validation to be performed by Dogtag itself
is (thankfully) limited.

In particular the Subject Alternative Name (SAN) extension can be used
as-is.

Some ACME clients (e.g. *certbot*) create CSRs with an empty Subject
DN.  We need to ensure Dogtag (and FreeIPA) can handle this
scenario.  Some ACME CAs promote one SAN DNS name to the Subject DN
*Common Name*, if it was empty in the CSR.  Dogtag will provide the
``SANToCNDefault`` profile component to implement this behaviour
(currently implemented in Endi's development branch but not merged).
We know that everything is fine here.  But now is probably a good
time to see how other parts of Dogtag and FreeIPA behave when
encountering a certificate with empty Subject DN.  (This not part of
the MVP).

ACME clients can request a specific validity period.  The request
does not bind the CA.  Apart from this, and the identifier type(s)
included in the *order*, there is no way for a client to indicate or
request a particular profile.

Therefore we should provide a single profile to be used for ACME,
with a fixed validity period of 3 months (or whatever).  Customers
can edit the profile (or supply an alternative profile), adjusting
the validity period if they wish.


ACME service authentication to Dogtag
-------------------------------------

The ACME service will be configured to use the ``"pki"`` (Dogtag)
backend.

The PKI backend uses an agent credential to authenticate to Dogtag.
We can use the IPA RA credential.

We want to get rid of the (shared and highly privileged) IPA RA
credential.  When we implement `GSS-API authentication to Dogtag`_
we can use either the host princpial, Dogtag service principal or a
dedicated ACME service principal to authenticate to Dogtag.  We
would need to ensure that this service principal is authorised to
issue certificates using the ACME profile.

.. _GSS-API authentication to Dogtag: https://www.freeipa.org/page/V4/Dogtag_GSS-API_Authentication



ACME service database backend
-----------------------------

We will implement an LDAP database backend for the ACME service.
This will let us use the replication already established by FreeIPA.

This is not yet implemented.  (TODO: file ticket).  In the meantime
the POC/demos will use the in-memory database and accounts and
orders will be forgotten upon restart.  In fact, maybe this is even
acceptable for MVP?  DISCUSS

Which subtree?
~~~~~~~~~~~~~~

We must decide whether to store ACME data in the Dogtag or FreeIPA
subtree.  I do not have an opinion on this yet.

How to authenticate to LDAP?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ideally we can use GSS-API and the ``dogtag/$HOSTNAME`` service
principal created by FreeIPA for every CA replica.  Alternatively,
an ``acme/$HOSTNAME`` principal could be created.

The ACME service is written in Java.  If Java makes it hard to use
GSS-API to authenticate to LDAP, we can use the Dogtag subsystem
certificate instead (as Dogtag itself does).


Topology / replication considerations
-------------------------------------

There are to main options on how to deploy the ACME capability
within a FreeIPA deployment.

**OPTION 1**: ACME service on all CA replicas

- Set up server to use ``ipa-ca.$DOMAIN`` DNS name (therefore the
  DNS record must exist and be correct).

- No additional operations required to configure ACME, other than to
  enable/disable it or control which challenges are enabled.

- ACME service configured on all CA replicas upon installation (or
  upgrade)


OPTION 2: ACME service on only some CA replicas
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- A new CNAME e.g. ``ipa-acme.$DOMAIN`` points to CA replicas with
  ACME role configured

- Additional steps to configure ACME on a replica (e.g.
  an ``ipa-acme-enable`` command).


I prefer **option 1**.


TLS requirements
----------------

`ACME requires TLS`_.  If we use the ``ipa-ca.$DOMAIN`` alias, we
need to add it to the Subject Alternative Name extension of the HTTP
service certificate, on each CA/ACME replica.

The alternative was that ACME clients need to be instructed to use
the Dogtag port (8443) directly, and that port would need to be
exposed on CA/ACME replicas.  This is undesirable from the usability
and security perspectives.

.. _ACME requires TLS: https://tools.ietf.org/html/rfc8555#section-6.1

To implement this change we need to:

- on installation (including ipa-replica-install and ipa-ca-install)
  ensure the HTTP service certificate gets (re)issued to include the
  include the alias.

- on upgrade (existing CA replicas), update the Certmonger tracking
  request for the HTTP service certificate to include the alias,
  then renew the cert.

There is no CA uninstall (at time of writing), so the scenario of
having to remove the alias does not arise.


Scalability considerations
--------------------------

Pruning expired certificates
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If customer uses ACME heavily, lots of short-lived certs will pile
up in the database.  We should implement pruning of expired
certificates, with knobs to enable/disable (DISABLED by default).
There are already tickets:

- upstream: https://pagure.io/dogtagpki/issue/1750
- downstream: https://projects.engineering.redhat.com/browse/RHCS-337


ACME accounts and orders
~~~~~~~~~~~~~~~~~~~~~~~~

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


Noteworthy gaps in Dogtag ACME implementation
---------------------------------------------

- Dogtag ``PKIBackend`` does not support certificate or GSS-API
  authentication (and may need to).

- Dogtag ``PKIBackend`` needs to work with profiles that immediately
  issue the certificates (current code breaks with profiles like
  ``caIPAserviceCert``).

- Need to implement an LDAP ``ACMEDatabase`` backend

- Dynamic (LDAP-based) configuration including which challenges are
  enabled, what profile to use, and whether ACME is enabled/disabled
  entirely.

- Pruning of stale/expired orders/accounts (could be done by a
  separate program e.g. on a cron job).

- Boosting the log verbosity of the ACME service currently requires
  editing ``/usr/share/pki/acme/webapps/acme/WEB-INF/web.xml`` (or
  am I missing someting...?)
