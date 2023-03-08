## `virsh(1)`

### Connect to system QEMU host by default

Set environment variable:

```
% export LIBVIRT_DEFAULT_URI=qemu:///system
```

### Add/remove USB device

**NOTE:** Kernel option `intel_iommu=on` must be set to enable
passthrough.  `/proc/cmdline` indicates the options of the running
kernel.

1. `lsusb(8)` to find vendor and product ID:

```shell
% lsusb |grep Yubi
Bus 001 Device 015: ID 1050:0112 Yubico.com Yubikey NEO(-N) CCID
```

2. Create device file:

```xml
<hostdev mode="subsystem" type="usb" managed="yes">
  <source>
    <vendor id="0x1050"/>
    <product id="0x0112"/>
  </source>
</hostdev>
```

3. Attach/remove device

```shell
% virsh attach-device --file device.xml <domain>
% virsh detach-device --file device.xml <domain>
```

## libvirt IPv6 setup

1. Enable XML editing of network configuration in preferences.

2. Edit > Connection Details > Virtual Networks

3. Add ``ipv6="yes"`` attribute to ``<network>`` element.

4. Add new ``<ip>`` element::

    <ip family="ipv6" address="fd00::1" prefix="64">
    </ip>

5. Apply and Reboot


## Prepare cloud image

- fedora cloud image http://fedoraproject.org/get-fedora#clouds
- guest must be shut down
- set up password:

```
% virt-sysprep -a Fedora-x86_64-20-20140407-sda.qcow2 \
    --password fedora:password:4me2Test
[   0.0] Examining the guest ...
[  27.0] Performing "abrt-data" ...
[  27.0] Performing "bash-history" ...
[  27.0] Performing "blkid-tab" ...
[  27.0] Performing "crash-data" ...
[  27.0] Performing "cron-spool" ...
[  27.0] Performing "dhcp-client-state" ...
[  27.0] Performing "dhcp-server-state" ...
[  27.0] Performing "dovecot-data" ...
[  27.0] Performing "logfiles" ...
[  27.0] Performing "machine-id" ...
[  27.0] Performing "mail-spool" ...
[  27.0] Performing "net-hostname" ...
[  27.0] Performing "net-hwaddr" ...
[  27.0] Performing "pacct-log" ...
[  27.0] Performing "package-manager-cache" ...
[  27.0] Performing "pam-data" ...
[  27.0] Performing "puppet-data-log" ...
[  27.0] Performing "rh-subscription-manager" ...
[  27.0] Performing "rhn-systemid" ...
[  27.0] Performing "rpm-db" ...
[  27.0] Performing "samba-db-log" ...
[  27.0] Performing "script" ...
[  27.0] Performing "smolt-uuid" ...
[  27.0] Performing "ssh-hostkeys" ...
[  27.0] Performing "ssh-userdir" ...
[  27.0] Performing "sssd-db-log" ...
[  27.0] Performing "tmp-files" ...
[  27.0] Performing "udev-persistent-net" ...
[  27.0] Performing "utmp" ...
[  27.0] Performing "yum-uuid" ...
[  27.0] Performing "customize" ...
[  27.0] Setting a random seed
[  27.0] Setting passwords
[  28.0] Performing "lvm-uuids" ...
```

```
ftweedal% virt-builder fedora-20 \
    --firstboot-command 'useradd -m ftweedal -G wheel -p 4me2Test ; mkdir /home/ftweedal/.ssh ; echo "$SSH_KEY" > /home/ftweedal/.ssh/authorized_keys ; chown -R ftweedal:ftweedal /home/ftweedal/.ssh ; chmod 700 /home/ftweedal/.ssh ; chmod 600 /home/ftweedal/.ssh/authorized_keys'
[   1.0] Downloading: http://libguestfs.org/download/builder/fedora-20.xz
#######################################################################  100.0%
[ 727.0] Planning how to build this image
[ 727.0] Uncompressing
[ 733.0] Opening the new disk
[ 737.0] Setting a random seed
[ 737.0] Installing firstboot command: [1] useradd -m ftweedal ; mkdir /home/ftweedal/.ssh ; echo "..." > /home/ftweedal/.ssh/authorized_keys ; chown -R ftweedal:ftweedal /home/ftweedal/.ssh ; chmod 700 /home/ftweedal/.ssh ; chmod 600 /home/ftweedal/.ssh/authorized_keys
[ 737.0] Setting passwords
Setting random password of root to JptaT3Ae56yEW7VE
[ 737.0] Finishing off
Output: fedora-20.img
Output size: 4.0G
Output format: raw
Total usable space: 5.2G
Free space: 4.5G (86%)
```

## Virtual TPM device

Add TPM hardware (emulated).  Requires ``swtpm-tools`` package on
host.
