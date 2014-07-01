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

This feature is slated for version **10.3**, or, if the `database
upgrade framework`_ feature is ready in time, a future **10.2.x**
release.


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
.. _Database upgrade framework: https://fedorahosted.org/pki/ticket/710
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

In introducing LDAP-based profiles, there exist two main options for
how file-based profiles are treated: file-based profiles can be
replaced by LDAP-based profiles, or file-based profiles can continue
to be used for system/default profiles.


LDAP-based profiles only
~~~~~~~~~~~~~~~~~~~~~~~~

All profiles will be stored in LDAP.

There is currently a 10.3 ticket to create a `database upgrade
framework`_. Once this framework is in place, it can be used to
perform a migration from files to LDAP, as well as modify default
profiles when the default profile is being used.


File-based system profiles
~~~~~~~~~~~~~~~~~~~~~~~~~~

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

(*alee*) I understand why you have profiles in both LDAP and file
format.  However, I think this makes things complicated. My
preference would be to have all new systems maintain their profiles
solely in LDAP, rather than some admixture.

There is a precedent for moving data that was formerly in files to
ldap - and that was the data in the security domain. Originally,
this data was in files. At some point, we changed the servlets that
update the security domain to use LDAP instead, and used a parameter
in CS.cfg to determine whether the data was in LDAP or files.

(*edewata*) I think all system/default profiles should remain
file-based and all custom profiles should be LDAP-based. It will
make a clean separation: system profiles are owned by us (Dogtag
developers), custom profiles are owned by the admin.

I think all system/default profiles should remain file-based and all
custom profiles should be LDAP-based. It will make a clean
separation: system profiles are owned by us (Dogtag developers),
custom profiles are owned by the admin.

The system profiles will be read-only. This way we will be able to
update the system profiles without writing any upgrade scripts
because the files will be updated automatically by RPM. Just one
requirement, all server instances must be upgraded to the same
version.

If the admin wants to change a system profile, they can clone it
into a custom profile and make the changes there. The custom
profiles cannot have the same names as the system profiles, so
there's won't be any conflict/confusion, and no need to support a
"restore" command. In general we won't need to write upgrade scripts
for custom profiles except if we change the LDAP schema.


LDAP schema
^^^^^^^^^^^

The existing profile registry stores the path to the profile
configuration file and a reference to the enrollment implementation.
For LDAP profiles, the data that would be stored in the profile
configuration file will be stored as octet strings, and the
enrollment class will be stored as a "classId" attribute.

The ``classId`` (Directory String) and ``profileConfig`` (Octet
String) attribute types and ``certProfile`` object class will be
added to ``schema.ldif``::

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( classId-oid
    NAME 'classId'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    X-ORIGIN 'user defined' )

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( certProfileConfig-oid
    NAME 'certProfileConfig'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.40
    X-ORIGIN 'user defined' )

  dn: cn=schema
  changetype: modify
  add: objectClasses
  objectClasses: ( certProfile-oid
    NAME 'certProfile'
    DESC 'CMS defined class'
    SUP top
    STRUCTURAL MUST cn MAY ( classId $ certProfileConfig )
    X-ORIGIN 'user defined' )

Profiles will be stored under a new OU::

  dn: ou=certProfiles,{rootSuffix}
  objectClass: top
  objectClass: organizationalUnit
  ou: certProfiles

LDAP-based profile records will look like::

  dn: cn=<certProfileId>,ou=certProfiles,{rootSuffix}
  objectClass: top
  objectClass: certProfile
  cn: <certProfileId>
  classId: <classId>
  certProfileConfig: <octet string>

The ``certProfile`` nomenclature has been used where possible to
disambiguate certificate profiles from TPS token profiles.

(*edewata*)  I suppose we want to have something that resembles the
actual Profile data structure (see ``ProfileData`` Java class).
There should be an LDAP attribute for each single-valued Java
attribute (e.g. name, description, enabled, visible). This way the
profile is more manageable and can be queried based on these
attributes. For collection attributes (e.g. inputs, outputs,
policySets) we can use child LDAP entries to represent them.


ProfileSubsystem
^^^^^^^^^^^^^^^^

Changes to the ``ProfileSubsystem`` will be necessary.  Names of
classes and methods are indicative and open to discussion.


LDAP-based profiles only
~~~~~~~~~~~~~~~~~~~~~~~~

The ``ProfileSubsystem`` will need to work with the database instead
of the filesystem.  This should require no significant changes to
its public API.


File-based system profiles
~~~~~~~~~~~~~~~~~~~~~~~~~~


Since profiles will now be stored both on the file system (in the
case of system/default profiles) and in LDAP, it may be appropriate
to move ``ProfileSubsystem`` to ``FileProfileSubsystem`` essentially
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


Keeping profiles up to date
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Currently, profiles are read at startup. This means that we need
some mechanism to trigger the restart/reloading of the
``ProfileSubsystem`` on clones, without a restart.  One such
mechanism would be to store when each clone last read in the
profiles.  This could be checked in the maintenance thread, and
updated/restarted as needed.  (There would be no need for the
maintenance thread to monitor file-based profiles for changes, as
these should only change if updated from RPMs.)

(*ftweedal*) Is there any way to be notified when a certain part of
the database has changed due to LDAP replication?  Or would this be
a poll operation?

(*simo*) For detecting changes on replicas you can use a persistent
search or a syncrepl operation (newest DS).


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

(*edewata*) About the REST interface & CLI, since this will be the
primary way to edit profiles, we might want to have more granular
commands to modify parts of the profile. Right now with
ca-profile-mod command you need to send the entire profile in a
file. It would be nice to be able to specify some parameters to
change certain attributes only, or use separate commands to manage
the inputs/outputs.

We'll also need an interface to find existing cert records that use
a certain profile and bulk modify them to use a different profile.
This will be useful when you create a clone to change the system
profile.


Access control considerations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Currently, only *Administrators* can create, modify or delete
profiles.  No changes to this access control are proposed.

(*alee*) Dogtag uses its own system of acls, which are enforced on
the servlet level.  Creating/changing profiles are done through
servlets and access controls are enforced there.  This allows us to
do complex things like requiring agents to disable a profile before
an admin can edit it.

Users do not access the dogtag internal db directly.  Rather, the db
is only accessed via a special system user that performs operations
on behalf of the server.

In any case, this mechanism is not going to change.  We will keep
the same Dogtag servlet ACLs, so the behavior will be the same.


Command-line utilities
^^^^^^^^^^^^^^^^^^^^^^

Editing of file-based profiles has until now been a simple matter of
editing the file and restarting Dogtag so that profile changes take
effect.  With profiles now to be stored in LDAP, new mechanisms are
needed to edit profiles.


Edit profile
~~~~~~~~~~~~

The ``pki profile edit <profile-id>`` command will be added.
With due consideration for authentication and authorisation, the
behaviour of this command will be:

#. Retrieve the current profile content (in the existing key-value
   format used for file-based profiles, rather than LDIF, JSON or
   other.)

#. Save the content to a temporary file.

#. Invoke an editor on the file.  Respect the ``EDITOR`` environment
   if set, otherwise invoke ``vi(1)``.  The user makes changes,
   saves the file and quits the editor.

#. If changes were made to the profile, store the updated profile in
   the database (the change will be automatically replicated to
   clones).  If no changes were made, report that no changes to the
   profile were detected.

#. Remove the temporary file.


Other operations
~~~~~~~~~~~~~~~~

Other useful operations that could be implement as subcommands of
``pki profile`` include:

* Showing a diff between a profile and the system/default version of
  that profile (if it exists).

* Restoring a profile to the system/default version (if it exists).


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
significant, the correct order.


LDAP-based profiles only
~~~~~~~~~~~~~~~~~~~~~~~~

The ``ProfileSubsystem`` will need to be initialised such that it
has read/write access to the database.


File-based system profiles
~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``LDAPProfileSubsystem`` needs to have read/write access to the
database, and the main ``ProfileSubsystem`` needs to be able to
dispatch requests to both the ``LDAPProfileSubsystem`` and the
``FileProfileSubsystem`` as appropriate.


Cloning
-------

10.3 -> 10.3
  This proposal does not present any new concerns for cloning a 10.3
  database using Dogtag 10.3.

10.3 -> 10.2
  Cloning a 10.3 database using Dogtag 10.2 will be prohibited.

10.2 -> 10.3
  Cloning a 10.2 database with Dogtag 10.3 will be permitted.  The
  10.3 installation will include LDAP-based profiles.  Modifying
  (file-based) profiles on the 10.2 installation will have no effect
  on the 10.3 installation.  This is a continuation of the present
  behaviour with file-based profiles.  Upgrading the 10.2
  installation to 10.3 at a later time may result in conflicts.  A
  strategy for dealing with these conflicts needs to be determined.

(*edewata*) I'm not sure if we should support 10.2 -> 10.3 cloning.
When we release 10.3 the 10.2 will still be fairly new so it might
be reasonable to require all clones to be upgraded. It will reduce
the amount of testing requirement too.


Updates and Upgrades
--------------------

``CS.cfg`` may require updating, as explained above.

Users should be alerted (via release notes) of this feature, and
instructed to disable any custom mechanisms they may have in place
to replicate profile changes between clones.

Further detail on upgrade implications for the two main approaches
follows.


LDAP-based profiles only
^^^^^^^^^^^^^^^^^^^^^^^^

The 10.3 migration process must move all profiles into LDAP.
File-based profiles will be left on the filesystem for the time
being, but will no longer be used.

A database attribute will record whether a profile was user-defined
or user-modified.  Because updates to default profiles are rare,
this design proposal does not specify a mechanism for handling them.
Such changes should be managed on a case-by-case basis by migration
scripts, subject to the following:

* Migration scripts *must not* simply overwrite a modified version
  of a default profile.

* A migration script *should* inform the administrator performing
  the upgrade when a default profile could not be updated due to
  modifications.

* A migration script *may* implement a mechanism for merging changes
  to a default profile, provided the administrator is notified when
  this mechanism is invoked and copies of the content involved in
  the merge are made available for inspection.


File-based system profiles
^^^^^^^^^^^^^^^^^^^^^^^^^^

Upgrade scripts must detect added or modified profiles and move
these into the LDAP profile storage.

Added profiles will then be removed from the CA subsystem profiles
directory, and modified profiles will be restored to a pristine
state, which will ensure:

* updates to default profiles can always be written to the
  corresponding file-based profiles without conflict;

* a smooth changeover to a `System profiles`_ directory will be
  possible, if this proposal is implemented.


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
