# AWS notes

## EC2

### UEFI / TPM

**Note: requires instance type family with UEFI support, e.g. T3**

To convert an AMI to one that support TPM:

1. Clone the snapshot

2. Register an image via the following command:

```
% aws ec2 register-image \
    --name "pki-workshop-f43-v4-tpm" \
    --tpm-support v2.0 \
    --boot-mode uefi \
    --architecture x86_64 \
    --root-device-name /dev/sda1 \
    --block-device-mappings \
        "DeviceName=/dev/sda1,Ebs={SnapshotId=snap-$SNAP_ID}"
```

For whatever reason the web console doesn't expose the
`--tpm-support` option.  Or I missed it or lack understanding.
Probably the latter.
