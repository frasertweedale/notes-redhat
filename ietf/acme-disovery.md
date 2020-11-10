%%%
title = "Automated Certificate Management Environment (ACME) Service Discovery"
abbrev = "ACME-SD"
workgroup = "Network Working Group"

ipr = "trust200902"
area = "Internet"
keyword = ["Internet-Draft"]

[pi]
toc = "yes"

[seriesInfo]
status = "standard"
name = "Internet-Draft"
value = "draft-tweedale-acme-discovery-01"
stream = "IETF"

date = 2020-10-22T00:00:00Z

[[author]]
initials = "F."
surname = "Tweedale"
fullname = "Fraser Tweedale"
organization = "Red Hat"
  [author.address]
  email = "ftweedal@redhat.com"

%%%


.# Abstract

This document specifies a service discovery mechanism that enables
capable clients to locate an Automated Certificate Management
Environment (ACME) server in their network environment.

{mainmatter}

# Introduction

Automatic Certificate Management Environment (ACME) [@!RFC8555]
specifies a protocol by which a client may, in an automatable way,
prove control of identifiers and obtain a certificate from an
Certificate Authority (the ACME server).  However, it did not
specify a mechanism by which a client can locate a suitable ACME
server.  It is assumed that a client will be configured to use a
particular ACME server, or else default to some well known, publicly
accessible ACME service.

In some environments, such as corporate networks, it may be
impossible for ACME clients to obtain certificates from a publicly
accessible ACME servers, or an organisation may prefer clients to
use a particular server.  Explicitly configuring ACME clients to use
a particular ACME server presents an administrative burden.

This document specifies a mechanism by which ACME clients can locate
an ACME server using the Uniform Resource Identifier (URI) DNS
resource record [@?RFC7553].

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in
BCP 14 [@?RFC2119] [@?RFC8174] when, and only when, they appear in all
capitals, as shown here.

# DNS URI Record

The URI resource record [@?RFC7553] facilitates client discovery of
ACME server(s) for a given DNS parent domain name ("parent domain"
having the meaning given in [@?RFC8552]).  The owner name of the URI
record SHALL be the parent domain with the label "\_acme-server"
prepended to it.  The target of the URI record SHALL be the URI
[@!RFC3986] of the directory resource of the target ACME server,
enclosed in double quotes (").  For example:

```
$ORIGIN example.com.
_acme-server IN URI 10 1 "https://ca.example.com/acme/directory"
```

There MUST be exactly zero or one URI records for the
"\_acme-server" node.


# Client Behaviour

## When to Perform Service Discovery

If an ACME client provides for explicit configuration of an ACME
server, and such configuration is provided, the client MUST use the
configured ACME server and MUST NOT perform service discovery.

Otherwise, if an ACME client supports service discovery, in the
absense of explicit configuration of an ACME server the client MAY
attempt to locate an ACME server using the mechanisms specified in
this document.  A client MAY refuse to perform service discovery
unless its configuration explicitly enables it.

## Candidate Parent Domains

To perform service discovery, the ACME client needs a list of
candidate parent domains.  The client will query the associated URI
records for the candidate parent domains.

If an ACME client provides for explicit configuration of parent
domains to use for service discovery, and such configuration is
provided, the candidate parent domains SHALL be the configured
values.

Otherwise, there are a variety of ways an ACME client could choose
candidate parent domains, including:

- The host's fully-qualified domain name with one or more labels
  removed from the left.

- The "search" domains from the host's DNS configuration.

- The Kerberos [@?RFC4120] realm of the host.

- The result of a PTR lookup on one of the host's non-loopback IP
  addresses, with one or more labels removed from the left.

An ACME client MAY use any or all of these or other suitable methods
for identifying candidate parent domains.  If multiple candidate
parent domains are identified the client MUST establish an order of
preference among them.  If any candidate parent domain A is a
subdomain of another candidate parent domain B, the client MUST
preference A higher than B.


## DNS URI Queries and Validation

Service discovery begins with the most preferred candidate parent
domain.

The ACME client SHALL prepend the label "\_acme-server" to the
candidate parent domain name and query the DNS URI record for the
resulting domain name.  If any records are returned, the ACME client
SHALL select exactly one of the target URIs.  The client SHALL
perform an HTTPS GET request for the target URI and SHALL attempt to
parse the response body as an ACME directory object.  If successful,
service discovery has succeeded; the client SHALL use the target of
the URI record as the ACME server, and MUST NOT process the
remaining candidate parent domains.

Otherwise, service discovery for the current parent domain has
failed.  Either there is no "\_acme-server" URI record under the
parent domain, or the target URI value is not well formed, or the
HTTP request failed, or the HTTP response is not a valid ACME
directory object.  In this case, the client MAY retry service
discovery with the next most preferred candidate parent domain.  The
client MAY continue retrying until no candidate parent domains
remain, or MAY give up earlier (e.g. after a fixed number of
attempts).

If service discovery does not succeed, an ACME client MAY fall back
to a default ACME server (e.g. a publicly accessible ACME server).


## ACME Operations

An ACME client MAY record (cache) the URI of the ACME server located
via service discovery and MAY use the cached server for new account
and new order operations, without performing service discovery each
time.

When storing data about accounts and orders, ACME clients SHOULD
record the URI of the actual ACME server used.  When retrieving or
revoking certificates or performing account operations, the client
SHOULD use the recorded URI to contact the ACME server and SHOULD
NOT perform service discovery.

When renewing or replacing a certificate, if the recorded ACME
server cannot be contacted or fails to issue a certificate, a client
MAY perform service discovery to attempt to locate an alternative
ACME server that may be able to issue the certificate.


# IANA Considerations

## Underscored Node Name for ACME Service Discovery

Per RFC 8552, please add the following entry to the "Underscored and
Globally Scoped DNS Node Names" registry:


```
   +---------+--------------+-----------------+
   | RR Type | _NODE NAME   | Reference       |
   +---------+--------------+-----------------+
   | URI     | _acme-server | {this document} |
   +---------+--------------+-----------------+
```

# Security Considerations

## TLS and Certificate Validation

Use of TLS is REQUIRED by the ACME specification [@!RFC8555].  X.509
[@!RFC5280] supports the Uniform Resource Identifier name type in
the Subject Alternative Name extension, but this name type is not
widely supported by TLS clients or certificates.  HTTP Over TLS
[@?RFC2818] does not describe the use of a URI-ID for HTTP services.
Therefore when an ACME server was located via service discovery its
certificate MUST be validated according to both RFC 5280 and
[@!RFC6125] and MUST match the host from the target URI against the
dNSName (if the host is a reg-name) or iPAddress (if the host is an
IP address) value(s) in the Subject Alternative Name extension.  The
client SHOULD NOT use a URI-ID when validating the server's
certificate.


## Parent Domain Selection

An attacker who is able to influence an ACME client's candidate
parent domains can influence which ACME server the client uses, or
cause service discovery to fail.  The attacker could use this
capability to perform a denial of service against the ACME client
(i.e. the client cannot acquire or renew a certificate), or against
parties that validate certificates issued to the client (because
they do not trust the issuing CA or because the certificate is
invalid in some way), or against a target ACME server (by directing
many clients to it).  ACME client implementers should carefully
consider which methods of determining the parent domain(s) are
appropriate for their use cases, and the security implications of
their chosen methods.

An ACME client may form candidate parent domains by removing one or
more labels from the left side of some other DNS name (e.g. the host
name of the client's machine).  If too many labels are removed, the
ACME client could perform DNS queries in zones outside the control
of the organisation that operates the ACME client.  As a result, the
ACME client could locate and use an ACME server that the
organisation does not intend.

To mitigate this risk, it is RECOMMENDED that clients limit the
amount of label pruning that occurs.  It is not possible to make a
concrete recommendation that is suitable for all environments.
Implementers must consider what is appropriate for their use cases
and environments.  The candidate parent domain ordering requirements
also mitigate this risk.


## DNS Security

Without ACME service discovery, an ACME client must be configured or
hard-coded to use a particular ACME server, specified as the HTTPS
URI of the server's directory resource.  Typically the host will be
a DNS name rather than an IP address, and one or more DNS queries
are necessary to resolve the host's DNS name to an IP address.

When service discovery is used, the URI of the ACME server is
obtained from a DNS URI record.  If an attacker is able to spoof the
\_acme-server URI record for a candidate parent domain name, the
attacker could cause service discovery to fail or could direct the
client to an ACME server of the attacker's choosing.  This could
constitute a denial of service attack against the client, against
parties that validate certificates issued to the client, or against
the target server.

Therefore it is RECOMMENDED that URI records used for ACME service
discovery be secured using DNSSEC.  It is RECOMMENDED that ACME
clients make DNS URI queries via DNSSEC-validating stub or recursive
resolvers.

Some methods of candidate parent domain selection may involve DNS
queries.  For example, a client could query PTR records to find a
host name, from which it derives a candidate parent domain.
Implementers must consider the security of DNS data used for parent
domain selection.


{backmatter}
