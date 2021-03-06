Relevant standards
==================

IEC 62351
---------

- developed by WG15 of IEC TC57
- handles security of TC 57 protocols
- provides
  - authentication
  - integrity
  - privacy
  - intrusion detection

Relevant subsections:

IEC 62351-5
  TLS for IEC 60870-5 (DNP3)

IEC 62351-8
  Role-based access control (RBAC) for users and agents in power
  systems.  Defines some X.509 extensions.


IEEE 1815: Electic Power Systems Communications - DNP3
------------------------------------------------------

- *Distributed Network Protocol*
- http://standards.ieee.org/findstds/standard/1815-2012.html
  - need subscription to access document

- DNP3 Secure Authentication
  - Enernex blog post (Oct 2013):
    http://www.enernex.com/blog/dnp3-secure-authentication-whats-all-the-buzz-about/
  - Currently at Version 5 (SAv5); included in IEEE 1815-2012.
  - Grant Gilchrist is primary editor.
  - Can use PKI, facilitates key rotation.
  - Announcement on SAv5:
    https://www.dnp.org/DNP3Downloads/DNP3%20SAv5%20Further%20Info%20Announcement%2020111201.pdf
  - Email address for comments/questions on SAv5:
    secure_authentication@dnp.org
  - SAv5 specification as at 2011-11-08 (publically available):
    http://www.dnp.org/Lists/Announcements/Attachments/7/Secure%20Authentication%20v5%202011-11-08.pdf
  - Uses IEC 62351-8 X.509 extensions (p123 of previous link).


RFC 5755
--------

- https://tools.ietf.org/html/rfc5755
- Attribute Certificate Profile
- Certificates without public keys, used to assign authorisation or
  other attributes to an entity who uses it in conjuction with
  public key certificate, and/or where public key known to other
  party.
- Is Dogtag currently able to sign attribute certificates?  If not,
  what is required to support them?
- Attribute certificates do not seem to be necessary for the
  functioning of SAv5/DNP3 (see below).  They may be required for
  compliance.


Dates and deliverables
======================

- Plugfest in August 26-28
- Utility workshop/demo Oct 28


Concepts and terminology
========================

User

  A "user" a human user.  This does not preclude automation.  From
  §7.3.9 "Multiple Users and Auditing":

    This standard assumes that there may be multiple users of the
    system located at the site of the master. It provides a method
    to authenticate each of the users separately from each other and
    from the master itself.

    The intent of this principle is to permit the outstation to
    conclusively identify the individual user (not just the device)
    that transmits any protocol message.

  From Table A-11 "User Role Definitions", user roles include
  VIEWER, OPERATOR, ENGINEER and INSTALLER, among others.

Authority

  *Authority* to the DNP3 concept, and not a *certificate
  authority*.  Where the latter is meant, the full term *certificate
  authority* or abbreviation *CA* will be used.


DNP3 PKI requirements
=====================

DNP3 entities are *master*, *outstations* and *users*.  In addition
to this there is the concept of an external *authority* that
provides certification of users.  Communication between master and
authority is not part of DNP3; the only requirement is that such
communition is secure.  From §7.4.1.7.2 (p9):

  The master’s job is merely to forward certifications of users to
  the outstation from the authority, and to ensure that the new
  Update Key is securely transmitted. The communications between the
  master and the authority for the purpose of certifying a user is
  out of the scope of this document but must also be secure.

This requirement is reiterated throughout the specification.


X.509 requirements
------------------

Attribute certificates
^^^^^^^^^^^^^^^^^^^^^^

In §A.45.8 "Authentication - User Certificate" (p120) of SAv5 spec:

  The data provided in this object is certified by an external
  authority that is not the master station itself.  The authority
  provides the certificate to the master, and the master provides
  the certificate to the outstation without modification. The key
  used to sign the certificate shall be the private key of the
  authority.

Attribute certificate (no publicy key) and ID certificate (public
key) are supported, see §A.45.8.2.1 and §A.45.8.2.2 for more info.
PKI support for attribute certificates seems to be non-essential but
desirable.

Extensions
^^^^^^^^^^

The g120v10 "Authentication - User Status Change" object format
expresses role information (see Table A-11 on p130) along with a
public key and related attributes.  A master may transmit a g120v8
"Authentication - User Certificate" object instead of a g120v10
object.  The g120v8 object carries an IEC 62351-8 certificate, which
is an X.509v3 certificate with extensions defined by IEC 62351-8.

Support for IEC 62351-8 certificates would seem to be non-essential
for a proof-of-concept or demonstration, but may be essential for
compliance, and is in any case desirable.

IEC 62351-8 lives behind a paywall so details of the extensions are
unknown at this stage.  Lack of details aside, I do not expect that
much work, if any, will be required in Dogtag to support these
extensions.


Key distribution
----------------

For distributing the *Authority Public Key*, Table 7-2 (p7) states:

  The Authority Public Key may be transmitted anywhere in the clear,
  but must be securely installed in the outstation by trusted
  personnel.

Likewise:

  The Outstation Public Key shall be generated by the outstation and
  may be transmitted anywhere in the clear, although it must be
  installed and stored securely in the master by trusted personnel.

And:

  The User Private Key shall be generated by the user and ideally
  should be carried to the master in a physical token by the user.
  In any case, the mechanism by which the master station accesses
  the user’s private key must be secure.

Another point about key generation and distribution is made in
§7.6.1.4.10 "Cryptograhpic Information", Note 3):

  The master must know the user’s private key in order to sign the
  Update Key for the outstation. The authority must know the user’s
  public key to certify it to the outstation. One solution for
  achieving these requirements may be for the authority to derive
  both keys and encode them on a token for the user to carry and
  insert at the master. Another may be for the master to derive both
  keys and securely provide the user’s public key to the authority
  for certification. There may be other solutions. The solution
  chosen is out of the scope of this standard. The master always
  receives the user’s public key in certification by the authority,
  even if it was originally derived by the master.


Provisioning
============

- AFAICT the DNP3 *master* and *authority* may reside on the same
  host, though they are always referred to as separate parties.

- DNP3 Users could map to FreeIPA users.  Modulo support in Dogtag
  for producing a certificate with IEC 62351-8 extensions, and a
  mapping of the user to the correct profile in FreeIPA,
  `ipa-getcert` with the user Kerberos principal and an appropriate
  CSR will yield the corresponding *ID certificate* for use with
  DNP3.

  Whether or not it makes sense to also store keys and role
  information in FreeIPA, as user attributes, depends on DNP3 master
  implementation details (see comments below).

- The authority is responsible for informing the master when users
  are added/removed/modified.  The master needs to know user
  **private** keys.

  These requirements are somewhat in tension.  The *authority* holds
  the authoritative information about user existance and roles, but
  the *master* must have the *private* key of each user.

- The mechanism for configuring a master/authority DNP3 setup are
  undefined and will probably vary between master implementations.
  The opendpn3_ implementation `does not support`_ SAv5.  Triangle
  Microworks have a `non-free library`_ that apparently supports
  SAv5.

- Do we know of and have access to any DNP3 master implementations
  that have SAv5 PKI support?  Are we hoping to support *a
  particular* implementation at this time?  We can do everything
  that we need to do on the FreeIPA/Dogtag side to support SAv5, but
  unless there are master implementations that can use it there may
  be much to do for us to be able to demonstrate this, e.g. at a
  plugfest.

- Implementation choices made by SAv5/DNP3 master implementors (see
  `Key distribution` above) will affect whether we need to store
  private keys and role information in FreeIPA (or a separate
  authority program that uses some FreeIPA facilities).

- Due to the fact that communication between master and authority
  is unspecified, we will probably never be able to claim "DNP3"
  support but only support for particular (hopefully leading, or
  defacto standard) DNP3 implementations.

.. _opendnp3: http://www.automatak.com/opendnp3/
.. _does not support: https://groups.google.com/forum/#!topic/automatak-dnp3/banTP-RbfCQ
.. _non-free library: http://www.trianglemicroworks.com/products/source-code-libraries/dnp-scl-pages
