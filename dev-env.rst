Packages etc needed for setting up a dev box how I like it...

Fedora
======

::

  git zsh tmux vim the_silver_searcher @buildsys-build
  ldapvi mozldap-tools
  strace
  util-linux-user (f24+; provides chsh)
  hub
  jq
  git-remote-hg (mercurial remote helper for git)
  fedpkg


Fedora workstation
==================

In addition to the above:

- authentication: ``krb5-workstation``
- build: ``@buildsys-build autoconf``
- vcs: ``git hub mercurial``
- editors: ``emacs-nox``
- mail: ``mutt fetchmail maildrop notmuch thunderbird``
- irc: ``isrri``
- containers: ``docker origin-clients``
- security: ``wireshark-gtk testssl``
- virt: ``virt-manager libguestfs-tools-c (virt-sparsify)``
- textproc: ``texlive-collection-latex pandoc pandoc-pdf``
- multimedia: ``gimp gpodder``
- other: ``gnome-tweak-tool``

Other setup steps:

- ``systemctl enable sshd``

Haskell dev
===========

- ``sudo dnf copr enable petersen/stack``
- ``sudo dnf install ghc-compiler stack cabal-install``
