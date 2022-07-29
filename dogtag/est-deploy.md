# Installation

## Option 1: Build from WIP branch

Details omitted.

## Option 2: Use COPR (Fedora 36 / rawhide)

```shell
# dnf copr enable -y ftweedal/pki-est
# dnf copr enable -y @pki/master
# dnf install -y pki-ca pki-est 389-ds-base
```

# Deployment and configuration

## Overview

The basic deployment and configuration steps are:

- Deploy CA subsystem
- Create EST RA user
- Create EST certificate profile
- Deploy and configure EST subsystem

## 1. Deploy CA subsystem

Deploy DS according to steps at
https://github.com/dogtagpki/pki/wiki/DS-Installation.  Note well
the Directory Manager password, which is required during Dogtag
deployment.

Then deploy the CA subsystem.  The following transcript shows the
interactive installation option:

```shell
# pkispawn
…
Subsystem (CA/KRA/OCSP/TKS/TPS) [CA]:
 
Tomcat:
  Instance [pki-tomcat]:
  HTTP port [8080]:
  Secure HTTP port [8443]:
  AJP port [8009]:
  Management port [8005]:
 
Administrator:
  Username [caadmin]:
  Password: ********
  Verify password: ********
  Import certificate (Yes/No) [N]?
  Export certificate to [/root/.dogtag/pki-tomcat/ca_admin.cert]:
 
Directory Server:
  Hostname [f36-1.ipa.test]:
  Use a secure LDAPS connection (Yes/No/Quit) [N]?
  LDAP Port [389]:
  Bind DN [cn=Directory Manager]:
  Password: ********
  Base DN [o=pki-tomcat-CA]: dc=pki,dc=example,dc=com
  Base DN already exists. Overwrite (Yes/No/Quit)? yes
 
Security Domain:
  Name [ipa.test Security Domain]:
 
Begin installation (Yes/No/Quit)? yes
 
Installing CA into /var/lib/pki/pki-tomcat.
…
    ==========================================================================
                                INSTALLATION SUMMARY
    ==========================================================================
 
      Administrator's username:             caadmin
      Administrator's PKCS #12 file:
            /root/.dogtag/pki-tomcat/ca_admin_cert.p12
 
      To check the status of the subsystem:
            systemctl status pki-tomcatd@pki-tomcat.service
 
      To restart the subsystem:
            systemctl restart pki-tomcatd@pki-tomcat.service
 
      The URL for the subsystem is:
            https://f36-1.ipa.test:8443/ca
 
      PKI instances will be enabled upon system boot
 
    ==========================================================================
```

Create the caadmin NSSDB for use with the pki(1) client tool.  For
convenience, reset the nickname of the certificate for "caadmin":

```shell
# mkdir nssdb
# certutil -d nssdb -f <(echo 4me2Test) -N
# pk12util -d nssdb -K 4me2Test \
    -i /root/.dogtag/pki-tomcat/ca_admin_cert.p12 -W Secret.123
pk12util: PKCS12 IMPORT SUCCESSFUL
# certutil -d nssdb -L | grep u,u,u
PKI Administrator for ipa.test                               u,u,u
# certutil -d nssdb -f <(echo 4me2Test) -n "PKI Administrator for ipa.test" \
    --rename –new-n caadmin
# certutil -d nssdb -L | grep u,u,u
caadmin                                                      u,u,u
```

## 2. Create EST RA user

Create a Dogtag user group for EST RA accounts, and an EST RA
account.  The EST subsystem will use this account to authenticate to
the CA subsystem and issue certificates on behalf of EST clients.

```shell
# pki -d nssdb -c 4me2Test -n caadmin ca-group-add "EST RA Agents"
---------------------------
Added group "EST RA Agents"
---------------------------
  Group ID: EST RA Agents
# pki -d nssdb -c 4me2Test -n caadmin ca-user-add \
    est-ra-1 --fullName "EST RA 1" --password est4ever
---------------------
Added user "est-ra-1"
---------------------
  User ID: est-ra-1
  Full name: EST RA 1
# pki -d nssdb -c 4me2Test -n caadmin ca-group-member-add "EST RA Agents" est-ra-1    
-----------------------------
Added group member "est-ra-1"
-----------------------------
  User: est-ra-1
```

## 3. Create EST certificate profile

We must create a certificate profile suitable for EST certificates.
Use of this profile is restricted (by way of its authz
configuration) to members of the EST RA Agents group.

::: note

The appropriate configuration of the AIA and CRLDP extensions will
vary by deployment.  The values below are examples only.  For
demo/test purposes, the AIA and CRLDP values only need to be changed
if you are performing OCSP checking or CRL checking in the test
environment.

:::

```shell
# cat >profile.cfg <<'EOF'
profileId=estServiceCert
auth.instance_id=SessionAuthentication
authz.acl=group="EST RA Agents"
classId=caEnrollImpl
desc=EST service certificate profile
enable=true
input.i1.class_id=certReqInputImpl
input.i2.class_id=submitterInfoInputImpl
input.list=i1,i2
name=EST Service Certificate Enrollment
output.list=o1
output.o1.class_id=certOutputImpl
policyset.list=serverCertSet
policyset.serverCertSet.1.constraint.class_id=keyUsageExtConstraintImpl
policyset.serverCertSet.1.constraint.name=Key Usage Extension Constraint
policyset.serverCertSet.1.constraint.params.keyUsageCritical=true
policyset.serverCertSet.1.constraint.params.keyUsageCrlSign=false
policyset.serverCertSet.1.constraint.params.keyUsageDataEncipherment=false
policyset.serverCertSet.1.constraint.params.keyUsageDecipherOnly=false
policyset.serverCertSet.1.constraint.params.keyUsageDigitalSignature=true
policyset.serverCertSet.1.constraint.params.keyUsageEncipherOnly=false
policyset.serverCertSet.1.constraint.params.keyUsageKeyAgreement=false
policyset.serverCertSet.1.constraint.params.keyUsageKeyCertSign=false
policyset.serverCertSet.1.constraint.params.keyUsageKeyEncipherment=true
policyset.serverCertSet.1.constraint.params.keyUsageNonRepudiation=false
policyset.serverCertSet.1.default.class_id=keyUsageExtDefaultImpl
policyset.serverCertSet.1.default.name=Key Usage Default
policyset.serverCertSet.1.default.params.keyUsageCritical=true
policyset.serverCertSet.1.default.params.keyUsageCrlSign=false
policyset.serverCertSet.1.default.params.keyUsageDataEncipherment=false
policyset.serverCertSet.1.default.params.keyUsageDecipherOnly=false
policyset.serverCertSet.1.default.params.keyUsageDigitalSignature=true
policyset.serverCertSet.1.default.params.keyUsageEncipherOnly=false
policyset.serverCertSet.1.default.params.keyUsageKeyAgreement=false
policyset.serverCertSet.1.default.params.keyUsageKeyCertSign=false
policyset.serverCertSet.1.default.params.keyUsageKeyEncipherment=true
policyset.serverCertSet.1.default.params.keyUsageNonRepudiation=false
policyset.serverCertSet.10.constraint.class_id=keyConstraintImpl
policyset.serverCertSet.10.constraint.name=Key Constraint
policyset.serverCertSet.10.constraint.params.keyParameters=2048,3072,4096,8192
policyset.serverCertSet.10.constraint.params.keyType=RSA
policyset.serverCertSet.10.default.class_id=userKeyDefaultImpl
policyset.serverCertSet.10.default.name=Key Default
policyset.serverCertSet.11.constraint.class_id=noConstraintImpl
policyset.serverCertSet.11.constraint.name=No Constraint
policyset.serverCertSet.11.default.class_id=crlDistributionPointsExtDefaultImpl
policyset.serverCertSet.11.default.name=CRL Distribution Points Extension Default
policyset.serverCertSet.11.default.params.crlDistPointsCritical=false
policyset.serverCertSet.11.default.params.crlDistPointsEnable_0=true
policyset.serverCertSet.11.default.params.crlDistPointsIssuerName_0=CN=Certificate Authority,o=ipaca
policyset.serverCertSet.11.default.params.crlDistPointsIssuerType_0=DirectoryName
policyset.serverCertSet.11.default.params.crlDistPointsNum=1
policyset.serverCertSet.11.default.params.crlDistPointsPointName_0=http://ipa-ca.ipa.test/ipa/crl/MasterCRL.bin
policyset.serverCertSet.11.default.params.crlDistPointsPointType_0=URIName
policyset.serverCertSet.11.default.params.crlDistPointsReasons_0=
policyset.serverCertSet.2.constraint.class_id=noConstraintImpl
policyset.serverCertSet.2.constraint.name=No Constraint
policyset.serverCertSet.2.default.class_id=extendedKeyUsageExtDefaultImpl
policyset.serverCertSet.2.default.name=Extended Key Usage Extension Default
policyset.serverCertSet.2.default.params.exKeyUsageCritical=false
policyset.serverCertSet.2.default.params.exKeyUsageOIDs=1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2
policyset.serverCertSet.3.constraint.class_id=noConstraintImpl
policyset.serverCertSet.3.constraint.name=No Constraint
policyset.serverCertSet.3.default.class_id=subjectKeyIdentifierExtDefaultImpl
policyset.serverCertSet.3.default.name=Subject Key Identifier Extension Default
policyset.serverCertSet.3.default.params.critical=false
policyset.serverCertSet.4.constraint.class_id=noConstraintImpl
policyset.serverCertSet.4.constraint.name=No Constraint
policyset.serverCertSet.4.default.class_id=authorityKeyIdentifierExtDefaultImpl
policyset.serverCertSet.4.default.name=Authority Key Identifier Default
policyset.serverCertSet.5.constraint.class_id=noConstraintImpl
policyset.serverCertSet.5.constraint.name=No Constraint
policyset.serverCertSet.5.default.class_id=authInfoAccessExtDefaultImpl
policyset.serverCertSet.5.default.name=AIA Extension Default
policyset.serverCertSet.5.default.params.authInfoAccessADEnable_0=true
policyset.serverCertSet.5.default.params.authInfoAccessADLocationType_0=URIName
policyset.serverCertSet.5.default.params.authInfoAccessADLocation_0=http://ipa-ca.ipa.test/ca/ocsp
policyset.serverCertSet.5.default.params.authInfoAccessADMethod_0=1.3.6.1.5.5.7.48.1
policyset.serverCertSet.5.default.params.authInfoAccessCritical=false
policyset.serverCertSet.5.default.params.authInfoAccessNumADs=1
policyset.serverCertSet.6.constraint.class_id=noConstraintImpl
policyset.serverCertSet.6.constraint.name=No Constraint
policyset.serverCertSet.6.default.class_id=userExtensionDefaultImpl
policyset.serverCertSet.6.default.name=User supplied extension in CSR
policyset.serverCertSet.6.default.params.userExtOID=2.5.29.17
policyset.serverCertSet.7.constraint.class_id=validityConstraintImpl
policyset.serverCertSet.7.constraint.name=Validity Constraint
policyset.serverCertSet.7.constraint.params.notAfterCheck=false
policyset.serverCertSet.7.constraint.params.notBeforeCheck=false
policyset.serverCertSet.7.constraint.params.range=90
policyset.serverCertSet.7.default.class_id=validityDefaultImpl
policyset.serverCertSet.7.default.name=Validity Default
policyset.serverCertSet.7.default.params.range=90
policyset.serverCertSet.7.default.params.startTime=0
policyset.serverCertSet.8.constraint.class_id=signingAlgConstraintImpl
policyset.serverCertSet.8.constraint.name=No Constraint
policyset.serverCertSet.8.constraint.params.signingAlgsAllowed=SHA256withRSA,SHA384withRSA,SHA512withRSA,SHA256withEC,SHA384withRSA,SHA384withEC,SHA512withEC
policyset.serverCertSet.8.default.class_id=signingAlgDefaultImpl
policyset.serverCertSet.8.default.name=Signing Alg
policyset.serverCertSet.8.default.params.signingAlg=-
policyset.serverCertSet.20.constraint.class_id=subjectNameConstraintImpl
policyset.serverCertSet.20.constraint.name=Subject Name Constraint
policyset.serverCertSet.20.constraint.params.pattern=CN=[^,]+,.+
policyset.serverCertSet.20.constraint.params.accept=true
policyset.serverCertSet.20.default.class_id=subjectNameDefaultImpl
policyset.serverCertSet.20.default.name=Subject Name Default
policyset.serverCertSet.20.default.params.name=CN=$request.req_subject_name.cn$, O=IPA.TEST
policyset.serverCertSet.21.constraint.class_id=noConstraintImpl
policyset.serverCertSet.21.constraint.name=No Constraint
policyset.serverCertSet.21.default.class_id=commonNameToSANDefaultImpl
policyset.serverCertSet.21.default.name=CN To SAN Default
policyset.serverCertSet.list=1,2,3,4,5,6,7,8,10,11,20,21
visible=true
EOF
# pki -d nssdb -c 4me2Test -n caadmin ca-profile-add --raw profile.cfg
...
----------------------------
Added profile estServiceCert
----------------------------
# pki -d nssdb -c 4me2Test -n caadmin ca-profile-enable estServiceCert
--------------------------------
Enabled profile "estServiceCert"
--------------------------------
```

## 4. Deploy and configure EST subsystem

```shell
# pki-server est-create
# cat >/etc/pki/pki-tomcat/est/backend.conf <<EOF
class=org.dogtagpki.est.DogtagRABackend
url=https://$(hostname):8443
profile=estServiceCert
username=est-ra-1
password=est4ever
EOF
# pki-server est-deploy
```

Additional configuration steps will arise when the authentication
and authorization facilities of the Dogtag EST service have been
implemented.

# Verification

Use `curl` to verify that the EST subsystem is deployed and is able
to communicate with the CA subsystem:

```shell
% curl -k --head https://$(hostname):8443/.well-known/est/cacerts
HTTP/1.1 200
Content-Type: application/pkcs7-mime
Transfer-Encoding: chunked
Date: Tue, 26 Jul 2022 05:47:49 GMT
```

HTTP response status 200 indicates success.
