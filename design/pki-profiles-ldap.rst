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

This feature is slated for version **10.3**, or possibly a future
**10.2.x** release.


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

There is an RFE for `Shared CA Enrollment Profiles`_, i.e., shared
across instances.  The design should be mindful of this RFE.

.. _Shared CA Enrollment Profiles: https://fedorahosted.org/pki/ticket/1067


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

Precis
^^^^^^

The essence of the design, as explained by *alee* is:

1. Continue to distribute the system profiles in flat files.  These
   files will be read and stored in LDAP when an instance is
   created.

2. All profiles for an instance should live in LDAP.  This makes it
   simple - no need to check to see if a profile is in LDAP or files
   or both, and which has priority etc.  Tools will be provided to
   manage/create/delete profiles etc.

3. Updates to system profile files will not affect the existing LDAP
   profiles.  We can provide update scripts or manual instructions
   for admins to run when they opt to do so.  This will be for
   behavioral changes.  If IPA has changes to their profiles, they
   can apply through the ldap update mechanisms they have in place.

4. Structural changes will be done using upgrade scripts using the
   database upgrade mechanism.  This framework is something that we
   had planned to do already in 10.3.  We already have a model on
   how to do this in our current upgrade framework.


Profile scope
^^^^^^^^^^^^^

Because profiles are currently stored as configuration for a
particular CA subsystem, it follows that LDAP profiles will be
stored as attributes of a particular CA or sub-CA subsystem.  This
will be simpler to implement and ensure that deployments prior to,
or not using the `Top-level Tree`_ capability can take advantage of
LDAP profile storage.


LDAP schema
^^^^^^^^^^^

The existing profile registry stores the path to the profile
configuration file and a reference to the enrollment implementation.
For LDAP profiles, the data that would be stored in the profile
configuration file will be stored according to the following schema,
which will be defined in ``schema.ldif``.

The ``certProfile`` terminology is used where possible to
disambiguate certificate profiles from TPS token profiles.

The ``classId`` attribute is a *Directory String* that stores the
the enrollment class identifier::

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( classId-oid
    NAME 'classId'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    X-ORIGIN 'user defined' )

The ``certProfileConfig`` attribute is an *Octet String* that stores
the profile configuration (the same format as is currently stored in
files)::

  dn: cn=schema
  changetype: modify
  add: attributeTypes
  attributeTypes: ( certProfileConfig-oid
    NAME 'certProfileConfig'
    DESC 'CMS defined attribute'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.40
    X-ORIGIN 'user defined' )

The ``certProfile`` object class defines the complete profile
record::

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

  dn: ou=certificateProfiles,ou=ca,{rootSuffix}
  objectClass: top
  objectClass: organizationalUnit
  ou: certificateProfiles

According to the above schema, LDAP-based profile records will look
like::

  dn: cn=<certProfileId>,ou=certificateProfiles,ou=ca,{rootSuffix}
  objectClass: top
  objectClass: certProfile
  cn: <certProfileId>
  classId: <classId>
  certProfileConfig: <octet string>


ProfileSubsystem
^^^^^^^^^^^^^^^^

The ``ProfileSubsystem`` will be changed to use the LDAP database as
its data store instead of the filesystem.  This should require no
significant changes to its public API.


Keeping profiles up to date
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Currently, profiles are read at startup. This means that we need
some mechanism to trigger the refreshing of the profiles (without
restart) when changes made on other clones are replicated to the
local database.

A *persistent LDAP search* will be executed in its own thread to
monitor for changes that occur beneath the ``certificateProfiles``
OU and update the ``ProfileSubsystem`` accordingly.  The entire
implementation is contained within the ``ProfileSubsystem`` class.
Specifically, the presistent query is executed by the ``run`` method
of the ``Monitor`` inner class, which extends ``Thread``.


API changes
^^^^^^^^^^^

The REST API should not require any significant changes.  Any
changes that are required should be reflected in the Python API.


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

The ``--raw`` flag will be added to the existing CLI commands
(``ca-profile-show``, ``ca-profile-add`` and ``ca-profile-mod``) for
working with profiles in the "raw" format, rather than the XML
format.


ca-profile-edit
~~~~~~~~~~~~~~~

The ``pki ca-profile-edit <profile-id>`` command will be added.
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


Other commands
~~~~~~~~~~~~~~

Other useful operations that could be implement as subcommands of
``pki ca-profile`` include:

* Showing a diff between a profile and the system/default version of
  that profile (if it exists).

* Creating a copy of a profile, under a different name (most likely
  for subsequent editing.)


Other considerations
~~~~~~~~~~~~~~~~~~~~

Updates to profiles via the CLI tool shall not require a restart of
the ``pki-tomcatd`` service.

Existing access controls shall remain.  That is:

* Update of an existing profile - agent disables the profile; admin
  then is allowed to update; agent reviews the profile and enables
  it.

* Adding a new profile - admin creates the profile; agent approves
  it.


Implementation
--------------

.. Any additional requirements or changes discovered during the
   implementation phase.

.. Include any rejected design information in the History section.

The implementation will be done in stages.  Additional requirements
or changes discovered during the implementation process will be
detailed for each stage of the implementation.  Patches will roughly
correspond with each stage.

#. Implement the LDAP schema.

#.  Update ``ProfileSubsystem`` to use the LDAP database instead of
    files.

    The ``LDAPConfigStore`` class was added.  It implements
    ``IConfigStore`` but since none of the profile code uses the
    ``backup`` feature, the ``commit`` method ignores this argument.
    The method is documented to explain this, and recommends an
    approach to implement backup should it be needed in the future.

#.  Implement script(s) for importing file-based profiles into the
    database.

    The import procedure is implemented as part of the
    ``CAInstallerServer`` process.

    The main issue encountered was that the ``ProfileSubsystem``,
    after being modified to talk to the database, cannot start up
    until the database connection is configured.  This was resolved
    by adding support for disabling dynamic subsystems in
    ``CS.cfg``, as well as the methods ``CMS.enableSubsystem(String
    id)`` and ``CMS.disableSubsystem(String id)``.  The profile
    subsystem is initially disable, but is enabled during the spawn
    process as soon as database configuration is completed.

#.  Add the ``--raw`` flag to existing CLI commands for working with
    the "raw" profile config format, and implement the
    ``pki ca-profile-edit`` CLI command.

    The ``ProfileResource`` REST API required a few new methods for
    working with the "raw" (i.e. ConfigStore) profile format, as a
    ``byte[]``, instead of the default XML/JSON profile transport
    format.  The new methods are:

    - ``createProfileRaw``
    - ``modifyProfileRaw``
    - ``retrieveProfileRaw``

    The ``ProfileClient`` API works with ``Properties`` objects
    instead of the raw ``byte[]`` objects, to make things more
    "developer-friendly".  A caveat of this decision is that
    ``Properties`` keys are not ordered.  Users of the
    ``ProfileClient`` API must therefore sort keys themselves if they
    wish to present sorted profile config properties to end users.


#.  Implement profile change replication monitoring and refresh
    mechanism.

    Some methods of the ``ProfileSubsystem`` were made
    ``synchronized`` in order to safely handle updates from the LDAP
    persistent search thread that monitors for updates to profiles.

    The LDAP persistent search implementation is entirely
    encapsulated within ``ProfileSubsystem`` and cannot be access or
    controlled by the user.

    One LDAP connection is held at all times by the persistent search
    thread.

#.  Implement upgrade scripts for initial import of file-based
    profiles into the database (using the script(s) from earlier).

    This is expected to use the upcoming database upgrade framework.

#. Update documentation and guides.


Major configuration options and enablement
------------------------------------------

.. Any configuration options? Any commands to enable/disable the
   feature or turn on/off its parts?

The ``ProfileSubsystem`` will need to be initialised such that it
has read/write access to the database.

Parts of ``CS.cfg`` and the registry will become obsolete, and can
be removed.

There remains the possibility that users will decide whether to use
LDAP profiles or file-based profiles.  If this is allowed,
corresponding configuration options and (most likely) ``pkispawn``
options will need to be added.


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

The 10.3 migration process must move all profiles into LDAP.
File-based profiles will be left on the filesystem for the time
being, but will no longer be used.

A database attribute will record whether a profile was user-defined
or user-modified, for use by update scripts.

Because behavioral changes to default profiles are rare, this design
proposal does not specify a mechanism for handling them.  Such
changes should be managed on a case-by-case basis by **optional**
update scripts (i.e., not run automatically, but at the
administrator's discretion).  Accompanying release notes should
explain the behavoiural changes and detail the process for applying
the changes.


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


Rejected and deferred proposals
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hybrid file-based and LDAP profiles (rejected)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

One of the two initially-proposed solutions was a hybrid LDAP/files
solution, where system profiles continued to be stored on the
filesystem, but modifications could be stored in LDAP, and all
custom profiles would be stored in LDAP:

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

The main motivation for this proposed solution was to simplify
application of updates to default profiles:

  When upgrading to LDAP-based profiles, upgrade scripts must detect
  added or modified profiles and move these into the LDAP profile
  storage.  Added profiles will then be removed from the CA
  subsystem profiles directory, and modified profiles will be
  restored to a pristine state, which will ensure:

  * updates to default profiles can always be written to the
    corresponding file-based profiles without conflict;

  * a smooth changeover to a `System profiles`_ directory will be
    possible, if this proposal is implemented.

*alee* had reservations:

  I understand why you have profiles in both LDAP and file format.
  However, I think this makes things complicated. My preference
  would be to have all new systems maintain their profiles solely in
  LDAP, rather than some admixture.

  There is a precedent for moving data that was formerly in files to
  ldap - and that was the data in the security domain. Originally,
  this data was in files. At some point, we changed the servlets that
  update the security domain to use LDAP instead, and used a parameter
  in CS.cfg to determine whether the data was in LDAP or files.

*edewata* proposed a variation where *only* custom profiles would be
stored in LDAP, and default profiles would continue to be managed on
the filesystem, as they currently are.

  I think all system/default profiles should remain file-based and
  all custom profiles should be LDAP-based. It will make a clean
  separation: system profiles are owned by us (Dogtag developers),
  custom profiles are owned by the admin.

  I think all system/default profiles should remain file-based and
  all custom profiles should be LDAP-based. It will make a clean
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
  "restore" command. In general we won't need to write upgrade
  scripts for custom profiles except if we change the LDAP schema.

One significant point in favour of *edewata*'s variation is that
administrators can continue to manage profiles in the way they are
used to, i.e. editing them directly.  The ``pki ca-profile-edit``
CLI is deemed to be a sufficient mitigation.

Due to the rejection of automatic updates to default profiles (see
below), which was the primary motivation for the files/LDAP hybrid
solution, and in consideration of the increased complexity, the
hybrid solution was rejected.


Automatic updates to default profiles (rejected)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The original proposal for LDAP-only profiles was to automatically
effect behavioural changes to default profiles as part of the
upgrade process:

  There is currently a 10.3 ticket to create a `database upgrade
  framework`_. Once this framework is in place, it can be used to
  perform a migration from files to LDAP, as well as modify default
  profiles when the default profile is being used.

This was rejected, although tools will still be provided for an
administrator to perform the update at their discretion.  *alee*
explains:

  There is another problem, and that is that it is not clear that we
  want updates to the default profiles to be propagated to existing
  instances.  I have looked at the profiles and there have been only
  a handful of changes over the last 7 years.  Those changes include
  things like updating the default signing algorithms or the default
  validity.  More likely than not, admins would prefer that we not
  change the behavior of profiles in existing instances underneath
  them.

  The changes that I have found are all behavioral - and therefore
  things that admin can opt out of -- or would prefer to do on their
  own schedule.  There have been no structural changes.

  If there are structural changes, then we need to (and can) provide
  an upgrade script which would run with the automatic upgrade.  An
  example of this would be a schema upgrade as we sort out how to
  represent profiles in LDAP.


Fine-grained LDAP profile storage (deferred)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*edewata* proposed a fine-grained storage of profile data, instead
of simply storing the current profile data as a single bytestring
(in the same way that all the profile data is currently stored in a
single file):

  I suppose we want to have something that resembles the actual
  Profile data structure (see ``ProfileData`` Java class).  There
  should be an LDAP attribute for each single-valued Java attribute
  (e.g. name, description, enabled, visible). This way the profile
  is more manageable and can be queried based on these attributes.
  For collection attributes (e.g. inputs, outputs, policySets) we
  can use child LDAP entries to represent them.

  About the REST interface & CLI, since this will be the primary way
  to edit profiles, we might want to have more granular commands to
  modify parts of the profile. Right now with ca-profile-mod command
  you need to send the entire profile in a file. It would be nice to
  be able to specify some parameters to change certain attributes
  only, or use separate commands to manage the inputs/outputs.

  We'll also need an interface to find existing cert records that
  use a certain profile and bulk modify them to use a different
  profile.  This will be useful when you create a clone to change
  the system profile.

There are obvious benefits to this proposal but it is more work (the
existing machinery for reading and modifying file-based profiles
would no longer be useful for LDAP profiles), and not necessary to
maintain the current behaviour and meet the basic goals concerning
replication.  It is therefore deferred.


Profile inheritance (deferred)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*edewata* proposed a mechanism whereby profiles can inherit from
other profiles:

  Basically each LDAP profile will have an optional parent. The
  parent can be the file-based system/default profile, or another
  LDAP profile. A sub-profile will inherit all attributes, except
  when it's explicitly declared in the sub-profile. This mechanism
  allows us to create just a proxy/alias, a full clone, or anything
  in between. For example, a proxy profile might only have a few
  attributes::

    dn: cn=caAdminCert,ou=Profiles,ou=CA,{suffix}
    objectClass: certProfile
    cn: caAdminCert
    parent: defaultAdminCert
    visible: true

This proposal was deemed to be out of scope with respect to current
requirements but fundamentally compatible with this proposal, and
was therefore deferred.


Troubleshooting
===============

LDAP-based profiles mean that there are more moving parts and
different kinds of errors are possible.  This section is designed to
help you troubleshoot issues that may be related to the LDAP
profiles subsystem.

Which profile subsystem is used by default?
-------------------------------------------

By default, PKI is configured to use the ``ProfileSubsystem`` class
which uses file-backed profiles.

When deployed as part of FreeIPA, since FreeIPA 4.2 (RHEL 7.2) the
``LDAPProfileSubsystem`` class is used.  The FreeIPA 4.2 upgrade
process switches deployed CA instances over the
``LDAPProfileSubsystem`` and imports profiles into the database.
There were a couple of bugs in the upgrade/migration procedure that
could result in missing profiles:

- https://bugzilla.redhat.com/show_bug.cgi?id=1284803
- https://bugzilla.redhat.com/show_bug.cgi?id=1300252


Identifying the profile subsystem currently in use
--------------------------------------------------

Execute::

  % grep subsystem.1.class /var/lib/pki/pki-tomcat/ca/conf/CS.cfg

The output indicates the subsystem in use, e.g.::

  subsystem.1.class=com.netscape.cmscore.profile.LDAPProfileSubsystem


Listing which profiles are present in the database
--------------------------------------------------

To see which profiles are present in the database, execute::

  % ldapsearch -D "cn=Directory Manager" -w $DM_PASSWORD \
    -b "ou=certificateProfiles,ou=ca,$BASEDN" -s one cn

(Replace ``$DM_PASSWORD`` and ``$BASEDN`` with the appropriate
values.  When deployed with FreeIPA, the base DN is ``o=ipaca``.)

If the ``LDAPProfileSubsystem`` is being used, the output should
show ~60 profiles.

If the output is::

  # extended LDIF
  #
  # LDAPv3
  # base <ou=certificateProfiles,ou=ca,o=ipaca> with scope oneLevel
  # filter: (objectclass=*)
  # requesting: cn 
  #

  # search result
  search: 2
  result: 32 No such object
  matchedDN: ou=ca,o=ipaca

  # numResponses: 1

Then the ``ou=certificateProfiles,...`` container is missing.

If the output is::

  # extended LDIF
  #
  # LDAPv3
  # base <ou=certificateProfiles,ou=ca,o=ipaca> with scope oneLevel
  # filter: (objectclass=*)
  # requesting: cn 
  #

  # search result
  search: 2
  result: 0 Success

  # numResponses: 1

Then there are no profile entries present at the correct location in
the database.


Triggering LDAP profile import with FreeIPA
-------------------------------------------

Prior to the fix for `bz1300252`_ being released, you can trigger
the migration of profiles into LDAP to be attempted again.

.. _bz1300252: https://bugzilla.redhat.com/show_bug.cgi?id=1300252

Edit ``/var/lib/pki/pki-tomcat/ca/conf/CS.cfg`` and replace the
line::

    subsystem.1.class=com.netscape.cmscore.profile.LDAPProfileSubsystem

with::

    subsystem.1.class=com.netscape.cmscore.profile.ProfileSubsystem

Then execute `ipa-server-upgrade`.  The upgrade program should
observe that LDAP-based profiles are not enabled, re-enable the
LDAPProfileSubsystem and migrate all file-based profiles into the
database.
