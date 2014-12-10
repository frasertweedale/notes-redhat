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
