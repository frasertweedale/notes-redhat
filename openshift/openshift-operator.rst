Defining operators
------------------

Create project::

  operator-sdk new NAME --type go

Add CRD API::

  operator-sdk add api --api-version=app.example.com/v1alpha1 --kind=App

Define API types in file ``pkg/apis/app/v1alpha1/app_types.go``.

Generate deepcopy functions::

  operator-sdk generate k8s

Genereate CRDs::

  operator-sdk generate crds

Add a new controller::

  operator-sdk add controller \
    --api-version=app.example.com/v1alpha1 --kind App

Define the operator reconciler logic (and primary and secondary
resources).

Create the CRD::

  oc create -f deploy/crds/app_v1alpha1_appservice_crd.yaml

If no CR endpoint with corresponding ``--kind`` exists, the
operator/controller will not run (or will be killed).


Run your operator locally::

  $ export OPERATOR_NAME=app-operator
  $ operator-sdk run --local --namespace myproject [--kubeconfig=FILE]

This command exists for operator development.  It's like running
your operator *outside the cluster*.

Build your operator (as a container?)::

  operator-sdk build quay.io/example/app-operator:v0.0.1

Push the image to container registry::

  podman push ...

Create service account (SR), roles, etc.

Deploy the *Operator Deployment Manifest*::

  $ cat deploy/operator.yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: app-operator
  spec:
    replicas: 1
    ...
      spec:
        containers:
          - name: plex-operator
            image: quay.io/example/app-operator:v0.0.1

  $ oc create -f deploy/operator.yaml

Operator is now alive.


Reconciler pattern
------------------

Four philosophical rules:

1. Use a data structure for all inputs and outputs

2. Ensure that the data structure is immutable

3. *Keep the resource map simple*.  The reconciler pattern should be
   mapped with a set of resources; reconciler should iterate the
   resources and offer a simple, linear approach.

4. Make the actual state match the expected state.

You can reach target state incrementally.  e.g. if you need 3
replicas and have zero, create one new pod at a time.  This is
considered best practice because:

- controller logic is simplier
- avoids "bursts"





Controller implementation
-------------------------

It is developer responsibility to make sure pods (and other objects)
have *owner references*.

Creating pods
-------------

.. code:: golang

 return &corev1.Pod{
    ObjectMeta: metav1.ObjectMeta{
      GenerateName: cr.Name + "-pod",  // suffixes random hash
      Namespace: cr.Namespace,
      Labels: labels,
    },
    Spec: corev1.PodSpec{
      Containers: []corev1.Container{
        {
          Name: "busybox",
          Image: "busybox",
          Command: []string{"sleep", "3600"},
        }
      },
    },
  },



OLM - Operator Lifecycle Manager
================================

Originally part of Tectonic.

OLM is the ... of operators (CRDs in parens):

- Installation (``InstallPlan``)
- Definition (``ClusterServiceVersion``)
- Resolution (``CatalogSource``)
- Upgrading (``Subscription`` / ``Package``)

OLM was Tech Preview in OpenShift v3.

3 files:

- ``Cluster_Service_Version.yaml``
- ``Package.yaml``
- ``CRD(s).yaml``

- Cluster Service Version (CSV) is tied to a particular operator
  version.

- "Descriptors" are what affect the OpenShift UI (i.e. for filling
  in CR fields)

- RBAC stuff

- ``Package.yaml``: which CSVs can a user "subscribe" to?

- Eliminating the need for individual CRDs, deployment file, role
  bindings, etc.

- An "app store" experience for discovering and installing
  operators.

- automated upgrade for Operators

- framework for building rich, reusable UIs

- package management and dep resolution

OK but *what is it*?

- A couple of operators + CRDs

- CatalogSource is a collection of ClusterServiceVersion objects and
  CRDs

- *channels* you can subscribe to, e.g. subscribe to alpha channel,
  get all alpha updates.
