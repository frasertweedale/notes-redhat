..
  Copyright 2015 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


{{Feature|version=4.2.0|ticket=57|ticket2=4002|ticket3=2915|ticket4=4938}}


Overview
========

FreeIPA currently only supports host and service certificates and
has a single, hard-coded certificate profile.  This proposal
introduces the ability to define new certificate profiles for with
user principals as well as services and hosts.


Use Cases
=========

Custom extension values
-----------------------

The current certificate profile sets both TLS Server Authentication
and TLS Client Authentication in the *Extended Key Usage* extension.
This is not appropriate for most uses.  Profile support will allow
the appropriate profile(s) to be defined.

Furthermore, wherever there is a use case that requires specific
values in certificate fields or extensions, it will be possible to
import a profile that supports that use case as long as Dogtag
supports the certificate extension(s) to be included.


DNP3 SAv5
---------

The DNP3 Secure Authentication version 5 (SAv5) standard uses the
IEC 62351-8 certificate authentication to carry authorization data
for the DNP3 smart-grid technology.  A custom certificate profile
would be needed to use this.


Design
======

Profiles will be stored in Dogtag.  A small amount of metadata will
be stored in FreeIPA's directory to track these profiles, store
their current state (enabled, disabled) and mapping to groups that
are allowed to use the profile.

IPA must be modified to respect the profile parameter in requests
from Certmonger (currently ignored).

Rich profile management (use of a command-line tool or Web UI to
build new profiles for use with FreeIPA, rather than the presuppose
the existence of a profile) can be implemented on top of the basic
profiles support, if there is demand.  At a minimum, there should be
tutorials and improved documentation in Dogtag for how to define
certificate profiles.


Profile formats
---------------

There are two profile formats used by Dogtag: an XML representation,
and the "raw" property list format which is also (at the current
time) the internal storage format.  Initial work will focus on the
raw format, but it should be simple to distinguish between and
support both formats.


Listing profiles
----------------

The list of all Dogtag profiles is retrieved via the Dogtag REST
API::

  GET /ca/rest/profiles


Profile import
--------------

(This section is about importing new profiles individually.  For
initial import of profiles during installation or upgrade, see the
**Configuration** and **Upgrade** sections.)

New profiles can be imported via CLI (specify profile filename) or
Web UI (paste file content).  Interactive "profile builder"
functionality is a future feature (see Dogtag ticket `#1331`_.)

.. _#1331: https://fedorahosted.org/pki/ticket/1331

Having obtained the profile content, FreeIPA will import import the
profile into Dogtag using the Dogtag REST API::

  PUT /ca/rest/profiles/<profileId>       (XML format)
  PUT /ca/rest/profiles/<profileId>/raw   (raw format)

Failure modes:

- Profile ID already in use
- Bad profile content


Retrieve profile
----------------

Profile data can be retrieved from Dogtag using the REST API::

  GET /ca/rest/profiles/<profileId>       (XML format)
  GET /ca/rest/profiles/<profileId>/raw   (XML format)

The XML or property list (whatever is used) can be parsed to
determine name, enabled/disabled state, and other data.  It is not
an initial requirement that FreeIPA provide a detailed breakdown of
the profile (inputs, policy constraints and defaults, etc), but the
basic information should be available.

Failure modes:

- Profile ID unknown


Delete profile
--------------

Profiles can be deleted from Dogtag using the REST API::

  DELETE /ca/rest/profiles/<profileId>

Failure modes:

- Profile ID unknown
- Profile enabled (profiles must be disabled before deletion)

**FEEDBACK REQUIRED** If a profile is enabled and a FreeIPA admin
attempts to delete it should we disable then delete it, or fail?


Enable/disable profile
----------------------

Enabling or disabling a profile in Dogtag is accomplished via the
REST API::

  POST /ca/rest/profiles/<profileId>?action=enable
  POST /ca/rest/profiles/<profileId>?action=disable

Failure modes:

- Profile ID unknown
- Profile already enabled/disabled

It may be useful to record the enabled/disabled state of a profile
in the FreeIPA directory, so that the state is visible and decisions
can be made based on the profile state without requiring a
round-trip to Dogtag to find out and to avoid blind attempts of
operations that could fail according to profile enabled/disabled
state (e.g. profile deletion).


Searching for certificates by profile
-------------------------------------

**FEEDBACK REQUIRED**

Investigate options for exposing or finding out from Dogtag what
profile a certificate was issued under.  Investigate also search by
profile (not as important).

Alternatively, this could be tracked on the FreeIPA side.  The
profile ID that was used can be stored along with the issued
certificate.


Implementation
==============



Feature Management
==================

UI
--

Profile management UI
^^^^^^^^^^^^^^^^^^^^^

A grid UI shall be provided that lists profiles and their important
attributes (description, enabled/disabled status, etc).  Actions to
enable/disable a profile, delete a profile, or download a profile's
full content will be provided.

A profile import dialog will allow an administrator to paste profile
content and import it into Dogtag.


Certificate management UI
^^^^^^^^^^^^^^^^^^^^^^^^^

There are existing UI elements for requesting a certificate for, and
displaying the certificate issued to a service principal.  These
aspects of the UI must be enhanced to support multiple certificates.

For certificate requests, a drop-down list of profiles will be
suitable for selecting a profile.

For viewing certificates, a list of certificates should be
presented.  Each should identify the profile that was used to issue
that certificate, and perhaps other important information such as a
certificate fingerprint.  Upon selecting a certificate the existing
dialog showing the Base-64 encoded certificate and providing options
for renewal or revocation will be shown.


CLI
---

``ipa certprofile-import <profileId> <filename>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Add a profile to FreeIPA and Dogtag.  Profiles will be enabled by
default.

The ``ipa cert-request`` command has a filename argument (for the
CSR).  We could do what it does (although I am told it is a bit of a
hack).

``ipa certprofile-disable <profileId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Disable the profile.  FreeIPA will prevent certificate issuance
using the profile while it is disabled.

``ipa certprofile-enable <profileId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

(Re)enable the profile.

``ipa certprofile-del <profileId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Delete the profile.  Certificates issued using the profile will
still be hanging around, but if we store references to the profile
that was used to issue a certificate, those will become danging
references, and if we expose that information to users (e.g. via UI
or CLI) this case will have to be handled.


``ipa cert-request``
'''''''''''''''''''''

Modify command to add ``--profile <profileId>`` argument.


Configuration
-------------

There is no specific configuration in FreeIPA to enable profiles.
Profiles themselves may be enabled and disabled separately (and get
enabled automatically upon import).

Essential profiles (if any beyond the default set in Dogtag) will be
added and enabled on server installation.  Other "pre-canned"
profiles can be introduced by FreeIPA in the future, as required.


Upgrade
=======

The upgrade process ensure that essential and other "pre-canned"
profiles are installed and enabled.

Dogtag instances must be configured to use LDAP-based profiles, so
that they are replicated.  This involves setting
``subsystem.1.class=com.netscape.cmscore.profile.LDAPProfileSubsystem``
in Dogtag's ``CS.cfg`` and importing profiles.


Handling inconsistent profiles
------------------------------

**FEEDBACK REQUIRED**

File-based profiles could be (but should not be) inconsistent
between replica.

This might need to be a manual upgrade task in case of inconsistent
profiles between Dogtag instances in a replicated environment, or
because the administrator may have already enabled LDAP profile
replication in Dogtag.

Alternatively, we take a "first upgrade wins" approach - whichever
replica is upgraded first, its profiles are imported.  On other
replica, the presence of LDAP profiles is detected and no import is
performed.  This behaviour must be clearly explained and
administrators who have custom profiles encouraged to check for
inconsistencies prior to upgrade.


How to Test
===========

..
  Easy to follow instructions how to test the new feature. FreeIPA
  user needs to be able to follow the steps and demonstrate the new
  features.

  The chapter may be divided in sub-sections per [[#Use_Cases|Use
  Case]].


Test Plan
=========

..
  Test scenarios that will be transformed to test cases for FreeIPA
  [[V3/Integration_testing|Continuous Integration]] during
  implementation or review phase. This can be also link to
  [https://git.fedorahosted.org/cgit/freeipa.git/ source in cgit] with
  the test, if appropriate.


Dependencies
============

- Dogtag with LDAP profile replication enabled.


Author
======

Fraser Tweedale

Email
  ftweedal@redhat.com
IRC
  ftweedal
