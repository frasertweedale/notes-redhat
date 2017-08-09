
Social login config:
http://www.keycloak.org/docs/3.0/server_admin/topics/identity-broker/social/google.html

- GitHub
  - Create OAuth application to get client ID and secret
    http://github.com/settings/applications/new

- mod_auth_oidc vs mod_auth_mellon for authn to application
  http://www.keycloak.org/docs/3.0/server_admin/topics/sso-protocols/saml-vs-oidc.html

Keycloak on OpenShift
---------------------

Docker image: 

The Docker image https://hub.docker.com/r/jboss/keycloak/ is not
suitable for OpenShift.  There is a ``Dockerfile`` for OpenShift but
they do not publish an image for it.  So let's grab that
``Dockerfile`` and build it ourselves, and push to the ``OpenShift``
image stream.  First clone the ``jboss-dockerfiles`` repo::

  % git clone https://github.com/jboss-dockerfiles/keycloak docker-keycloak
  Cloning into 'docker-keycloak'...
  remote: Counting objects: 1132, done.
  remote: Compressing objects: 100% (22/22), done.
  remote: Total 1132 (delta 14), reused 17 (delta 8), pack-reused 1102
  Receiving objects: 100% (1132/1132), 823.50 KiB | 158.00 KiB/s, done.
  Resolving deltas: 100% (551/551), done.
  Checking connectivity... done.

Next build the Docker image for OpenShift::

  % docker build docker-keycloak/server-openshift
  Sending build context to Docker daemon 2.048 kB
  Step 1 : FROM jboss/keycloak:latest
   ---> fb3fc6a18e16
  Step 2 : USER root
   ---> Running in 21b672e19722
   ---> eea91ef53702
  Removing intermediate container 21b672e19722
  Step 3 : RUN chown -R jboss:0 $JBOSS_HOME/standalone &&     chmod -R g+rw $JBOSS_HOME/standalone
   ---> Running in 93b7d11f89af
   ---> 910dc6c4a961
  Removing intermediate container 93b7d11f89af
  Step 4 : USER jboss
   ---> Running in 8b8ccba42f2a
   ---> c21eed109d12
  Removing intermediate container 8b8ccba42f2a
  Successfully built c21eed109d12

Next we tag the image and push it to the *image stream* (which seems
to be OpenShift jargon for a a Docker image registry).  You can get
the repository info from the OpenShift web UI or from the command
line client::

  % oc get is
  NAME        DOCKER REPO                                      TAGS      UPDATED
  keycloak3   172.30.208.107:5000/pyconau-keycloak/keycloak3   latest    24 hours ago

With that information in hand, tag and push::

  % docker tag c21eed109d12 172.30.208.107:5000/pyconau-keycloak/keycloak3:openshift
  % docker push 172.30.208.107:5000/pyconau-keycloak/keycloak3:openshift
  The push refers to a repository [172.30.208.107:5000/pyconau-keycloak/keycloak3]
  Get https://172.30.208.107:5000/v1/_ping: dial tcp 172.30.208.107:5000: getsockopt: no route to host

Huh, ok.  Well I guess the OpenShift Online's integrated Docker
registry cannot be reached externally, in this way.  Or maybe it is
something specifically pertaining to *image streams*.  I'm not quite
sure.  Anyhow, let's try a different strategy.

I found out that you can create an OpenShift *build* that will build
the image for you, and put it in an image stream.  Here we use the
``oc new-build`` command to create a build.  There are several build
strategies and options available, including to give it the literal
contents of a ``Dockerfile``, which it will use to build the image.
I also have to use the ``--to <tag>`` option because the default tag
``latest`` is already taken... or something like that::

  % cat docker-keycloak/server-openshift/Dockerfile \
    | oc new-build -D - --to openshift

  --> Found Docker image fb3fc6a (7 days old) from Docker Hub for "jboss/keycloak:latest"

      * An image stream will be created as "keycloak:latest" that will track the source image
      * A Docker build using a predefined Dockerfile will be created
        * The resulting image will be pushed to image stream "openshift:latest"
        * Every time "keycloak:latest" changes a new build will be triggered

  --> Creating resources with label build=openshift ...
      imagestream "keycloak" created
      imagestream "openshift" created
      error: buildconfigs "openshift" is forbidden: build strategy Docker is not allowed
  --> Failed

Ok, another problem to investigate.  A `Stack Overflow answer`_ had
the explanation:

  OpenShift Online does not allow you to build images from a
  Dockerfile in the OpenShift cluster itself. This is because that
  requires extra privileges which at this time are not safe to
  enable in a multi user cluster. - Graham Dumpleton

.. _Stack Overflow answer: https://stackoverflow.com/a/44337918/4148211


Finally, I found some useful info in the `OpenShift Online 3 docs`_.

.. _OpenShift Online 3 docs: https://docs.openshift.com/online/dev_guide/managing_images.html#accessing-the-internal-registry

So, ``docker login``::

  % docker login -u `oc whoami` -p `oc whoami -t` \
      https://registry.starter-us-east-1.openshift.com
  Login Succeeded

Then tag and push the image::

  % docker tag c21eed109d12 registry.starter-us-east-1.openshift.com/pyconau-keycloak/keycloak3:openshift
  % docker push registry.starter-us-east-1.openshift.com/pyconau-keycloak/keycloak3:openshift
  The push refers to a repository [registry.starter-us-east-1.openshift.com/pyconau-keycloak/keycloak3]
  ...
  unauthorized: authentication required

There is another problem, but I didn't want to waste any more time
on getting my image into OpenShift - so I took yet another approach:
uploading my image into the ``hub.docker.com`` registry and then
importing it into OpenShift from there::

  % docker tag c21eed109d12 registry.hub.docker.com/frasertweedale/keycloak-openshift

  % docker login -u frasertweedale registry.hub.docker.com
  Password:
  Login Succeeded

  % docker push registry.hub.docker.com/frasertweedale/keycloak-openshift
  ... wait for upload ...
  latest: digest: sha256:c82c3cc8e3edc05cfd1dae044c5687dc7ebd9a51aefb86a4bb1a3ebee16f341c size: 2623

  % oc tag --source docker frasertweedale/keycloak-openshift:latest pyconau-keycloak/keycloak:latest
  Tag keycloak:latest set to frasertweedale/keycloak-openshift:latest.

Now the image stream is ready for use.  ``oc get is/<name>`` to
confirm.


Deploying the app
^^^^^^^^^^^^^^^^^

::

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

At this point the app is deployed, but we cannot log into the
console so we need to set some environment variables.

::

  % oc set env dc/keycloak \
    KEYCLOAK_USER=admin \
    KEYCLOAK_PASSWORD=admin \
    PROXY_ADDRESS_FORWARDING=true
  deploymentconfig "keycloak" updated

(envvars could also be set during 
