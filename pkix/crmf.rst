::

  16:46 <mrniranjan> http://dhcp207-176.lab.eng.pnq.redhat.com/pki/pki/tests/dogtag/shared/generateCRMFRequest.java
  16:48 <mrniranjan> java -cp 
  :./:/usr/lib/java/jss4.jar:/usr/share/java/pki/pki-nsutil.jar:/usr/share/java/pki/pki-cmsutil.jar:/usr/share/java/apache-commons-codec.jar:/usr/share/java/pki/pki-silent.jar:/opt/rhqa_pki/java/generateCRMFRequest.jar: generateCRMFRequest 
                     -client_certdb_dir /tmp/foo3 -client_certdb_pwd redhat -debug false -request_subject 'CN=Idm 
                     User4,UID=IdmUser4,E=idmuser4@example.org,OU=MAP Division,O=Example Org,C=US' -request_keytype rsa -r

