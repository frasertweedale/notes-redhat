..
  Copyright 2018  Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.

.. CERTIFICATE RENEWAL BEHAVIOUR

.. raw:: mediawiki

  {{Admon/important|Work in progress|This design is not complete yet.}}
  {{Feature|version=|ticket=7580|author=Ftweedal}}

Overview
--------

In the past, FreeIPA automatically revoked certificates upon
renewal.  This behaviour was acceptable when the *one certificate
per service* was the only thing that was possible.

With the implementation of `custom certificate profiles`_ and `user
certificates`_, it was decided to stop revoking certificates upon
renewal.  Because of the possibility of multiple certificates (for
different purposes) per principal, it was not always known which
certificate should be revoked.  Revocation list growth was also a
concern.

.. _custom certificate profiles: V4/Certificate Profiles
.. _user certificates: V4/User Certificates

This change in behaviour continues to confuse users and developers.
For example, https://pagure.io/freeipa/issue/7482 was filed,
suggesting the lack of revocation of the old certificate upon
renewal was a regression.  A patch and `pull request`_ were created
before, in the ensuing discussion, it was discovered that this was
the intended behaviour.  This episode prompted a debate about what
our certificate revocation behaviour should be.

.. _pull request: https://github.com/freeipa/freeipa/pull/1915#issuecomment-388295460

The purpose of this design is to formalise what FreeIPA's
certificate revocation behaviour(s) should be (being the canonical
reference for such behaviour), and to outline any changes necessary
to implement the behaviour(s).


Terminology
^^^^^^^^^^^

*IPA-managed CA*
  The IPA CA, any lightweight CA hosted in the Dogtag instance, or
  any other CA that FreeIPA can cause to revoke certificates.


Design guidelines
^^^^^^^^^^^^^^^^^

The following guidelines inform this design.  They are important
considerations, not unbreakable rules.  Deviations should be
justified.

- Command behaviour should be consistent across use cases.  For
  example, a command should not revoke a certificate in some
  circumstances but not others (unless explicitly told to do so).

- Similar commands for different principal types should have similar
  behaviour.  For example, if ``service-disable`` revokes
  certificates, then ``user-disable`` should revoke certificates.

- Specialised behaviour should belong to specialised commands.  For
  example, a general command for manipulating LDAP objects should
  not have specialised behaviours for some attributes, such as
  revoking removed ``userCertificate`` values.

- Multiple simpler commands are better than single commands with
  complex behaviour and many options.  Yes, it might mean an
  administrator has to type more commands.  But automation reduces
  that concern, and it is easier for the administrator to get it
  right.

- Ideally, there should be a single command to accomplish a given
  action.  Administrators should not have to ask *"should I use
  service-mod or service-remove-cert?"*

Assumptions
^^^^^^^^^^^

**Hosts and services can have multiple certificates.**  The common
case is when host or services principals only need one certificate.
Although it may seem desirable to automatically revoke an old
certificate when it is renewed, in the general case where a subject
principal can have multiple certificates, it is not decidable which
of their existing certificates is being renewed (and should be
revoked, removed).

**A certificate is included in the ``userCertificate`` attribute of
at most one principal.** In this design we ignore the possibility of
a single ``userCertificate`` attribute value occurring on multiple
principals.  This situation does not arise in normal use.


Use Cases
---------

Issuance of a new certificate (non-renewal)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A host, service or user certificate is being requested for some new
purpose.  The subject may already have certificates for other
purposes.  Existing certificates *must not be revoked*.

Renewal due to impending expiry
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A certificate is requested to renew an existing certificate.  After
the new certificate is issued, it does no harm to revoke the old
certificate.  But it is *not necessary to revoke* the old
certificate, because it will soon expire.

Renewal for other reasons
^^^^^^^^^^^^^^^^^^^^^^^^^

A certificate could be renewed before its expiration time is near,
for any reason (e.g. re-key due to compromise, add a Subject
Alternative Name, etc.)  As a simplifying assumption, we'll treat
all revocation reasons the same way.  It is therefore *necessary to
revoke* the certificate that is being replaced (and only that
certificate).

Revocation without renewal
^^^^^^^^^^^^^^^^^^^^^^^^^^

A certificate (or its subject) may cease operation such that
revocation is required.  If a single certificate requires
revocation, in the common case, it should also be removed from the
subject's ``userCertificate`` attribute (if present).  If the
principal is being disabled or deleted, all of its certificates
should be revoked, whether it is a host, service or user principal.

**TODO** is there any case where an administrator would want to
disable/preserve a user but *not revoke certificates*?


Design
------

``cert-request``
^^^^^^^^^^^^^^^^

Based on the use cases above, requesting a new certificate is
*sometimes* associated with a desire to revoke *one* certificate.
Revocation as a default behaviour is wrong.

Could we make ``cert-request`` smart enough to guess what it should
do?  Fuzzy heuristics that could be employed to make a guess, e.g.
by examining certificate attributes, validity period, the subject
public key, the profile and CA that were used, and so on.  The
guessing logic would be complex, and could not guarantee a correct
answer.  It is not the right approach.

Keeping in mind the desire for consistent behaviour of commands, and
the fact that ``cert-request`` is already a complicated command, the
correct behaviour is for ``ipa cert-request`` to **never revoke any
certificate**, nor remove any ``userCertificate`` attribute value
from the subject principal's entry.

Differences from current behaviour
''''''''''''''''''''''''''''''''''

None.


``{host,service,user}-mod``
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Removal of a ``userCertificate`` attribute value **shall not revoke
the certificate**.

Rationale: The ``cert-revoke`` command already provides revocation
behaviour.  Non-IPA-managed certificates cannot be revoked by
FreeIPA, so revoking IPA-managed certificates violates the
consistency guideline.  Not all certificates that need revocation
will appear in the subject's ``userCertificate`` attribute (e.g. if
the profile does not store certificates), so explicit
``cert-revoke`` is still needed.  Furthermore, forcing the operator
to use ``cert-revoke`` allows them to specify a revocation reason.

Differences from current behaviour
''''''''''''''''''''''''''''''''''

Revocation behaviour needs to be removed from the ``service-mod``
and ``host-mod`` commands.  (**Backwards compatibility concern.**)


``{host,service,user}-remove-cert``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``{host,service,user}-remove-cert`` commands **shall not revoke
certificates**.

Rationale: The ``cert-revoke`` command already provides revocation
behaviour.  Non-IPA-managed certificates cannot be revoked by
FreeIPA, so revoking IPA-managed certificates violates the
consistency guideline.  Not all certificates that need revocation
will appear in the subject's ``userCertificate`` attribute (e.g. if
the profile does not store certificates), so explicit
``cert-revoke`` is still needed.  Furthermore, forcing the operator
to use ``cert-revoke`` allows them to specify a revocation reason.

Differences from current behaviour
''''''''''''''''''''''''''''''''''

Revocation behaviour needs to be removed from the
``service-remove-cert`` and ``host-remove-cert`` commands.
(**Backwards compatibility concern.**)


``{host,service,user}-{del,disable}``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When deleting or disabling a user, host or service it makes sense to
revoke certifiates.  (**QUESTION** counterexamples?)  Should
``{host,service,user}-{del,disable}`` revoke certificates, or not?

Points in favour:

- Unlike other commands that deal with individual certificates,
  there is no alternative command for revoking *all of a principal's
  certificates*.  Command proliferation is undesirable.

- This is the current behaviour for the ``host-`` and ``service-``
  commands.  Fewer behavioural changes are required.

Points against:

- A principal may have a mix of IPA-managed and non-IPA-managed
  certificates.  IPA cannot revoke the latter.  This violates the
  consistency guideline.

The decided behaviour is that these commands **shall revoke all
IPA-managed certificates** and, for the ``-disable`` and ``user-del
--preserve`` commands, **all IPA-managed certificates shall be
removed from the entry**.  The revocation reason shall be
``unspecified``.

Command output shall be updated to advise of any non-IPA-managed
certificates, so that an administrator may take appropriate actions.

Differences from current behaviour
''''''''''''''''''''''''''''''''''

The ``user-del`` and ``user-disable`` commands need to have the
revocation behaviour implemented.

The affected commands need to be enhanced to report the
non-IPA-managed certificates.


``ipa cert-revoke``
^^^^^^^^^^^^^^^^^^^

The ``cert-revoke`` command shall revoke the nominated certificate.
It shall not remove the revoked certificate from LDAP entries.

Differences from current behaviour
''''''''''''''''''''''''''''''''''

None.


Certmonger
^^^^^^^^^^

Unlike the ``cert-request`` command, Certmonger renewal helpers have
precise knowledge of the certificate being renewed.  It is also the
case that for any renewal performed via Certmonger, it is either
desirable to revoke the certificate (e.g. key rotation due to
compromise), or it is not a significant operational concern to
revoke the certificate (e.g. renewal due to impending expiry; the
revoked certificate appear on CRL only for a short time).

Therefore the ``ipa`` renewal helper **shall revoke the superseded
certificate** after successful issuance of a new certificate.

Furthermore, the accumulation of ``userCertificate`` attribute
values in principal entries where short-lived certificates are used
is a known pain point.  Therefore, Certmonger **shall remove the
superseded certificate from the principal's entry**.

**QUESTION** is this actually a good idea?  What are customer
expectations?  If you're rekeying due to compromise, surely it is
not too much a burden to ``getcert rekey`` *and* ``ipa
cert-revoke``?

Differences from current behaviour
''''''''''''''''''''''''''''''''''

The ``ipa`` renewal helper needs to be updated to invoke
``cert-revoke`` and ``{user,host,service}-remove-cert`` (or
equivalent) after a successfull renewal.


Implementation
--------------

TODO


Feature Management
------------------

There are no management knobs for controlling the revocation
behaviour.


Upgrade
-------

No specific upgrade steps are required.

Behavioural changes need to be prominently and clearly outlined in
release notes.  Changes in revocation behaviour could catch users
off guard.  It is important not to rush any changes through.  We'll
need to engage with our user base to explain the changes, and
outline steps to preserve the existing revocation behaviour if so
desired.


Test Plan
---------

TODO
