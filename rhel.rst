RHEL notes
==========

Network
-------

Edit ``/etc/sysconfig/network-scripts/ifcfg-eth0`` and set::

  ONBOOT=yes
  PEERDNS=no
  DNS1=192.168.xxx.xxx
  BOOTPROTO=dhcp

Or as appropriate.  On RHEL 6 add nameserver to
``/etc/resolv.conf``.


Firewall
--------

RHEL 6::

  # service iptables stop


Hostname
--------

Update ``/etc/hostname``.


Subscription
------------

Register the system to a subscription management service::

  % subscription-manager register
  Username: <username>
  Password: 
  The system has been registered with ID: <uuid>

  % subscription-manager attach --auto
  Installed Product Current Status:
  Product Name: Red Hat Enterprise Linux Server
  Status:       Subscribed


KVM image
---------

How to change the password (guestfish):
https://access.redhat.com/discussions/664843


Devel
-----

``rhpkg`` and ``brew`` in repo (Fedora)::

  [rcm-tools-fedora-rpms]
  name=RCM Tools for Fedora $releasever (RPMs)
  baseurl=http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-F-$releasever/compose/Everything/$basearch/os/
  enabled=1
  gpgcheck=0
