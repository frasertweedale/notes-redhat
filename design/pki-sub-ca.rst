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


Use cases
---------

FreeIPA security domains
~~~~~~~~~~~~~~~~~~~~~~~~

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
- CRL generation by the main CA (**need to confirm this would work**)
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


Key generation and storage
^^^^^^^^^^^^^^^^^^^^^^^^^^

**TODO: more detail needed here**

Keys will be generated when a sub-CA is created, according to the
user-supplied parameters.

Signing certificates and keys are currently stored in the NSS
database at ``/var/lib/pki/pki-tomcat/alias``.

The Sub-CA signing certificates and keys will need to be stored
somehow, and there will need to be a mapping from the representation
of a sub-CA in the LDAP database to corresponding signing keys and
certificates.

Appropriate mechanisms for propagating sub-CA private key material
to clones needs to be devised.  Possible approaches are outlined
below.

DNSSEC implementation example
'''''''''''''''''''''''''''''

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

  Personally, I would say that this is the way to go.

  Petr^2 Spacek


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

**TODO: design API; examples.**


Initialisation
^^^^^^^^^^^^^^

Sub-CA ``CertificateAuthority`` instances will need to be
initialised such that:

- its ``CertificateChain`` is correct;

- its ``ISigningUnit`` can access the sub-CA signing key;

- its ``CertificateRepository`` references the subsystem
  certificateRepository DN


Certificate repository considerations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A design decision was made as to whether to use a single, shared
*certificate repository* for all CAs (including sub-CAs) within a CA
subsystem, or whether each CA within a CA subsystem should have a
distinct certificate repository.

The certificate repository for a CA subsystem is located at
``ou=certificateRepository,ou=ca,{rootSuffix}``, an object of the
``top`` and ``repository`` object classes.  This object shall be
referred to as the *primary repository*.  Sub-CAs will be located
beneath the primary repository, having the object classes as the
primary repository.  The OU of a *sub-repository* will be the
user-chosen name of the sub-CA (possibly with some normalisation
applied.)

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
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Serial numbers used by sub-CA certificates can safely collide with
serial numbers used by other signing certificates - parent, siblings
or children.

Each certificate repository or sub-repository will be accessed via a
distinct ``CertificateRepository`` instance owned by the
``CertificateAuthority`` instance representing that CA or sub-CA.
An implication of this is that certificates issues by different CAs
could have the same serial number.


OCSP and CRL considerations
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Need to determine whether sub-CAs use the existing OCSP responder,
e.g. *http://domain:80/ca/ocsp*, or mount their own responder at
some sub-resource, e.g. *http://domain:80/ca/subca1/ocsp*.


HTTP interface
~~~~~~~~~~~~~~

Sub-CA creating and administration
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

All profiles available to the *primary CA* will be available for use
with sub-CAs.  That is: the profile store is common to the *CA
subsystem* and shared by the primary CA and all sub-CAs.


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

.. Any additional requirements or changes discovered during the
   implementation phase.

.. Include any rejected design information in the History section.


Major configuration options and enablement
------------------------------------------

FILL ME IN

.. Any configuration options? Any commands to enable/disable the
   feature or turn on/off its parts?


Cloning
-------

In a FreeIPA deployment, lightweight sub-CAs **must be replicated**.
Since sub-CA configuration is stored in the database, this
configuration will be replicated.

The method of propagation of signing certificates and keys to clones
needs to be designed.


Updates and Upgrades
--------------------

Because this design introduces entirely new functionality, there are
no known upgrade path concerns.


Tests
-----

.. Identify any tests associated with this feature including:
   - JUnit
   - Functional
   - Build Time
   - Runtime


Dependencies
------------

.. Any new package and library dependencies?


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
