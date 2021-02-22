# OpenShift installer notes

## Master vs worker nodes

OpenShift installer only *directly* provisions the master nodes.  It
is then up to the *machine-api* cluster operator to provision worker
nodes.

### Worker nodes not created

If the worker nodes do not appear, it can help to inspect the
machine-api logs:

```shell
oc --namespace=openshift-machine-api logs \
    deployments/machine-api-controllers \
    --container=machine-controller
```
