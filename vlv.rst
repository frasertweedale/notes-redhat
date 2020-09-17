Performing VLV search
=====================

Performing VLV search for highest serial number in range.  This kind
of search can be used to diagnose whether corrupt or incomplete VLV
index is the cause of issuance failures.  Other repositories
(requests, keys, etc) work in the same way but use a different
attribute.

::

  # ldapsearch -LLL -D "cn=Directory Manager" -w $PASS -s one \
      -b ou=certificateRepository,ou=ca,o=ipaca '(certStatus=*)' \
      -E 'sss=serialno' -E 'vlv=5/0:09267911168' 1.1
  dn: cn=397,ou=certificateRepository,ou=ca,o=ipaca

  ## NOTE: beyond clone's range, can be ignored.
  dn: cn=267911185,ou=certificateRepository,ou=ca,o=ipaca

  # sortResult: (0) Success
  # vlvResultpos=2 count=177 context= (0) Success

Note: due to how numbers are stored in Dogtag, the leading '0' in
the target value is critical!


Rebuild VLV indices (Dogtag)
============================

Procedure derived from
https://www.dogtagpki.org/wiki/DS_Database_Indexes#Rebuilding_VLV_indexes.

::

  $ /bin/cp /usr/share/pki/ca/conf/vlvtasks.ldif .
  $ sed -i "s/{instanceId}/pki-tomcat/g" vlvtasks.ldif
  $ sed -i "s/{database}/ipaca/g" vlvtasks.ldif
  $ ldapadd -x -D "cn=Directory Manager" -w $DM_PASS -f vlvtasks.ldif

Note that ``{database}`` should be replaced with ``ipaca`` in a
FreeIPA instance, but usually ``ca`` for a standalone Dogtag
deployment.

Check that task has completed successfully.  The task object will
only live for 10 seconds after the task finishes::

  $ ldapsearch -x -D "cn=Directory Manager" -w $DM_PASS \
    -b "cn=index1160589769,cn=index,cn=tasks,cn=config"

Object after completion (before removal)::

  dn: cn=index1160589769,cn=index,cn=tasks,cn=config
  objectClass: top
  objectClass: extensibleObject
  cn: index1160589769
  ttl: 10
  nsinstance: ipaca
  nsindexvlvattribute: allCerts-pki-tomcatIndex
  # .. 33 more nsindexvlvattribute values
  nsTaskCurrentItem: 0
  nsTaskTotalItems: 1
  nsTaskCreated: 20200916021128Z
  nsTaskLog:: aXBhY2E6IEluZGV4aW #... (base64-encoded log text)
  nsTaskStatus: ipaca: Finished indexing.
  nsTaskExitCode: 0

Server should be restarted after indexing complete.
