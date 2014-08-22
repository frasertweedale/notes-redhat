pbr and semver - Robert Collins
===============================

aka Python Build Reasonableness and Semantic Versioning


Setuptools
----------

- openstack has fairly simple code but complex environments.
  identical infrastructure code across many projects. maint
  nightmare.

- Refactor!
  - New project
  - Setuptools plugin


PBR
===

- consistent setuptools integration glue for all OpenStack projects.
- Depends on git and a recent pip for installation support.

Testing
-------

- testr
  - ``python setup.py test``

Git integration
---------------

- hard requirement
- automatically picks up all versions, builds changelog, etc.

PyPI Integration
----------------

- Generates a rich summary from README.rst + changelog

Documentation
--------------

- sphinx API glue
- sphinx manpage generation

pip
---

- pulls requirements from ``requirements*.txt``

Versioning
----------

- generates pre-release version numbers for you from tags and or
  config settings


Semantic versioning
===================

- simple and clear set of rules for versioning software to clearly
  indicate compatibility interaction
- adopted a couple years ago in OpenStack
- it didn't quite work, so OpenStack adopted a fork of semver.

There are still some problems.

- getting a release wrong is not hard, because there's not a lot you
  have to do to make it happen (tag and push).

Binary packaging
----------------

- everyone reinvents the same integration and version translation
  glue *differently*

pbr-semver
----------

- a spec, approved in Oslo.  New, shiny, magic.
- Will enforce PEP 440 compatible version numbers.
- epic fail on existing version

- pragmata in commit messages will *update version number* in
  appropriate ways, e.g. *feature*, *bugfix*, *api-break*.
- you no longer need to think about what version you release.
  Just ``python setup.py tag-release``

To use:

- four lines in ``setup.py``
- ``setup.cfg`` as well
