Attaching QCOW2 disk to host
============================

Create ``nbd`` (network block device) device nodes::

  modprobe nbd max_part=16

Attach image to device node::

  qemu-nbd -c /dev/nbd0 image.qcow2

(Re)probe partitions::

  partprobe /dev/nbd0

Then write MBR, mount, or do whatever you need to do.
