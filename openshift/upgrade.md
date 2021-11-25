# Upgrading an OpenShift cluster

Upgrading can take 2-3 hours on a small cluster.  Most of the time
is spent waiting for machine-config-operator to upgrade.

Upgrading to a specific release image:

```shell
oc adm upgrade --allow-explicit-upgrade --force=true \
    --to-image=quay.io/openshift-release-dev/ocp-release:4.8.4-x86_64
```
