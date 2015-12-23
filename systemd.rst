Testing socket activated daemons
--------------------------------

See ``systemd-activate(8)``.

Example::

  % /usr/lib/systemd/systemd-activate -l 5700 \
    ./src/progs/tang-serve -d db
  Listening on [::]:5700 as 3.
  < time passes >
  Communication attempt on fd 3.
  Execing ./src/progs/tang-serve (./src/progs/tang-serve -d db)
