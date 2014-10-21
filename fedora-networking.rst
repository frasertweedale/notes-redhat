Networking
==========

- network interface configs at /etc/sysutils/network-scripts/if-XXX
- remove the ``mdns [NOTFOUND=return]`` from hosts line in
  ``nsswitch.conf`` to resolve ``.local`` via dns.

Firewall
--------

Disable ``firewalld``::

  $ sudo systemctl disable firewalld
  $ sudo systemctl stop firewalld

List the current configuration::

  $ sudo firewall-cmd --list-all

Open a port in the default zone::

  $ sudo firewall-cmd --add-port=8140/tcp [--permanent]

The ``--permanent`` flag causes the change to take effect the next
time the service starts.

Open ports for a service in the default zone::

  $ sudo firewall-cmd --add-service=dns [--permanent]
