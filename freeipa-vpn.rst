FreeIPA OpenVPN integration
===========================

The big ideas:

- Having to connect to domain, connect VPN manually takes a small
  amount of time (which adds up), and it is annoying, esp. when e.g.
  going to meetings etc.

- Can we have a service (SSSD or other) automatically retrieve VPN
  certificates and connect to a VPN?

- Can we support Cisco VPN and OpenVPN?  Others?

Existing documentation
----------------------

OpenVPN PKI overview
  http://openvpn.net/index.php/open-source/documentation/howto.html#pki

OpenVPN Key Usage and EKU parameters
  http://openvpn.net/index.php/open-source/documentation/howto.html#mitm

Cisco PKI overview
  http://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/Security/DCertPKI.html

Notes
-----

- Cisco max key size supported is 2048
