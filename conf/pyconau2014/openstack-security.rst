OpenStack Security - Grant Murphy (Red Hat)
===========================================

Agenda:

- vuln mgmt process

- vuln metrics

- common Python mistakes that lead to security problems


Vulnerability Management Team
=============================

- members are independent and security-minded

- ensure vulns dealt with in a timely manner and downstream
  stakeholders are notified in a coordinated and fair manner.

- Process flowchart:
  https://wiki.openstack.org/wiki/VulnerabilityManagement


Getting notified
================

- openstack-announce@lists.openstack.org
- openstack@lists.openstack.org
- oss-security@lists.openwall.com

Can register for advance notice of issues (i.e. during embargo
period).


Helpful tips
============

- If you raise a private security issue for an OpenStack project,
  let the VMT manage the privacy of the issue

- We do NOT have a bug bounty program (reporters are given credit).

- Just because the Launchpad bug is private doesn't mean the gerrit
  review will be.  Only attach patches to the Launchpad bug for
  review of embargoed issues.


Vulnerability metrics
=====================

- catalogued entire OSSA history for the VMT into a structured data
  format (JSON)

- built a simple website that presents this information

- missing CWE assessment

- missing git commit sha1 of when flaw was introduced/fixed and
  detailed project version info

- CVSS2 score and impact ratings based on Red Hat data

- basis for automation of VMT process moving forward

- url: http://openstack-security.info (WIP)


Advisories by project
=====================

- Nova has had most issues.

- Keystone next most, but the most Important issues (cf Critical,
  Moderate, Low)

- There has not yet been a Critical-rated issue.


Advistories classification
==========================

# denial of service
# information disclosure
# access control
# ... the rest


Reports by Company
==================

# Red Hat (26)
# HP (16)
# Rackspace (10)
# unknown (10)
# Nebula (4)
# ... the rest


Common Python mistakes
======================

- *Read the manual*
- API calls that have security implications are well marked.

Examples:

- use ``compare_digest`` for HMAC comparison.
- ``subprocess`` module, ``shell=True`` can be security hazard
  (unsanitised user input).
- ``httplib`` does not do any verification of server's certificate.
- ``xml`` module is not secure against maliciously constructed data.
- never extract tarfiles from untrusted sources (can overwrite any
  file executing process has access to).
- not creating secure temp files.
- ``pickle`` not secure against erroneous or maliciously constructed
  data.
- These warnings are all on the website but few of them appear in
  ``help`` output.  Maybe it should be there?


Summary
=======

- Join the OSSG (OpenStack Security Group)
- currently > 150 members
- #openstack-security on freenode
- mailing list: openstack-security@lists.openstack.org

OSSG activities:

- OpenStack Security Notes (OSSN)
- OpenStack security guide
- Consult on security vulnerabilities
- Security reviews
- Threat modelling
- Static analysis
- Secure development guidelines
- Security audits
- lots of other things in progress
