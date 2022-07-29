# EST client notes

## libest (C, Cisco)

### Usage

Retrieve CA certs:

```shell
% EST_OPENSSL_CACERT=~/cacert.pem ./example/client/estclient \
    -s $EST_SERVER -p $EST_PORT -o $OUT_DIR -g
```

Simple enroll:

```shell
% EST_OPENSSL_CACERT=~/cacert.pem ./example/client/estclient \
    -s $EST_SERVER -p $EST_PORT -o $OUT_DIR --pem-output -g \
    --common-name "CN=$HOSTNAME"
```
