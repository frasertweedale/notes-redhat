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


copr
----

*Cool Other Package Repositories*.

::

  sudo yum install -y dnf-plugins-core
  sudo dnf copr enable -y mkosek/freeipa
