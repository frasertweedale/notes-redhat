FreeIPA YubiKey authentication
==============================

Client configuration
--------------------

On Fedora, the ``ykpers`` package installs the appropriate udev
rules::

  % sudo yum install -y ykpers


Add HOTP credentials via the Python API.  The base32-encoded OTP key
was read out of the configuration URL in FreeIPA::

  >>> import base64
  >>> import yubico
  >>> k = yubico.find_yubikey()
  >>> k
  <YubiKeyUSBHID instance at 0x7f6e5e942998: YubiKey version 2.2.2>
  >>> conf = k.init_config()
  >>> otpkey = base64.b32decode('QW2UUBMG52JTBOFA7U4C5EE2JUZRWECU')
  >>> otpkey
  '\x85\xb5J\x05\x86\xee\x930\xb8\xa0\xfd8.\x90\x9aM3\x1b\x10T'
  >>> conf.mode_oath_hotp(otpkey, 6)
  >>> conf.extended_flag('SERIAL_API_VISIBLE', True)
  False
  >>> k.write_config(conf, slot=1)
  >>> del k

Note that the above code explicitly writes the configuration to the
first slot.  The YubiKey has two slots, so write to ``slot=2`` if
the first slot is in use.

