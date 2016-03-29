..
  Copyright 2014, 2015 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


.. test scenarios:
  - 4.4 -> replica+ca
  - (4.2 -> 4.4) -> replica+ca
  - (4.2 -> 4.4) -> (replica -> ca-install)
  - 4.4 -> replica -> standalone ca
  - 3.x -> replica+ca


Lightweight sub-CAs
===================

Overview
--------

Dogtag supports operation as a sub-CA, but only as a separate
instance.  This document proposes *lightweight sub-CAs*, where one
or more sub-CAs can reside alongside the primary CA in a single
instance.  other subsystems including the parent CA.

This feature is aimed for inclusion in Dogtag 10.3, to be included
in Fedora 21.


Terminology
~~~~~~~~~~~

*primary CA*
  The existing signing capability of the CA subsystem and associated
  keys, certificates and data.  Put another way, this is the
  "highest-level" CA in a Dogtag instance, which may or may not be a
  root CA.

*sub-CA*
  A signing capability and associated keys, certificates and data,
  which will exist as a new capability of CA subsystem and which has
  the primary CA as an authority in its certification chain.

*subsystem*
  A Dogtag instance subsystem, i.e. that which is created by
  ``pkispawn(8)``.  When referring to subsystems within a CMS
  instance, the term *CMS subsystem* is used.


Associated Bugs and Tickets
---------------------------

Multiple subsystems in a single instance
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Dogtag 10.0 introduced ability to host multiple subsystems within a
single instance by hosting the subsystems' HTTP interfaces at
different paths.  How this change was carried out might inform and
influence the sub-CA change.

- https://fedorahosted.org/pki/ticket/89
- http://pki.fedoraproject.org/wiki/PKI_Instance_Deployment


`Top-level Tree`_
~~~~~~~~~~~~~~~~~

A design proposal to avoid proliferation of replication agreements,
justified by FreeIPA use cases (including lightweight sub-CAs).  The
proposed change is to enhance ``pkispawn`` to create subsystem
databases as subtrees under a top-level tree, such that a single
replication agreement can replicate all subsystems.

.. _Top-level Tree: http://pki.fedoraproject.org/wiki/Top-Level_Tree


Support for multiple OCSP signing certificates
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Link: https://fedorahosted.org/pki/ticket/1179

Ticket for adding support for multiple OCSP signing certificates.
Each sub-CA will need its own OCSP signing certificate.


Use cases
---------

FreeIPA use cases
~~~~~~~~~~~~~~~~~

FreeIPA usefulness and appeal as a PKI is currently limited by the
fact that there is a single X.509 security domain.  Any certificate
issued by FreeIPA is signed by the single authority, regardless of
purpose.

FreeIPA requires a mechanism to issues certificates with different
certification chains, so that certificates issues for some
particular use (e.g. Puppet, VPN authentication, DNP3) can be
regarded as invalid for other uses.

The existing Dogtag sub-CA capabilities, i.e. spawning a new
instance configured as a sub-CA, has been deemed too heavyweight and
complex for this use case.  Reasons include:

- Spawning a Dogtag instance is an expensive operation.
- The spawning would need to take place and all replicas, and
  replication agreements set up.
- FreeIPA would need to track the ports of all sub-CAs instances and
  communicate on those ports.

Accordingly, a more lightweight solution to the sub-CA problem is
sought.  Ideally, the capability to create new sub-CAs would be
exposed via the REST API, and no manual intervention would be
necessary in order to begin using a new sub-CA.

Some activities require special attention to ensure that sub-CAs
continue to work:

- Root / top-level CA chain of trust changes
- Key rotation of the top-level CA or an intermediary


Hosting unrelated CAs / sub-CAs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For FreeIPA 4.2 the requirement is only for sub-CAs directly
subordinate to the top-level CA.  In future releases we want Dogtag
to support multiple *independent* CAs.

Of this use case, Dmitri wrote:

  I see the architecture to be such that Dogtag would provide
  multiple CAs from one dogtag instance.  In this single Dogtag
  instance there will be a "main" CA of IPA.  It can be root or
  chained.  There will be additional CAs.  These additional CAs will
  be either independent root CAs, chained to some other CAs or
  chained to IPA main CA. In future may be even chained to each
  other.  IPA would wrap this functionality and allow creation and
  establishing relations between these CAs.

Nathan Kinder provided a concrete use case:

  Consider Barbican in OpenStack.  Barbican is getting into
  certificate issuance now, but it's quite likely that separate
  tenants within a cloud do not want to trust each other.  Barbican
  backed by IPA/Dogtag could offer PKI-as-a-service, where each
  tenant could create their own root and then issue certificates for
  their services/applications within their instances.

These use cases should be considered in the design of the sub-CAs
feature.


Operating System Platforms and Architectures
--------------------------------------------

Linux (Fedora, RHEL, Debian).


Design
------

Sub-CA functionality resides in the root CA webapp.  In essence, a
sub-CA would consist of a name mapped to a new signing certificate.
Almost all resources could be shared, including:

- Certificate database
- Tomcat instance (ports, etc.)
- SSL server certificate, subsystem certificate, audit signing
  certificate
- Logging
- Audit logging
- UI pages
- Users, groups, ACLs
- Serial numbers for certficates and requests.  The same serial
  number generator would be used, so we might have serial number 5
  issued by CA, serial number 6 issued by sub-CA 1, serial number 7
  issued by sub-CA2, etc.
- Backend DB tree.
- Admin interface
- Self test framework
- Profiles

With this solution, it would be very difficult to separate a sub-CA
out into a separate instance.  We could develop scripts to separate
the cert records if needed, and in fact, I (*alee*) suspect we may
need to somehow mark the cert records with the CA identifier to help
searches (say, for all the certs issued by a sub-CA).  (*ftweedal*:
this is mitigated by using a hierarchichal certificate repository.)


Creating sub-CAs
~~~~~~~~~~~~~~~~

Creation of sub-CAs at any time after the initial spawning of an CA
instance is a requirement.  Preferably, restart would not be needed,
however, if needed, it must be able to be performed without manual
intervention.

We will provide an API for creating a sub-CA, which will be part of
the CA subsystem's web API.  See the *HTTP interface* section below.


Key generation
^^^^^^^^^^^^^^

Keys will be generated when a sub-CA is created, according to the
user-supplied parameters.  If replica exist, they will become aware
of the new sub-CA when LDAP replication occurs, but they will not
have the signing key.  A mechanism for replicating the keys is
described in a later section.

In the initial implementation, the sub-CA signing key (which is used
to sign certificates) will also be used for signing CRLs and OCSP
responses.  This simplifies the implementation and configuration,
and means that only one private key needs to be replicated.  Support
for delegated OCSP and CRL signing could be implemented at a later
time, if the use case emerges.

Signing certificates and keys are currently stored in the NSS
database at ``/var/lib/pki/pki-tomcat/alias``.  Sub-CA signing keys
will also be stored in the NSS DB, with the key nickname recorded in
LDAP for locating the correct key.


Sub-CA objects and initialisation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In Java, a sub-CA will be an instance of ``CertificateAuthority``
(or in the case of substantial implementation differences between
the primary CA and sub-CAs, a subclass thereof).

The (single) ``CertificateAuthority`` in the current system is a CMS
subsystem, and the "entry point" to signing behaviour and the
certificate repository is via ``CMS.getSubsystem(SUBSYSTEM_CA)``.
Therefore, new behaviour will be added to ``CertificateAuthority``
for it to locate and initialise sub-CAs, and methods added to
provide access to the sub-CAs (which are also instances of
``CertificateAuthority``).

**TODO:** document the API (which has already been designed/implemented)


Initialisation
^^^^^^^^^^^^^^

Sub-CA ``CertificateAuthority`` instances will need to be
initialised such that:

- its ``CertificateChain`` is correct;

- its ``ISigningUnit`` can access the sub-CA signing key;

- its ``CertificateRepository`` references the subsystem
  certificateRepository DN


Key replication
~~~~~~~~~~~~~~~

Initial requirements:

- Sub-CA signing keys must be propagated from the security
  database of the clone on which the key was generated, to
  the security databases of other clones.

- Keys must be installed with the same nickname.

- Only keys matching certain criteria (they are sub-CA
  signing keys) shall be replicated.  For example, new subsystem
  keys must not be replicated.

Future requirements:

- Once OCSP signing delegation is supported for sub-CAs, sub-CAs'
  OCSP signing keys must also be transferred.

- Provide a convenient way for administrators to perform key
  distribution themselves if they are unwilling or unable to use
  Custodia.

As the *initial* implementation of lightweight CAs will be
exclusively to support the FreeIPA sub-CAs use case and not
supported otherwise, it is acceptable in the initial implementation
to rely on aspects of FreeIPA's Custodia configuration.

The Custodia_ program will be used to perform key replication.
Futher details of Custodia's design and use are found in the
`Replica Promotion design proposal`_.

.. _Custodia: https://github.com/latchset/custodia
.. _Replica Promotion design proposal: https://www.freeipa.org/page/V4/Replica_Promotion#Sharing_Secrets_Securely


Design
^^^^^^

Custodia supports GSS-API for authentication.  It is possible to
implement additional authentication methods but since the initial
requirement is for FreeIPA integration, we can assume Dogtag has a
Kerberos principal and keytab that will be used to authenticate to
Custodia.  The principal must be authorized to access ``ca`` keys.

Upon initialisation of the ``SigningUnit`` of a lightweight CA,
Dogtag shall observe that signing keys are absent and spawn a thread
that invokes an implementation of the ``KeyRetriever`` interface.
Note that this can happen during server startup (e.g. initial run of
a fresh clone of an existing CA instance with lightweight CAs) or at
any other time (e.g. a lightweight CA is created on another clone,
and the corresponding LDAP entry is seen by the persistent search).

::

  interface KeyRetriever {
    /**
     * Retrieve the specified signing key from specified host and
     * store in local NSSDB.
     *
     * @return true if the retrieval was successful, otherwise false
     */
    boolean retrieveKey(String nickname, Collection<String> hostname);
  }

Each lightweight authority LDAP entry shall contain an multi-valued
attribute that lists clones that possess the signing key.  Dogtag
shall retrieve these hostnames and subsequently pass them to the
``KeyRetriever`` along with the nickname of the key being sought.

The ``KeyRetriever`` class to be used is configured in ``CS.cfg``.
The configuration key shall be
``feature.authority.keyRetrieverClass``

Dogtag then spawns a thread that invokes the ``retrieveKey`` method
of the configured ``KeyRetriever`` class.  (It is fine for the
``retrieveKey`` method to block the thread).  Any exception thrown
during the execution of the ``retrieveKey`` method shall be caught
and logged.

If the ``retrieveKey`` method returns ``true``, then ``SigningUnit``
initialisation is restarted.  If the ``SigningUnit`` initialisation
now completes successfully, the clone adds itself to the list of
clones that possess the signing key in the authority's LDAP entry.


``IPACustodiaKeyRetriever``
'''''''''''''''''''''''''''

The ``IPACustodiaKeyRetriever`` class will be the default
``KeyRetriever`` implementation used deployments of Dogtag as part
of FreeIPA.  It will invoke a helper program written in Python that
use FreeIPA's ``CustodiaClient`` class to retrieve keys.  Dogtag's
Kerberos keytab will be used for authentication.

The Kerberos principal used for authenticating shall be
``dogtag/HOSTNAME@REALM``.  The principal must be authorised to
retrieve ``ca`` keys from Custodia.

The principal's keytab shall be stored at
``/var/lib/pki/pki-tomcat/ca/conf/dogtag.keytab`` with ownership
``pkiuser:pkiuser`` and mode ``0600``.


Behaviour when signing keys are not present
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In a replicated environment, users and applications will need to be
tolerant of not-yet-replicated signing keys.  For users, a small
delay while replication occurs before the new CA can be used on
different replica is tolerable.  For testing, tests that involve the
creation of lightweight CAs should be tolerant of the (temporary)
absense of signing keys on another instance.  Similarly,
applications should be aware of and tolerant of this possibility.

When information about a lightweight CA is requested (e.g.
``ca-authority-find`` or ``ca-authority-show`` commands), the
information shall indicate whether the CA's signing keys are present
on the instance at which the request was directed.

When a signing operation is requested but the signing key is not yet
present, Dogtag shall respond with HTTP status **503 Service
Unavailable**.

(Note that if the lightweight CA's LDAP entry has not been
replicated to an instance, requests to that authority on that
instance will typically result in **404 Not Found** or a similar
response.)

Appropriate mechanisms for propagating sub-CA private key material
to clones needs to be devised.  A secure, automatic key transport
procedure is needed.  (Note: it must be ensured that wrapping keys
are at least as cryptographically strong as the key being wrapped.)
Consideration should also be given to allowing users to opt out of
this behaviour and (manually) transport keys themselves, should they
wish.



Database schema
~~~~~~~~~~~~~~~

Certificate and revocation requests
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Certificate issuance and revocation requests are currently stored in
a single "queue" at ``cn=<N>,ou=ca,ou=requests,{rootSuffix}``.  The
single queue will continue to be used (shared by the top-level CA
and all sub-CAs) but the data stored for a queue will now include a
reference to the sub-CA (if any) to which the request is directed.

Request objects have the ``extensibleObject`` object class, so the
existing ``setExtData`` and ``getExtDataInString`` facility will be
used to store a ``String`` sub-CA reference, using the key
``req_authority_ref``.


Certificate repository
^^^^^^^^^^^^^^^^^^^^^^

A design decision was made as to whether to use a single, shared
*certificate repository* for all CAs (including sub-CAs) within a CA
subsystem, or whether each CA within a CA subsystem should have a
distinct certificate repository.

The certificate repository for a CA subsystem is located at
``ou=certificateRepository,ou=ca,{rootSuffix}``, an object of the
``top`` and ``repository`` object classes.  This object shall be
referred to as the *primary repository*.  Sub-CAs will be located
beneath the primary repository, having the same object classes as
the primary repository.  The OU of a *sub-repository* will be the
sub-CA ID.  Therefore, the DN for a sub-CA's certificate repository
is ``ou={subCAId},ou=certificateRepository,ou=ca,{rootSuffix}``.

Although not an initial requirement, this approach accomodates
nested sub-CAs to an arbitrary depth.

Certificate records themselves have as their final path component
``cn={serialNo}`` and the object class ``certificateRecord``, so
various kinds of LDAP searches are easily supported, including:

- all certificates, by searching in the *primary repository* DN with
  ``SCOPE_SUB`` and filter ``(objectClass=certificateRecord)``.

- only certificates issued by a particular CA or sub-CA, by
  searching in the relevant repository's DN with ``SCOPE_ONE`` and
  filter ``(objectClass=certificateRecord)``.


Serial number considerations
''''''''''''''''''''''''''''

If sequential serial numbers are used, serial numbers of
certificates issued by sub-CAs can collide with serial numbers of
certificates issued by other CAs - parent, siblings or children.
This may also occur if random serial numbers are used, although it
is less likely.


CRL considerations
~~~~~~~~~~~~~~~~~~

The ``MasterCRL`` CRL is (by default) signed by the top-level CA.
CRLs can be signed either by the issuing CA, or by a certificate
issued by the issuing CA that contains the ``crlSign`` key usage.

A CRL may include certificates issued by an entity other than the
CRL issuer, in which case it is an *indirect CRL*.  Conforming
applications are not required to support indirect CRLs, and Dogtag
does not yet support the CRL and CRL entry extensions needed for
indirect CRLs (see https://fedorahosted.org/pki/ticket/636), so each
sub-CA will have its own *CRL Distribution Point* (referred to in
the codebase and database schema as a *CRL Issuing Point* or
*CRLIP*).

CRL support for lightweight CAs is not an initial requirement.  A
ticket has been filed to track this feature:
https://fedorahosted.org/pki/ticket/1627


Schema
^^^^^^

CRLs for the top-level CA are located at
``cn=<CRL_id>,ou=crlIssuingPoints,ou=ca,{rootSuffix}``.

Sub-CA CRLIPs will be located beneath the top-level CRLIP OU, in an
OU named for the sub-CA ID.  Therefore, a sub-CA's CRLIP OU will be
have the DN ``ou={subCAId},ou=crlIssuingPoints,ou=ca,{rootSuffix}``,
with CRLs located beneath that.

Initially, only the one CRLIP per sub-CA will be maintained.
Support for multiple sub-CA CRLIPs is YAGNI'd unless a clear use
case emerges.


Publishing
^^^^^^^^^^

The ``CertificateAuthority.initCRL()`` method is responsible for
initialising a CA's CRLIPs.  This method needs to be updated to read
lightweight CAs' CRLIP configuration from the database (or infer it
from other data).  For the top-level CA, the existing behaviour
shall be retained.


REST API
^^^^^^^^

**TODO** document the REST API (already designed/implemented)


OCSP considerations
~~~~~~~~~~~~~~~~~~~

The existing OCSP responder (part of the CA subsystem) will be used
to obtain status information for certificates issued by lightweight
CAs.

OCSP requests contain a sequence of ``CertID`` values, each of which
identifies an issuing authority and the serial number of the
certificate being checked::

   CertID          ::=     SEQUENCE {
       hashAlgorithm       AlgorithmIdentifier,
       issuerNameHash      OCTET STRING, -- Hash of issuer's DN
       issuerKeyHash       OCTET STRING, -- Hash of issuer's public key
       serialNumber        CertificateSerialNumber }

The ``issuerKeyHash`` of the first ``CertID`` in an OCSP request is
used to locate the appropriate ``CertificateAuthority`` to which to
direct the OCSP request.  If no authority can be found, the result
is **404 Not Found**.  If an authority is found, the ``CertStatus``
response for any ``CertID`` identifying a different authority will
be ``unknown``.


Revocation check
^^^^^^^^^^^^^^^^

**TODO: how does the below process fit in?  The OCSPServlet does not
use CRL data at all.  Is this section relevant for separate OCSP
instances?**

OCSP revocation checks take place in the ``processRequest`` method
of the ``DefStore`` class.  This method is passed a ``CertID``,
which contains the *authority key identifier* and the *serial
number* of the certificate being checked, and returns a
``SingleResponse`` object.  The current behaviour of this method is
summarised as follows:

#. The cache of *CRL Issuing Points* (CRLIPs), keyed by authority
   key identifier, is searched.

#. If no result is found, CRLIP database objects are iterated until
   the CRLIP for the authority is found, by equality check on key
   digest.  The CRLIP is added to the cache.

#. The ``X509CRLImpl`` is retrieved from the CRLIP and searched for
   the *serial number* of the certificate being checked.  If the
   serial number is found in the CRL, a ``RevokedInfo`` status will
   be returned, otherwise ``GoodInfo`` or ``UnknownInfo`` is
   returned, according to the result of the ``isNotFoundGood()``
   method.

Given the existing implementation, minimal changes are required to
the OCSP implementation in order to support multiple sub-CAs.  The
main area of concern is the linear traversal of CRLIP records to
find the CRL for the issuing authority of the certificate being
checked.  Since this cost is only incurred on a CRLIP cache miss,
performance for a large number of sub-CAs/CRLs should be profiled,
and optimisation attempted only if the performance is unacceptable.


HTTP interface
~~~~~~~~~~~~~~

Sub-CA creation and administration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A new REST resource will be implemented providing sub-CA creation
and administration capabilities.

New sub-CA
''''''''''

Create a sub-CA, including keys and signing certificate, based on
relevant inputs.  Aspects of the sub-CA that are not stored in the
LDAP database must be automatically propagated to clones.  If the
operation is successful the sub-CA will be available for immediate
use, without having required a restart.

Several parameters are needed to create they sub-CA and generate its
keys and signing certificate.  Some or all of these would be API
parameters (i.e., user-supplied), and those that are not would be
fixed, or fixed with respect to user-supplied values.

- Immediate parent.  For the initial implementation, with nested
  sub-CAs (i.e., sub-CAs *within* sub-CAs) not being a requirement,
  this may be an implied parameter, with the *primary CA* as the
  fixed value.

- Validity (start and end, or start and duration).  Aspects of this
  parameter may be inferred or defaulted.

- Subject Name
  - User-supplied.  May be derived from a separate "friendly name"
    argument).

- Key algorithm
  - User-supplied

- Key size
  - User-supplied
  - Acceptable values depend on the chosen key algorithm

- Basic Constraints
  - Critical
  - CA: true
  - pathLenConstraint: optional; should be validated with respect to
    the intermediary CA certificate that will sign the sub-CA
    certificate.

- Key Usage
  - Critical
  - Digital Signature, Non Repudiation, Certificate Sign, CRL Sign

- Signing algorithm (i.e., what algorithm should the intermediary
  use to sign the sub-CA certificate)
  - Acceptable values depend on the *intermediary's* key algorithm


Certificate requests
^^^^^^^^^^^^^^^^^^^^

Communication with the CA webapp would involve optionally providing
a new parameter to select the sub-CA to be used. This would be
simplest to implement and require fewer mappings.  The fact is that
most resources are going to be shared and serviced by the main CA
app in any case.

We care about which sub-CA we need when issuing/revoking a cert.  We
can modify the REST servlet for enrollment to look for this
parameter and direct the request accordingly.

We may need to consider how to do things like list the certs issued
by a particular sub-CA, or list requests for a particular sub-CA,
etc.


Profiles
^^^^^^^^

In the initial implementation of this feature, all profiles
available to the *primary CA* will be available for use with
sub-CAs.  That is: the profile store is common to the *CA subsystem*
and shared by the primary CA and all sub-CAs.

It may be desirable to have the ability to restrict sub-CAs to only
issue certificates in a particular profile or limited set of
profiles.  This will not be in the initial work but design detail
and implementation can come later, as use cases are clarified.


ACLs
^^^^

The existing ACLs shall apply for reviewing/assigning/approving
certificate requests to a sub-CA.  Future work could implement
"sub-CA-scoped agents" if such a use case emerges.

Sub-CA creation and administration will require administrator
credentials.


User interface
~~~~~~~~~~~~~~

New controls or widgets will need to be written for the web
interface for:

- Choosing the CA to which to direct a certificate request performed
  via the web UI.

- Indicating which CA a certificate request is for, when viewing
  a certificate request.

- Searching for certificates or certificate requests of a
  particular CA.


Implementation
--------------

``EnrollProfile`` and ``CAEnrollProfile``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``EnrollProfile`` class is responsible for populating
certificate information.  Modifications needed are:

* When creating request objects, store the sub-CA indicator from the
  profile context in the request data.

* When executing requests, switch the ``ICertificateAuthority``
  context for enrollment to the sub-CA indicated in the request data
  (if any).


``SigningUnit``
~~~~~~~~~~~~~~~

Update ``SigningUnit`` and have its owners supply the nickname
configuration, so that there can be multiple ``SigningUnit``
instances using different keys.


``CertificateAuthority`` and ``ICertificateAuthority``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Add methods to retrieve a sub-CAs given a ``String`` sub-CA
reference or an ordered ``List<String>`` of individual sub-CA
handles.

Update construction and initialisation to give the instance
awareness of its position in the CA heirarchy, and to initialise the
``CertificateRepository``, ``SigningUnit`` instances to the correct
DNs, nicknames, etc.


``AuthInfoAccessExtDefault``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The *Authority Information Access* extension shall include the
``caRef`` parameter in the OCSP responder URI (see the OCSP
discussion above).  This is accomplished by reading the sub-CA
reference from the request and if not null, appending a query
parameter to the responder URI.


``AuthorityKeyIdentifierExtDefault``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The *Authority Key Identifier* extension must identify the immediate
signing authority, which could be a sub-CA.  Accordingly, the sub-CA
reference reference is read from the request data and used to query
the top-level CA for the appropriate sub-CA.


Servlets and web interface
~~~~~~~~~~~~~~~~~~~~~~~~~~

Servlets and web templates (HTML, javascript) will be update to
recognise and propagate the ``caRef`` request parameter, which
indicates a sub-CA.  If the parameter is absent or empty, the
top-level CA is implied.

Care must be taken in JavaScript code to ensure that ``null`` values
for the ``caRef`` parameter do not result in a literal string value
of ``"null"``.  This case should be handle by either using the empty
string or omitting the parameter from the subsequent request.

Where appropriate, web forms should include a field for specify a
sub-CA.


Major configuration options and enablement
------------------------------------------

A single, instance-wide configuration value should enable or disable
the *creation* of sub-CAs.  The ``pkispawn(8)`` configuration format
should be updated to provide a way to control this configuration
when deploying an instance.

**TODO** should we default on/off for new instances?


Cloning
-------

When a clone is spawned, all sub-CA private signing keys (including
CRL/OCSP signing keys) must be made available to the clone, in
addition to the top-level CA signing key.


Upgrading
---------

Several web templates have been updated and these updates will need
to be deployed on existing instances by ``pki-server-upgrade(8)``.


Tests
-----

.. Identify any tests associated with this feature including:
   - JUnit
   - Functional
   - Build Time
   - Runtime


Dependencies
------------

* Secure key/secret replication service.


Packages
--------

.. Provide the initial packages that finally included this feature
   (e.g. "pki-core-10.1.0-1")


External Impact
---------------

.. Impact on other development teams and components?


History
-------

.. Provide the original design date in 'Month DD, YYYY' format (e.g.
   September 5, 2013).

.. Document any design ideas that were rejected during design and
   implementatino of this feature with a brief explanation
   explaining why.

.. Note that this section is meant for documenting the history of
   the design, not the history of changes to the wiki.

**ORIGINAL DESIGN DATE**: June 20, 2014


Rejected design: sub-CA subsystem (*Solution 1*)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Enable deployment of multiple CA webapps within a single Tomcat
instance.  In this case, the sub-CA is treated exactly the same as
other subsystems like the KRA, which can exist within the same
Tomcat instance as the CA (and so have the same ports).  These
systems share a certificate database, and some system certifcates
(subsystem certificate and SSL server certificate), but have
separate logging, audit logging (and audit signing certificate), and
UI pages.  They also have separate directory subtrees (which contain
different users, groups and ACLs).

This approach has several distinct advantages:

* It would be easy to implement.  Just extend ``pkispawn`` to create
  multiple CAs with user-defined paths.  ``pkispawn`` already knows
  how to create sub-CA's.

* CAs would be referenced by different paths /ca1, /ca2 etc.

* No changes would be needed to any interfaces, and no special
  profiles would be needed.  Whatever interfaces are available for
  the CA would be available for the sub-CAs.  The sub-CAs are just
  full fledged CAs, configured as sub-CAs and hosted on the same
  instance.

* It is very easy to separate out the sub-CA subsystems to separate
  instances, if need be (though this is not a requirement).

Disadvantages of this approach include:

* FreeIPA would need to retain a separate X.509 agent certificate
  for each sub-CA, and appropriate mappings to ensure that the
  correct certificate is used when contacting a particular sub-CA.

* The challenge of automatically (i.e., in response to an API call)
  spawning sub-CA subsystems on multiple clones is likely to
  introduce a lot of complexity and may be brittle.


Creating sub-CAs
^^^^^^^^^^^^^^^^

Modify ``pkispawn`` to be able to spawn sub-CAs.  Users and software
wishing to create a new sub-CA would invoke ``pkispawn`` with the
appropriate arguments and configuration file and then, if necessary,
restart the Tomcat instance.  ``pkispawn`` will create all the
relevant config files, system certificates, log files and
directories, database entries, etc.

This would actually not be that difficult to code.  All we need to
do is extend ``pkispawn`` to provide the option for a sub-CA to be
deployed at a user defined path name.  It will automatically get all
the profiles and config files it needs.  And ``pkispawn`` already
knows how to contact the root CA to get a sub-CA signing CA issued.


HTTP interface
^^^^^^^^^^^^^^

The sub-CA is another webapp in the Tomcat instance in the same way
as the KRA, CA, etc.  The sub-CAs would be reached via ``/subCA1``,
``/subCA2``.  The mapping is user-defined (through ``pkispawn``
options or configuration).  ``pkispawn`` would need to check for and
reject duplicate sub-CA names and other reserved names (*ca*, *kra*,
etc.)  Nesting is possible, though it would not necessarily be
reflected in the directory hierarcy or HTTP paths.

This would eliminate the need to create mappings from sub-CA to CA
classes, or the need to create new interfaces that have to also be
maintained as the CA is maintained.

From the point of view of the client, there is no need to use
special profiles that somehow select a particular sub-CA.  All they
need to do is select the right path - which they can do because they
know which sub-CA they want to talk to.


Cloning
^^^^^^^

Cloning would require invoking ``pkispawn`` in the appropriate
manner on all replica.


Reasons for rejection
^^^^^^^^^^^^^^^^^^^^^

The challenge of spawning sub-CA subsystems on multiple clones is
likely to introduce a lot of complexity and may be brittle.  The
alternative solution of storing sub-CA configuration in the
database, thus allowing easy replication, was preferred.


Rejected design: sub-CA key transport via LDAP
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Initial design efforts focused on mechanisms to transport sub-CA
private keys to replicas by wrapping them and replicating them
through the LDAP database.

Design details
^^^^^^^^^^^^^^

DNSSEC implementation example
'''''''''''''''''''''''''''''

Comments from *Petr^2 Spacek* about how key distribution is
performed for the DNSSEC feature:

  Maybe it is worth mentioning some implementation details from DNSSEC
  support:

  - *Every replica has own HSM* with standard PKCS#11 interface.
    - By default we install SoftHSM.
    - In theory it can be replaced with real HSM because the
      interface should be the same. This allows users to "easily"
      get FIPS 140 level 4 certified crypto instead of SoftHSM if
      they are willing to pay for it.

  - Every replica has own private-public key pair stored in this HSM.
    - Key pair is generated inside HSM.
    - Private part will never leave local HSM.
    - Public part is stored in LDAP so all replicas can see it.

  - *All* crypto operations are done inside HSM, no keys ever leave
    HSM in plain text.

  - LDAP stores wrapped keys in this was:
    - DNS zone keys are wrapped with DNS master key.
    - DNS master key is wrapped with replica key.

  Scenario: If replica 1 wants to use "key2" stored in LDAP by
  replica 2:

  - Replica 1 downloads wrapped master key from LDAP.
  - Replica 1 uses local HSM to unwrap the master key using own
    private key -> resulting master key is stored in local HSM and
    never leaves it.
  - Replica 1 downloads "key2" and uses master key in local HSM to
    unwrap "key2" -> resulting "key2" is stored in local HSM and
    never leaves it.

  Naturally this forces applications to use PKCS#11 for all crypto
  so the raw key never leaves HSM. Luckily DNSSEC software is built
  around PKCS#11 so it was a natural choice for us.


``CryptoManager`` based implementation
''''''''''''''''''''''''''''''''''''''

Notes about this implementation:

- Key generation is done within a JSS ``CryptoToken``.

- All decryption is done within a JSS ``KeyWrapper`` facility, on a
  JSS ``CryptoToken``.

- I do not see a way to retrieve a ``SymmetricKey`` from a
  ``CryptoToken``, so the key transport key must be unwrapped each
  time a clone uses a sub-CA for the first time.

Each clone has a *unique* keypair and accompanying X.509 certificate
for wrapping and unwrapping symmetric *key transport key* (KTK).
The private key is stored in the NSSDB and used via
``CryptoManager`` and ``CryptoToken``.

Creating a clone will cause the private keypair to be created and a
wrapped version of the KTK for that clone is stored in LDAP.

::

  KeyWrapper kw = cryptoToken.getKeyWrapper();

  SymmetricKey ktk;
  kw.initWrap(clonePublicKey, algorithmParameterSpec);
  byte[] wrappedKTK = kw.wrap(ktk);
  // store wrapped KTK in LDAP

When a sub-CA is created, its private key is wrapped with the KTK
and stored in LDAP:

::

  PrivateKey subCAPrivateKey;
  kw.initWrap(ktk, algorithmParameterSpec);
  byte[] wrappedCAKey = kw.wrap(subCAPrivateKey);
  // store wrapped sub-CA key in LDAP

When a clone needs to use a sub-CA signing key, if the private key
is not present in the local crypto token, it must unwrap the KTK,
then use the KTK to unwrap the sub-CA private key and store the
private key in its crypto token.

::

  /* values retrieved from LDAP */
  byte[] wrappedKTK;
  byte[] wrappedCAKey;
  PublicKey subCAPublicKey;

  kw.initUnwrap(clonePrivateKey, paramSpec);
  SymmetricKey ktk = kw.unwrapSymmetric(wrappedKTK, ktkType, -1);

  kw.initUnwrap(ktk, paramSpec2);
  PrivateKey subCAPrivateKey =
      kw.unwrapPrivate(wrappedCAKey, caKeyType, subCAPublicKey);

At this point, the sub-CA private key is stored in the clone's
crypto token for future use.  The unwrap operation is performed at
most once per sub-CA, per clone.


SoftHSM implementation
''''''''''''''''''''''

Should the security of the ``CryptoManager`` implementation (above)
prove insufficient, a SoftHSM_ implementation will be investigated
in depth.

The current OpenDNSSEC design is based around SoftHSM v2.0 (in
development) and may be a useful study in SoftHSM use for secure key
distribution.

.. _SoftHSM: https://www.opendnssec.org/softhsm/


Reasons for rejection
^^^^^^^^^^^^^^^^^^^^^

Storage of private signing keys in LDAP was deemed to be too great a
security risk, regardless of the wrapping used.  Should access to
the database be gained, offline attacks can be mounted to recover
private keys or intermediate wrapping keys.

It was further argued that in light of these risks, Dogtag's
reputation as a secure system would be undermined by the presence of
a signing key transport feature that worked in this way, even if was
optional and disabled by default.


Archived designs: key replication suggestions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ade's suggestion
''''''''''''''''

1. We create a new service on the CA for the distribution of subCA
signing keys.  This service may be disabled by a configuration setting
on the CA.  Whether it should be disabled by default is open to debate.

2. SubCA detects (through ldap) that a subCA has been added.  It sends a
request for the CA signing key, including the identifier for the subCA
and half of a session key (wrapped with the subsystem public key).
Recall that the subsystem key is shared between clones and is the key
used to inter-communicate between dogtag subsystems.

3. The service on the master CA generates the other half of a session
key and wraps that with the subsystem public key.  It also sends back
the subCA signing key wrapped with the complete session key.

There are lots of variations of the above, but they all rely on the fact
that the master and clones share the same subsystem cert - which was
originally transported to the clone manually via p12 file.

The subsystem certificate is stored in the same cert DB as the signing
cert, so if it is compromised, most likely the CA signing cert is
compromised too.

Christina's suggestion
''''''''''''''''''''''

(A refinement of the above proposal.)

* A subCA is created on CA0

* CA1 and CA2 realized it, each sends CA0 a "get new subCA signing
  cert/keys" request, maybe along with each of their transport cert.

* CA0 (after ssl auth) do the "agent" authz check

* once auth/authz passed, CA0 generates a session key, use it to
  wrap its priv key, and wrap the session key with the corresponding
  transport cert in the request , Send them along with CA0's signing
  cert back to the caller in response. (see additional layers of
  security measurement below)

* CA1 and CA2 each receives its respective wrapped session key and
  the wrapped CA signing key and the CA cert, do the unwrapping onto
  the token, etc.

We also want to make sure the transport certs passed in by the
caller are valid ones.

One way to do it is to have Security Domain come into play.  The SD
is supposed to have knowledge of all the subsystems within its
domain.  Could we add something in there to track which ones are
clones of one another?  Could we maybe also "register" each clone's
transport certs there as well.  If we have such info at hand from
the SD, then the "master of the moment" could look up and verify the
cert.

Also, one extra step that can be taken is to generate a nonce
encrypted with the transport cert and receive it back encrypted with
the "master of the moment"s own transport cert to ensure that the
caller indeed has the transport cert/keys.


References
==========

* [[PKI CA Authority CLI]]
