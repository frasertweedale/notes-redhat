========================================
Changing the world with ZeroVM and Swift
========================================
Bringing the application to the data
========================================

ZeroVM
======

ZeroVM Genesis
--------------

- In 2008 Google release NaCl paper.
- Sandbox env for safe client-side execution of native code in
  Chrome browser.
- Combines memory segmentation with runtime disassembly.

Plain english
-------------

  ZeroVM creates a secure isolated execution environment that allow
  suser to run a single application or program.

  Service providers can leverage ZeroVM to allow their users to run
  application inside of multi-tenant systems.

Technical details
-----------------

- based on NaCl
- leverages ZeroMQ broker (networked named pipes)
- includes a full compiler toolchain
- ZRT (ZeroVM Runtime) provides subset of POSIX API.
  - Many programs can compile to it right now.
- ZRT also includes a port of the CPython interpreter
  - Most Python programs can run in ZeroVM
  - Biggest caveat: shared objects cannot be loaded.
- Single-threaded
- No concurrency (only by using multiple applications)
- No NICs.
- No filesystem.

NaCl vs ZeroVM
---------------
- ZeroVM retains same restrictions as NaCl
- ZeroVM retains the disassembly checking
- ZeroVM comes with its own runtime environment (ZRT)
- Files represent input and output in true UNIX fashion

ZeroVM principles
-----------------

- Small (a few 100 KB), light (spawn <5ms), fast (near-native)
- Secure (fault isolation; sandbox; pre-execution disassembly)
- Functional
- Hyper-scalable
- Open Source
- Embeddable (anywhere you can put Linux)


Evolution of computing
======================

The path to abstraction
-----------------------

- Physical machines (one unit)
- Virtual machine (one unit)
- Cloud infrastructure (still tied to idea of "server" as an atomic
  unit)
- Containers (i.e. Docker, jails)
- People don't actually care about the server; they care about the
  application.
- ZeroVM; get rid of everything else and focus on the application

VM vs Container vs ZeroVM
-------------------------

- VM: shared hardware, dedicated kernel/OS, high overhead, slow
  start (minutes).
- Container: shared hardware, shared kernel/OS, low overhead, fast
  startup (seconds).
- ZeroVM: shared hardware, no kernel/OS, very low overhead, very
  fast startup (microseconds).


Embedding ZeroVM in OpenStack Swift
===================================

- Artificial problem: *storage* and *compute* in different places.
- Compute power is useless unless we're operating on data.
- Data is also useless unless we do stuff with it.
- This motivates putting ZeroVM on Swift.

Swift architecture
------------------

- *Proxy nodes* schedule and route requests to *storage nodes*.
- ZVM on all nodes.
- ZVM can start immediately on a node and e.g. perform some
  computation on a file.
- Massively parallel data processing (example: map-reduce word
  count)
- Called *Zerocloud*.

Use cases
---------

- Video transcoding (low hanging fruit; killer app)
  - Video is binary; doesn't compress well.
  - Replace with specially designed Swift cluster that *becomes* the
    render farm.
  - Just recompile the existing applications to target ZeroVM

- Log searching (parallel grep)
  - Has been done.
  - They ran grep through 17G of misc log files
  - Usually took 5 hours to run the search
  - With Zerocloud: 3 minutes!

- Distributed SQL
  - ZeroVM as SQL engine

Resources
---------

- https://github.com/zerovm
- http://zerovm.org
- http://zebra.zerovm.org - publically accessible Swift cluster with
  ZeroVM.  Request an account.
