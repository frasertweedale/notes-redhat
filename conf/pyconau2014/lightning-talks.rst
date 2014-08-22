Saturday
========

toga
----

``pip install toga``


Git notes
---------

- Can I use for igor?
- libgit2 support?  (binding support?)


Sunday
======

State of Jython
---------------

- 2.7.0 under active development (currently in beta3)
- should have final release by Q4.
- min ver now JVM 7
- support for buffer and memoryview
- enables mixing Python and Java types in the bases of a class
- socket-reboot
  - implements socket/select/ssl on Netty 4
  - supports requests!
- PyPA tooling support
- virtualenv and tox support
- performance tuning of regular expressiosn (sre)
- tools:
  - clamp - improve Java and Python integration
  - jiffy - Python C FFI support
  - patois
  - JyNI


Saratoga - @hawkowl
-------------------

- implementations (do things) + definitions (of what your API is)
- api is versions
- versions have endpoints
- endpoints maps to functions
- functions return data
- metadata (global across API) and versions (per processor)
