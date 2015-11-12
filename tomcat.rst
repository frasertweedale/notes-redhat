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
    isInitiator=false;
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
