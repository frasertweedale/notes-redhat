Framework notes
---------------

- ``virtual_attribute`` flag only works for *options*, not
  positional arguments.

- LDAP ``post`` callbacks must return ``dn``.


Updating config templates
-------------------------

Do not forget to update the ``VERSION`` line.  ``ipa-upgradeconfig``
will then pick it up and format and deploy the new template.
This bit me when updating ``ipa-pki-proxy.conf``.


Updating API
------------

Remember to bump the API version number and comment in ``VERSION``
if a commit changes ``API.txt``.
