OpenStack Keystone Federated Identity
=====================================


Keystone: authentication, authorization and service discover.

token flow:

- user submits pwd to keystone and gets back token valid for nova,
  glance, etc.
- user/pass xmitted one only, to keystone
- token is short lived (~1hr); lower risk if intercepted

- distinction between authorization and authentication elaborated

- with keystone, auth ideally managed by a separate identity store,
  and keystone manages authorization


- federation = ability to use someone's externally managed identity
  within keystone.

- why: convenience, integration (enterprise, partnerships),
  migration and interop (mult clouds, single ident), security (one
  less idp)

- want to get away from keystone as an identity provider (but hard
  to get away from this - will take several cycles)

- keystone will be a *service provider*, issuing tokens.
  performance boost (running behind apache; identity validation
  offloaded to battle-tested apache modules)

- to get there, a couple of competing standards.
  - OpenID Connect
  - AbFab
  - SAML (common in enterprise); XML based; out of OASIS

- SAML xmits authentication and authorization data.  i.e. who user
  is, and all *roles* the IdP knows about the user, bundle up in an
  *assertion*

- mod_mellon will populate app environment with lots of variables
  incl uid and roles.

- mappings convert IdP assertions to OpenStack roles.
  - different roles mean different things on different IdPs.
  - *same* roles can mean different things for different IdPs.
  - mapping table is per-idp per-protocol
  - mapping definition is json object
    - "remote" part of a mapping entry *matches* assertion
    - "local" part assigns matching entries into a group
  - REST CRUD

- Status
  - It works.
  - Only SAML2 ECP (Enhanced Client or Proxy; a profile of SAML)
    - non-interactive; not that useful for us
  - Client side is in review

- Future
  - Anything you can map
    - mod_auth_openid (OpenID Connect; higher prio)
    - mod_identity_lookup (SSSD/FreeIPA)
    - AbFab (relatively new; fairly important to some EU
      universities)
  - You could even...
    - mod_auth_kerb
    - mod_auth_digest
  - Keystone -> Keystone.  E.g. private cloud token being accepted
    by a public cloud to offload some workloud.
    - Roles in one keystone mapping into roles in another
      keystone.

- Contributors
  - CERN and U Kent did most of design.  CERN are trying to put into
    production as quick as possible.
  - Also Red Hat, IBM, Rackspace et al.
