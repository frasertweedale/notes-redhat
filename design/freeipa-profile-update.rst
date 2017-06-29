..
  Copyright 2017  Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.

{{Admon/important|Work in progress|This design is not complete yet.}}
{{Feature|version=4.6.0|ticket=5323|author=Ftweedal}}


Overview
========

FreeIPA includes a variety of certificate profiles for various use
cases.  The profile primarily consists of a Dogtag profile
configuration, and a small amount of FreeIPA-specific configuration.
Occasionally we need to update the Dogtag configuration for a
profile, typically to make use of new profile policy components in
Dogtag, to improve usable, increase the range of supported use
cases, and/or improve the compatibility of issued certificates with
server and client software.

FreeIPA configures Dogtag to use LDAP-based storage for profiles, so
that profile configuration changes made on one CA master are
automatically replicated to the other CA masters in the topology.

When updating a profile to use a profile component that is only
available from a particular version of Dogtag, we hit a problem.
Because FreeIPA can run in a mixed-version topology (i.e. different
replicas, including CA replicas, at different releases), updating a
profile to include a policy component only avaiabile in a newer
release of Dogtag potentially breaks certificate issuance on older
releases of Dogtag in the topology.  This is undesirable.

Until now, our approach has been to ship the updated profile to be
included in new installations, but to leave the profile unchanged on
existing deployments to avoid potential breakage.  This is also
undesirable, because it leaves the topology with a suboptimal
profile configuration, even when all CA masters in the topology are
at a version that could support the updated configuration.

The purpose of this design is to introduce a general, topology-aware
profile update mechanism that ensures that the latest version of a
profile that can be supported by the topology gets used, providing
safe, automatic profile updates.

Terminology
-----------

*included profile*
  A profile that is included with FreeIPA

*profile (configuration) template*
  The profile template that is shipped with FreeIPA, containing
  various installation-specific substitutions to be performed to
  produce a valid Dogtag profile configuration

*profile configuration*
  A complete Dogtag profile configuration.


Feature Management
==================

There is no user or administrator interaction involved in this
mechanism (modulo conflict resolution; see *Dealing with modified
profiles* below).

From a development perspective, updating a profile will involve the
following:

- If the updated profile configuration will require a higher minimum
  version of FreeIPA than the current profile configuration, copy
  the profile template to a new file, with the new
  ``ipa-lower-bound`` in the filename.

- Modify the profile configuration template, and increment the
  ``template-version``.

See *Profile template versioning* below for a discussion of these
requirements.


Design
======

Design at a glance
------------------

Each profile configuration shall now be accompanied by a version *of
that profile*.  FreeIPA ``certprofile`` objects shall be updated to
include the profile configuration version that is currently active.

Each profile configuration shall now also be accompanied by the
minimum version of FreeIPA that supports that profile.  Each profile
may have multiple configurations available, with different lower
bounds.

FreeIPA master entries shall be updated to include the version of
FreeIPA that the master is currently at.

During server upgrade, the highest version of the profile
configuration that is supported by all CA masters in the topology
shall be selected.  If the current version of that profile is lower
than the selected version, the profile shall be updated in Dogtag.


Profile template versioning
---------------------------

Each profile template shall have a version consisting of two parts.

The ``ipa-lower-bound`` part shall be the earliest version of
FreeIPA that supports that version of the profile template.  When a
profile template update requires a newer version of FreeIPA, a
**copy** of the profile template is made, and the
``ipa-lower-bound`` of that copy shall be the version of FreeIPA it
requires.  The older version of the profile template is kept.
An example ``ipa-lower-bound`` value is ``4.5.3``.

The ``template-version`` part shall be a non-negative integer.
Whenever a profile template is updated, whether or not it requires a
newer version of FreeIPA, the ``template-version`` is incremented.
If the profile does not require a newer version of FreeIPA, the
changes are performed in-place (i.e. no copy of the profile template
is made).

Filesystem storage
^^^^^^^^^^^^^^^^^^

Profile templates are currently stored as::

  /usr/share/ipa/profiles/<profile-name>.cfg

Now that we need to store multiple versions of a profile template,
we shall use the following schema::

  /usr/share/ipa/profiles/<profile-name>.<ipa-lower-bound>

Each template file shall contain a ``template-version`` directive
asserting the template version.


Schema changes
--------------

Certificate profile objects
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``ipaCertProfile`` object class shall be updated with a new
optional integer attribute for storing the version of the profile::

  # New attribute
  attributeTypes: ( 2.16.840.1.113730.3.8.21.1.9
    NAME 'ipaCertProfileVersion'
    DESC 'Profile version'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.27
    EQUALITY integerMatch
    ORDERING integerOrderingMatch
    SINGLE-VALUE
    X-ORIGIN 'IPA v4.6 Profile update mechanism' )

  objectClasses: ( 2.16.840.1.113730.3.8.21.2.1
    NAME 'ipaCertProfile' SUP top STRUCTURAL
    MUST ( cn $ description $ ipaCertProfileStoreIssued )
    MAY ipaCertProfileVersion
    X-ORIGIN 'IPA v4.2' )

The absense of the ``ipaCertProfile`` attribute value implies the
starting value of ``0``.


IPA master entries
^^^^^^^^^^^^^^^^^^

Information about IPA masters is stored in entries
``cn=$FQDN,cn=masters,cn=ipa,cn=etc,$SUFFIX``.  These entries shall
be updated to assert the version of FreeIPA currently installed on
that master.

**QUESTION** the master entries have auxiliary object classes
``ipaConfigObject`` and ``ipaSupportedDomainLevelConfig``.  Should
we...

1. Use ``ipaConfigString: ipa-version $VERSION`` to indicate the
   current IPA version of the master?

2. Add a new attribute to the ``ipaSupportedDomainLevelConfig`` to
   indicate the IPA version of the master?

3. Define a new auxiliary object class and an associated attribute
   for the purpose of indicating the IPA version of the master, and
   add this object class and attribute to master entries.

I lean towards 3, or 2.


Changes to ``ipa-server-upgrade``
---------------------------------

IPA version update
^^^^^^^^^^^^^^^^^^

The ``/usr/share/ipa/master-entry.ldif`` template shall be updated
to include the current IPA version information, according to the
*IPA master entries* schema changes outlined above.  The template
substitution dictionary shall be updated to include this datum.

This is small enhancement to the domain level bounds update already
performed by ``ipa-server-upgrade``.


Profile update
^^^^^^^^^^^^^^

*Note that the `IPA version update`_ must be performed before
profile updates.*

During upgrade, the right template for the topology must be chosen
and, if not the version currently in use, the profile must be
updated in Dogtag.

Find all CA masters in the topology (search base
``cn=masters,cn=ipa,cn=etc,$SUFFIX`` with filter ``(cn=CA)``).

For each CA master entry returned, query the IPA version of the
parent entry, according to the *IPA master entries* schema changes
outlined above.  Choose the lowest version (denoted the *target IPA
version*).

For each included profile, glob
``/usr/share/ipa/profiles/<profile-name>.*`` to find templates for
that profile.  Each template file is suffixed with the
``ipa-lower-bound``.  Eliminate templates with an
``ipa-lower-bound`` that exceeds the *target IPA version*.  Then
choose the template with the highest ``ipa-lower-bound`` (denoted
the *target template*).

Read the *target template* to discover its ``template-version``.
Read the LDAP ``certprofile`` object to discover its current
version.  If the ``template-version`` exceeds the current profile
version, format the template and update the profile.


Dealing with modified profiles
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``certprofile`` plugin currently allows included profiles to be
modified.  Admins may have modified the configurations of included
profiles (e.g. to change the validity period of issued
certificates).  The main question to answer here is:

**QUESTION**

  *Should we try to detect customisations and incorporate them in
  the updated profile configuration?*

Implications of **yes** to the question:

- More complexity and more data to retain so that we can detect user
  modifications and attempt to merge them into the new profile
  configuration.  For example, it may be necessary to retain *every*
  version of a profile that has been shipped, rather than just
  versions for each ``ipa-lower-bound``, so that diffs against the
  "pristine" version of the current profile version can be
  performed.  Essentially a 3-way diff must be performed.

- The possibility of merge conflicts, therefore the need of a
  conflict resolution process of some kind, possibly requiring the
  involvement of an admin, or explicit and clear reporting of the
  conflicts that were encountered and how they were resolved.

- The possibility of configuration choices made by admins resulting
  in invalid or otherwise problematic configurations or problematic
  issued certificates, even where there were not merge conflicts.

Implications of **no** to the question:

- Profile configuration customisations will be reverted, possibly
  resulting in changed profile behaviour that is is contrary to user
  expectations.

- Profile configurations should be backed up, so that admins can
  easily restore custom configurations (preferably as a separate
  profile).

- Release notes will have to prominently notify of this change and
  discuss its implications.

- The ``certprofile-mod`` command should be updated to prohibit
  future modification of included profile configurations.


Implementation
==============


Upgrade
=======


How to Use
==========

There is no user or administrator action required to use this
mechanism.


Test Plan
=========
