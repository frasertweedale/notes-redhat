Mypy in FreeIPA
===============

f26 provides mypy v0.521 which includes many enhancements over
v0.4.3 (f25).

We still support python 2 and for a long time, and fixes will be
backported to versions using py2 for a long time, so we will use the
comment syntax only.

imports of 'typing' may require python version check.  the 'typing'
module is available as a pip install but is not packaged for Fedora
/ RHEL.  OTOH maybe it is fine to incur this as part of CI-only
checks.

imports of 'typing' may require suppression of pep8 'unused import'
warning, because the imported values are only referenced in type
comments.
