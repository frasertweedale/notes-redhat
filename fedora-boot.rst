To rebuild initramfs::

  # dracut -f


To change boot cmdline for initramfs, edit ``/etc/default/grub``
(e.g., to remove ``rhgb`` and ``quiet`` options from
``GRUB_CMDLINE_LINUX``).  Then exceute::

  # grub2-mkconfig -o /boot/grub2/grub.cfg

To update grub configuration.

cmdline options::

``rd.shell``
  Drop to shell if cannot mount root.

``rd.debug``
  Spew output to console.

``rd.break``
  Unconditionally drop to shell at end.
