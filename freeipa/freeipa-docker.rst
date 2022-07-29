FreeIPA Docker integration
==========================

Resources
---------

- Dockerfile reference: http://docs.docker.io/reference/builder/

Questions
---------

- There doesn't seem to be a simple way to build a Docker image from
  an arbitrary commit in the freeipa repository.  Is someone working
  on this?  I'd be happy to tackle it if people agree it's a good
  idea, and noone else is working on it.

  - Side note to this, having this information in a Dockerfile
    results in build-and-install instructions stored in a
    recognisable location *in the repository*.  No more hunting
    around in wiki for this stuff; just point newcomers to the
    Dockerfile... if they didn't already think to look there.

- Related: if we go ahead with the above, should we merge the
  docker-freeipa repo into the freeipa repo, or keep it as a
  separate repo?  My hunch is that it will be easier (or cleaner) to
  build development images if the Dockerfile and associated assets
  live in the freeipa repo.  However, it might be appropriate to
  separately maintain the docker-freeipa repo for building images
  where freeipa-server has been installed from the official yum
  repos.

- Related: can we begin using the `official Docker registry`_ for
  sharing images, or is there / should there be an internal Red Hat
  or IdM image registry?  This will make it easy to share
  development builds for testing/review/demo without requring the
  tester/reviewer/audience to build the software.

  - If we use the Docker.io registry we could use the `trusted
    builds`_ feature to automate the building of development images,
    tracking some branch(es).  Caveat: the trusted build system
    pulls from GitHub so we would need to mirror our repositories to
    GitHub to do this.

  - Side note: I'm not yet sure what the server/storage requirements
    would be, for running our own registry.

- Is anyone from the IdM team going to Dockercon_? (June 9-10, San
  Francsico).

.. _Dockercon: http://www.dockercon.com/
.. _Official Docker registry: https://index.docker.io/
.. _Trusted builds: http://docs.docker.io/docker-io/builds/#trusted-builds


TODO
----

- no ``MAINTAINER`` instruction in Dockerfile
- no comments in Dockerfile
