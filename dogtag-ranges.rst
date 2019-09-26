Replica range sanity: what to check
===================================

Complete sanity checking is a topology-wide operation, i.e. to
collect every replica's view about its own and other replicas'
ranges, and making sure that they all agree.

Any disagreement among replicas is probably due to LDAP conflicts.
So even without comprehensive range checking, if there are other
checks for conflict entries, it is still possible to discover
disagreements.

In the meantime, there are some sanity checks that can be performed
per-replica.

Current and next range are non-empty
------------------------------------------

The ``CS.cfg`` current range and (if present) next range must be
non-empty.  The range is *inclusive*, so the upper bound must be
greater than or equal to the lower bound.

Current and next range do not overlap
-------------------------------------------

The next range, if defined, must not overlap with the current range.

No overlaps in initial range assignments
----------------------------------------

The LDAP ranges subtree for each managed range contains entries of
the following form::

  dn: cn=10000001,ou=requests,ou=ranges,o=ipaca
  objectClass: top
  objectClass: pkiRange
  beginRange: 10000001
  endRange: 20000000
  cn: 10000001
  host: rhel76-1.ipa.local
  SecurePort: 443

Note that reconciling these against ranges in ``CS.cfg`` is
difficult for a couple of reasons:

- The range object records an *original* range assignment to the
  clone ``(host,SecurePort)`` indicated in the object.  But due to
  *delegation* other clones could have range assignments in
  ``CS.cfg`` that fall within this range.

- The initial range assignments for the first replica are not
  recorded in a range object.  Therefore, a range assignment
  (including ranges delegated to other clones) may not have *any*
  ``pkiRange`` object that includes it.

One sanity check we *can* perform is to ensure that there are no
overlaps in any of the ``pkiRange`` objects for a single managed
range.  The LDAP ranges subtree parent for each managed range type
is recorded in the `Objects and parameters`_ section below.

Repository object ``nextRange`` exceeds known ranges
----------------------------------------------------

For each number type, the *repository* object is the parent object
of the objects whose IDs are assigned from that range.  These are
all recorded in `Objects and parameters`_ below.  For example the
certificate repository object looks like::

  dn: ou=certificateRepository,ou=ca,o=ipaca
  nextRange: 40000001
  serialno: 011
  ou: certificateRepository
  objectClass: top
  objectClass: repository

The value of the ``nextRange`` attribute is the *start* of the next
range to be assigned.  The size of the next range assignment is
determined by a ``CS.cfg`` parameter (and doesn't really matter
much).

So the value of the ``nextRange`` must be greater than the
``endRange`` value of *all* ``pkiRange`` objects for the managed
range.


Report range extents
--------------------

All replicas should report their range extents (current and next
ranges) an "info" level.  Other / future tools (Insights?) can
ingest these data and perform topology-wide sanity checks.



Objects and parameters
======================

This section records the objects and parameters for each managed
range.

CA certificate serial numbers
-----------------------------

- Base: **hexademical**

- Current range: dbs.beginSerialNumber ..  dbs.endSerialNumber

- Next range: dbs.nextBeginSerialNumber .. dbs.nextEndSerialNumber

- LDAP repository object (nextRange attribute):
  ``ou=certificateRepository,ou=ca,o=ipaca``

- LDAP ranges subtree parent:
  ``ou=certificateRepository,ou=ranges,o=ipaca``


CA requests
-----------

Base: demical

CS.cfg attributes:

Current range: dbs.beginRequestNumber .. dbs.endRequestNumber
Next range: dbs.nextBeginRequestNumber .. dbs.nextEndRequestNumber

LDAP repository object (nextRange attribute):

dn: ou=ca,ou=requests,o=ipaca

LDAP ranges subtree parent:

dn: ou=requests,ou=ranges,o=ipaca

Replica numbers
---------------

Base: demical

CS.cfg attributes:

Current range: dbs.beginReplicaNumber .. dbs.endReplicaNumber
Next range: dbs.nextBeginReplicaNumber .. dbs.nextEndReplicaNumber

LDAP repository object (nextRange attribute):

dn: ou=replica,o=ipaca

LDAP ranges subtree parent:

dn: ou=replica,ou=ranges,o=ipaca

KRA keys
--------

- Base: **hexademical**

- Current range: dbs.beginSerialNumber .. dbs.endSerialNumber

- Next range: dbs.nextBeginSerialNumber .. dbs.nextEndSerialNumber

- LDAP repository object (nextRange attribute):
  ``ou=keyRepository,ou=kra,o=kra,o=ipaca``

- LDAP ranges subtree parent:
  ``ou=keyRepository,ou=ranges,o=kra,o=ipaca``

KRA requests
------------

Base: demical

Current range: dbs.beginRequestNumber .. dbs.endRequestNumber
Next range: dbs.nextBeginRequestNumber .. dbs.nextEndRequestNumber

LDAP repository object (nextRange attribute):

dn: ou=kra,ou=requests,o=kra,o=ipaca

LDAP ranges subtree parent:

dn: ou=requests,ou=ranges,o=kra,o=ipaca

KRA replicas numbers
--------------------

Base: demical

Current range: dbs.beginReplicaNumber .. dbs.endReplicaNumber
Next range: dbs.nextBeginReplicaNumber .. dbs.nextEndReplicaNumber

LDAP repository object (nextRange attribute):

dn: ou=replica,o=kra,o=ipaca

LDAP ranges subtree parent:

dn: ou=replica,ou=ranges,o=kra,o=ipaca
