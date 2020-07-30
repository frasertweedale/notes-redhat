OpenShift DNS notes
===================

Forward zones
-------------

How does adding a forward zone in the DNS Operator configuration
affect the coredns configuration?

Before::

  ftweedal% oc exec \
      --namespace=openshift-dns -c dns dns-default-xvjmg \
      -- cat /etc/coredns/Corefile
  .:5353 {
      errors
      health
      kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
      }
      prometheus :9153
      forward . /etc/resolv.conf {
          policy sequential
      }
      cache 30
      reload
  }

Adding forwarder config via ``oc edit dns.operator/default``::

  spec:
    servers:
      - name: ftweedal-bogus
        zones:
          - ftweedal.test
        forwardPlugin:
          upstreams:
            - 1.1.1.1
            - 2.2.2.2

Inspecting the config files on the DNS servers again::

  # ftweedal-bogus
  ftweedal.test:5353 {
      forward . 1.1.1.1 2.2.2.2
  }
  .:5353 {
      errors
      health
      kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
      }
      prometheus :9153
      forward . /etc/resolv.conf {
          policy sequential
      }
      cache 30
      reload
  }

We can see that the forward zone info was put *at the beginning*.
Therefore it is possible to forward a subdomain of the cluster
domain (``cluster.local``) to a different DNS server.


Forwarding to IPA server
------------------------

For this to work we would need:

- Apply a specific ``label`` to all FreeIPA server pods that have
  the DNS role.

- ``Service`` object with ``ClusterIP`` and pod/endpoint
  ``selector`` targeting that label.

- Edit ``dns.operator/default`` object to point to the ``ClusterIP``
  of that ``Service``

Whether it is necessary or appropriate to configure FreeIPA DNS
server to forward requests back to ``openshift-dns`` or elsewhere is
not yet determined.
