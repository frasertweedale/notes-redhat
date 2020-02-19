HSM MVP:

- CA signing key on HSM; all other keys on internal token
- Replica installation works (HOW?)
- LWCAs on internal token.
- KRA????
- integration/regression test using softhsm


Future work:

- more control over which keys live on which tokens
- HSM-based LWCAs (need to solve key replication)


Out of scope:

- Migrating existing deployment to/from HSM


Where do keys live?

- server cert: should live on internal token
- Audit signing key: can probably live on HSM (todo: check?)
- Subsystem: used for LDAP authn; should probably live on internal token
- OCSP: should probably live on internal token
- TODO kra
