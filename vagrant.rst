Hostname
========

To set hostname::

  <machine>.vm.hostname = "foo.local"

Machine will resolve own hostname to ``127.0.0.1`` (on centos/7 at
least).


DNS
===

``vagrant-dnsmasq``
-------------------

Install plugin (some dependencies need gem native extension)::

  % sudo dnf install ruby-devel libvirt-devel
  % vagrant plugin install vagrant-dnsmasq
