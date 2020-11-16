%%%
title = "Automated Certificate Management Environment (ACME) Server Capability Advertisements"
abbrev = "ACME-CapAdv"
workgroup = "Network Working Group"

ipr = "trust200902"
area = "Internet"
keyword = ["Internet-Draft"]

[pi]
toc = "yes"

[seriesInfo]
status = "standard"
name = "Internet-Draft"
value = "draft-tweedale-acme-server-capabilities-00"
stream = "IETF"

[[author]]
initials = "F."
surname = "Tweedale"
fullname = "Fraser Tweedale"
organization = "Red Hat"
  [author.address]
  email = "ftweedal@redhat.com"

%%%

.# Abstract

Automated Certificate Management Environment (ACME) servers
typically support only a subset of the ACME identifier types and
validation types that have been defined.  This document defines new
fields for the the ACME directory object to allow servers to
advertise their capabilities, assisting clients to select a suitable
server.

{mainmatter}

# Introduction

Automatic Certificate Management Environment [@!RFC8555] specifies a
protocol by which a client may, in an automatable way, prove control
of identifiers and obtain a certificate from an Certificate
Authority (the ACME server).  The ACME protocol can be (and has
been) extended to support different identifier types and validation
methods.  Identifier types include "dns" [@!RFC8555], "ip"
[@?RFC8738], and "email" [@?I-D.draft-ietf-acme-email-smime-10].
Validation methods include "http-01" and "dns-01" [@!RFC8555],
"tls-alpn-01" [@?RFC8737], and "email-reply-00"
[@?I-D.draft-ietf-acme-email-smime-10].

An ACME client could have awareness of and access to multiple ACME
servers, and the servers could differ in which identifier types and
validation methods they support.  This document specifies a
mechanism to assist ACME clients to select a server that supports
the identifier type(s) it needs and the validation method(s) it can
perform.  It does so by defining new fields in the "meta" field of
the ACME directory object, in which a server can advertise its
capabilities.  Clients can check these fields to see whether the
server capabilities satisfy their requirements.

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in
BCP 14 [@?RFC2119] [@?RFC8174] when, and only when, they appear in all
capitals, as shown here.

# ACME Directory Metadata Fields

This specification defines new fields for the ACME directory
object's "meta" field that servers can use to convey their supported
capabilities.  All of these new fields are OPTIONAL (as is the
"meta" field itself).

## "supportedIdentifierTypes" Field

The "supportedIdentifierTypes" field lists identifier types
supported by the server.  Its value SHALL be a JSON array of JSON
strings, each of which SHOULD be a value that is registered in the
IANA ACME Identifier Types registry [@?IANA-ACME-ID].  The array SHOULD
include each identifier type supported by the server.

If this field is present in the directory object, clients SHOULD NOT
attempt to create new orders containing identifier types that are
not advertised.

## "supportedValidationMethods" Field

The "supportedValidationMethods" field lists validation methods
(also called "challenge types") supported by the server.  Its value
SHALL be a JSON array of JSON strings, each of which SHOULD be a
value that is registered in the IANA ACME Validation Methods
registry [@?IANA-ACME-VAL].  The array SHOULD include each validation
method supported by the server.

If this field is present in the directory object, clients SHOULD NOT
attempt to create new orders unless the advertised validation
methods include methods that the client is capable of performing.

# Example Directory Object

The following example extends the example directory object from
Section 7.1.1 of [@!RFC8555] with the "supportedIdentifierTypes" and
"supportedValidationMethods" fields.  This server advertises support
for the "dns" and "ip" identifier types and the "dns-01" and
"tls-alpn-01" validation methods.

    {
      "newNonce": "https://example.com/acme/new-nonce",
      "newAccount": "https://example.com/acme/new-account",
      "newOrder": "https://example.com/acme/new-order",
      "newAuthz": "https://example.com/acme/new-authz",
      "revokeCert": "https://example.com/acme/revoke-cert",
      "keyChange": "https://example.com/acme/key-change",
      "meta": {
        "termsOfService": "https://example.com/acme/terms/2017-5-30",
        "website": "https://www.example.com/",
        "caaIdentities": ["example.com"],
        "externalAccountRequired": false,
        "supportedIdentifierTypes": ["dns", "ip"],
        "supportedValidationMethods": ["dns-01", "tls-alpn-01"]
      }
    }

# Server Policy is Distinct From Server Capabilities

The presence of an identifier type in the "supportedIdentifierTypes"
field does not suggest that a server will issue a certificate for
arbitrary identifiers of that type.  Servers may refuse orders if
the requested identifiers do not satisfy server policy.  For
example, a server might refuse to issue certificates for high value
"dns" identifiers, or restrict "email" identifiers to their
organisation's domain.

Likewise, the "supportedValidationMethods" field does not reveal how
the server decides which validation methods can be used for a given
authorization.  A server might support both the "http-01" and
"dns-01" validation methods, but as a matter of policy might use
just one and not the other for a particular identifier (or reject
the identifier outright).

Therefore clients SHOULD handle issuance failure uniformly for all
servers, regardless of whether capabilities were advertised or not.
The exception is if the server advertised its supported identifier
types, but rejected an order containing only supported identifier
types with an "unsupportedIdentifier" error.  A client MAY make a
special effort to report this situation, which indicates a server
misconfiguration.

## Server Policy Advertisements (Possible Future Work)

Consider the following scenario.  An organisation operates an ACME
server for issuing certificates to internal clients requesting
certificates for "dns" identifiers under the "corp." DNS domain.
ACME clients requesting certificates "dns" identifiers in other
domains should use a different ACME server.  Clients learn about the
servers via a service discovery mechanism.

For any particular "dns" identifier only one of the two ACME servers
can issue the certificate.  But there is no mechanism that can
assist the client to make the correct choice.

An ACME "meta" advertisement with content similar to the [@?RFC5280]
Name Constraints extension could accommodate this and similar use
cases.  In an environment with access to multiple ACME servers,
clients would be able to select a suitable server with greater
accuracy.

No practical mechanism could express all possible server policies
(e.g. "don't issue certificates to people named Bob on Tuesdays").
It is also unclear whether it is worth the effort to devise and
implement a server policy advertisement mechanism, or if it is
better to allow clients to experience failures and fall back to
other servers.  This document leaves this as an open topic for
possible future work.

# IANA Considerations

## ACME Directory Metadata Fields

Please add the following entries to the ACME Directory Metadata
Fields registry [@?IANA-ACME-META]:

    +----------------------------+-----------------+-----------+
    | Field Name                 | Field Type      | Reference |
    +----------------------------+-----------------+-----------+
    | supportedIdentifierTypes   | array of string | [thisdoc] |
    | supportedValidationMethods | array of string | [thisdoc] |
    +----------------------------+-----------------+-----------+


# Security Considerations

This specification does not raise any security concerns beyond those
of [@!RFC8555].


{backmatter}

<reference anchor="IANA-ACME-ID" target="https://www.iana.org/assignments/acme/acme.xhtml#acme-identifier-types">
    <front>
        <title>ACME Identifier Types</title>
        <author><organization>IANA</organization></author>
    </front>
</reference>
<reference anchor="IANA-ACME-VAL" target="https://www.iana.org/assignments/acme/acme.xhtml#acme-validation-methods">
    <front>
        <title>ACME Validation Methods</title>
        <author><organization>IANA</organization></author>
    </front>
</reference>
<reference anchor="IANA-ACME-META" target="https://www.iana.org/assignments/acme/acme.xhtml#acme-directory-metadata-fields">
    <front>
        <title>ACME Directory Metadata Fields</title>
        <author><organization>IANA</organization></author>
    </front>
</reference>
