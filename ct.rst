::

  podman run -it lanrat/ct

In container::

  root@970fb0bade0a:/data# cd
  root@970fb0bade0a:~# openssl ecparam -name prime256v1 > privkey.pem
  root@970fb0bade0a:~# openssl ecparam -in privkey.pem -genkey -noout >> privkey.pem
  root@970fb0bade0a:~# openssl ec -in privkey.pem -pubout -out pubkey.pem
  read EC key
  writing EC key
  root@970fb0bade0a:~# vi ci-roots.pem    # write valid roots to this file
  root@970fb0bade0a:~# mkdir -p /data/keys
  root@970fb0bade0a:~# cp * /data/keys


Run CT server::

  root@12c0a5718d23:/data# ct-server \
    --key=/data/keys/privkey.pem \
    --trusted_cert_file=/data/keys/ca-roots.pem \
    --leveldb_db=/data/leveldb/ \
    --i_know_stand_alone_mode_can_lose_data \
    --colorlogtostderr \
    --logtostderr \
    --guard_window_seconds=5 \
    --tree_signing_frequency_seconds=10
