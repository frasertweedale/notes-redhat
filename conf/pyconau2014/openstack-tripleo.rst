TripleO - What Why How.  Joseph Gordon (HP)
===========================================

Mission statement:

  Develop and maintain tooling and infrastructure able to deploy
  OpenStack in production, using OpenStack itself wherever possible.

Url: https://wiki.openstack.org/wiki/TripleO


Why
---

Do the cloud deployment job *once*.

  I heard you like cloud so I put a cloud in your cloud.


How
---

Note that this does not use and has nothing to do with nested
virtualisation.

*Seed cloud*:

- Minimal number of services.

- Pre-built; the idea is to walk into a datacentre with it on a USB
  stick.

- FKA "undercloud"

- Used to deploy the *deploy cloud*.

- Solves bootstrap issue: Heat needed to deploy other environments,
  but OpenStack needed to run Heat.

Deploy cloud:

- A few more services than seed cloud.
- A few more machines.
- Enables you do the rest of the deployment.
- Ironic provides Nova driver for deploying to bare metal.
- Deploy *workloud cloud*

Workload cloud:

- The is the "the cloud" i.e. what your customers want to access.


Benefits
--------

- Good security separation
- Well defined way to cold-boot datacentre


Architecture
------------

- UNIX philosophy; small pieces, loosely joined
- Mostly written in Python


Tools
-----

- used existing OpenStack tools where possible
- Uses Heat, Glance, Keystone etc
- Unique tools:
  - diskimage-builder: http://youtu.be/dnAjnMIXdUo
    - compile disk image ahead of time, put through testings.
    - that exact image goes out to every single node in datacentre.
    - called a *machine compiler*
  - ``os-*-config``
    - os-collect-config collects config from *places* and compiles
      them into a single JSON object that describes a machine.
    - os-apply-config takes the blob and applies it
    - os-refresh-config: a service to apply modifications to config.
      Run semi-regularly.
    - os-cloud-config
    - os-net-config
    - These tools not intended to be replacements for puppet or
      chef.  Designed to be specific to OpenStack needs; a minimal
      toolchain to get your cloud up and running.
  - Tuskar (being developed by Red Hat)
  - ``devtest(_.*|).sh``


Getting started
---------------

::

  $ sudo pip install tox
  $ git clone http://git.openstack.org/tripleo-incubator
  $ cd tripleo-incubator
  $ ./scripts/devtest.sh --trash-my-machine

- Read the "manual".  Sphinx documentation in most of the scripts.

Useful infrastructure:

- squid or other caching proxy
- apt-mirror/reposync
- devpi (or bandersnatch; cache PyPI)
- RAM.  Lots of RAM.
