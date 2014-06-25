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

.. _Top-level Tree: http://pki.fedoraproject.org/wiki/Top-Level_Tree
.. _System profiles: https://fedorahosted.org/pki/ticket/778
.. _Lightweight sub-CAs: http://pki.fedoraproject.org/wiki/Lightweight_sub-CAs


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

Profile scope
^^^^^^^^^^^^^

Because profiles are currently stored as configuration for a
particular CA subsystem, it follows that LDAP profiles will be
stored as attributes of a particular CA or sub-CA subsystem.  This
will be simpler to implement and ensure that deployments prior to,
or not using the `Top-level Tree`_ capability can take advantage of
LDAP profile storage.


Relationship to file-based profile storage
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Profile *creation* will store the new profile in LDAP, so that it
will be replicated.

*Modification* of a file-based profile will result in the modified
profile being stored in LDAP, so that it will be replicated.
Consequently, the LDAP profile storage must take precedence over
file-based profile storage in the profile lookup process.

Because LDAP and file-based versions of a single profile may now
exist at the same time (the LDAP version being the active version),
the behaviour of the *delete profile* operation needs to be
clarified.  Because `System profiles`_ proposes using the shared
system profiles (which an instance will not be able to delete), I
propose that Dogtag prohibit the deletion of profiles that have a
file-based version (whether or not there is also an LDAP version).

If there is a use case for restoring a profile to the default
version distributed or installed by Dogtag (where it exists), a new
*restore profile* operation can be implemented.  This operation
would remove the (modified) profile from the LDAP directory.  The
file-based version will then become the active version.  Attempting
to restore a profile that exists *only in LDAP* would be an error.


LDAP schema
^^^^^^^^^^^

The existing profile registry stores the path to the profile
configuration file and a reference to the enrollment implementation.
For LDAP profiles, the data that would be stored in the profile
configuration file will be stored as binary data, and the enrollment
class will be stored as a "classId" attribute.

The ``classId`` and ``profileConfig`` attribute types and ``profile``
object class will be added to ``schema.ldif``::

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( classId-oid
    NAME 'classId'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.40
    X-ORIGIN 'user defined' )

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( profileConfig-oid
    NAME 'profileConfig'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.40
    X-ORIGIN 'user defined' )

  dn: cn=schema
  changetype: modify
  add: objectClasses
  objectClasses: ( profile-oid
    NAME 'profile'
    DESC 'CMS defined class'
    SUP top
    STRUCTURAL MUST cn MAY ( classId $ profileConfig )
    X-ORIGIN 'user defined' )

Profiles will be stored under a new OU::

  dn: ou=profiles,{rootSuffix}
  objectClass: top
  objectClass: organizationalUnit
  ou: profiles

LDAP-based profile records will look like::

  dn: cn=<profileId>,profiles,{rootSuffix}
  objectClass: top
  objectClass: profile
  cn: <profileId>
  classId: <classId>
  profileConfig;binary:


Please provide feedback on the LDAP schema, as I have not had much
experience with LDAP before and would be surprised if I got things
right on the first attempt.


ProfileSubsystem
^^^^^^^^^^^^^^^^

Names of classes and methods are indicative and open to discussion.

Changes to the ``ProfileSubsystem`` class will be necessary.  Since
profiles will now be stored both on the file system (in the case of
default or system profiles) and in LDAP, it may be appropriate to
move ``ProfileSubsystem`` to ``FileProfileSubsystem`` essentially
unchanged, introduce ``LDAPProfileSubsystem implements
IProfileSubsystem`` for handling the LDAP profile storage, and
reimplementing ``ProfileSubsystem`` an an implementation of
``IProfileSubsystem`` that dispatches or aggregates calls to a
``FileProfileSubsystem``, ``LDAPProfileSubsystem`` or both, as
appropriate.

The ``IProfileSubsystem`` API may need some minor changes to
facilitate this, e.g. an exception or result type indicating that
the implementation is unable to perform some action (e.g. the
``FileProfileSubsystem`` might prohibit deletion; see above).  If
such changes turn out to be not strictly required to implement LDAP
profile storage in a clean and safe manner, they shall be deferred.


API changes
^^^^^^^^^^^

The REST API should not require any significant changes.  Minor
changes that may be required include:

* There may be some new failure conditions (e.g., deletion of a
  particular profile prohibited; see above).  Appropriate HTTP
  response status codes and response bodies should be returned.

* A *restore profile* operation may be required (see above).  Design
  of this API change is deferred until it is decided that it is
  required.

Any changes to the REST API will be reflected in the Python API.


Access control considerations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Currently, only *Administrators* can create, modify or delete
profiles.  No changes to this access control are proposed.


Implementation
--------------

.. Any additional requirements or changes discovered during the
   implementation phase.

.. Include any rejected design information in the History section.


Major configuration options and enablement
------------------------------------------

.. Any configuration options? Any commands to enable/disable the
   feature or turn on/off its parts?

``CS.cfg`` may need to be updated to instantiate any profile
subsystems, including new subsystems, in the correct manner and, if
significant, the correct order.  The main considerations here are
that ``LDAPProfileSubsystem`` needs to be able to communicate with
the LDAP server, and the main ``ProfileSubsystem`` needs to be able
to dispatch requests to both the ``LDAPProfileSubsystem`` and the
``FileProfileSubsystem`` as appropriate.


Cloning
-------

Implications of cloning a Dogtag instance that has not been upgraded
to a version with LDAP profile storage need to be considered.

* Will replication of new/modified LDAP profiles from the clone to
  the original occur?

* If so, will the presence of profile data in the LDAP database of a
  version that has not been upgraded to a version with support for
  LDAP profiles cause any issues, including issues when the original
  *is* upgraded to a version with support for LDAP profiles?


Updates and Upgrades
--------------------

``CS.cfg`` may require updating, as explained above.

Upgrade scripts must detect added or modified profiles and move
these into the LDAP profile storage.  Added profiles will then be
removed from the CA subsystem profiles directory, and modified
profiles will be restored to a pristine state, which will ensure a
smooth changeover to a `System profiles`_ directory, when this
feature is implemented.

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

**ORIGINAL DESIGN DATE**: June 20, 2014

.. Provide the original design date in 'Month DD, YYYY' format (e.g.
   September 5, 2013).

.. Document any design ideas that were rejected during design and
   implementatino of this feature with a brief explanation
   explaining why.

.. Note that this section is meant for documenting the history of
   the design, not the history of changes to the wiki.
