Thread:
https://www.redhat.com/archives/freeipa-users/2014-October/msg00153.html

Using custom FreeIPA pkg repo::

  # mkdir -p /usr/local/etc/pkg/repos
  # cat >/usr/local/etc/pkg/repos/FreeIPA.conf <<"EOF"
  FreeIPA: {
    url: "https://frase.id.au/pkg/${ABI}_FreeIPA",
    signature_type: "pubkey",
    pubkey: "/usr/share/keys/pkg/FreeIPA.pem",
    enabled: yes
  }
  EOF
  # pkg install -y ca_root_nss
  # ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem
  # cat >/usr/share/keys/pkg/FreeIPA.pem <<EOF
  -----BEGIN PUBLIC KEY-----
  MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAopt0Lubb0ur+L+VzsP9k
  i4QrvQb/4gVlmr/d59lUsTr9cz5B5OtNLi+WMVcNh4EmmNIiWoVuQY4Wqjm2d1IA
  VCXw+OqeAuj9nUW4jSvI/lDLyErFBXezNM5yggeesiV2ii+uO41zOjUxnSkupFzh
  zOWr+Oj4kJI/iNU++3RpzyrBSmSGK9TN9k3afhyDMNlJi5SqK/wOrSjqAMfaufHE
  MkJqBibDL/+xx48SbtInhtD4LIneHoOGxVtkLIcTSS5EpnIsDWZgXX6jBatv9LJe
  u2UeQsKLKcCgrhT3VX+pc/aDsUFS4ZqOonLRt9mcFVxC4NDNMKsfXTCd760HQXYU
  enVLydNavvGtGYQpbUWx5IT3IphaNxWANACpWrcvTawgPyGkGTPd347Nqhm5YV2c
  YRf4rVX/S7U0QOzMPxHKN4siZVCspiedY+O4P6qe2R2cTyxntjLVGZcTBlXAdQJ8
  UfQuuX97FX47xghxR6wyWfkXGCes2kVdVo0fF0vkYe1652SGJsfWjc5ojR9KFKkD
  DN3x3Wu6kW0koZMF3Tf0rtSLDmbZEBddIPFrXo8QHiyqFtU3DLrYWGmbLRkYKnYR
  KvG3XCJ6EmvMlfr8GjDIaEiGo7E7IyLusZXXzbIW2EKQdwa6p4N8wrW/30Ov53jp
  rO+Bwn10+9DZTupQ3c04lsUCAwEAAQ==
  -----END PUBLIC KEY-----
  EOF
  # pkg update
  # pkg install -r FreeIPA cyrus-sasl2-gssapi sssd

