Open questions
==============

- how can FreeIPA services be extended to refer to a dogtag profile?
  (with default, e.g. caIPAserviceCert?).  LDAP attributes,
  presumably.

- do we favour more customizable profiles over a proliferation of
  profiles?

- extend user/host/service schema with profile/sub-CA to use?

- Sub-CA
  - use existing sub-ca capability of dogtag (complex!)?
  - IPA itself act as sub-CA? (preferably not)
  - implement and use "lightweight" sub-CAs in Dogtag
    - **profile** specifies sub-CA?

- Special attributes in certificates?  OU in SN?
  - servers can be configured to ensure the ducks are in a row
  - still a single certificate validity (cryptographic) domain


Dogtag interface
================

- CA interface is ipaserver.plugins.dogtag.ra
- ``class ra(ipaserver.plugins.rabase.rabase)``
- this is currently only concrete RA (Request Authority)
  implementation
- some contants and low-level machinery  (e.g. https request
  methods) are defined in ``ipapython.dogtag``.


Certificate request
-------------------

- hits CA interface at ``/ca/eeca/ca/profileSubmitSSLClient``
  - uses ``caIPAserviceCert`` profile unconditionally
  - ee = "end entity"?
