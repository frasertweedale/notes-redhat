Listening to a network port
---------------------------

Configure ipa-otpd to listen to a network port.

In ``/usr/lib/systemd/system/ipa-otpd@.service``, add the RADIUS
port to the ``[Socket]`` section::

  [Socket]
  ListenStream=/var/run/krb5kdc/DEFAULT.socket
  ListenDatagram=1812
  ...

Unfortunately, ``radclient`` from ``freeradius-utils`` package only
supports UDP, not TCP.

Reload the systemd unit files::

  % sudo systemctl daemon-reload

View status::

  $ systemctl status ipa-otpd.socket

Follow log::

  $ journalctl --follow /usr/libexec/ipa-otpd



RADIUS protocol
---------------

http://web.mit.edu/~kerberos/krb5-devel/doc/admin/otp.html

``ipa-otpd`` uses an empty string as the secret.

The principal is used in the User-Name attribute of the RADIUS
packet.


KDC OTP configuration
---------------------

::

  [otp]
    DEFAULT = {
      timeout = 30
      strip_realm = false
    }


