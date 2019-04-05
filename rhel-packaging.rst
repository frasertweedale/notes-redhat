Resources
=========

Fedora resources:

- https://fedoraproject.org/wiki/Using_Mock_to_test_package_builds

RHEL-8-friendly RCM builds for RHEL 7::

  [koji-rhel-8-rpms-noarch]
  baseurl = http://yum.engineering.redhat.com/pub/yum/redhat/koji-rhel8/$releasever/noarch
  enabled = 1
  exclude = kernel* perf* python-perf*
  gpgcheck = 1
  gpgkey = http://yum.engineering.redhat.com/pub/RPM-GPG-KEY-redhatengsystems
  name = Koji packages for RHEL8 compose - noarch

  [koji-rhel-8-rpms]
  baseurl = http://yum.engineering.redhat.com/pub/yum/redhat/koji-rhel8/$releasever/$basearch
  enabled = 1
  exclude = kernel* perf* python-perf*
  gpgcheck = 1
  gpgkey = http://yum.engineering.redhat.com/pub/RPM-GPG-KEY-redhatengsystems
  name = Koji packages for RHEL8 compose - $basearch

Also needed ``dnf-plugin-builddep`` on the build host.

Generate a ``mock`` config (fresh one each day)::

  brew mock-config --target rhel-8.0-candidate --arch x86_64 > mock.cfg

Update ``mock.cfg`` to use ``dnf`` instead of ``yum``::

  config_opts['package_manager'] = 'dnf'

User needs to be in ``mock`` group (or ``root``).


In the choot
------------

Get into chroot (absolute patch is needed for some reason)::

  /usr/bin/mock -r mock.cfg --shell

Copy file into chroot::

  [root@vm-150 rhel-8.0]# /usr/bin/mock -r mock.cfg \
    --copyin /tmp/resteasy-jaxrs-all-3.5.1.Final-redhat-1-project-sources.tar.gz /tmp
  INFO: mock.py version 1.3.4 starting (python version = 2.7.5)...
  Start: init plugins
  INFO: selinux enabled
  Finish: init plugins
  Start: run
  Start: chroot init
  INFO: calling preinit hooks
  INFO: enabled HW Info plugin
  Mock Version: 1.3.4
  INFO: Mock Version: 1.3.4
  Finish: chroot init
  INFO: copying /tmp/resteasy-jaxrs-all-3.5.1.Final-redhat-1-project-sources.tar.gz to /var/lib/mock/rhel-8.0-build-repo_2625155/root/tmp
  Finish: run

Install a package in the chroot::

  [root@vm-150 rhel-8.0]# /usr/bin/mock -r mock.cfg --install vim-minimal
  INFO: mock.py version 1.3.4 starting (python version = 2.7.5)...
  Start: init plugins
  INFO: selinux enabled
  Finish: init plugins
  Start: run
  Start: chroot init
  INFO: calling preinit hooks
  INFO: enabled HW Info plugin
  Mock Version: 1.3.4
  INFO: Mock Version: 1.3.4
  Finish: chroot init
  INFO: installing package(s): vim-minimal
  Last metadata expiration check: 0:00:00 ago on Wed 11 Jul 2018 04:07:54 PM CEST.
  Dependencies resolved.
  =================================================================================================================================================================================
   Package                                    Arch                                  Version                                             Repository                            Size
  =================================================================================================================================================================================
  Installing:
   vim-minimal                                x86_64                                2:8.0.1763-4.el8+7                                  build                                571 k

  Transaction Summary
  =================================================================================================================================================================================
  Install  1 Package

  Total download size: 571 k
  Installed size: 1.2 M
  Downloading Packages:
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total                                                                                                                                            235 kB/s | 571 kB     00:02     
  Running transaction check
  Transaction check succeeded.
  Running transaction test
  Transaction test succeeded.
  Running transaction

  Installed:
    vim-minimal.x86_64 2:8.0.1763-4.el8+7

  Complete!
  INFO: 
  Finish: run



Packaging resteasy
==================

Build VM:  ``%ssh root@vm-150.abc.idm.lab.eng.brq.redhat.com``


Dependencies
============

Unused dependencies of *jackson* (not *jackson2*):

- jackson
  - joda-time (removed)
  - objectweb-asm3 (removed)

- jsr-311 (previously required by jackson-module-jaxb-annotations)
- jcip-annotations (previously required by resteasy)

- woodstox-core (previously required by xmlstreambuffer)
  - stax2-api

- jboss-servlet-2.5-api
  - jboss-specs-parent

- jboss-jsp-2.2-api
  - requires jboss-servlet-3.0-api
  - requires jboss-el-2.2-api

- jboss-servlet-3.1-api


stuff to move to stream-pki-10.6 (ticket
https://projects.engineering.redhat.com/browse/RCM-38875)

- xmlstreambuffer
- stax-ex
- glassfish-fastinfoset


possible removals
-----------------

- relaxngcc (CANNOT REMOVE)
  - xsom
    - glassfish-fastinfoset (patch)
    - glassfish-jaxb (PATCHED*)

- shrinkwrap
  - jboss-modules
    - byteman
    - jboss-logmanager
      - jboss-logging
        - resteasy (probably can't avoid this one)

- codemodel
  - istack-commons
    - glassfish-jaxb


possible extraction to module-only
----------------------------------

- (glassfish-fastinfoset)
  - xsom
    - relaxngcc

- (resteasy)
  - jboss-logging-tools
    - jdeparser
    - jboss-logmanager
    - jboss-logging
  - jboss-annotations-1.2-api


broken packages
---------------

- msv (missing; requires isorelax)
- relaxngcc (requires msv)
- xsom (requires relaxngcc)


tickets
-------

- https://bugzilla.redhat.com/show_bug.cgi?id=1613113 DONE jackson
- https://bugzilla.redhat.com/show_bug.cgi?id=1613116 DONE jsr-311
- https://bugzilla.redhat.com/show_bug.cgi?id=1613119 DONE stax2-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613120 DONE jboss-servlet-2.5-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613121 DONE jboss-servlet-3.0-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613122 DONE jboss-servlet-3.1-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613145 DONE jboss-specs-parent
- https://bugzilla.redhat.com/show_bug.cgi?id=1613148 DONE jboss-jsp-2.2-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613159 DONE woodstox-core
- https://bugzilla.redhat.com/show_bug.cgi?id=1613209 DONE jcip-annotations
- https://bugzilla.redhat.com/show_bug.cgi?id=1613226 DONE jboss-el-2.2-api
- https://bugzilla.redhat.com/show_bug.cgi?id=1613579 DONE glassfish-dtd-parser
- TODO msv

- move to module-only requests
  - DONE stax-ex
  - DONE xmlstreambuffer
  - DONE glassfish-fastinfoset
  - DONE glassfish-jaxb
  - DONE resteasy
