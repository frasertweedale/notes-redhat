Managing boxes
==============

Add box from filesystem::

  % vagrant box add --name <name> <path>
  ==> box: Adding box '<name>' (v0) for provider: 
      box: Downloading: file://<path>
  ==> box: Successfully added box '<name>' (v0) for 'virtualbox'!

List boxes::

  % vagrant box list
  box-cutter/fedora22 (virtualbox, 2.0.2)
  centos/7            (libvirt, 1508.01)
  centos/7            (virtualbox, 1508.01)
  ipa-workshop        (virtualbox, 0)



Hostname
========

To set hostname::

  <machine>.vm.hostname = "foo.local"

Machine will resolve own hostname to ``127.0.0.1`` (on centos/7 at
least).


DNS
===

``vagrant-hostmanager``
------------------------

Install plugin::

  % vagrant plugin install vagrant-hostmanager


``vagrant-dnsmasq``
-------------------

Install plugin (some dependencies need gem native extension)::

  % sudo dnf install ruby-devel libvirt-devel
  % vagrant plugin install vagrant-dnsmasq
