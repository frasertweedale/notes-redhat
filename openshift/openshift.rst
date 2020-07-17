Explanation of available resources::

  oc api-resources

Questions: how to create users?  I don't want to do everything as
admin.


Definitions
-----------

CRD
  custom resource definition; object that modifies the API.
  Typically requires cluster-wide privileges to create.

GVK aka *TypeMeta*
  "group" (G), apiVersion (V), kind (K).  e.g.
  ``group.example.com/v1alpha1`` (group and version)

OLM
  *Operator Lifecycle Manager* (something about role/privilege
  management?).  Handles installation, resolution and dependency
  management for operators.  Comes with OCP4.
  

ReplicaSets and Deployments
---------------------------

- Provide redundancy

Deployment or DeploymentConfig can incorporate ReplicaSet to achieve
HA.

https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/

**Deployments** superseded **DeploymentConfig** as of OCP4.

Deployment is to ReplicaSet as DeploymentConfig is to
ReplicationController.  i.e. the latter objects are superseded;
*Deployment* and *ReplicaSet* is the way to go as of OCP4.

DNS
---

Should we use IPA integrated DNS or is there an "official" OpenShift
DNS service we should integrate with?


Operators
----------

Can handle upgrades, backups, etc.


Identity and numbering
----------------------

``StatefulSet``.  Suitable for databases and other distributed
applications.  This might be important for us?

QUESTION: is it possible to define an application to ensure
availability (i.e. there are replicas) in all regions.  (I see it
possible to restrict to a given region.)


Autoscaling
-----------

Is it desirable?  Maybe out of scope for MVP, and administrators
choose number of replicas.

How would it be possible?

*Horizonal Pod Autoscaler (HPA)*:
https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/


Regions
-------



resource
--------

- ``status`` is automatically populated by operator/controller; you
  don't modify these directly


StatefulSet
-----------

Provides:

- predictable naming
- does not destroy data volume when pod destroyed

Some of the existing controllers may be appropriate for you
application.  You don't necessarily have to write an operator (or
the operator can lean quite heavily on the existing controllers).

DaemonSets
----------

Ensure a pod runs on every node in the environment


Worker
------

A type of node, runs the applications rather than "control plane"
stuff that is part of OCP itself.


Pod deletion
------------

Programs running in pod need to respond to SIGTERM.  They have 30s
(configurable) to tear themselves down before being forcibly killed.
