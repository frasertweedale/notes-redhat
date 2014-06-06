Using FreeIPA with Puppet
=========================

Existing articles:

- http://jcape.name/2012/01/16/using-the-freeipa-pki-with-puppet/
- http://docs.puppetlabs.com/puppet/3/reference/config_ssl_external_ca.html
- http://docs.puppetlabs.com/guides/passenger.html

Puppet supports a *two intermediate CA* setup; one is used for
issuing certificates for masters and the other is used for issuing
certificates to agents.  Agents cannot act as servers and masters
cannot act as clients, when using this configuration.

- Rack server required (Apache or Nginx will do it)
  - terminate SSL
  - verify client cert
  - set req headers for verification-success and client-DN

- PEM encoding.
- Master certs must contain DNS name at which agent nodes will
  attempt to contact that master, either as subject CN or SAN.
- CRL checking works in all configurations (CRL must be updated "out
  of band"; puppet won't update it)

This guide is for Fedora 20.  We will configure a Puppet Master with
the hostname ``puppet-master.ipa.local`` and a Puppet agent on the
separate host ``puppet-client0.ipa.local``.


Install Puppet
--------------

Links:

- http://docs.puppetlabs.com/guides/install_puppet/pre_install.html
- http://docs.puppetlabs.com/guides/install_puppet/install_fedora.html
- http://docs.puppetlabs.com/guides/install_puppet/post_install.html

Install and enrol puppet master as FreeIPA client::

  $ sudo yum install freeipa-client
  $ sudo ipa-client-install --domain ipa.local --server ipa-1.ipa.local
  Autodiscovery of servers for failover cannot work with this
  configuration.
  If you proceed with the installation, services will be configured
  to always access the discovered server for all operations and will
  not fail over to other servers in case of failure.
  Proceed with fixed values and no DNS discovery? [no]: yes
  Hostname: puppet-master.ipa.local
  Realm: IPA.LOCAL
  DNS Domain: ipa.local
  IPA Server: ipa-1.ipa.local
  BaseDN: dc=ipa,dc=local

  Continue to configure the system with these values? [no]: yes
  User authorized to enroll computers: admin
  Synchronizing time with KDC...
  Password for admin@IPA.LOCAL:
  Successfully retrieved CA cert
      Subject:     CN=Certificate Authority,O=IPA.LOCAL
      Issuer:      CN=Certificate Authority,O=IPA.LOCAL
      Valid From:  Wed May 28 06:02:12 2014 UTC
      Valid Until: Sun May 28 06:02:12 2034 UTC

  Enrolled in IPA realm IPA.LOCAL
  Created /etc/ipa/default.conf
  New SSSD config will be created
  Configured /etc/sssd/sssd.conf
  Added the CA to the systemwide CA trust database.
  Added the CA to the default NSS database.
  Configured /etc/krb5.conf for IPA realm IPA.LOCAL
  trying https://ipa-1.ipa.local/ipa/xml
  Forwarding 'ping' to server 'https://ipa-1.ipa.local/ipa/xml'
  Forwarding 'env' to server 'https://ipa-1.ipa.local/ipa/xml'
  Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub
  Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub
  Forwarding 'host_mod' to server 'https://ipa-1.ipa.local/ipa/xml'
  Could not update DNS SSHFP records.
  SSSD enabled
  Configured /etc/openldap/ldap.conf
  NTP enabled
  Configured /etc/ssh/ssh_config
  Configured /etc/ssh/sshd_config
  Client configuration complete.

Install and configure Puppet master::

  $ sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-fedora-20.noarch.rpm
  $ sudo yum install puppet-server -y

Install and configure Puppet agent.  FreeIPA client configuration as
before.

::

  $ sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-fedora-20.noarch.rpm
  $ sudo yum install puppet -y


Configure Puppet Master
-----------------------

In ``/etc/puppet/puppet.conf`` section ``[main]`` add::

  dns_alt_names = puppet-master.ipa.local,puppet.ipa.local

Set up certificates (will configure puppet to act as CA, which will
be changed later).  Press ``^C`` to kill the process::

  $ sudo puppet master --verbose --no-daemonize
  Info: Creating a new SSL key for ca
  Info: Creating a new SSL certificate request for ca
  Info: Certificate Request fingerprint (SHA256): 97:98:23:BB:1E:58:94:93:E9:9F:5A:99:0E:15:CD:90:DB:5E:B5:7A:FB:99:70:D3:DB:A6:43:FD:0A:17:B6:A0
  Notice: Signed certificate request for ca
  Info: Creating a new certificate revocation list
  Info: Creating a new SSL key for puppet-master.ipa.local
  Info: csr_attributes file loading from /etc/puppet/csr_attributes.yaml
  Info: Creating a new SSL certificate request for puppet-master.ipa.local
  Info: Certificate Request fingerprint (SHA256): 20:B9:2F:9C:A0:53:3F:49:77:DF:8F:7C:47:34:60:E9:26:81:6C:1A:03:EB:65:6F:0E:3C:FF:B4:BB:94:D6:CE
  Notice: puppet-master.ipa.local has a waiting certificate request
  Notice: Signed certificate request for puppet-master.ipa.local
  Notice: Removing file Puppet::SSL::CertificateRequest puppet-master.ipa.local at '/var/lib/puppet/ssl/ca/requests/puppet-master.ipa.local.pem'
  Notice: Removing file Puppet::SSL::CertificateRequest puppet-master.ipa.local at '/var/lib/puppet/ssl/certificate_requests/puppet-master.ipa.local.pem'
  Notice: Starting Puppet master version 3.6.1
  ^CNotice: Caught INT; calling stop

Add a *main manifest* to the manifest directory (no environments)::

  $  .. TODO work out what goes here


Set up Apache
^^^^^^^^^^^^^

The ``mod_passenger`` package from the Fedora yum repository did not
work for me.  I had to endure the hardship of building
``mod_passenger`` myself, and configuring Apache to use it.

``passenger`` carries some native extension baggage.  Note that the
gem directory may be different.  I already had compilers and a bunch
of development headers installed on the system, so the list of
additional packages below may be incomplete.  If you try all this on
a fresh Fedora installation, take note of the packages you install
and me know if I missed any so I can update this post!

::

  $ sudo yum install -y gcc gcc-c++ ruby-devel httpd-devel
  $ sudo -i gem install rake rack passenger --no-rdoc --no-ri
  $ cd /usr/local/share/gems/gems/passenger-4.0.44
  $ rake apache2

Create the Apache configuration file
``/etc/httpd/conf.d/passenger.conf`` with the following contents,
noting that the paths therein may differ slightly according to the
version of ``passenger``::

  LoadModule passenger_module /usr/local/share/gems/gems/passenger-4.0.44/buildout/apache2/mod_passenger.so
  <IfModule mod_passenger.c>
     PassengerRoot /usr/local/share/gems/gems/passenger-4.0.44
     PassengerRuby /usr/bin/ruby
  </IfModule>

  Listen 8140
  <VirtualHost *:8140>
      SSLEngine On

      # Only allow high security cryptography. Alter if needed for compatibility.
      SSLProtocol             All -SSLv2
      SSLCipherSuite          HIGH:!ADH:RC4+RSA:-MEDIUM:-LOW:-EXP
      SSLCertificateFile      /var/lib/puppet/ssl/certs/puppet-master.ipa.local.pem
      SSLCertificateKeyFile   /var/lib/puppet/ssl/private_keys/puppet-master.ipa.local.pem
      SSLCertificateChainFile /var/lib/puppet/ssl/ca/ca_crt.pem
      SSLCACertificateFile    /var/lib/puppet/ssl/ca/ca_crt.pem
      SSLCARevocationFile     /var/lib/puppet/ssl/ca/ca_crl.pem
      SSLCARevocationCheck        chain
      SSLVerifyClient         optional
      SSLVerifyDepth          1
      SSLOptions              +StdEnvVars +ExportCertData

      # These request headers are used to pass the client certificate
      # authentication information on to the puppet master process
      RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
      RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
      RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

      DocumentRoot /usr/share/puppet/rack/puppetmasterd/public

      <Directory /usr/share/puppet/rack/puppetmasterd/>
        Options None
        AllowOverride None
        # Apply the right behavior depending on Apache version.
        <IfVersion < 2.4>
          Order allow,deny
          Allow from all
        </IfVersion>
        <IfVersion >= 2.4>
          Require all granted
        </IfVersion>
      </Directory>

      ErrorLog /var/log/httpd/puppet-master.ipa.local_ssl_error.log
      CustomLog /var/log/httpd/puppet-master.ipa.local_ssl_access.log combined
  </VirtualHost>

Configure the Puppet ``passenger`` application::

  $ sudo mkdir -p /usr/share/puppet/rack/puppetmasterd
  $ sudo mkdir /usr/share/puppet/rack/puppetmasterd/public \
      /usr/share/puppet/rack/puppetmasterd/tmp
  $ sudo curl -o /usr/share/puppet/rack/puppetmasterd/config.ru \
    https://raw.githubusercontent.com/puppetlabs/puppet/master/ext/rack/config.ru
  $ sudo chown puppet:puppet /usr/share/puppet/rack/puppetmasterd/config.ru
  $ sudo chown apache:apache /usr/share/puppet/rack/puppetmasterd/tmp

Ensure port 8140 is available to external hosts and start the Apache
service::

  $ sudo systemctl disable firewalld
  $ sudo systemctl stop firewalld
  $ sudo systemctl enable httpd
  $ sudo systemctl start httpd

Here I have disabled ``firewalld`` but have not enabled another
firewall.  Please configure another firewall, e.g. ``iptables``, if
the system is publically accessible or destined for production.
SELinux was also causing me grief, so I turned it off.  If you need
SELinux, a web search should turn up some `useful resources`_ on
that front.

.. _useful resources: http://sandcat.nl/~stijn/2012/01/20/selinux-passenger-and-puppet-oh-my/

To confirm that the puppet master is now up an running, you should
be able to load the page and see a message like the following::

  $ curl -k https://localhost:8140
  The environment must be purely alphanumeric, not ''


Configure Puppet Agent
----------------------

Puppet Agents try to contact the ``puppet`` host out of the box, but
since my Puppet Master's hostname is ``puppet-master.ipa.local`` it
is necessary to add some configuration to ``/etc/puppet/puppet.conf``::

  [agent]
    server = puppet-master.ipa.local

Leave the rest of the configuration as is.  The ``server`` setting
could have gone in the ``[main]`` section instead of ``[agent]`` but
I think it makes more sense under ``[agent]``.  Now start the
agent::

  $ sudo systemctl start puppet

The first time the agent contacts the master a certificate signing
request is generated.  On the *master*, you can list and sign these
requests::

  $ sudo puppet cert list
    "puppet-client0.ipa.local" (SHA256) 91:7B:D4:5C:33:B5:98:4C:8F:F8:2C:F3:15:C1:28:45:D4:0B:78:18:4D:AF:C2:A9:09:5C:C7:EA:50:1E:B3:0C
  $ sudo puppet cert sign puppet-client0.ipa.local
  Notice: Signed certificate request for puppet-client0.ipa.local
  Notice: Removing file Puppet::SSL::CertificateRequest puppet-client0.ipa.local at '/var/lib/puppet/ssl/ca/requests/puppet-client0.ipa.local.pem'
