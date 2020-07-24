Volumes
=======

For compatibility in a variety of environments we should create PVs
and PVCs using default ``StorageClass`` with *optional* override
with user-specified ``StorageClass`` in the ``IDM`` spec.

Therefore you can just create the PVC without even creating or
specifying underlying PV.  You can specify ``storageClassName`` or
leave unspecified for the default storage class (if defined).  For
example::

  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: pvc-test
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
	storage: 10Gi

First let's see what PVs exist::

  ftweedal% oc get pv
  NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                             STORAGECLASS   REASON    AGE
  pvc-d3bc7c81-8a24-4318-a914-296dbdc5ec3f   100Gi      RWO            Delete           Bound     openshift-image-registry/image-registry-storage   standard                 7d22h

There is one PV, with capacity 100Gi.  It is used for the image registry.

Now, lets create the PVC specified above::

  ftweedal% oc create -f deploy/pvc-test.yaml
  persistentvolumeclaim/pvc-test created

  ftweedal% oc get pvc pvc-test
  NAME       STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
  pvc-test   Pending                                       standard       11s

  ftweedal% oc get pv
  NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                             STORAGECLASS   REASON    AGE
  pvc-d3bc7c81-8a24-4318-a914-296dbdc5ec3f   100Gi      RWO            Delete           Bound     openshift-image-registry/image-registry-storage   standard                 7d22h

  ftweedal% oc get pvc pvc-test -o yaml |grep storageClassName
  storageClassName: standard

The PVC ``pvc-test`` was created and has status ``pending``.  No new
PV appeared yet.  Finally note that the PVC has ``storageClassName:
standard``.  Because we did not specify ``volumeName`` this PVC was
assigned the cluster's default ``StorageClass``.

Now lets create a pod that uses ``pvc-test``, mounting it at
``/data``.  We will write a file under ``/data``, delete then
re-create the pod, and observe that the previous write was
persisted::

  ftweedal% oc create -f deploy/pod-test.yaml
  pod/pod-test created

  ftweedal% oc exec pod-test -- sh -c 'echo "hello world" > /data/foo'

  ftweedal% oc delete pod pod-test
  pod "pod-test" deleted

  ftweedal% oc create -f deploy/pod-test.yaml
  pod/pod-test created

  ftweedal% oc exec pod-test -- cat /data/foo
  hello world

  ftweedal% oc delete pod pod-test
  pod "pod-test" deleted

So we can see that the PVC works as intended.  Let's check the
status of the PVC and PVs to see what happened behind the scenes::

  ftweedal% oc get pvc pvc-test
  NAME       STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
  pvc-test   Bound     pvc-26d82d50-8e66-4938-bdee-f28ff2bcb49c   10Gi       RWO            standard       16m

  ftweedal% oc get pv
  NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                             STORAGECLASS   REASON    AGE
  pvc-26d82d50-8e66-4938-bdee-f28ff2bcb49c   10Gi       RWO            Delete           Bound     ftweedal-operator/pvc-test                        standard                 4m53s
  pvc-d3bc7c81-8a24-4318-a914-296dbdc5ec3f   100Gi      RWO            Delete           Bound     openshift-image-registry/image-registry-storage   standard                 7d23h

Before creating the pod, ``pvc-test`` had status ``Pending``.  Now
it is ``Bound`` to the volume
``pvc-26d82d50-8e66-4938-bdee-f28ff2bcb49c`` which was dynamically
created with capacity 10Gi has required by ``pvc-test``.

Finally if we delete ``pvc-test``, observe that the corresponding PV
will automatically be deleted::

  ftweedal% oc delete pvc pvc-test
  persistentvolumeclaim "pvc-test" deleted

  ftweedal% oc get pv
  NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                             STORAGECLASS   REASON    AGE
  pvc-d3bc7c81-8a24-4318-a914-296dbdc5ec3f   100Gi      RWO            Delete           Bound     openshift-image-registry/image-registry-storage   standard                 7d23h


``pvc-26d82d50-8e66-4938-bdee-f28ff2bcb49c`` went away, as expected.
