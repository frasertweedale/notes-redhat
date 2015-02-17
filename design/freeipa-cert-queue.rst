..
  Copyright 2015 Red Hat, Inc.

  This work is licensed under a
  Creative Commons Attribution 4.0 International License.

  You should have received a copy of the license along with this
  work. If not, see <http://creativecommons.org/licenses/by/4.0/>.


{{Admon/important|Work in progress|This design is not complete yet.}}
{{Feature|version=4.2.0|ticket=4907}}


Overview
========

With the arrival of [[V4/Certificate Profiles]] and [[V4/Sub-CAs]],
we will initially be issuing certificates automatically provided the
certificate request is permitted by the ACIs.  This design proposal
adds the ability to work with certificate profiles that do not
automatically issue certificates, instead enqueuing requests for
manual processing.  It adds commands to list, review, approve or
reject certificate requests, and is primarily an interface to
underlying Dogtag capabilities.


Use Cases
=========

Review and approval of certificate requests
-------------------------------------------

Once user certificates are allowed via profiles, the next RFE is
likely to be a queue management system so that certificates are not
automatically issued.


Design
======

Dogtag already has the capability to enqueue, review, approve, deny
or delete certificate requests, in cases where certificates are not
automatically issued.  FreeIPA will expose a subset of Dogtag's
capabilities for managing these queues.

Existing ACIs will be used to control which entities can issue
requests to which CAs, using which profiles.


Implementation
==============



Feature Management
==================

UI
--

**TODO**


CLI
---

``ipa certrequest-find <cahandle>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Search for or list pending certificate requests for the given CA.


``ipa certrequest-show <cahandle> <requestId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Show detail of the given certificate request.


``ipa certrequest-approve <cahandle> <requestId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Approve the certificate request, resulting in certificate issuance.


``ipa certrequest-reject <profileId>``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Reject the certificate request.


Upgrade
=======

No upgrade procedures are required.


How to Test
===========

..
  Easy to follow instructions how to test the new feature. FreeIPA
  user needs to be able to follow the steps and demonstrate the new
  features.

  The chapter may be divided in sub-sections per [[#Use_Cases|Use
  Case]].


Test Plan
=========

..
  Test scenarios that will be transformed to test cases for FreeIPA
  [[V3/Integration_testing|Continuous Integration]] during
  implementation or review phase. This can be also link to
  [https://git.fedorahosted.org/cgit/freeipa.git/ source in cgit] with
  the test, if appropriate.


Dependencies
============

- [[V4/Sub-CAs]]


Author
======

Fraser Tweedale

Email
  ftweedal@redhat.com
IRC
  ftweedal
