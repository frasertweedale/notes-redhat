Repos
-----

To enable 'updates' and/or 'updates-testing' repos in kickstart, add
the following to the kickstart file::

  repo --name=updates
  repo --name=updates-testing

This "short" form is possible for repos that are *defined* but
*disabled*.  To add *unknown* repos, additional args are needed.
See https://github.com/rhinstaller/pykickstart/blob/master/docs/kickstart-docs.rst#repo.


Installer updates
-----------------

Sometimes there are bugs in the installer and updates are made
available.  The ``inst.updates`` kernel param can be used to point
to an update that will be downloaded and applied, e.g.::

  inst.updates=https://fedorapeople.org/groups/qa/updates/1277638.img
