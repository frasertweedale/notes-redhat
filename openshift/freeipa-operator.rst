First steps
===========

::

  ftweedal% operator-sdk new idmocp --type go
  INFO[0000] Creating new Go operator 'idmocp'.           
  INFO[0000] Created go.mod                               
  INFO[0000] Created tools.go                             
  INFO[0000] Created cmd/manager/main.go                  
  INFO[0000] Created build/Dockerfile                     
  INFO[0000] Created build/bin/entrypoint                 
  INFO[0000] Created build/bin/user_setup                 
  INFO[0000] Created deploy/service_account.yaml          
  INFO[0000] Created deploy/role.yaml                     
  INFO[0000] Created deploy/role_binding.yaml             
  INFO[0000] Created deploy/operator.yaml                 
  INFO[0000] Created pkg/apis/apis.go                     
  INFO[0000] Created pkg/controller/controller.go         
  INFO[0000] Created version/version.go                   
  INFO[0000] Created .gitignore                           
  INFO[0000] Validating project       ---- stuck here?

Why is it stuck at "validating project"?

It was a DNS issue.  It hung for about ~1hr before timing out.

Running with --verbose shows that the ``Validating project`` step
downloads dependencies (and builds the project?).  This can take a
long time on a slow Internet connection so the lack of information
or progress output about what's actually happening at this stage is
a problem.


You have to ``cd`` into subdir before running ``add api``::

  ftweedal% pwd
  /home/ftweedal/dev/idmocp-operator/src

  ftweedal% operator-sdk add api --api-version=idmocp.redhat.com/v1alpha1 --kind=IDM
  FATA[0000] must run command in project root dir: project structure requires build/Dockerfile 

  ftweedal% cd idmocp

  ftweedal% operator-sdk add api --api-version=idmocp.redhat.com/v1alpha1 --kind=IDM
  INFO[0000] Generating api version idmocp.redhat.com/v1alpha1 for kind IDM. 
  INFO[0000] Created pkg/apis/idmocp/group.go     
  INFO[0096] Created pkg/apis/idmocp/v1alpha1/idm_types.go
  INFO[0096] Created pkg/apis/addtoscheme_idmocp_v1alpha1.go
  INFO[0096] Created pkg/apis/idmocp/v1alpha1/register.go
  INFO[0096] Created pkg/apis/idmocp/v1alpha1/doc.go
  INFO[0096] Created deploy/crds/idmocp.redhat.com_v1alpha1_idm_cr.yaml
  INFO[0096] Running deepcopy code-generation for Custom Resource group versions: [idmocp:[v1alpha1], ]
  INFO[0104] Code-generation complete.
  INFO[0104] Running CRD generator.
  INFO[0105] CRD generation complete.
  INFO[0105] API generation complete.
  INFO[0105] API generation complete.


Regenerate k8s files and CRD definitions::

  ftweedal% operator-sdk generate k8s
  INFO[0000] Running deepcopy code-generation for Custom Resource group versions: [idmocp:[v1alpha1], ]
  INFO[0008] Code-generation complete.

  ftweedal% operator-sdk generate crds
  INFO[0000] Running CRD generator.
  INFO[0000] CRD generation complete.

Scaffold controller::

  ftweedal% operator-sdk add controller \
      --api-version=idmocp.redhat.com/v1alpha1 --kind IDM
  INFO[0000] Generating controller version idmocp.redhat.com/v1alpha1 for kind IDM.
  INFO[0000] Created pkg/controller/idm/idm_controller.go
  INFO[0000] Created pkg/controller/add_idm.go
  INFO[0000] Controller generation complete.



Building::

  ftweedal% operator-sdk build quay.io/freeipa/operator:v0.0.1
  INFO[0000] Building OCI image quay.io/freeipa/operator:v0.0.1
  Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg.
  STEP 1: FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
  Getting image source signatures
  Copying blob 526a64b80f4f done
  Copying blob 111578375543 done
  Copying config fd80bdd9b8 done
  Writing manifest to image destination
  Storing signatures
  STEP 2: ENV OPERATOR=/usr/local/bin/idmocp     USER_UID=1001     USER_NAME=idmocp
  --> 787217bc00f
  STEP 3: COPY build/_output/bin/idmocp ${OPERATOR}
  --> 77ea6dd8994
  STEP 4: COPY build/bin /usr/local/bin
  --> ae6201059b4
  STEP 5: RUN  /usr/local/bin/user_setup
  + echo 'idmocp:x:1001:0:idmocp user:/root:/sbin/nologin'
  + mkdir -p /root
  + chown 1001:0 /root
  + chmod ug+rwx /root
  + rm /usr/local/bin/user_setup
  --> 5cf280f7678
  STEP 6: ENTRYPOINT ["/usr/local/bin/entrypoint"]
  --> e895ed230c6
  STEP 7: USER ${USER_UID}
  STEP 8: COMMIT quay.io/freeipa/operator:v0.0.1
  --> 535d6ca1a9a
  535d6ca1a9a83c505ebaacfee8d19a376fc817589cda2e62d83b7439231d498a
  INFO[0072] Operator build complete.


Note: this tries to run the ``docker`` program.  ``dnf install
podman-docker`` to install a shim to run ``podman`` as ``docker``.

The ``quay.io/blah`` location does not need to exist (until you try
to ``docker/podman push`` which must be done separately).

Or you can run controller locally via ``operator-sdk run``.



Create CRD (requires cluster admin privs)::

  ftweedal% oc create -f deploy/crds/idmocp.redhat.com_idms_crd.yaml
  customresourcedefinition.apiextensions.k8s.io/idms.idmocp.redhat.com created

Create service account, role and role binding::

  ftweedal% oc create -f deploy/service_account.yaml
  serviceaccount/idmocp created

  ftweedal% oc create -f deploy/role.yaml
  role.rbac.authorization.k8s.io/idmocp created

  ftweedal% oc create -f deploy/role_binding.yaml
  rolebinding.rbac.authorization.k8s.io/idmocp created


Running the operator locally
============================

Run the operator **locally**, against the **remote** cluster::

  ftweedal% operator-sdk run local --watch-namespace ftweedal-operator
  INFO[0000] Running the operator locally; watching namespace "ftweedal-operator"
  {"level":"info","ts":1595503782.5421903,"logger":"cmd","msg":"Operator Version: 0.0.1"}
  {"level":"info","ts":1595503782.5422142,"logger":"cmd","msg":"Go Version: go1.14.3"}
  {"level":"info","ts":1595503782.5422215,"logger":"cmd","msg":"Go OS/Arch: linux/amd64"}
  {"level":"info","ts":1595503782.5422294,"logger":"cmd","msg":"Version of operator-sdk: v0.18.1"}
  {"level":"info","ts":1595503782.5434256,"logger":"leader","msg":"Trying to become the leader."}
  {"level":"info","ts":1595503782.5434394,"logger":"leader","msg":"Skipping leader election; not running in a cluster."}
  I0723 21:29:45.014098  202077 request.go:621] Throttling request took 1.047337527s, request: GET:https://api.permanent.idmocp.idm.lab.bos.redhat.com:6443/apis/migration.k8s.io/v1alpha1?timeout=32s
  {"level":"info","ts":1595503786.3361971,"logger":"controller-runtime.metrics","msg":"metrics server is starting to listen","addr":"0.0.0.0:8383"}
  {"level":"info","ts":1595503786.3374689,"logger":"cmd","msg":"Registering Components."}
  {"level":"info","ts":1595503786.33769,"logger":"cmd","msg":"Skipping CR metrics server creation; not running in a cluster."}
  {"level":"info","ts":1595503786.3377118,"logger":"cmd","msg":"Starting the Cmd."}
  {"level":"info","ts":1595503786.338082,"logger":"controller-runtime.manager","msg":"starting metrics server","path":"/metrics"}
  {"level":"info","ts":1595503786.3384473,"logger":"controller-runtime.controller","msg":"Starting EventSource","controller":"idm-controller","source":"kind source: /, Kind="}
  {"level":"info","ts":1595503786.7392015,"logger":"controller-runtime.controller","msg":"Starting EventSource","controller":"idm-controller","source":"kind source: /, Kind="}
  {"level":"info","ts":1595503787.0400546,"logger":"controller-runtime.controller","msg":"Starting Controller","controller":"idm-controller"}
  {"level":"info","ts":1595503787.04015,"logger":"controller-runtime.controller","msg":"Starting workers","controller":"idm-controller","worker count":1}

Now to make the operator do something, create an IDM object::

  ftweedal% cat deploy/crds/idmocp.redhat.com_v1alpha1_idm_cr.yaml
  apiVersion: idmocp.redhat.com/v1alpha1
  kind: IDM
  metadata:
    name: example-idm
  spec:
    realm: IPA.TEST

  ftweedal% oc create -f deploy/crds/idmocp.redhat.com_v1alpha1_idm_cr.yaml                                                                                             
  idm.idmocp.redhat.com/example-idm created                                                                

Additional operator output indicates the detection of the creation of the idm
object and deployment of the pod::

  {"level":"info","ts":1595504035.8039277,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504036.0934615,"logger":"controller_idm","msg":"Deploying IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504036.5116532,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504036.7884111,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504038.6349363,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504044.5828426,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504066.7951272,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}
  {"level":"info","ts":1595504066.7953176,"logger":"controller_idm","msg":"Reconciling IDM","Request.Namespace":"ftweedal-operator","Request.Name":"example-idm"}

List and inspect the ``idm`` object via ``oc get``::

  ftweedal% oc get idms
  NAME          AGE
  example-idm   10m

  ftweedal% oc get idm example-idm -o yaml
  apiVersion: idmocp.redhat.com/v1alpha1
  kind: IDM
  metadata:
    creationTimestamp: 2020-07-23T11:33:30Z
    generation: 1
    name: example-idm
    namespace: ftweedal-operator
    resourceVersion: "3129192"
    selfLink: /apis/idmocp.redhat.com/v1alpha1/namespaces/ftweedal-operator/idms/example-idm
    uid: cd866bdf-052b-4ff7-b538-ae72436a90fa
  spec:
    realm: IPA.TEST
  status:
    servers:
    - example-idm-pod52s84

Observe that the pod was created.  Via ``oc exec`` I confirmed that the pod
container is using the ``freeipa-server`` container image::

  ftweedal% oc exec example-idm-pod52s84 -- which ipa-server-configure-first
  /usr/sbin/ipa-server-configure-first


Deploying the operator
======================

TODO


Creating volumes
================

The IDM operator needs to create a volume to be mounted in the container.
There are two ways to achieve this:

1. The controller manually creates a ``PersistentVolumeClaim`` (PVC), as well
   as manually creating the pod.  The pod spec will reference the PVC.

2. Using a ``StatefulSet``, we can specify pod and PVC *templates*.  The
   ``StatefulSet`` will automatically create the PVC and pod for each replica.

The next step for the FreeIPA operator is to update it to create a
``StatefulSet`` so that the pod has a volume for data storage, and
modify the pod command to actually run the FreeIPA server.
