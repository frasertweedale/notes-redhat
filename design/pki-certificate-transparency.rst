Overview
========

*Certificate Transparency* (CT) is an approach to logging
certificates issued by a certificate authority for audit purposes.
This design adds CT support to Dogtag.

Specifications
--------------

CT was first developed and deployed at Google.  `RFC 6962`_ was
published *post hoc* and describes the original protocol developed
and deployed by Google.  Many logs still use this protocol.  It is
now referred to as CT 1.0.

.. _RFC 6962: https://tools.ietf.org/html/rfc6962

Later, the IETF `*trans* working group`_ was formed to refine and
achieve consensus on a CT protocol for widespread deployment.  An
`Internet-Draft`_ defining CT 2.0 is being actively developed.

.. _*trans* working group: https://datatracker.ietf.org/wg/trans/documents/
.. _Internet-Draft: https://datatracker.ietf.org/doc/draft-ietf-trans-rfc6962-bis/

Right now, most logs conform to CT 1.0 but CT 2.0 is likely to
dominate in the future.


Terminology
-----------

*CT log* (or just *log*)
  A network service that implements the CT protocol and maintains
  a log of submitted certificates.

*Signed Certificate Timestamp*
  A verifiable object issued by a CT log, to assert inclusion of
  a particular certificate in a log.

*precertificate*
  A signed object containing a ``TBSCertificate`` structure
  identical to the certificate that will be issued, except that the
  *Transparency Information* extension is omitted.  In CT 1.0 this
  is an X.509 certificate.  In CT 2.0 it is a CMS structure (to
  avoid violating serial number constraints)

*embedded SCT*
  A SCT embedded in the X.509 certificate via the *Transparency
  Information* extension.

*Log ID*
  A unique OID assigned to each log (CT 2.0), or a digest of the
  log's public key (CT 1.0).


CT logs
-------

A CT log maintains an append-only, cryptographically verifiable log
of certificates submitted to it.  Typically, a given log will only
accept certificates that chain to particular root CAs.  For example,
a public CT log is likely to accept certificates that chain to
popular, public-trusted CAs.  Upon acceptance of a certificate to a
log, the CT log returns a *Signed Certificate Timestamp (SCT)* to
the client.

A certificate can be submitted to multiple logs.

Certificates may be submitted prior to or after issuance, by any
party, but typically by the CA itself.  Pre-issuance logging logs a
signed *precertificate*, and the returned SCT can be included in the
final certificate via an extension.  When precertificate logging is
performed, the CA must perform two signing operations: one for the
precertificate and, afterwards, one for the certificate.

Anyone can operate a CT log, and anyone can submit certificates to
public CT logs.  Anyone can monitor a public CT log.  For
certificate verification, browsers utilise a select set of public CT
logs.  The exact set will vary over time (logs can be "retired" for
various reasons, and new logs brought online) and may differ between
browsers.

Each log is identified by a *Log ID* which is a unique OID in CT 2.0
and a digest of the log's public key in CT 1.0.
in the CT protocol include the DER-encoded Log ID.


Browser requirements
--------------------

In the years leading up to 2018, CT logging was required for EV
certificates (to be recognised as EV) and for certificates issued by
some CAs (to be trusted at all).  In mid-2018, browsers began to
require all publicly-trusted certificates to be present in multiple
logs.

The requirements of a browser may be complex.  For example, the
`Chromium CT policy`_ requires *at minimum* SCTs from one
Google-operated log and one non-Google-operated log.  In some
circumstances SCTs from five qualified logs are required.

.. _Chromium CT policy: https://github.com/chromium/ct-policy/blob/master/ct_policy.md#qualifying-certificate

The CT logging requirement is only applied to certificates issued by
"public" CAs.  Certificates issued by private PKIs are not subjected
to the requirement.  Nevertheless, there are benefits in using CT
with private PKIs (outlined below).


Benefits of CT
--------------

CAs, browser vendors and the public can monitor logs to identify
mis-issued certificates or hijacked infrastructure.  This applies
equally to public and private PKI.  When CT logging is required,
encountering a non-logged certificate implicates the issuing CA in
either a failure of security controls, or malpractice.

Domain operators can monitor logs for occurences of their domains,
making it possible to observe unauthorised issuance of certificates
to their domains.

Public CT logs are a source of intelligence regarding potential
phishing attacks, brand/trademark protection, etc.


Conveying SCTs to browsers
--------------------------

There are three ways to convey SCTs to browsers:

1. SCTs embedded in certificates.  This requires the CA to log
   the precertificate and embed the returned SCT(s) in the final
   certificate.  This approach requires changes to CA software.

2. SCTs in OCSP responses.  The OCSP responder can collect SCTs for
   a certificate and include them in OCSP responses.  A TLS server
   can use OCSP stapling to convey the SCT-bearing OCSP response to
   the client.  This approach requires changes to OCSP responder
   software.  It also requires the TLS server to support OCSP
   stapling (already widely supported).

3. The TLS server can use a TLS extension to convey SCTs to the
   client.  This requires changes to TLS server software but does
   not require any changes to CA or OCSP software.




Associated Bugs and Tickets
===========================

Main ticket: https://pagure.io/dogtagpki/issue/2989


Use Cases
=========

There are a number of use cases relevant to Dogtag.
Initially we may address only a subset of them.

#. As an enterprise PKI operator or auditor, I want the CA to log
   all certificates to one or more CT logs for monitoring purposes.

#. As an operator of a Dogtag instance chained to a publicly-trusted
   CA, I want Dogtag to issue certificates with embedded SCTs such
   that they will be trusted by browsers.

#. As an operator of a Dogtag instance chained to a publicly-trusted
   CA, I want Dogtag's OCSP responder to include SCTs in responses,
   such that certificates will be trusted by browsers when OCSP
   stapling is used.

#. As an operator of a Dogtag instance I want to log
   previously-issued certificates to a CT log that was not
   previously used by the instance.


Design
======

There are two main aspects to CT support in Dogtag: CT logging
itself, and OCSP responder enhancements.  These are related but
independent.

CT logging
----------

Configuration
^^^^^^^^^^^^^

CT logging is all or nothing.  It does not make sense to log
certificates for some profiles but not others.  Therefore, a global
configuration for CT logging is appropriate.

CT logging configuration shall be stored in LDAP.  Changes to CT
logging configuration on one clone shall be effected topology-wide
due to LDAP replication

An instance may be configured to log to zero or more logs.

**TODO**: define log configuration objects, attributes and semantics

A log configuration must include:

- The log URL
- The CT protocol version to use


Pre- or post-issuance logging?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Precertificate logging introduces a dependency on external system(s)
during certificate issuance.  If logging fails (e.g. due to log
downtime or transient error), one of two things must happen:

1. Issuance fails or is deferred until precertificate logging has
   succeeded.

2. Issuance continues, without logging (therefore without an
   embedded SCT).  The issued certificate can be added to a queue
   for later logging.

Alternatively, post-issuance logging involves attempting to log the
certificate after issuance.  Rather than make this part of the
request cycle, it is logical to enqueue the certificate and have a
background thread deal with the logging.

Furthermore, it will sometimes be desirable to log previously-issued
certificates with new logs that were not configured at the time of
issuance.  Browsers' CT log "agility" means that embedded SCTs that
were accepted by browsers at the time of issuance may be rejected by
browsers at some later time.  Whether directly supported by Dogtag
or not, *post hoc* logging of certificates will sometimes be
required.

Therefore, the initial implementation in Dogtag shall be
**post-issuance** logging, i.e. logging of the issued certificate.


Storing SCTs
^^^^^^^^^^^^

Whether logged as a precertificate or after issuance, SCTs returned
by logs shall be stored in a certificate record.  SCTs shall be
stored in the certificate entry.  Schema as follows::

  ( OID-TO-BE-DEFINED
     NAME 'signedCertificateTimestamp'
     EQUALITY octetStringMatch
     SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )

``1.3.6.1.4.1.1466.115.121.1.40`` refers to the Octet String syntax
(RFC 4517).

The value is either:

- for CT 1.0, a ``SignedCertificateTimestamp`` structure

- for CT 2.0, a ``TransItem`` structure of type ``x509_sct_v2`` or
  ``precert_sct_v2`` encapsulating a
  ``SignedCertificateTimestampDataV2`` structure.

**NOTE:** it might be better to define two attributes - one for CT
1.0 SCTs and one for CT 2.0 ``TransItem`` structures.


Logging queue and thread
^^^^^^^^^^^^^^^^^^^^^^^^

There are several options for processing enqueued logging requests:

- The queue is per-clone and ephemeral.  Each certificate is logged
  by the clone that issued it.  The queue is in-memory and not
  committed to the database.  This has the simplest implementation,
  but if the server process is terminated, pending log requests are
  lost.

- Each clone logs its own certificates, but the queues are committed
  to the database to avoid missing log operations if the server
  process is terminated before all log operations have completed and
  SCTs committed to the database.

- A single clone appointed "CT master" can perform all CT logging.
  This may be desirable to constrain firewall holes to a single
  place.  Logging requests must be written to the database when a
  clone issues a certificate, and the CT master shall monitor the
  queue and perform requested logging.

A fourth option - that any clone or an appointed subset of clones
can log any certificate - is summarily excluded on the basis of
undue complexity due to "locking" requirements.  That is, we do not
want to log the same certificate multiple times to each configured
CT log, and to prevent this introduces an unacceptable amount of
complexity.

The **per-clone ephemeral queue** is suggested as the initial
implementation.  With the right design, its implementation could be
re-used within a database-based logging queue implementation.

**TODO** detailed design.


No-queue option
'''''''''''''''

It's possible to perform desired logging without an *explicit* queue
structure (either ephemeral or in database).

Suppose Dogtag's CT logging configuration includes a *start* date
for the use of a particular CT log.  For each configured log, the
logging thread can search for all certificates issued after that
date.  If the certificate record does not contain an SCT for that
log, it should be logged.

This is an expensive approach, *O(n)* in the number of certificates
certificate records to be processed (if we regard the typically
small number of logs involved as a constant factor).  It is not a
good *general* approach for logging, but is discussed for
completeness.


OCSP responder
--------------

The CT 2.0 Internet-Draft (v28) states::

  7.1.1.  OCSP Response Extension

     A certification authority MAY include a Transparency Information
     X.509v3 extension in the "singleExtensions" of a "SingleResponse" in
     an OCSP response.  All included SCTs and inclusion proofs MUST be for
     the certificate identified by the "certID" of that "SingleResponse",
     or for a precertificate that corresponds to that certificate.

The Transparency Information extension is non-criticial, so there is
no harm in unconditionally including it in OCSP responses.
Therefore, all SCTs in a certificate record shall be included in
OCSP responses.

See `Storing SCTs`_ for a description of how SCTs are stored in a
certificate record.

.. _Storing SCTs: #Storing_SCTs


Configuration
^^^^^^^^^^^^^

No configuration is required.

Response extensions
^^^^^^^^^^^^^^^^^^^

CT 1.0 SCTs shall be included in an OCSP extension with OID
``1.3.6.1.4.1.11129.2.4.5`` and body::

   SignedCertificateTimestampList ::= OCTET STRING

   opaque SerializedSCT<1..2^16-1>;

   struct {
       SerializedSCT sct_list <1..2^16-1>;
   } SignedCertificateTimestampList;

See https://tools.ietf.org/html/rfc6962#section-3.3 for details.


CT 2.0 SCTs and related ``TransItem`` values shall be included in an
OCSP extension with OID ``1.3.101.75`` and body::

  TransparencyInformationSyntax ::= OCTET STRING

  opaque SerializedTransItem<1..2^16-1>;

  struct {
      SerializedTransItem trans_item_list<1..2^16-1>;
  } TransItemList;

See
https://tools.ietf.org/html/draft-ietf-trans-rfc6962-bis-28#section-7.1
for details.


Implementation
==============

Some complexity is anticipated in dealing with CT 1.0 and CT 2.0.
Details will be added as these complexities emerge.


How to use
==========

**TODO**

Cloning
=======

There is no impact on cloning.


Updates and Upgrades
====================

The new schema for storing SCTs must be added on upgrade.


Tests
=====


Dependencies
============

.. Any new package/lib dependencies?

External Impact
===============

After delivery of this feature, it can be considered whether FreeIPA
should be enhanced to include an optional CT log role.

History
=======

