CA ACL enhancements:

Use cases:

- Currently, services can only appear individually on CA ACLs.  This
  means that there is either a large administrative overhead where
  related services are concerned, or the coarse/overbroad
  servicecat=all must be used.  A "service group" concept is needed
  to, e.g., define a "vpnservers" service group and reference it in
  CA ACLs.

- More fine grained control over who may request certificates for
  particular subjects.

- Issue certs to entities that are not IPA user/host/service
  objects, e.g.
  krbPrincipalName=krbtgt/IPA.LOCAL@IPA.LOCAL,cn=IPA.LOCAL,cn=kerberos,dc=ipa,dc=local
  (PKINIT cert for KDC)

- Issue certs to principal from a trusted realm

- Allow principal from a trusted realm to request certificates


Implementation details:

- FOR KRBTGT ONLY: we could target the HOST principal and
  a special-case the KRB5PrincipalName SAN check: if the
  KRB5PrincipalName is krbtgt/REALM@REALM, check that the host is in
  hostgroup "ipaservers".

  QUESTION: what principal is requesting the cert for KDC?
  QUESTION: what is Subject DN?
  QUESTION: what is princ argument?
    krbtgt/... because certmonger

- Fine-grained permissions for which IPA principals may request
  certs for particular subjects with particular CAs/profiles can be
  done using the (currently unused) srchost field of Hbac machinery.
  (The srchost field, like others, supports groups).

- The path to service groups and their use in CA ACLs is clear.
  Implement the servicegroup plugin, and the concept will be
  implemented in CA ACLs in the same way as user groups and
  hostgroups.

- Referencing non-user/host/service entities: there are two
  scenarios:

  1. object in IPA directory, e.g. krbtgt/REALM@REALM
  2. object not in IPA directory, e.g. trusted realm principal
     QUESTION: what other kinds of "external objects" might we
     want as either the subject, or the requestor, of a certificate?

  The immediate need is (1).  The two scenarios need not be
  addressed in the same way.

  Note that for both scenarios, we cannot perform access control
  based on ability of requestor to write the 'userCertificate'
  attribute of the subject (in scenario (1), that attribute might
  not exist; in scenario (2) there is not even an entry to check).
  Therefore, support for restricting requestor in CA ACL is probably
  a prerequisite.

  QUESTION: how do we determine whether the subject name(s)
  correspond to the subject entity?  Possibilities:

  One possibility is to define mappings that select rules for
  checking the subject name(s) against the subject entity.  For
  example::

    ``ipa cert-request CSR --principal pkinit-kdc:<DN>``

  This would select a set of rules called "pkinit" for checking the
  CSR against the subject entity (which in this case is identified
  by the DN).  In addition to these subject validity checks, the
  issuance would also be guarded by caacl checks, where the target
  subject entity is the DN.

  The specifics of the "pkinit-kdc" subject checking rules would be
  something like:

  - Check that CN is a domain name matches a host in the ipaservers
    hostgroup
  - Check that KRB5PrincipalName otherName is present in SAN and matches
    "krbtgt/REALM@REALM"
  - Check that SAN dnsName is present and matches same host as CN.

  To add the krbtgt to the CA ACL, the command might look like::

    # DN="krbPrincipalName=krbtgt/IPA.LOCAL@IPA.LOCAL,cn=IPA.LOCAL,cn=kerberos,dc=ipa,dc=local"
    # ipa caacl-object-add <caacl-name> --objects "$DN"

  This would add the krbtgt object to the ACL and allow certificates
  to be issued for it.

  If we want to allow access to groups of objects, we could do it
  by one or more of the following approaches:

  - basedn: allow if the basedn is a prefix of the subject's dn
  - filter: allow if the given ldap filter matches the subject object


mtg notes:

- think about pushing evaluation to external tools
  - e.g. ACME, validate princpials from external domain

- acl that has "self" target; enable self-service per-rule
  - further restrict to a group
  - e.g. hosts in "vpnservers" group can self-service with
    "vpnserver" profile and "vpnca" ca

- only check bind principal has write access to 'userCertificate'
  attr if profile storeIssued attribute is True


AI:

- design pages: TITLES ONLY

- dogtag plugin interface
