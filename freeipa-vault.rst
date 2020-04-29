Exploring FreeIPA Vault
=======================

FreeIPA has a secret store feature called *vaults*.  I have never
used this feature, except in a minimal way to verify the system is
working properly.  But I have received some very good questions from
other developers and the documentation team about the design and
user experience of FreeIPA Vault.

This blog post is, simply put, a transcript of my exploration of the
Vault system.  With some cleanups and commentary.  The directions of
exploration were guided by the questions posed by my colleagues, so
I'll include some context at various stages.

My thanks to my colleague Endi Dewata who wrote much of the Vault
system and was diligent to document_ `the design_` in the FreeIPA
upstream wiki.  He also provided some detailed responses to the
questions we received about Vault.

.. _document: https://www.freeipa.org/page/V4/Password_Vault/Design
.. _the design: https://www.freeipa.org/page/V4/Password_Vault_1.2


Vault installation
------------------

FreeIPA vault requires the *Key Recovery Authority (KRA)* server
role.  The KRA is part of Dogtag PKI and requires the CA role first
be installed on the server.

During initial FreeIPA installation you can install the KRA with::

  ipa-server-install --setup-ca --setup-kra ...

Replica installation is similar::

  ipa-replica-install --setup-ca --setup-kra ...

But note that for replica installation, the CA and KRA must already
have been installed elsewhere in the topology.

To install a KRA on an existing FreeIPA server (whether or not it
will be the first KRA instance in the topology), execute::

  ipa-kra-install

The CA role must already be installed on that server.

To see which servers in your deployment are KRA servers use the
``ipa server-role-find`` command::

  # ipa server-role-find --role 'KRA server'
  ---------------------
  1 server role matched
  ---------------------
    Server name: rhel82-0.ipa.local
    Role name: KRA server
    Role status: enabled
  ----------------------------
  Number of entries returned 1
  ----------------------------

In my test deployment there is one KRA server.  In a real-world
deployment, you should have **at least two** for reliability and
data loss prevention.


Vault commands
--------------

I executed ``ipa help vault`` to read the built-in Vault topic
documentation.  There is some introductory text explaining the types
of vault encryption (symmetric, asymmetric, and *standard*) and that
there are three "categories": user/private, service, and shared.
There are some command usage examples, and then a list of all the
related commands::

  Topic commands:
    vault-add                    Create a new vault.                          
    vault-add-member             Add members to a vault.                      
    vault-add-owner              Add owners to a vault.                       
    vault-archive                Archive data into a vault.                   
    vault-del                    Delete a vault.
    vault-find                   Search for vaults.                           
    vault-mod                    Modify a vault.
    vault-remove-member          Remove members from a vault.                 
    vault-remove-owner           Remove owners from a vault.                  
    vault-retrieve               Retrieve a data from a vault.                
    vault-show                   Display information about a vault.           
    vaultconfig-show             Show vault configuration.                    
    vaultcontainer-add-owner     Add owners to a vault container.             
    vaultcontainer-del           Delete a vault container.                    
    vaultcontainer-remove-owner  Remove owners from a vault container.        
    vaultcontainer-show          Display information about a vault container. 

One of the questions I am to investigate is: *what is the deal with
vault containers?*.  And it is easy to see why.  There are commands
to ``show`` and ``delete``, but no ``add`` or ``find``.

Before I begin that investigation, let me briefly discuss secret
storage and retrieval.  Vaults have three *types*, referring to the
mechanism used to secure the secret:

``standard``
  The secret is transported to/from and stored securely by the KRA.
  But anyone with read access on the vault can read the secret.

``symmetric``
  The secret is wrapped using a symmetric key.  In additional to
  vault access checks, the symmetric key is required to store or
  retrieve a secret.

``asymmetric``
  The secret is wrapped using a public key.  In additional to
  vault access checks, the public key is required to store a
  secret, and the private key is required to retrieve the secret.

Each of these types is useful for different use cases.  Horses for
courses.  The commands used to create vaults, and store or retrieve
secrets are ``vault-add``, ``vault-archive`` and ``vault-retrieve``.
These commands are straightforward.  I will not go into much detail
because that is not my current line of investigation.  Use ``ipa
help <command>`` or the ``--help`` option to learn about them).


Vault containers
----------------

So, back to *vault containers*.  There is no ``ipa
vaultcontainer-add`` command so where do they come from?  I just
created a new user ``bob`` and will create a vault to investigate.

::

  # klist |grep principal:
  Default principal: bob@IPA.LOCAL

  # ipa vault-find
  ----------------
  0 vaults matched
  ----------------
  ----------------------------
  Number of entries returned 0
  ----------------------------

  # ipa vaultcontainer-show
  ipa: ERROR: : vaultcontainer not found

  # ipa vaultcontainer-show --user bob
  ipa: ERROR: : vaultcontainer not found

Witness that ``bob`` has no vaults, and no vault containers.

::

  # ipa vault-add --type=standard vault-bob-1
  -------------------------
  Added vault "vault-bob-1"
  -------------------------
    Vault name: vault-bob-1
    Type: standard
    Owner users: bob
    Vault user: bob

  # ipa vaultcontainer-show
    Owner users: bob
    Vault user: bob

We created ``vault-bob-1``, and lo, a vault container appeared.  But
what even is a vault container?  Let's use the ``--all`` option to
have a closer look at these objects.

::

  # ipa vault-show vault-bob-1 --all
    dn: cn=vault-bob-1,cn=bob,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Vault name: vault-bob-1
    Type: standard
    Owner users: bob
    Vault user: bob
    objectclass: ipaVault, top

Now we have a clue.  The vault object exists inside the
``cn=bob,cn=users,cn=vaults,cn=kra,{basedn}`` container.  Let's now
use ``--all`` with ``vaultcontainer-show``::

  # ipa vaultcontainer-show --all
    dn: cn=bob,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Owner users: bob
    Vault user: bob
    cn: bob
    objectclass: ipaVaultContainer, top

  # ipa vaultcontainer-show --user=bob  --all
    dn: cn=bob,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Owner users: bob
    Vault user: bob
    cn: bob
    objectclass: ipaVaultContainer, top

This confirms that the *vault container*, at least for users, is a
namespace in which all the user's vaults live.  The vault container
is created "on demand" when the user creates a vault.  There is no
``ipa vaultcontainer-add`` command; it does not seem to be required.

The lack of add command does not align with how most objects are
managed in FreeIPA.  It might be technically possible to resolve the
discrepancy and require vault containers to be explicitly created,
before user vaults can be added.  But it would be a behavioural
change and it might be better to leave it alone and document the
behaviour well.

The lack of ``ipa vaultcontainer-find`` command is another departure
from the standard FreeIPA interface.  Now that I understand the
object layout, it is clear that it would be feasible to implement
it.  But based on my current (limited) knowledge it does not seem
useful because each user only has one vault container.  Perhaps my
opinion will change as I learn more.

Finally, observe in the previous transcript that the following
commands output the same object::

  # ipa vaultcontainer-show --all
  # ipa vaultcontainer-show --user=bob  --all

I deduce that the first form implicitly supplies the current user
(or perhaps more generally, *principal*).  TODO check source code.


Removing vault containers
-------------------------

There may be no ``vaultcontainer-add``, but there is a
``vaultcontainer-del`` so let's play with it::

  # ipa vaultcontainer-del 
  ipa: ERROR: Not allowed on non-leaf entry

  # ipa vaultcontainer-del --user=bob 
  ipa: ERROR: Not allowed on non-leaf entry

Again it seems the first form implies the authenticated principal.
The server did not delete the vault container because it is a
"non-leave entry" i.e., it contains at least one object (vault).
Let's remove the vault.  Perhaps ``vault-del`` will automatically
delete the vault container when the last vault is deleted (i.e. the
dual of ``vault-add`` automatically adding the vault container).

::

  # ipa vault-del vault-bob-1
  ---------------------------
  Deleted vault "vault-bob-1"
  ---------------------------

  # ipa vaultcontainer-show
    Owner users: bob
    Vault user: bob

  # ipa vaultcontainer-del
  -----------------------
  Deleted vault container
  -----------------------

  # ipa vaultcontainer-show
  ipa: ERROR: : vaultcontainer not found

So vault containers are not automatically deleted when they become
empty.  But after deleting the last vault, ``vaultcontainer-del`` is
effective.


Vault ownership
---------------

I will now explore in more detail the topic of vault and vault
container ownership.

We see that the ``ipa vault-add`` command has a ``--user`` option.
Can a user create vaults in other users' vault containers?

::

  # klist |grep principal:
  Default principal: bob@IPA.LOCAL

  # ipa vault-add vault-alice-1 --user alice --type standard
  ipa: ERROR: Insufficient access: Insufficient 'add' privilege to add the entry
  'cn=vault-alice-1,cn=alice,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local'.

``bob``, an ordinary user, does not have permission to create a
vault on behalf of ``alice``.  But it seems like you could assign
such permissions to users.  Certainly the ``admin`` account has
permission to do this::

  # klist |grep principal:
  Default principal: admin@IPA.LOCAL

  # ipa vault-add --type=standard vault-alice-1 --user alice --all
  ---------------------------
  Added vault "vault-alice-1"
  ---------------------------
    dn: cn=vault-alice-1,cn=alice,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Vault name: vault-alice-1
    Type: standard
    Owner users: admin
    Vault user: alice
    objectclass: ipaVault, top

  # ipa vaultcontainer-show --user alice --all
    dn: cn=alice,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Owner users: admin
    Vault user: alice
    cn: alice
    objectclass: ipaVaultContainer, top

So, ``admin`` is the vault (and vault container) *owner*, and
``alice`` is a *user* of the vault.  Can we supply ``--user``
multiple times when creating a vault?

::

  # ipa vault-add --type=standard vault-alice-and-bob \
      --user alice --user bob --all
  ipa: ERROR: invalid 'username': Only one value is allowed

That is not valid.  So the following is now clear:

- ``--user`` nominates the vault container *namespace*

- The corresponding user becomes the (initial) *vault user*

- The user who created the vault is the *vault owner*; the could be
  the vault user or a different user with the required permissions


Managing vault owners
~~~~~~~~~~~~~~~~~~~~~

TODO


Vaults for non-existent users
-----------------------------

Can we create a vault in a vault container corresponding to a user
who doesn't exist?

::

  # klist |grep principal:
  Default principal: admin@IPA.LOCAL

  # ipa user-show carol
  ipaipa: ERROR: carol: user not found

  # ipa vault-add --type=standard vault-carol-1 --user carol --all
  ---------------------------
  Added vault "vault-carol-1"
  ---------------------------
    dn: cn=vault-carol-1,cn=carol,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Vault name: vault-carol-1
    Type: standard
    Owner users: admin
    Vault user: carol
    objectclass: ipaVault, top

  # ipa vaultcontainer-show --user carol --all
    dn: cn=carol,cn=users,cn=vaults,cn=kra,dc=ipa,dc=local
    Owner users: admin
    Vault user: carol
    cn: carol
    objectclass: ipaVaultContainer, top

That is allowed.  A bit surprising too.  This could happen in real
use if the operator mistyped the user name.  I tried to think of a
legitimate use case.  One idea came to mind: to populate a user
vault with passwords or keys for onboarding when they join the
organisation.  But of course, you can pre-create the user too, so
that use case isn't a strong justification.

I reached out to others for comment.  If an explanation or an action
plan emerges, I'll add an update here.



MORE TODO HERE


Action items
------------

We should add a vault container help topic, i.e. ``ipa help
vaultcontainer`` should bring up some documentation about vault
containers.
