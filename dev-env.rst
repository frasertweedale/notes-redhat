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
- mail: ``mutt fetchmail maildrop notmuch thunderbird lynx``
- irc: ``isrri``
- containers: ``docker origin-clients``
- security: ``wireshark-gtk testssl``
- virt: ``virt-manager libguestfs-tools-c libvirt-client``
- textproc: ``texlive-collection-latex pandoc pandoc-pdf``
- multimedia: ``gimp gpodder``
- other: ``gnome-tweak-tool``

Other setup steps:

- ``systemctl enable sshd``

- polkit policy to allow user to control libvirtd without
  password prompt: https://superuser.com/questions/548433/how-do-i-prevent-virt-manager-from-asking-for-the-root-password

- In ``/etc/systemd/logind.conf``, set ``KillUserProcesses=no``
  so that systemd does not kill tmux session on logout
  (or gnome-shell crash).

``gnome-terminal`` configuration
--------------------------------

::

  dconf load /org/gnome/terminal/ <<EOF
  [legacy/keybindings]
  help='disabled'

  [legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
  foreground-color='rgb(255,255,255)'
  palette=['rgb(26,26,26)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(205,205,0)', 'rgb(0,116,230)', 'rgb(255,53,233)', 'rgb(0,255,255)', 'rgb(229,229,229)', 'rgb(76,76,76)', 'rgb(255,0,0)', 'rgb(0,255,0)', 'rgb(255,255,0)', 'rgb(0,116,230)', 'rgb(255,0,255)', 'rgb(0,255,255)', 'rgb(255,255,255)']
  word-char-exceptions=@ms '|'
  cursor-shape='block'
  use-system-font=false
  use-theme-colors=false
  font='DejaVu Sans Mono 9'
  allow-bold=true
  bold-color-same-as-fg=true
  background-color='rgb(0,0,0)'
  audible-bell=false

  [legacy]
  schema-version=uint32 3
  default-show-menubar=false
  EOF


Haskell dev
===========

- ``sudo dnf copr enable petersen/stack``
- ``sudo dnf install ghc-compiler stack cabal-install``
- ``sudo dnf install ghc-ghc-devel happy`` (for building ghc-mod)
