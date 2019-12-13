FreeIPA ACME support
====================

Open design questions:

- In which LDAP subtree to store ACME service data?

- Whether to support multiple profiles, and if so how?

- Do we allow ACME service to use a sub-CA



LDAP ACME service schema
========================

LDAP tree::

  acmedn = e.g. cn=acme,cn=ipa,{basedn}

  nonces = cn=nonces,{acmedn}
  accounts = cn=accounts,{acmedn}
  orders = cn=orders,{acmedn}
  authorizations = cn=authorizations,{acmedn}
  challenges = cn=challenges,{acmedn}

LDAP schema::

  attributeTypes: ( acmeExpires-oid NAME 'acmeExpires'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.24
    EQUALITY generalizedTimeMatch
    ORDERING generalizedTimeOrderingMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeValidatedAt-oid NAME 'acmeValidatedAt'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.24
    EQUALITY generalizedTimeMatch
    ORDERING generalizedTimeOrderingMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeStatus-oid NAME 'acmeStatus'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeStatus-oid NAME 'acmeError'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    SINGLE-VALUE )

  attributeTypes: ( acmeNonceValue-oid NAME 'acmeNonceValue'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeAccountId-oid NAME 'acmeAccountId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeAccountContact-oid NAME 'acmeAccountContact'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch
    SUBSTR caseIgnoreSubstringsMatch )

  attributeTypes: ( acmeAccountKey-oid NAME 'acmeAccountKey'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    SINGLE-VALUE )

  attributeTypes: ( acmeOrderId-oid NAME 'acmeOrderId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeIdentifier-oid NAME 'acmeIdentifier'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
    EQUALITY caseIgnoreMatch )

  attributeTypes: ( acmeAuthorizationId-oid NAME 'acmeAuthorizationId'
    SUP name )

  attributeTypes: ( acmeAuthorizationWildcard-oid NAME 'acmeAuthorizationWildcard'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.7
    EQUALITY booleanMatch
    SINGLE-VALUE )

  attributeTypes: ( acmeChallengeId-oid NAME 'acmeChallengeId'
    SUP name
    SINGLE-VALUE )

  attributeTypes: ( acmeToken-oid NAME 'acmeToken'
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )



  objectClasses: ( acmeNonce-oid NAME 'acmeNonce'
    STRUCTURAL
    MUST ( acmeNonceValue $ acmeExpires ) )

  objectClasses: ( acmeAccount-oid NAME 'acmeAccount'
    STRUCTURAL
    MUST ( acmeAccountId $ acmeAccountKey $ acmeStatus )
    MAY acmeAccountContact )

  objectClasses: ( acmeOrder-oid NAME 'acmeOrder'
    STRUCTURAL
    MUST ( acmeOrderId $ acmeAccountId $ acmeStatus $ acmeIdentifier $ acmeAuthorizationId )
    MAY ( acmeError $ userCertificate $ acmeExpires ) )

  objectClasses: ( acmeAuthorization-oid NAME 'acmeAuthorization'
    STRUCTURAL
    MUST ( acmeAuthorizationId $ acmeAccountId $ acmeIdentifier $ acmeStatus )
    MAY ( acmeExpires $ acmeAuthorizationWildcard ) )

  objectClasses: ( acmeChallenge-oid NAME 'acmeChallenge'
    ABSTRACT
    MUST ( acmeChallengeId $ acmeAccountId $ acmeAuthorizationId $ acmeStatus )
    MAY ( acmeValidatedAt $ acmeError )

  objectClasses: ( acmeChallengeDns01-oid NAME 'acmeChallengeDns01'
    SUP acmeChallenge
    STRUCTURAL
    MUST acmeToken )
