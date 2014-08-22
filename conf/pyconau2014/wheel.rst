Grug make fire! Grug make wheel! - Dr Russell Keith-Magee
=========================================================

- BeeWare - The IDEs of Python.
  - togo!


What mess?
----------

- setuptools, distribute, distutils, distutils2, pip, standard
  library, eggs, wheel


This talk
---------

On producer end:

- use setuptools to define your setup.py

- build wheels if you can

- provide source distributions

- go to packaging.python.org

On user end:

- create pyvenv / virtualenv

- install using pip


setuptools
----------

- not in stdlib, but extends functionality in stdlib.
- defines package and metadata
- also a tool you run


wheel
-----

- distrubutable unit of python code
- if you don't have a way to compile code in a platform-specific
  manner, you can't install some packages
- code that needs to be run when a package is *installed*
- a zip file will defined internal structure and some metadata
- versioned by operation system they support, i.e. "windows wheel",
  "OSX wheel"; PyPA team working on Unix.

Do we wheely need it?

- haven't I just described what an egg is?
- eggs were intended to be an execution format; wheel is explicitly
  *not*, i.e. installation only.

Other tools:

- tox: metatesting tool
- sphinx: doc builder (ReST)
- Read The Docs: doc hosting


setup.cfg
---------

- ini format
- headings are setup.py commands; configs are options.
- not strictly required; just defining default settings for running
  setuptools.

Other tools:

- check-manifest
- bumpversion
- semver?


Packaging tools
---------------

::

  pip install setuptools
  pip install wheel
  pip install twine

- twine is used to wrap up the packages that you sent to PyPI
- universal wheel; use only if:
  - runs on Python 2 & 3
  - has no C exts
- platform wheel; use if:
  - project has C exts
  - only for OSX and Windows
- register your package
  - manually
  - automated, via setup.py (not secure; ticket logged)
- upload your package
  - ``twine upload dist/*`` (does it support signing)
  - replacement for ``python setup.py upload``
  - lets you do pre-upload testing


Installing wheels
-----------------

- ``pip install python-fire``
- pip will prefer wheels over source distributions
- to get pip:
  - Python >= 3.4: ``python -m ensurepip``


virtualenv
----------

::

  $ pyvenv proj-sandbox
  $ source proj-sandbox/bin/activate
