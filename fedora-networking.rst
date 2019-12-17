Networking
==========

DNS
---

Network interface configs live at
``/etc/sysconfig/network-scripts/if-XXX``.

To force ``.local`` resolution to DNS remove ``mdns
[NOTFOUND=return]`` from hosts line in ``nsswitch.conf``.

To tell NetworkManager to never touch ``/etc/resolv.conf``, in
``/etc/NetworkManager/NetworkManager.conf`` put::

  [main]
  dns=none


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


Wifi
----

If Intel wireless device drops the ball, unload and reload kernel
module::

    $ sudo rmmod iwlmvm && sudo rmmod iwlwifi
    $ sudo modprobe iwlwifi


IPv6
----

Configure IPv6 with static address and gateway::

  # nmcli c m eth0 \
      ipv6.method manual \
      ipv6.address fd00::1231:82:0 \
      ipv6.gateway fd00::1
  # nmcli c u eth0

Note there are some short aliases for some options, e.g.
``ip6`` and ``gw6``.  See ``nmcli(1)`` for details.

Configure host for IPv6, static address, static DNS and set default
route (IPv4 disabled)::

  # nmcli connection modify en

  # nmcli c m enp1s0 \
    ipv4.method disabled ipv4.address "" \
    ipv6.method manual ipv6.address "fd00::f31:0" \
    ipv6.dns "fd00::1" ipv6.gateway fd00::1
  # nmcli c u enp1s0
  # ip addr del 127.0.0.1/8 dev lo
