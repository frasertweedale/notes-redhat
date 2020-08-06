Security Context Constraints (SCC)
==================================

Overview:
https://docs.openshift.com/container-platform/4.5/authentication/managing-security-context-constraints.html

Add ``anyuid`` SCC to a service account::

  $ oc adm policy add-scc-to-user anyuid -z $SERVICEACCOUNT
