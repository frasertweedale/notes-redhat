Physical volumes
----------------

Create lvm pv (*physical volume*) partition with ``parted`` or
``pvcreate``.


Volume groups
-------------

List volume groups::

  # vgs

Add physical volumes to a volume group::

  # vgextend fedora /dev/sdb4


Logical volumes
---------------

List logical volumes::

  # lvs

To see which physical volumes (and how much) a logical volume uses::

  # lvs -a -o +devices

Extend logical volume ``/dev/fedora/home`` by the amount of free
space on physical volume ``/dev/sdb4``::

  # lvextend /dev/fedora/home /dev/sdb4

See ``lvextend(8)`` for more advanced use.

After changing size of logical volume, resize the (ext2 / ext3 /
ext4) filesystem::

  # resize2fs /dev/fedora/home

Instead of ``lvextend`` followed by ``resize2fs``::

  # lvresize --resizefs /path/to/lv /path/to/pv
