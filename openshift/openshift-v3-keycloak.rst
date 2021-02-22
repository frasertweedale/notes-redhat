CLI client
==========

Installation::

  dnf install origin-clients

Login::

  % oc login https://api.starter-us-east-1.openshift.com
  Authentication required for https://api.starter-us-east-1.openshift.com:443 (openshift)
  Username: ftweedal@redhat.com
  Password:
  Login successful.

  You have one project on this server: "pyconau-keycloak"

  Using project "pyconau-keycloak".
  Welcome! See 'oc help' to get started.

Ok, cool.

Choose project::

  % oc project
  Using project "pyconau-keycloak" on server "https://api.starter-us-east-1.openshift.com:443".

  % oc project foo
  error: You are not a member of project "foo".
  You have one project on this server: PyCon Australia Keycloak demo (pyconau-keycloak)

  % oc project pyconau-keycloak
  Already on project "pyconau-keycloak" on server "https://api.starter-us-east-1.openshift.com:443".


List resources::

  % oc get all
  NAME           DOCKER REPO                                      TAGS      UPDATED
  is/keycloak    172.30.208.107:5000/pyconau-keycloak/keycloak    latest    2 months ago
  is/keycloak2   172.30.208.107:5000/pyconau-keycloak/keycloak2   latest    2 months ago
  is/keycloak3   172.30.208.107:5000/pyconau-keycloak/keycloak3   latest    About an hour ago

  NAME           REVISION   DESIRED   CURRENT   TRIGGERED BY
  dc/keycloak3   1          1         1         config,image(keycloak3:latest)

  NAME             DESIRED   CURRENT   READY     AGE
  rc/keycloak3-1   1         1         0         47m

  NAME            CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
  svc/keycloak3   172.30.196.12   <none>        8080/TCP   47m

  NAME                   READY     STATUS             RESTARTS   AGE
  po/keycloak3-1-2plwz   0/1       CrashLoopBackOff   13         46m

``is``
  imagestream
``dc``
  deploymentconfig
``rc``
  replicationcontroller
``svc``
  service
``po``
  pod

Expose a service::

  % oc expose svc/foo
  route "foo" exposed

Open a shell in a pod::

  % oc rsh keycloak3-5-q69bk

Deploying a new app from existing image stream::

  % oc new-app --image-stream keycloak
  --> Found image aa6cf7e (5 days old) in image stream "myproject/keycloak" under tag "latest" for "keycloak"

      * This image will be deployed in deployment config "keycloak"
      * Port 8080/tcp will be load balanced by service "keycloak"
        * Other containers can access this service through the hostname "keycloak"

  --> Creating resources ...
      deploymentconfig "keycloak" created
      service "keycloak" created
  --> Success
      Run 'oc status' to view your app.

Set environment variables for a deployment config::

  % oc set env dc/keycloak KEYCLOAK_USER=admin KEYCLOAK_PASSWORD=admin
  deploymentconfig "keycloak" updated


Manage volumes::

  % oc volume dc/keycloak3 --add --mount-path /log
  info: Generated volume name: volume-ppc2f
  deploymentconfig "keycloak3" updated

  % oc volume dc/keycloak3 --add --mount-path /data
  info: Generated volume name: volume-jl39q
  deploymentconfig "keycloak3" updated

  % oc volume dc/keycloak3 --add --mount-path /tmp
  info: Generated volume name: volume-p0b55
  deploymentconfig "keycloak3" updated

  % oc volume dc/keycloak3 --add --mount-path /deployments
  info: Generated volume name: volume-x70rx
  deploymentconfig "keycloak3" updated

  % oc volume dc/keycloak3
  deploymentconfigs/keycloak3
    empty directory as volume-ppc2f
      mounted at /log
    empty directory as volume-jl39q
      mounted at /data
    empty directory as volume-p0b55
      mounted at /tmp
    empty directory as volume-x70rx
      mounted at /deployments


Running OpenShift locally
=========================

``oc cluster up``
-----------------

::

  % oc cluster up

Is it really that easy?

::

  % oc cluster up
  -- Checking OpenShift client ... OK
  -- Checking Docker client ... OK
  -- Checking Docker version ... OK
  -- Checking for existing OpenShift container ... OK
  -- Checking for openshift/origin:v1.5.0 image ...
     Pulling image openshift/origin:v1.5.0
     Pulled 0/3 layers, 3% complete
     ...
     Pulled 3/3 layers, 100% complete
     Extracting
     Image pull complete
  -- Checking Docker daemon configuration ... FAIL
     Error: did not detect an --insecure-registry argument on the Docker daemon
     Solution:

       Ensure that the Docker daemon is running with the following argument:
          --insecure-registry 172.30.0.0/16

Add ``--insecure-registry 172.30.0.0/16`` to the ``OPTIONS``
variable in ``/etc/sysconfig/docker``, then restart Docker.

This will check that the local machine has acceptable versions of
OpenShift client and Docker installed, pulls the
``openshift/origin:v1.5.0`` image, and runs it.

Open some ports in the firewall::

  % sudo firewall-cmd \
    --add-port 8443/tcp \
    --add-port 53/tcp \
    --add-port 53/udp

Then start the cluster::

  % oc cluster up
  -- Checking OpenShift client ... OK
  -- Checking Docker client ... OK
  -- Checking Docker version ... OK
  -- Checking for existing OpenShift container ... OK
  -- Checking for openshift/origin:v1.5.0 image ... OK
  -- Checking Docker daemon configuration ... OK
  -- Checking for available ports ... OK
  -- Checking type of volume mount ...
     Using nsenter mounter for OpenShift volumes
  -- Creating host directories ... OK
  -- Finding server IP ...
     Using 192.168.0.160 as the server IP
  -- Starting OpenShift container ...
     Creating initial OpenShift configuration
     Starting OpenShift using container 'origin'
     Waiting for API server to start listening
  -- Adding default OAuthClient redirect URIs ... OK
  -- Installing registry ... OK
  -- Installing router ... OK
  -- Importing image streams ... OK
  -- Importing templates ... OK
  -- Login to server ... OK
  -- Creating initial project "myproject" ... OK
  -- Removing temporary directory ... OK
  -- Checking container networking ... OK
  -- Server Information ... 
     OpenShift server started.
     The server is accessible via web console at:
         https://192.168.0.160:8443

     You are logged in as:
         User:     developer
         Password: developer

     To login as administrator:
         oc login -u system:admin

Success!

To access the internal docker registry::

  % oc login -u system:admin
  Logged into "https://192.168.0.160:8443" as "system:admin" using existing credentials.

  You have access to the following projects and can switch between them with 'oc project <projectname>':

      default
      kube-system
    * myproject
      openshift
      openshift-infra

  Using project "myproject".

  % oc get svc docker-registry -n default
  NAME              CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
  docker-registry   172.30.1.1   <none>        5000/TCP   6h

Use this IP address in docker commands.

In the end, the ``oc cluster up`` approach messed a bit too much
with the routing tables given the various other VM networks I
have on my machine, so I decided try out *Minishift*.


Minishift
---------

First install `docker-machine`_ and `docker-machine-driver-kvm`_.
(follow the instructions at the preceding links).  Unfortunately
these are not packaged for Fedora.

.. _docker-machine: https://github.com/docker/machine/releases
.. _docker-machine-driver-kvm: https://github.com/dhiltgen/docker-machine-kvm/releases

Download and extract the Minishift release for your OS from
https://github.com/minishift/minishift/releases.

Run ``minishift start``::

  % ./minishift start
  -- Installing default add-ons ... OK
  Starting local OpenShift cluster using 'kvm' hypervisor...
  Downloading ISO 'https://github.com/minishift/minishift-b2d-iso/releases/download/v1.0.2/minishift-b2d.iso'

  ... wait a while ...

It downloads a *boot2docker* VM ISO containing the openshift
cluster, boots the VM, and the console output then resembles the
output of ``oc cluster up`` (I infer that ``oc cluster up`` is
indeed being executed on the VM).

