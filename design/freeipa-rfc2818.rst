..
  Copyright 2016 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


{{Admon/important|Work in progress|This design is not complete yet.}}
{{Feature|version=4.4.0|ticket=4970|ticket2=5706|author=Ftweedal}}


.. Title: Service certificate compliance and compatibility improvements

*********
DELETE ME
*********


Overview
========

`RFC 2818 - HTTP Over TLS`_ deprecates the practice of carrying the
subject hostname in the Subject DN Common Name (CN) field.  Pursuant
to RFC 2818 some TLS libraries now issue warnings when they
encounter certificates that do not have the DNS name at which the
service was accessed in the subjectAltName (SAN) extension.  FreeIPA
currently does not take measures to ensure that host or service
certificates it issues are compliant with RFC 2818.  This design
proposes a measure to, where appropriate, copy the contents of the
CN into the subjectAltName extension as a dNSName, resulting in an
RFC 2818-compliant certificate.

`RFC 6125 - Best Practices for Checking of Server Identities in the
Context of Transport Layer Security (TLS)`_ further clarifies that
certificates SHOULD include a DNS-ID and that CAs SHOULD NOT issue
certificates with a CN-ID unless another specification explicitly
requires or encourages it.  RFC 6125 has greater scope than this
design, all work for this design should comply with RFC 6125.

.. _RFC 2818 - HTTP Over TLS: http://tools.ietf.org/html/rfc2818#section-3.1
.. _RFC 6125 - Best Practices for Checking of Server Identities in the Context of Transport Layer Security (TLS): https://tools.ietf.org/html/rfc6125


`RFC 5280`_ defines the maximum length of the CN to be 64 characters
(the maximum size in bytes depends on the string encoding used).  It
is now common to encounter DNS names longer than 64 characters,
particularly in cloud infrastructure (see ticket `#4415`_ for an
example of an issue caused by hostnames exceeding this limit).  To
support service and host certificates where the hostname is longer
than 64 characters, FreeIPA must support carrying the subject
information in the subjectAltName extension *only* (the
subjectAltName extension must be marked *critical* in this
scenario).

.. _RFC 5280: http://tools.ietf.org/html/rfc5280#section-4.1.2.6
.. _#4415: https://fedorahosted.org/freeipa/ticket/4415


Use Cases
=========

Per the overview, the goal of this design is to avoid deprecated
ways of providing subject naming information in a certificate (which
some TLS libraries are now warning about) and to support subject DNS
names longer than 64 characters.


Design
======

Copying CN to SAN dNSName
-------------------------

This measure involves the creation of a new Dogtag profile component
that, on profiles that enable it, performs the following steps:

1. Retrieve the Subject Common Name from the certificate data.

2. Retrieve the subjectAltName extension from the certificate data,
   or create an empty subjectAltName extension if it does not exist.

3. Search the subjectAltName extension for a dNSName value that
   matches the Common Name.  If not found, add the Common Name to
   the subjectAltName extension as a dNSName.

The component shall be called ``SubjectAltNameCopyCNDefault``.
Its instantiation shall be called ``subjectAltNameCopyCNDefaultImpl``.
The ``caIPAserviceCert`` profile shall be updated to use this
profile component.

Caveats
^^^^^^^

The profile component that performs these steps must execute after
other profile components that add or modify the Common Name and
subjectAltName extension.  It is preferable that this condition be
encoded as part of the definition of the component itself, such that
Dogtag can enforce it.  However, if this is not possible, it would
be required that the profile configuration introduce the component
after the other components which must run first; any such
requirement must be clearly documented.


SAN-only certificate support
----------------------------

Let's first clarify the requirement for SAN-only certificates:

1. A DNS name longer than 64 characters *cannot* be carried in the
   CN but can (and therefore must) be carried as a dNSName value in
   the subjectAltName extension.

2. In the absense of other distinguishing data in the Subject DN,
   the entire Subject DN must be the empty sequence, because RFC
   5280 states:

      Where it is non-empty, the subject field MUST contain an X.500
      distinguished name (DN).  The DN MUST be unique for each subject
      entity certified by the one CA as defined by the issuer field.

3. If the Subject DN is empty, the subjectAltName extension must be
   marked *critical*.


The existing subject name profile policy component,
``SubjectNameDefault``, does not offer enough flexibility to handle
either the presence or absense of a Subject DN field (e.g. CN).
For example, the ``caIPAserviceCert`` profile configuration::

  policyset.serverCertSet.1.default.class_id=subjectNameDefaultImpl
  policyset.serverCertSet.1.default.name=Subject Name Default
  policyset.serverCertSet.1.default.params.name=CN=$request.req_subject_name.cn$,O=IPA.LOCAL

shows that:

- The "substituted" Subject DN will be invalid if there is no CN in
  the CSR.  (The ``"CN="`` key is an immutable part of the template
  string), and;

- There is no mechanism that provides for "optional" fields in the
  Subject DN.  (A separate profile would be needed).


``SubjectNameFieldsDefault`` profile policy component
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It is clear that a new Subject Name profile policy component is
needed to handle the case of possibly-absent Subject DN fields.
This component would need to support configuration that allows a
profile to define:

- Which Subject DN fields, if any, are optional (if any)

- Which Subject DN fields, if absent, cause the final Subject DN to
  be the empty sequence (i.e. fields that *distinguish* the
  subject).

With these requirements in mind, a configuration suitable to replace
the above configuration would be::

  policyset.serverCertSet.1.default.class_id=subjectNameFieldsDefaultImpl
  policyset.serverCertSet.1.default.name=Subject Name Fields Default
  policyset.serverCertSet.1.default.params.cn=$request.req_subject_name.cn$
  policyset.serverCertSet.1.default.params.o=IPA.LOCAL
  policyset.serverCertSet.1.default.params.excludeIfEmpty=cn
  policyset.serverCertSet.1.default.params.emptySubjectIfFieldEmpty=cn
  policyset.serverCertSet.1.default.params.order=cn,o

Breaking this configuration down:

- A template is provided for each field (``cn``, ``o``, etc.) that
  *may* be included in the final Subject DN.  The existing template
  substitution mechanism is used to format the value for each field.

- The ``excludeIfEmpty`` parameter is a (possibly empty)
  comma-separated list of fields that shall be omitted from the
  final Subject DN if their values (after substitution) are empty.
  It is an error if a field that is *not* included in the list is
  empty (after substitution).  This parameter is **optional** and
  defaults to the empty list.

- The ``emptySubjectIfFieldEmpty`` parameter is a (possibly empty)
  comma-separated list of fields that if empty (after substitution)
  cause the final Subject DN to be the empty list.  This parameter
  is **optional** and defaults to the empty list.

- The ``order`` parameter is a comma-separated list defining the
  order (from "most specific" to "least specific") of the RDNs in
  the final Subject DN.  This parameter is **required**.  Each
  listed field must have a corresponding template in the
  configuration.

The profile policy component shall be called ``SubjectNameFieldsDefault``.
Its instantiation shall be called ``subjectNameFieldsDefaultImpl``.
The ``caIPAserviceCert`` profile shall be updated to use this
component instead of ``SubjectNameDefault``.


Marking the SAN extension as critical
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The SAN extension must be marked critical when subject naming
information is present only the subjectAltName extension.

**TODO** need to define mechanism to achieve this.  It would
definitely be possible with another profile component to run at the
end, but a less intrusive mechanism would be better.


``ipa cert-request`` changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``ipa cert-request`` command must be updated to handle CSRs
where no subject information is carried in CSR Subject DN (CN field
in particular).  This will be achieved with the following changes.

- Initialise an empty *DNS names* list.

- The existing "CN matches principal name" check is deferred for
  certificate requests where the target principal is a *host* or
  *service*.  (The check is retained for *user* principals).

- For hosts and services, the CN, if present, is appended to the
  list of *DNS names*.

- For each dNSName in the subjectAltName extension, ensure that the
  name corresponds to a principal that is *managed by* the target
  principal, then append the name to the list of *DNS names*.

- For hosts and services, after processing of the SAN extension is
  complete, ensure that one name in the *DNS names* list matches the
  target principal.  This is to prevent issuance of a certificate
  that omits the target principal.


Wildcard certificates
---------------------

FreeIPA currently does not support wildcard certificates, although
`ticket #3475`_ is an RFE to support them.  It should also be noted
that `RFC 6125`_ essentially deprecates the issuance of wildcard
certificates, but several established use cases still require them.

Regarding this design, no special handling of names containing
wildcards is required.  Enforcement of restrictions on where
wildcards may appear in names is assumed.  The
``SubjectAltNameCopyCNDefault`` component, if used, will copy a CN
whether or not it contains a wildcard.  Wildcards are also allowed
in SAN dNSNames, so there is no bearing on SAN-only certificates.

.. _ticket #3475: https://fedorahosted.org/freeipa/ticket/3475
.. _RFC 6125: https://tools.ietf.org/html/rfc6125


Implementation
==============


Feature Management
==================

No UI or CLI is required to manage these features.

The ``certutil`` instructions "New certificate for Host/Service"
dialog in the Web UI should be updated to indicate how to add a
DNS names to the subjectAltName request extension, e.g.::

  # certutil -R -d <database path> -a -g <key size>
    -s 'CN=f23-2.ipa.local,O=IPA.LOCAL' -8 'f23-2.ipa.local'

The new Dogtag profile policy components must be documented so that
administrators can understand their purpose and how to use them in
custom profiles.


Upgrade
=======

Each CA clone has the file ``/etc/pki/pki-tomcat/ca/registry.cfg``,
which defines the name and class of each profile policy component to
instantiate.  This file must be updated to instantiate the new
profile policy components.  This should be done as part of Dogtag's
upgrade procedure.

The ``caIPAserviceCert`` profile configuration must be updated to
use the new profile policy components.  Because FreeIPA now owns its
profiles, this shall be done as part of the FreeIPA upgrade
procedure.


How to Test
===========



Test Plan
=========
