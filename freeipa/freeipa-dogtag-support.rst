Profile issues
--------------

Symtoms
^^^^^^^

From IPA:

- ``Request failed with status 400: Non-2xx response from CA REST API:
  400.  Invalid profile data``

Procedure
^^^^^^^^^

- Get full profile configuration that is causing the issue.  Inspect
  it.

- Check all policysets mentioned in the ``list`` parameter
  have a corresponding ``default`` **and** ``constraint``
  components configured.


