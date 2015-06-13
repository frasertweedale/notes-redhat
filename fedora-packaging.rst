Tools
=====

yum
---

Add a repo::

  sudo cp example.repo /etc/yum.repos.d/

To erase packages machine some pattern::

  yum list installed |grep GIT | cut -d ' ' -f 1 | xargs sudo yum erase -y

Prevent update of a package::

  $ yum install -y yum-plugin-versionlock
  $ echo tomcat-7.0.54-3.fc21.noarch \
    >> /etc/yum/pluginconf.d/versionlock.list

(The full package name is required; use `rpm -qa` to find it.)


dnf
---

To downgrade a package as well as dependents, use the
``--allowerasing`` to appease the solver.  flag.  For example, the
following will downgrade ``pki-base`` as well as dependents::

  $ sudo dnf downgrade --allowerasing pki-base-10.2.3-2.fc22


Building RPMs
-------------

Nalin Dahyabhai writes;

  You'll want to install fedpkg (which essentially works like rhpkg,
  which "knows" about the internal repository that we use for RHEL),
  and use its 'sources' command to pull them down from the lookaside
  caches, or its 'compile' command to do that and the equivalent of
  an 'rpmbuild -bc' in the checked out directory.  Some of fedpkg's
  commands are just thin wrappers around git commands (I have no use
  for its 'switch-branch' command, for example), but it does have
  its uses.


Koji_ is the RPM build system used by Fedora.

.. _Koji: https://fedoraproject.org/wiki/Koji


For a directory with a spec file, ``fedpkg`` knows where to find
source tarballs and provides commands for building the software and
compile the RPM(s) locally.  ``fedpkg local`` will build the RPM,
and ``fedpkg install`` will install a locally-built RPM.


COPR
====

*Cool Other Package Repositories*.

Enabling a COPR
---------------

::

  sudo yum install -y dnf-plugins-core
  sudo dnf copr enable -y mkosek/freeipa

Setting up a COPR
-----------------

To build packages, upload the SRPM(s) somewhere, go to **New Build**,
paste the package URL(s) and **Build**.

To enable the updates-testing repo for builds, add to the
repository list::

  ``http://download.fedoraproject.org/pub/fedora/linux/updates/testing/$releasever/$basearch/``


Becoming a Fedora packager
==========================

- packaging workshop

- writing specfile
  - https://fedoraproject.org/wiki/Packaging:Guidelines

- submitting to bugzilla
  - https://fedoraproject.org/wiki/Package_Review_Process

- get a sponsor
  - https://fedoraproject.org/wiki/How_to_get_sponsored_into_the_packager_group

- reviewing packages
  - find packages to review and review them?
