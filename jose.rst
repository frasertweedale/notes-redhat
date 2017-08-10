Things wrong with JOSE:

- Use of JSON, esp. encoded protected header.  JSON within JSON.
  No canonical serialisation.  etc.

- The flattened serialisation special cases (more complex parsing,
  compat issues).

- The compact serialisation special cases (unprotected headers
  cannot be represented)

- Protected / unprotected header.  Makes proper parsing and ensuring
  only valid states are represented very difficult.

  - Keys allowed to occur in at most one header
  - Even more complex in JWE multi-recip scenario!

- JWE: "dir" and "ECDH-ES" are problematic in multiple-recipient
  scenarios.  More errors that must be specially checked to ensure
  an invalid JWE is not produced.  I don't even know why these
  exist because it is just one more step to wrap/unwrap a CEK.
