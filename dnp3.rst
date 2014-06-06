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


IEEE 1815: Electic Power Systems Communications - DPN3
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
  - Uses IEC 62351-8 X.509 extensions (p123 of previous link)


RFC 5755
--------

- Attribute Certificate Profile
- Certificates without public keys, used to assign authorisation or
  other attributes to an entity who uses it in conjuction with
  public key certificate, and/or where public key known to other
  party.
- Dogtag support for attribute certificates????


Dates and deliverables
======================

- Plugfest in August.
- Formal demo for utilities October 28/29.
