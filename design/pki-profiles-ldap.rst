LDAP Profile Storage
====================

Overview
--------

Dogtag supports adding and modifying CA profiles.  New profiles are
created on the filesystem alongside the default profiles installed
by Dogtag, and updates to profiles are performed in-place.  There
is no mechanism to replicate profiles.

It is now required to implement support for CA profiles in FreeIPA.
Because FreeIPA is typically deployed in a multi-master replication
configuration, with replication agreements between the LDAP
databases on separate hosts, and because changes to profiles will
also need to be replicated, this document proposes a design for
LDAP-based profile storage in Dogtag.

It is furthermore noted that according to *alee*, LDAP profile
storage and replication has been "on the wishlist" for a while.


Associated Bugs and Tickets
---------------------------

Some related tickets that it may make sense to attack whilst
implementing this proposal:

System profiles
  https://fedorahosted.org/pki/ticket/778
IPA should own its certificate profile
  https://fedorahosted.org/freeipa/ticket/4002


Use Cases
---------

FreeIPA profiles
^^^^^^^^^^^^^^^^

A FreeIPA user adds a new profile for a certain use case, e.g. a
client certificate with a certain application-specific X.509
extension (the interface for defining/importing profiles in FreeIPA
is beyond scope of this proposal).  As a result of this action, the
profile should be available on all replicas.

Similarly, modifying a profile should result in the modification
being effected on all replicas.


Operating System Platforms and Architectures
--------------------------------------------

Linux (Fedora, RHEL, Debian).


Design
------

LDAP schema
^^^^^^^^^^^

FILL ME IN


ProfileSubsystem
^^^^^^^^^^^^^^^^

Changes to the ``ProfileSubsystem`` class will be necessary.  Since
profiles will now be stored both on the file system (in the case of
default or system profiles) and in LDAP, it may be appropriate to
move ``ProfileSubsystem`` to ``FileProfileSubsystem`` essentially
unchanged, write ``LDAPProfileService implements IProfileSubsystem``
for handling the LDAP profile storage, and implementing a top-level
``AggregatingProfileSubsystem implements IProfileSubsystem`` for
dispatching and aggregating calls to one or more
``IProfileSubsystem`` instances as appropriate.

The ``IProfileSubsystem`` API may need some minor changes to
facilitate this, e.g. an exception or result type indicating that
the implementation is unable to perform some action.  Though
potentially useful, if such changes turn out to be not strictly
required to implement LDAP profile storage, they shall be deferred.


API changes
^^^^^^^^^^^

The REST API should not require any changes.


Access control considerations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

FILL ME IN


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

FILL ME IN

.. Any impact on cloning?


Updates and Upgrades
--------------------

Upgrade scripts should detect added or modified profiles and move
these into the LDAP profile storage.

Users should be alerted (via release notes) of this feature, and
instructed to disable any custom mechanisms they may have in place
to replicate profile changes between replica, where LDAP replication
agreements are in place.


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

**ORIGINAL DESIGN DATE**: [SEE BELOW]

.. Provide the original design date in 'Month DD, YYYY' format (e.g.
   September 5, 2013).

.. Document any design ideas that were rejected during design and
   implementatino of this feature with a brief explanation
   explaining why.

.. Note that this section is meant for documenting the history of
   the design, not the history of changes to the wiki.
