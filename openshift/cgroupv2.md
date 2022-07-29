openshift cgroupv2 notes:

- OpenShift `enhancements` PR:
  https://github.com/openshift/enhancements/pull/652

- [Design doc (rendered)][design-rendered]

- PR for "Day 1" cgroupv2 via installer:
  https://github.com/openshift/installer/pull/4648


[design-rendered]: https://github.com/openshift/enhancements/blob/fddf0d5be74bd8d74c724f6614789f6aa9b32d5b/enhancements/node/node-cgroupv2.md


## Via MCO

Copy/paste from [design doc][design-rendered].

Enable cgroup v2 on worker nodes:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: enable-cgroupv2-workers
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/worker: ""
  kernelArguments:
    - systemd.unified_cgroup_hierarchy=1
    - cgroup_no_v1="all"
    - psi=1
```

Enable cgroup v2 on master nodes:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: enable-cgroupv2-master
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/master: ""
  kernelArguments:
    - systemd.unified_cgroup_hierarchy=1
    - cgroup_no_v1="all"
    - psi=1
```
