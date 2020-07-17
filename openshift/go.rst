``GOPATH``
==========

See https://golang.org/doc/gopath_code.html#Workspaces for overview.

go looks for source code under ``$GOPATH/src``.  It also downloads
depedency source code under there.  It builds binaries into
``$GOPATH/bin``.  The directory pointed to by ``$GOPATH`` is called
the *workspace*.

Although the Go docs say it defaults to ``$HOME/go``,
``operator-sdk`` did not like it when the ``GOPATH`` environment
variable was not set.

``GOPATH`` is actually a list of directories, like ``PATH``.
