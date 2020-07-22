Using operator-sdk
==================

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

