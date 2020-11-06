Pod hostnames and FQDN
======================

Some complex or legacy applications make strict and pervasive
assumptions about their execution environment.  Relying on the host
having a *fully qualified domain name (FQDN)* is an example of this
kind of assumption.  Indeed this is a particularly thorny kind of
assumption because there are several ways an application can query
the hostname, and they don't always agree!

It is not surprising that we have hit this particular issue during
our effort to containerise FreeIPA and operationalise it for
OpenShift.  Whereas container runtimes like Podman and Docker offer
full control of a container's FQDN, Kubernetes (and by extension
OpenShift) is more strongly opinionated.  By default, a Kubernetes
pod has only a short name, not a fully qualified domain name.  There
are limited ways to configure a pod's hostname and FQDN.
Furthermore, there is currently no way to use a pod's FQDN as the
(Kernel) hostname.

In this post I will outline the challenges and document the
attempted workarounds as we try to make FreeIPA run in OpenShift in
spite of the Kubernetes hostname restriction.


Querying the FQDN
-----------------

There are several ways an a program can query the host's hostname.

- Read ``/etc/hostname``.  The name in this file may or may not be
  fully qualified.

- Via the POSIX ``uname(2)`` system call.  The ``nodename`` field in
  the ``utsname`` struct returned by this system call is intended to
  hold a network node name.  Once again, it could be a short name or
  fully qualified.  Furthermore, on most systems it is limited to 64
  bytes.  From userland you can use the ``uname(1)`` program or
  ``uname(3)`` library routine.  The ``gethostname(2)`` and
  ``gethostname(3)`` are another way to retrieve this datum.

- On systems that use *systemd* the ``hostnamectl(1)`` program can
  be used to get or set the hostname.  Once again, the hostname is
  not necessarily fully qualified.  ``hostnamectl`` distinguishes
  between the *static* hostname (set at boot by static
  configuration) and *transient* hostname (derived from network
  configuration).  These can be queried separately.

- A program could query DNS PTR records for its non-loopback IP
  addresses.  This approach could yield zero, one or multiple FQDNs.

- The ``getaddrinfo(3)`` routine when invoked with the
  ``AI_CANONNAME`` flag can return a FQDN for a given hostname (e.g.
  the name return by ``gethostname(2)``.  This allows any *Name
  Service Switch (NSS)* plugin to provide a canonical FQDN for a
  short name.  NSS is usually configured to map hostnames using the
  data from ``/etc/hosts``, but there are other plugins including
  for *systemd-resolved*, *dns* and *sss* (SSSD).


Auditing FQDN query behaviour
-----------------------------

In order to decide how to proceed, we first needed to audit both
FreeIPA and its dependencies to see how they query the hostname and
host FQDN.  I have published `the results of this audit`_.  It is
perhaps not exhaustive, but hopefully fairly thorough.

.. _the results of this audit: https://docs.google.com/document/d/e/2PACX-1vQzxjMw3eqkpuPfqaLbCW-GN8gwS1QvFjrs9TnPM02DMfNqBVSGapqITvAyZyxc2TN9jJShJrbqGayC/pub



Pod hostname configuration
--------------------------

We assume that the operator (human or machine) will create pods with
deterministic FQDN.  That is, it knows what the pod's FQDN should be
(or rather, what it wants the application running in the pod to
believe is the FQDN).  The operator can use some mechanism to convey
the FQDN value to the programs running in the pod.


Possible workaround: ConfigMap
------------------------------

TODO


FreeIPA changes
---------------

FreeIPA asks for the host FQDN or the system hostname (in order to
check that it is a FQDN) in lots of places and uses different query
mechanisms.  If we find all those places we can abstract away the
check.  In practice, we would provide separate library support for C
code and Python code.

With hostname query logic abstracted behind these interfaces, we can
perform the lookup in whatever way is appropriate for the deployment
environment.  For a traditional deployment, we use
``gethostname(3)`` and ``getaddrinfo(3)`` with ``AI_CANONNAME``.
But in an OpenShift deployment we can instead return a value
supplied via a ``ConfigMap`` or other appropriate mechanism.

Upstream pull request `#5107`_ implemented this change.  It
consolidated the hostname query behaviour into new C and Python
routines.  It did not implement alternative behaviour for other
environments such as OpenShift, but abstracting the query behind a
single interface (for each language) makes it easy to do this later.

.. _#5107: https://github.com/freeipa/freeipa/pull/5107

TODO


Next steps
----------

The investigation into hostname/FQDN query behaviour of FreeIPA's
dependencies continues.  In particular, we have not yet undertaken a
thorough investigation of Samba, which is used for Active Directory
trust support.  Also, there are open questions about some other
dependencies including Dogtag and Certmonger.  It is possible that
configuration or code changes will be required to make these
programs work in environments
