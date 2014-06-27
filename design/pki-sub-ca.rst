Dogtag sub-CA subsystems
========================

Overview
--------

Dogtag supports operation as a sub-CA, but only as a separate
instance.  This document proposes *lightweight sub-CAs*, where one
more more sub-CAs subsystems can run in a single instance, alongside
other subsystems including the parent CA.

This feature is aimed for inclusion in Dogtag 10.3, to be included
in Fedora 21.


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
sought.


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
searches (say, for all the certs issued by a sub-CA).


Creating sub-CAs
~~~~~~~~~~~~~~~~

Creation of sub-CAs at any time after the initial spawning of an
instance is a requirement.

We will provide an API for creating a sub-CA.  This could be part of
the CA webapp's API, or the ROOT webapp.  Preferably, restart would
not be necessary, however, if necessary, it must be able to be
performed without manual intervention.

A REST servlet will be implemented that would generate the new
sub-CA signing certificate based on relevant inputs, including the
user-defined identifier of the CA/sub-CA that needs to issue the
certificate.  This will allow nested sub-CA's (**not a
requirement**).  The servlet would also register the new sub-CA
identifier in the CA subsystem's database (or subtree) so that it
can be replicated, and instantiate a ``SigningUnit`` class for that
sub-CA.  That would allow creation of the sub-CA facility without
requiring a restart.


HTTP interface
~~~~~~~~~~~~~~

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

All profiles available available in the "host" CA subsystem would be
available for use by the sub-CA.


LDAP schema
~~~~~~~~~~~

Yet to be designed.


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
