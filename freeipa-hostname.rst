Audit of hostname/FQDN query and use in FreeIPA and dependencies
================================================================

FreeIPA
-------

ipa-otpd
~~~~~~~~

- ``gethostname`` (``main.c:~230``).  Used to set NAS-Identifier
  for RADIUS (NAS = *Network Access Server*).

  - Impact: probably harmless

ipa-sam
~~~~~~~

- ipa-sam = Samba passdb backend

- ``ipasam_generate_principals`` uses result of ``gethostname``
  directly to construct ``cifs/`` and ``ldap/`` principal names.

  - Impact: breakage; wrong princpal names are constructed

  - Remedy: follow to fqdn?  explicit config?

- ``save_sid_to_secret`` uses result of ``gethostname`` as key to
  store SID in passdb.

  - Impact: **unsure**

ipa-slapi-cldap
~~~~~~~~~~~~~~~

- CLDAP = LDAP over UDP, with some NETBIOS bits?

  -  info: https://ldapwiki.com/wiki/Netlogon%20attribute

- ``gethostname`` called from ``ipa_cldap_netlogon``
  (``daemons/ipa-slapi-plugins/ipa-cldap/ipa_cldap_netlogon.c:~324``).

  - Impact: explicitly fails if hostname does not contain period.

  - Usage: used to set ``nlr->pdc_dns_name``.  **unsure** of impact.

  - Usage: also used to make a netbios name, by reading max 15 chars
    from leftmost label (``make_netbios_name()``).  Shortname would
    suffice here.

  - Remedy: follow ``gethostname`` to FQDN, or read from config.
    Note the follow TODO that was seen in earlier revisions, removed
    in commit ``b1cfb47dc03a49648fca7b9d5b0b041342689a88``::

      /* TODO: get our own domain at plugin initialization, and avoid
       * gethostname() */
      ret = gethostname(hostname, MAXHOSTNAMELEN);
      ...


Installer and support code
~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``installutils.get_fqdn()`` calls ``socket.gethostname()`` as a
  fallback if ``socket.getfqdn()`` fails.

  - Usage: if hostname is not supplied to ``ipa-server-install`` as
    an option or interactively, this is where IPA will get it from.
    The result is subsequently checked using
    ``installutils.verify_fqdn()``.

  - Impact: ``get_fqdn()`` is used by ``ipa-csreplica-manage``,
    ``ipa-replica-manage``, ``ipa-server-install`,
    ``ipaserver.install.ldapupdate``,
    ``ipaserver.install.schemaupdate``, ``ipaserver.plugins.join``
    and ``ipaserver.dcerpc``.

  - Remedy: ``get_fqdn()`` uses ``socket.getfqdn(3)``.  If there is
    no system FQDN at all, we could read it from config instead of
    falling back to ``socket.gethostname()``

- ``ipalib.constants.FQDN``

  - similar to installutils, prefers ``socket.getfqdn()`` and falls
    back to ``socket.gethostname()``.

  - Usage: only used in ``ipa_restore.py``, and elsewhere in
    ``ipalib.constants``.

  - Remedy: because it is only used in one place, refactor
    ``ipa_restore`` refactored to use ``installutils.get_fqdn()`` or
    similar (which should be dealt with as discussed elsewhere in
    this document), and remove the definition.

- ``ipaserver.install.service``

  - ``Service`` base class sets ``self.fqdn =
    socket.gethostbyname()`` (``service.py:~293``).

  - Remedy: this also should use ``installutils.get_fqdn()`` or a
    similar FQDN query abstraction.

- ``ipaplatform.redhat.tasks.backup_hostname()``

  - Reads ``socket.gethostname()`` and saves it.  The counterpart
    method ``restore_hostname()`` uses ``hostnamectl(1)`` to restore
    the hostname.

  - Remedy: **unsure**.  Operationally it seems fine to leave as-is.
    But for consistency, because we restore with ``hostnamectl
    set-hostname``, perhaps for symmetry we should change this to
    read ``hostnamectl --static``.

- ``adtrustinstance``

  - Reads ``socket.gethostname()`` and compares to ``self.fqdn``,
    which is set to the value of ``api.env.host`` (which should be
    set from ``default.conf``).  Specifically,
    ``ipaserver.install.adtrust.install`` invokes
    ``ADTRUSTInstance.setup`` which sets ``self.fqdn``.

  - Impact: if ``socket.gethostname() != self.fqdn``, setup fails
    (see ``__validate_server_hostname``, ``adtrustinstance.py:~690``).

  - Remedy: **unsure**.  I assume the ``gethostname()`` check
    mirrors something that happens inside the samba library, and we
    need to keep this check more or less as-is?

- Use of ``hostnamectl(1)``

  - AFAICT we only use it to *set* the hostname (on
    uninstall/restore).  So there is nothing else to do here.

- Use of ``hostname(1)``

  - Only in tests, can ignore.


Certmonger
----------

- Default subject DN for cert requests uses result of ``gethostname`` 
  as CN  (``src/getcert.c:~817``).

  - Impact: will cause TLS service cert tracking requests to be
    created with incorrect subject, unless subject is explicitly
    set.

  - Remedy: ensure we are creating tracking requests with explicit
    subject DN.

  - Remedy: modify certmonger to attempt to determine FQDN given
    result of ``gethostname``.


MIT Kerberos
------------

TODO


389 DS
------

TODO


Dogtag
------

TODO


Samba
-----

TODO
