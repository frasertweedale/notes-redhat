yum
===

Add a repo::

  sudo cp example.repo /etc/yum.repos.d/

To erase packages machine some pattern::

  yum list installed |grep GIT | cut -d ' ' -f 1 | xargs sudo yum erase -y


Networking
==========

- network interface configs at /etc/sysutils/network-scripts/if-XXX
- remove the ``mdns [NOTFOUND=return]`` from hosts line in
  ``nsswitch.conf`` to resolve ``.local`` via dns.

Firewall
--------

Disable the default firewall::

  $ sudo systemctl disable firewalld
  $ sudo systemctl stop firewalld
