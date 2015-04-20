Networking
==========

- network interface configs at /etc/sysconfig/network-scripts/if-XXX
- remove the ``mdns [NOTFOUND=return]`` from hosts line in
  ``nsswitch.conf`` to resolve ``.local`` via dns.

DHCP
----

DHCP server might dish out different IP addresses to the same
machine if the client ID is not based on the MAC address.  To
remedy::

    $ echo "send dhcp-client-identifier = hardware;" >> /etc/dhcp/dhclient.conf


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
