Tomcat SPNEGO configuration
===========================

Minimal Tomcat SPNEGO configuration using as much default stuff as
possible.  IPA-enrolled host.

``web.xml``::

  <?xml version="1.0" encoding="ISO-8859-1"?>
  <web-app xmlns="http://java.sun.com/xml/ns/j2ee"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://java.sun.com/xml/ns/j2ee http://java.sun.com/xml/ns/j2ee/web-app_2_4.xsd"
      version="2.4">

      <display-name>Hello, World Application</display-name>
      <description>
          This is a simple web application with a source code organization
          based on the recommendations of the Application Developer's Guide.
      </description>

      <servlet>
          <servlet-name>HelloServlet</servlet-name>
          <servlet-class>mypackage.Hello</servlet-class>
      </servlet>

      <servlet-mapping>
          <servlet-name>HelloServlet</servlet-name>
          <url-pattern>/hello</url-pattern>
      </servlet-mapping>

      <security-constraint>
          <web-resource-collection>
              <url-pattern>/*</url-pattern>
          </web-resource-collection>
          <auth-constraint>
              <role-name>user</role-name>
          </auth-constraint>
      </security-constraint>

      <login-config>
         <realm-name>default</realm-name>
         <auth-method>SPNEGO</auth-method>
      </login-config>

  </web-app>

The ``<auth-constraint>`` seems to be a critical part of the
``<security-constraint>``.  Unsure how to apply different
``<login-config>`` sections for different regions of site.

With TGT and running
``curl -u : --negotiate -v -L f23-2.ipa.local:8080/sample/``,
Negotiate protocol works fine but status 500 due to::

  java.io.IOException: /usr/share/tomcat/conf/jaas.conf (No such file or directory)


The *default login module name* per `Tomcat constants`_ is
``com.sun.security.jgss.krb5.accept``.

.. _Tomcat constants: https://github.com/apache/tomcat/blob/3c8b971d9b6fe48149ea4c483436615a1920c47a/java/org/apache/catalina/authenticator/Constants.java#L39-L40


Write contents of ``/usr/share/tomcat/conf/jaas.conf``::

  com.sun.security.jgss.krb5.accept {
    com.sun.security.auth.module.Krb5LoginModule required
    principal="HTTP/f23-2.ipa.local"
    useKeyTab=true
    keyTab="/etc/tomcat/f23-2.keytab"
    storeKey=true;
  };


Restart Tomcat.  Now getting error::

  javax.security.auth.login.LoginException: Cannot locate KDC


Copy ``/etc/krb5.conf`` to ``/etc/tomcat/krb5.conf``.
**NOTE** could also symlink perhaps?

Then I get status 401 Unauthorized on second request which has
``Authorization: Negotiate YII...`` header.

Add ``debug=true`` to ``jaas.conf`` shows in journal::

    Debug is  true storeKey false useTicketCache false useKeyTab true doNotPrompt false ticketCache is null isInitiator
    principal is HTTP/f23-2.ipa.local@IPA.LOCAL
    Will use keytab
    Commit Succeeded
    [Krb5LoginModule]: Entering logout
    [Krb5LoginModule]: logged out Subject

So it appears that login succeeds but then the principal is
immediately logged out.

Firing up ``jdb`` and stepping through the ``authenticate`` method,
``GSSManager.createContext()`` throws ``PrivilegedAccessException``.
See https://github.com/apache/tomcat/blob/4e2728396fe591f09e7fd7f8c260eb52a47319be/java/org/apache/catalina/authenticator/SpnegoAuthenticator.java#L228.
The error (which is not logged by default) is::

  java.security.PrivilegedActionException: GSSException: No valid
    credentials provided (Mechanism level: Failed to find any Kerberos
    credentails)

Aha.  So actually, the ``Krb5LoginModule`` debug is in relation to
*service* credentials, not successful authentication of users.

The problem was that ``storeKey`` was not set in ``jaas.conf``.
Adding it and restarting Tomcat allowed us to get past line 228.
The principal is successfully authenticated from the Kerberos
ticket, assuming that they can authenticate to the *Realm*.

After this I was getting 403; fixed up roles in Realm and
``web.xml`` security constraint to resolve.


Realm configuration
===================

Set up JNDIRealm::

    <Realm className="org.apache.catalina.realm.JNDIRealm"
        connectionURL="ldaps://f22-2.ipa.local"
        userBase="cn=users,cn=accounts,dc=ipa,dc=local"
        userSearch="(&amp;(objectClass=posixaccount)(uid={0}))"
        roleBase="cn=groups,cn=accounts,dc=ipa,dc=local"
        roleSearch="(&amp;(objectClass=groupofnames)(member={0}))"
        roleName="cn"
    />

You can either configure explicit username and password which
JNDIRealm uses to connect to DS or, when the SPNEGO authenticator is
used, it will use delegated credentials if available otherwise the
service principal's credentials.

I hit a ``java.lang.NegativeArraySizeException`` in the JGSS
Kerberos implementation which is `due to`_ the server being
configured with *minimum security strength* factor ``minssf=0``.

.. _due to: https://gerrit.ovirt.org/#/c/21505/

The workaround was to add ``spnegoDelegationQop="auth"`` to the
``JNDIRealm`` configuration.  QOP = *quality of protection*; default
value is ``auth-conf`` (authentication and confidentiality).

The DS access log shows the bind and searches performed by
``JNDIRealm`` in this configuration::

  op=12 BIND dn="" method=sasl version=3 mech=GSSAPI
  op=12 RESULT err=14 tag=97 nentries=0 etime=0, SASL bind in progress
  op=13 BIND dn="" method=sasl version=3 mech=GSSAPI
  op=13 RESULT err=14 tag=97 nentries=0 etime=0, SASL bind in progress
  op=14 BIND dn="" method=sasl version=3 mech=GSSAPI
  op=14 RESULT err=0 tag=97 nentries=0 etime=0 dn="krbprincipalname=http/f23-2.ipa.local@ipa.local,cn=services,cn=accounts,dc=ipa,dc=local"
  op=15 SRCH base="cn=users,cn=accounts,dc=ipa,dc=local" scope=1 filter="(&(objectClass=posixaccount)(uid=alice))" attrs="1.1"
  op=15 RESULT err=0 tag=101 nentries=1 etime=0
  op=16 SRCH base="cn=groups,cn=accounts,dc=ipa,dc=local" scope=1 filter="(&(objectClass=groupofnames)(member=uid=alice,cn=users,cn=accounts,dc=ipa,dc=local))" attrs="cn"
  op=16 RESULT err=0 tag=101 nentries=1 etime=0

Note the result of operation 14 which shows that a successful
``BIND`` for the service principal and the two ``SRCH`` operations;
one to look up user ``alice`` and then one to find her group
membership.


Using delegated credentials
---------------------------

::

  curl -u : --negotiate --delegation policy f23-2.ipa.local:8080/sample/

See ``curl(1)`` for full details of ``--delegation`` option.



S4U2Proxy
=========

JGSS supports s4u2proxy `as of Java 8`_.

.. _as of Java 8: http://docs.oracle.com/javase/8/docs/technotes/guides/security/jgss/jgss-features.html
