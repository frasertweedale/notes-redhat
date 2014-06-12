Introduction
============

Use cases are emerging for user certificates in FreeIPA.  Known use
cases are detailed below.

Dmitri's comments on the use cases we ought to focus on first:

  I think it is important to differ short term and long term
  certificates for users.  The long term certificates are used for
  authentication and signing.  They are put on devices like smart
  cards. They need to be associated with the user in the back end.
  They can be revoked.  The short lived certificates do not need to
  be recorded on the server side.  They are just issued and since
  they do not live long there is no need to record them in the back
  end or to try to revoke them. This IMO a crucial difference.

  For now we focus on the long living certificates for hosts,
  services, devices and short lived certificates for any identity.
  IMO long lived certs for users is a separate big use case that we
  currently should set aside and solve after we solve the other use
  cases.


Use cases
=========

VPN certificates
----------------

A user logs into an IPA domain.  They are not connected to a wired
network so a background service (SSSD or other) acquires a
short-lived client certificate for connecting to the company VPN
(and connects it, thus saving the user some time and hassle).


DNP3 Smart-Grid
---------------

A DNP3 Smart-Grid user's roles are updated.  A new IEC 62351-8
certificate must be signed by the CA and provided to the DNP3 to be
sent to outstations on the network.


802.11 EAP-TLS
--------------

John Dennis points out:

  A common discussion on the RADIUS mailing lists is the desire to
  deploy using `EAP-TLS`_ but the difficulty of provisioning user
  certs is always the stumbling block.

Nathaniel's comments on `EAP-TTLS`_ (Tunnelled Transport Layer
Security):

  Yes, this I understand. But in my experience, TTLS is being widely
  deployed in combination with an inner client authentication
  precisely because TLS was so hard to maintain. MS fought TTLS for
  a long time and eventually gave in in Windows 8 precisely because
  so many people were deploying TTLS with an inner authenticator.

  I can't think of a single example of a TLS deployment that can't
  be given a better user experience by migrating to TTLS (old
  Windows excluded of course).

.. _EAP-TLS: http://en.wikipedia.org/wiki/Extensible_Authentication_Protocol#EAP-TLS
.. _EAP-TTLS: http://en.wikipedia.org/wiki/Extensible_Authentication_Protocol#EAP-TTLS


TLS client authentication for other network services
----------------------------------------------------

TLS client authentication is sometimes used for HTTP and may be used
with other TCP/IP services.
