Pod hostnames and FQDN
======================

Complex and legacy applications can make strict and/or pervasive
assumptions about their execution environment.  An application
relying on the host having a *fully qualified domain name (FQDN)* is
an example of this kind of assumption.  Indeed this is a
particularly thorny kind of assumption because the hostname/FQDN can
be queried in many ways, and they don't always agree!

Unsurprisingly this issue has come up as we try to containerise
FreeIPA and operationalise it for OpenShift.  Whereas container
runtimes like Podman and Docker offer full control of a container's
FQDN, in Kubernetes (and by extension OpenShift) there are limited
ways to configure a pod's hostname and FQDN.  Furthermore, there is
currently no way to use a pod's FQDN as the (Kernel) hostname.

In this post I will outline the challenges and document the
attempted workarounds as we try to make FreeIPA run in OpenShift in
spite of the Kubernetes hostname restriction.


Querying hostname/FQDN
----------------------



Pod hostname configuration
--------------------------

TODO


Possible workaround: ConfigMap
------------------------------

TODO


Possible workaround: hoodwink FreeIPA
-------------------------------------

FreeIPA asks for the host FQDN or the system hostname (in order to
check that it is a FQDN) in lots of places.  If we find all those
places we can abstract away the check.  For a traditional
deployment, we continue to ask in a traditional way, e.g.
``hostname``, ``hostnamectl`` or reading ``/etc/hosts``.  But in an
OpenShift deployment we can instead return some other configuration
supplied via a ``ConfigMap`` or volume mount.

This approach would probably mean a lot of small changes in the
FreeIPA codebase.  But unifying how we query the hostname and FQDN
across the codebase seems like a nice thing to do.  The bigger
quesion is whether there are any other programs we depend on that
would also have problems in an OpenShift environment.  For example,
MIT Kerberos, BIND, etc.  Patching FreeIPA and other projects we
(Red Hat) steer is tractable.  Patching other projects upon which we
depend is an unknown (i.e. there is a risk we might not be able to).


Next steps
----------

TODO
