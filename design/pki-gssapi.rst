..
  Copyright 2016, 2017  Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.

GSS-API authentication for Dogtag
=================================

This document outlines a design for GSS-API / SPNEGO authentication of
external identities to Dogtag and handling authorisation for those
principals.

Problem Description
-------------------

When Dogtag is running in a Kerberised environment it is desirable to
support GSS-API (Kerberos mechanism) authentication.

Additionally, it is desirable to be able to support external identities,
i.e. identities that are defined not in Dogtag's own database but in an
external identity store, avoiding identity silos and reducing
administrative overhead.  A mechanism of mapping external groups/roles
to Dogtag roles is required, or alternatively, conditional substitution
of Dogtag's built in ACL evaluator for an alternative access evaluator
that can evaluate an authenticated principal's authorisation to perform
Dogtag operations using data or facilities provided by the external
identity store.

Dogtag provides an HTTP interface, so `SPNEGO over HTTP (RFC 4559)
<https://tools.ietf.org/html/rfc4559>`__ will be the protocol used.

Use case: FreeIPA
~~~~~~~~~~~~~~~~~

The FreeIPA framework current uses a privileged **RA Agent** account
to perform CA operations, in violation of the principle that the
framework should only ever operate with the permissions of the
currently-authenticated user (a kind of privilege separation).  The
FreeIPA framework possesses a certificate for the RA Agent account,
and TLS client certificate authentication is used.  The lack of
privilege separation means that the IPA framework must make
authorisation decisions about whether an operator has permission to
commandeer the RA Agent certificate to perform the requested
operation.  Unfortunately, several security issues have occurred as
a result of failure to correctly authorise such operations.
Allowing the framework to authenticate to Dogtag with user
credentials avoids the need to for the IPA framework to perform
these authorisation checks.

In contrast, when the FreeIPA framework needs to perform LDAP
operations, it uses `S4U2Proxy
<http://k5wiki.kerberos.org/wiki/Projects/Services4User>`__ (also
known as *constrained delegation*) to acquire a ticket for the LDAP
server on behalf of the user.  We wish for the same to occur when
FreeIPA talks to Dogtag to e.g. issue a certificate or create a new
profile.

Use case: Barbican
~~~~~~~~~~~~~~~~~~

Barbican agent or service users should be able to access only Barbican
secrets.  Initially we expect those users/groups to exist in the Dogtag
database.  Eventually these could become IPA users/groups.


Proposed Changes
----------------

Overview
~~~~~~~~

For regular requests, changes include:

#. Apache performs SPNEGO authentication (mod_auth_gssapi) and
   mod_lookup_identity adds the principal's groups and permissions to
   the request.
#. ``ExternalAuthenticationValve`` reads groups out of the request
   environment and adds them to the Principal .
#. ``AuthMethodInterceptor`` updated to recognise external
   authentication method(s).
#. ``ACLInterceptor`` updated to consult the ``AuthzSubsystem``
   differently, depending on whether the principal is externally
   authenticated or not.

For certificate profile processing, a new profile constraint
implementation will allow an external process to be invoked to perform
additional authorisation and/or validation, according to the needs of
the external system.  The constraint can be added to profiles as
appropriate.

The following diagram shows an overview of request processing, including
new components (or new component instances):

 |pki-gssapi.png|

Apache frontend performs SPNEGO authentication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Use Apache's mod_auth_gssapi to perform the GSS-API (SPNEGO)
authentication.  It is assumed that a service principal for Dogtag
exists in the Kerberos database, and that a local keytab file is
available.

Use Apache's mod_lookup_identity to look up user groups/roles and
populate the request environment.  Components in Tomcat or Dogtag
will construct a principal from information in the request
environment.   Assuming AJP is used to connect Apache to Tomcat
(this is the case for FreeIPA), this means that mod_lookup_identity
must prefix the variables it wishes to convey to Dogtag with
``"AJP_"``.  These are made available via
``ServletRequest.getAttribute(String name)`` where ``name`` has been
stripped of the ``"AJP_"`` prefix.

Kerberos principal
^^^^^^^^^^^^^^^^^^

The choice of Kerberos principal(s) to use for Dogtag needs to be
decided.  Several possibilities exist:

- **Standalone Dogtag deployment**: each Dogtag clone must have its
  own principal of the form ``HTTP/<hostname>``, permitting access
  using standard HTTP clients supporting SPNEGO (including web
  browsers).

- **IPA CA deployment (ipa-ca.<ipadomain>)**: instances of the IPA
  CA can be accessed at ``ipa-ca.<ipadomain>``.  Access using this
  domain name implies the principal name
  ``HTTP/ipa-ca.<ipadomain>``.  This principal's key would have to
  be be shared among Dogtag clones.  Standard HTTP clients can be
  used.

- **IPA CA deployment (keytab shared with IPA framework)**: on each
  IPA server, both the IPA framework and Dogtag HTTP could use the
  keytab of the ``HTTP/<hostname>`` principal for GSS-API
  authentication.  This approach is not ideal because from the KDC's
  point of view, there is no distinction between the IPA web
  interface and Dogtag on a single server.  In this scenario, the
  IPA framework would still use S4U2Proxy to acquire a ticket for
  communicating with Dogtag.  Standard HTTP clients including web
  browsers can be used.

- **IPA CA deployment (different domain names)**: each Dogtag instance
  would be accessed using a unique domain name and a corresponding
  ``HTTP/<hostname>`` service principal for authentication.  Standard HTTP
  clients including web browsers will work.  Additional DNS records and
  CA domain name bookkeeping is required, which more or less rules
  out this approach.

- **IPA CA deployment (``"dogtag"`` service type)**: Dogtag would be
  accessed using the hostname of the IPA service, but the service
  principal is ``dogtag/<hostname>``.  There are no new DNS
  requirements, but HTTP clients that do not allow full control over
  which principal to acquire a service ticket for cannot be used for
  GSS-API authentication.  The advantage of this approach is that
  fine-grained S4U2Proxy delegation authorisation rules can be
  expressed.

Example SSSD and Apache configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The following ``sssd.conf`` snippet will make all group memberships
(including indirect membership) available to mod_lookup_identity as
the ``roles`` attribute.  The ``memberOf`` attribute includes
permissions that are inherited through FreeIPA's RBAC rules.  These
are cached under a different attribute name because it appears that
``memberOf`` is treated specially, and the D-Bus
``org.freedesktop.sssd.infopipe.GetUserGroups`` method only returns
direct memberships.

::

  [domain/EXAMPLE.COM]
  ...
  ldap_user_extra_attrs = roles:memberOf

  [ifp]
  allowed_uids = apache
  user_attributes = +roles

The following is an example ``httpd.conf`` snippet showing how
mod_auth_gssapi and mod_lookup_identity can be configured to perform
SPNEGO authentication and provide AJP attributes containing user groups,
conditional on the request query string containing an attribute called
``"gssapi"``::

  <If "%{QUERY_STRING} =~ /\bgssapi=/">
    AuthType GSSAPI
    AuthName "Kerberos Login"
    GssapiCredStore keytab:/etc/httpd/conf/ipa.keytab
    GssapiCredStore client_keytab:/etc/httpd/conf/ipa.keytab
    GssapiDelegCcacheDir /var/run/httpd/ipa/clientcaches
    GssapiUseS4U2Proxy on
    GssapiAllowedMech krb5
    Require valid-user
    LookupUserAttrIter roles +AJP_REMOTE_USER_GROUP
  </If>

Systems using SELinux must be configured to allow Apache to communicate
with SSSD over D-Bus::

  % sudo setsebool -P httpd_dbus_sssd 1

Alternative approaches considered
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. An alternative approach is to leverage Tomcat's
   ``SpnegoAuthenticator`` and use ``JDNIRealm`` to read the
   groups/roles of the authenticated principal.  However, the Tomcat
   ``Authenticator`` interface does not support "stacking" or
   "chaining" of authenticators, nor is it possible to configure
   different authenticators for different paths in the application;
   only one authenticator is supported per ``Context``.  Therefore
   it would have been necessary to run multiple instances of the
   application; one using SPNEGO authentication and the other using
   the existing authenticator (``SSLAuthenticatorWithFallback``).

2. A variation of (1) this approach would be to modify
   ``SSLAuthenticatorWithFallback``, which currently authenticates
   the client certificate (if present) otherwise falls back to BASIC
   authentication, to *also* support SPNEGO authentication.  The
   existing pattern of using ``HttpServletRequestWrapper`` to
   attempt authentication and falling back to another method if
   authentication fails should apply, with some modifications, to
   using ``SpnegoAuthenticator`` alongside ``SSLAuthenticator`` and
   ``BasicAuthenticator``.  This approach would support the existing
   deployment layout but retains the drawbacks of using
   ``JNDIRealm`` or additional behaviour in ``PKIRealm`` to look up
   group membership. Realms, unlike Authenticators, can be composed
   using ``CombinedRealm``.

Handling externally authenticated principals
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Tomcat must provide a ``java.security.Principal`` object
representing the remote user. The principal can be retrieved via
``HTTPServletRequest.getUserPrincipal()``.

Currently, each PKI instance defines a single AJP 1.3 Connector
(port 8009 by default), with the ``tomcatAuthentication`` attribute
not specified (defaulting to ``true``).  If an AJP request carries
remote user information, it is not propagated from the AJP request
to the Catalina ``Request``.  In order to propagate remote user
information from an AJP request to the ``HTTPServletRequest``, it
suffices to configure the connector with
``tomcatAuthentication="false"``.

When ``tomcatAuthentication="false"``, Tomcat Authenticators are
still invoked, but all Authenticator classes shipped with Tomcat
short-circuit if they observe that the ``HTTPServletRequest``
already bears a ``Principal``.  Dogtag's
``SSLAuthenticatorWithFallback`` exhibits the same behaviour,
because it merely invokes Tomcat Authenticator instances.

Setting roles of the ``Principal``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Per the `AJP Connector documentation
<https://tomcat.apache.org/tomcat-8.0-doc/config/ajp.html>`__, an
externally authenticated ``Principal`` does not have any roles
associated with it.  Group or role membership information provided
in the request environment (by mod_lookup_identity) must be added
to the ``Principal`` .

The class of the ``Principal`` in the request is
``CoyotePrincipal``, which does not have any roles, nor any method
to add roles.

A ``Valve`` called ``ExternalAuthenticationValve`` shall be
implemented, which reads ``REMOTE_USER_GROUP_*`` request attributes
provided by mod_lookup_identity and constructs a new principal
value, copying data from the original ``Principal`` and adding the
roles and request attributes.  It then calls
``org.apache.catalina.connector.Request.setUserPrincipal()`` to
replace the principal in the ``Request``.  Due to the CMS
dependencies of the ``PKIPrincipal`` class, the new principal shall
have the type ``ExternalPrincipal``, which is a new class that
extends ``org.apache.catalina.realm.GenericPrincipal`` with an
attribute that stores the Coyote request attributes (so that the
``KRB5CCNAME`` attribute that gets set by mod_auth_gssapi can be
propagated through the system).

Caching external principal in the HTTP session
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``ExternalAuthenticationValve`` shall cache the externally
authenticated principal (if any) in the session.

Assumptions about the class of the ``Principal``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Many parts of Dogtag assume or require that the principal is an
instance of ``PKIPrincipal`` (which has an ``IAuthToken``) or,
roughly equivalently, that an ``IAuthToken`` and ``IUser`` are
available in the ``SessionContext``.

Due to external authentication this assumption or requirement no
longer holds; the externally authenticated principal will not be an
instance of ``PKIPrincipal`` and consequently will not provide an
``IAuthToken``.

It is proposed to provide a new implementation of ``IAuthToken``
called ``ExternalAuthToken`` that wraps a ``GenericPrincipal`` and
provides reasonable values for particular attribute keys where
possible.  Code that currently calls ``PKIPrincipal.getAuthToken()``
will be updated to acquire or construct an ``IAuthToken`` value
according to the type of the principal.

``AuthMethodInterceptor`` changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``AuthMethodInterceptor`` is used to restrict access to
resources based on the authentication method (specifically, the name
of the ``IAuthManager`` instance) that was used to authenticate a
``PKIPrincipal``.

Because an externally authenticated ``GenericPrincipal`` does not
have an associated ``IAuthManager``, ``AuthMethodInterceptor`` shall
be enhanced to handle externally authenticated principals.  Two
approaches to deal with this are possible:

- If it is satisfactory to treat all external authentication
  methods homogeneously, infer that any principal that is not a
  ``PKIPrincipal`` was externally authenticated and set the the
  ``authManager`` name to ``"external"``.

- If fine-grained access control based on different external
  authentication methods is needed, extend ``GenericPrincipal`` with
  a property to store the authentication type, and update
  ``AuthMethodInterceptor`` to read it (similarly to how it reads
  the ``TOKEN_AUTHMGR_INST_NAME`` from the ``IAuthToken`` of a
  ``PKIPrincipal``.)

In either case, the default ``auth-method.properties`` file shall be
updated to allow SPNEGO authentiction at all API endpoints.

Authorisation for external identities
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

General authorisation
^^^^^^^^^^^^^^^^^^^^^

Authorization is currently performed by asking the
``AuthzSubsystem`` to use a named ``IAuthzManager`` to evaluate
whether a principal (represented by an ``IAuthToken`` object) is
allowed to perform a particular operation against a particular kind
of *resource*.

When an operation needs to be authorised, if the principal is a
``PKIPrincipal``, whatever ``IAuthzManager`` is currently used shall
continue to be used.  ``PKIPrincipal.getAuthToken()`` provides the
``IAuthToken`` object.

If the principal is an ``ExternalPrincipal``, the name of the
``IAuthzManager`` to query shall be looked up via the
``AuthzSubsystem.getAuthzManagerNameByRealm`` method.  The realm is
the part of the principal name after the ``"@"`` symbol.
Accordingly, ``IAuthzManager`` plugin instances that will be used
for external principals must have the realm  configuration set in
``CS.cfg``, e.g to define an authorisation plugin instance for
authenticating principals in the ``EXAMPLE.COM`` realm::

  authz.instance.IPAAuthz.pluginName=DirAclAuthz
  authz.instance.IPAAuthz.realm=EXAMPLE.COM
  authz.instance.IPAAuthz.ldap=internaldb
  authz.instance.IPAAuthz.searchBase=cn=IPA.LOCAL,cn=aclResources

The ``IAuthToken`` created for externally authenticated principals
shall be an instance of ``ExternalAuthToken``.

To support multiple ``DirAclAuthz`` instances sharing a single
``ldap`` connection whilst loading different sets of ACLs for
different realms, ``DirAclAuthz`` shall learn the ``searchBase``
configuration parameter, which allows an alternative base DN to be
specified.

Alternative approaches
''''''''''''''''''''''

#. ``AuthzSubsystem.checkRealm()`` can check authorisation for an
   operation in a particular realm.  The ``IAuthzSubsystem`` lookup
   by realm is performed internally (the caller must still provide
   the realm name).  The realm name gets prepended to the
   *resource*, then ``IAuthzManager.authorize()`` is invoked.  The
   advantage of this approach is that no additional authz managers
   are required.  The disadvantage is that all ACLs for all realms
   live alongside each other (in the case of ``DirAclAuthz``, in a
   single LDAP entry, though they are distinguished by resource
   prefix).

Authorising FreeIPA principals
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For authorising FreeIPA principals to perform Dogtag administrative
operations (e.g. managing certificate profiles or lightweight CAs),
an additional instance of the ``DirAclAuthz`` plugin can be defined
in ``CS.cfg`` and configured to load ACLs from a different entry (or
entries).

The ACLs themselves shall be managed by FreeIPA and can contain
references to FreeIPA users, groups and permissions, e.g.
*cn=admins,cn=groups,cn=accounts,dc=example,dc=com* or *cn=System:
Add CA,cn=permissions,cn=pbac,dc=example,dc=com*.

The main advantage of this approach is that it allows Dogtag to
enforce access controls defined in the external IdP.  A specific
``IAuthzManager`` plugin is configured for each IdP.  To authorise
an operation, the plugin's ``authorize`` method is invoked with an
``IAuthToken`` (which contains the principal's name and groups),
resource and operation, and it evaluates access.  It is possible for
the plugin to communicate with other systems.

Profile authorisation
^^^^^^^^^^^^^^^^^^^^^

Immediate issuance of a certificate is authenticated (and
authorised) via the ``IProfileAuthentication`` plugin configured for
a profile.  The authenticator instance for a profile is configured
via the ``auth.instance_id`` profile configuration parameter.  If no
profile authenticator is configured for a given profile, requests
are enqueued as *pending*, even if the requestor is currently
authenticated.

Certificate issuance authorisation for FreeIPA-managed certificate
profiles is currently accomplished via the ``raCertAuth``
authenticator; an instance of the ``AgentCertAuthentication`` plugin
that authenticates a principal using TLS certificate authentication
and checks that they are a member of the *Registration Manager
Agents* internal group.  In other words, if the RA Agent certificate
is used, immediate certificate issuance is authorised.  The use of
the RA Agent certificate is subject to authorisation checks in the
FreeIPA framework, including:

#. The operator must have the *Request Certificate* permission or it
   must be a self-service request.

#. CA ACLs, which encode which combinations of subject, CA and
   profile are valid, are checked.

When operator (proxy) credentials are used for issuing certificate
requests, Dogtag itself well have to perform these (or equivalent)
authorisation checks.  New request authorisation and validation
behaviour is needed to do this, and it must be able to use the CA
name, profile name and CSR in determining whether certificate
issuance should proceed.  This is detailed in the subsections that
follow.

Because the operator is now authenticated directly to Dogtag, a new
profile authenticator called ``SessionAuthentication`` shall be used
to authorise immediate issuance.  This plugin shall merely return
the ``IAuthToken`` from the session context, if present.

How certificate requests are processed
''''''''''''''''''''''''''''''''''''''

It is helpful to note how requests are processed, and when
particular data are populated into the CMS request object.  The
procedure (starting in ``EnrollmentProcessor.processEnrollment()``)
is outlined below.  Non-relevant steps have been omitted.  Steps of
particular importance are highlighted in boldface.

#.  If there is no ``IAuthToken`` , ``CAProcessor.authenticate()``
    is invoked, which, if the profile has an
    ``IProfileAuthenticator`` configured, invokes its
    ``authenticate()`` method.

#.  Call ``EnrollProfile.createRequests()``

    #. Create request object

    #. **Set the requested CA's authority ID in the request**

#.  Call ``CertProcessor.populateRequests()``

    #. **Profile inputs are added to the request
       (``setInputsIntoRequest()``)**

    #. **Data from the ``IAuthToken`` are serialised into the
       request**

    #. **Set the profile ID in the request**

    #. If there is an ``IAuthToken``,
       ``IProfileAuthenticator.populate()`` is called (this is a
       no-op for ``AgentCertAuthentication``)

    #. ``profile.populateInput()`` and ``profile.populate()`` are
       called

#.  Call ``CertProcessor.submitRequests()`` , which calls
    ``EnrollProfile.submit()`` for each request

#.  Call ``EnrollProfile.validate()`` , which validates the request
    against all constraint policies.

Proposed solution: ``ExternalProcessConstraint``
''''''''''''''''''''''''''''''''''''''''''''''''

A new ``IPolicyConstraint`` implementation shall be added.  It shall
execute as a subprocess a program (whose path is given by the
``executable`` configuration parameter) that can authorise and
verify the request.

Dogtag shall execute the program with no command line arguments.
The program **should** ignore command line arguments.

The program shall be provided the following data via environment
variables:

``DOGTAG_AUTHORITY_ID``
  Authority ID (UUID) of target CA
``DOGTAG_CERT_REQUEST``
  Certificate request value, e.g. a PEM-encoded PKCS #10 CSR
``DOGTAG_PROFILE_ID``
  Name of certificate profile
``DOGTAG_USER``
  Operator principal name (i.e. who is submitting the request)
``DOGTAG_USER_DATA`` (optional)
  User-supplied data, if any (see following section)

An ``ExternalProcessConstraint`` instance can be configured to read
additional request attributes from the ``IRequest`` into the
subprocess environment, via the ``env`` configuration sub-store,
whose keys are environment variable names and whoes values are
``IRequest`` *extData* keys.  Keys that are not found in the
``IRequest`` are ignored (nothing gets added to the subprocess
environment).

Example configuration::

  policyset.serverCertSet.12.default.class_id=noDefaultImpl
  policyset.serverCertSet.12.default.name=No Default
  policyset.serverCertSet.12.constraint.class_id=externalProcessConstraintImpl
  policyset.serverCertSet.12.constraint.name=IPA policy enforcement
  policyset.serverCertSet.12.constraint.params.executable=/usr/libexec/ipa/ipa-pki-validate-cert-request
  policyset.serverCertSet.12.constraint.params.env.KRB5CCNAME=auth_token.PRINCIPAL.KRB5CCNAME

The program can use the data available in its environment to
authorise and/or validate the request.  The outcome is conveyed in
the exit status and in standard output:

- If the request is permitted, the exit status SHALL be zero.

- If the request is not permitted for any reason (FreeIPA example:
  issuance not permitted by CA ACLs), the exit status SHALL be
  nonzero, and a description of the failure SHOULD be provided on
  standard output.  (Standard error is case out-of-band data is
  output on standard error, e.g. logging).

A nonzero exit status shall cause ``ERejectException`` to be thrown,
with the standard output from the executable as its argument.  This
value gets persisted in the request entry (LDAP ext data, key
``IRequest.ERROR``) and propagated to the client in the
``"errorMessage"`` field of the response (this is existing
behaviour, and is sufficient).


Propagating arbitrary data to ``ExternalProcessConstraint``
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Some use cases may require aribitrary data supplied by the requestor
to be observed by the profile policies, e.g. in the FreeIPA use
case, the operator must indicate the subject principal name, and
this must be propagated to the request validation program via
``ExternalProcessConstraint``.

To support this, a new, optional *user data* parameter will be
recognised by the enrolment processor.  Specifically, if the HTTP
request parameter ``user-data`` occurs, its value will be recorded
in the ``IRequest``, and the ``ExternalProcessConstraint`` will
expose it in the subprocess environment (see above).

Propagating principal attributes to ``ExternalProcessConstraint``
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Some use cases may require attributes about an externally
authenticated principal that have been made available in the HTTP
request environment (e.g. attributes from mod_lookup_identity or
mod_auth_gssapi) to be made available to profile policies, e.g. the
``KRB5CCNAME`` variable.

If the authenticated principal is an ``ExternalPrincipal``, all of
the values from the principal's attribute map shall be added to the
``IRequest`` as *extData*, under the key
``auth_token.PRINCIPAL.<attr-key>``.  The
``ExternalProcessConstraint`` can then be configured to add
variables of interest to the subprocess environment.

..
  KRA authorisation
  ^^^^^^^^^^^^^^^^^

  TODO: this section needs expansion.

  1. multiple applications that try to access a secret
     i.e. do not allow ipa user to access barbican secrets; vice versa
  2. ownership determines whether or not someone can access secret
  3. application-specific authz check are needed, e.g. IPA Vault
     manager should be able to access all vault secrets.
     authz call for resource-class + operation
     authz plugin for resource-INSTANCE + operation
          - "post-authorize" call?
          - what are params?
            - object app/tag/idp
            - object owner
            - object group access?
          - only gets invoked if app/idp on object matches principal
          - what we don't want to happen:
            - suppose user in IPA who is vault manager has access to IPA secrets
            - don't want that user to be access to be able to access
              secrets stored by barbican user, EVEN IF barbican
              authenticated with ticket in IPA domain.
            - this does make sense (once you think about it)
            - question: how does KRA know what application is storing the
              secret?
              - is there a vaultUser class?
              - it is a parameter of the vault-add
            - OPEN QUESTION: is there a null or default application
            - when you retrieve, you also have to pass a parameter
              - I am retrieving in context of application X
              - you will then be evaluated in context of application X
              - question: is there any exploit here
                - application must not form part of identity of secret
            - question: are we registereing authz plugins by
              (idp, application) pair.

  - TODO talk to Jack; auth based on resource things to TPS

Data model impact
~~~~~~~~~~~~~~~~~

A new LDAP entry or entries containing ACLs for an external realm
will be required in most external authentication use cases.

Some new configuration is needed; in particular:

- Addition and instantiation of ``SessionAuthentication`` profile
  authenticator in ``CS.cfg``.

- Addition and instantiation of ``ExternalProcessConstraint``
  profile constraint in ``registry.cfg``.

REST API impact
~~~~~~~~~~~~~~~

It must be possible to log into the REST API (``GET
/ca/rest/account/login``) using SPNEGO.  It is possible to offer
SPNEGO login at a separate path or guarded by a query parameter if
it is not possible to offer a single login resource that can handle
SPNEGO, TLS client certificate or BASIC authentication.

Some parts of the API must be accessible by unauthenticated
principals (e.g. OCSP responder). The authenticating proxy must be
configured to not require SPNEGO authentication (or any other
authentication) at these resources.

Some parts of the REST API are intended to be used with a
cookie-based session, subsequent to prior authentication at the
``/ca/rest/account/login`` resource.  The login resource shall
support SPNEGO authentication.

Security impact
~~~~~~~~~~~~~~~

Dogtag (or Apache on behalf of Dogtag, or ``gssproxy`` on behalf of
both) must have access to the keytab for the Dogtag service
principal.  The keytab, being secret key material, must be
appropriately secured.

The connection between Apache and Tomcat must be secure from
external access because it carries identity assertions that are
trusted by Dogtag.  External hosts or processes other than Apache
must not be able to send data to Tomcat that contains forged
identity assertions.

Notifications & Audit Impact
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

None known.

Command Line Client Impact
~~~~~~~~~~~~~~~~~~~~~~~~~~

We may wish to enhance the ``pki`` CLI to be able to perform SPNEGO
authentication, using standard credential caches available to the
client program.  (This is not an initial requirement for the FreeIPA
use case).

Depending on the Dogtag principal name (``HTTP/<hostname>`` versus
``dogtag/<hostname>``) standard SPNEGO implementations may not be
appropriate or may require enhancement, because the standard
behaviour is to acquire a ticket for ``HTTP/<hostname>``.

Other end user impact
~~~~~~~~~~~~~~~~~~~~~

None known.

Performance Impact
~~~~~~~~~~~~~~~~~~

A client may need to contact the KDC to acquire a service ticket for
Dogtag.  Tickets should be cached.

SPNEGO typically requires two round trips to the HTTP server, increasing
latency and server load.  Mitigations include:

#. Use SPNEGO to authenticate to a login resource that issues a
   session cookie.  Present the cookie in subsequent requests,
   avoiding the need for SPNEGO authentication.

#. If the client knows that it will be required to perform SPNEGO,
   it can acquire a service ticket and send the ``"Authorization:
   Negotiate ..."`` header in the first request, avoiding the
   initial 401 response that would otherwise occur.

Cloning Impact
~~~~~~~~~~~~~~

If using GSS-API authentication, Apache must be set up in front of
clones.  This could (eventually) be done by ``pkispawn``.  If
initial use cases already require Apache (this is the case for
FreeIPA), this work can be deferred.

If clones are accessed via different hostnames, each clone must have
its own service principal in the Kerberos database, and Apache must
use that principal's keytab.  If clones are accessed via a single
hostname (e.g.  load balanced or multiple DNS records) a shared
keytab must be used.   See `Simo's blog post`_ for more detail about
load balancing and Kerberos.

.. _Simo's blog post: https://ssimo.org/blog/id_019.html

Other deployer impact
~~~~~~~~~~~~~~~~~~~~~

When deployed with FreeIPA, in addition to configuring Apache,
constrained delegation support must be set up.  The FreeIPA framework
shall use S4U2Proxy to acquire a ticket for Dogtag, on behalf of the
authenticated principal.

``pkispawn`` shall learn a new configuration option for deploying
``pki-tomcatd`` with the AJP connector configured with
``tomcatAuthentication="false"``.  The default behaviour shall be to
deploy without this setting.

``pkispawn`` shall learn a new configuration option for deploying
``pki-tomcatd`` with the AJP connector configured with a
``requiredSecret``.  The default behaviour shall be to not set this
option.

Developer impact
~~~~~~~~~~~~~~~~

Developers cannot assume that the class of an authenticated
``Principal`` is ``PKIPrincipal``.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  ftweedal

Other contributors:
  alee

Work Items
----------

Dependencies
============

- Apache, mod_auth_gssapi, mod_lookup_identity

Testing
=======

Documentation Impact
====================

What is the impact on the docs of this change? Specifically, which
docs and man pages need to be modified?

References
==========

.. |pki-gssapi.png| image:: pki-gssapi.png
