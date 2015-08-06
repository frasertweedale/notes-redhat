Privsep
-------

[VIDEO NOT UPLOADED YET]

This was a very interesting talk about privilege separation in
OpenStack.  Covered the history of originally using sudo
(``sudoers`` became unmaintainable), ``rootwrap`` and
``rootwrap-daemon`` which are command-line oriented and finally
``privsep`` which is based around Python function calls and uses
SELinux.

Well worth a watch and I wonder if there are places we could use
``privsep`` in IdM.


Making sensible security decisions by assuming the worst - Tom Eastman
----------------------------------------------------------------------

https://www.youtube.com/watch?v=EQVaNTRqIjY

Good "defense in depth" encourages thinking about bad actors and
their motivations, and reducing attack surface at all the layers
within your organisation / infrastructure, not just the obvious
entry-points.

2FA and SELinux / AppArmor were highly regarded by the presenter and
he was encouraging their use.


Practical Federated Identity - Jamie Lennox
-------------------------------------------

https://www.youtube.com/watch?v=YYzJdxI_g6g

Jamie's impressive demo for setting up OpenStack Keystone and
Horizon to use Ipsilon for authenticating / authorising users.  I
didn't end up covering Ipsilon in my Django-IdM talk (25 minutes is
not much time!) so I'm glad Jamie was able to show it off.


Future of Identity (Keystone) in OpenStack - Morgan Fainberg
------------------------------------------------------------

https://www.youtube.com/watch?v=BiFUDT4aGFk

Talked about the push to remove all authentication facilities from
Keystone itself and embrace federated SSO, limitiations of PKI
tokens and discussion of the next gen protocol which will use Fernet
tokens.  I guess (but did not ask) that they will be using
python-cryptography for the Fernet implementation.


JSON Standards for the Open Web - Jamie Lennox
----------------------------------------------

https://www.youtube.com/watch?v=BplV6BwAdsI

Jamie's other talk about JSON standards for API discoverability
(jsonhome), object syntaxes / validation (jsonschema), patch formats
(jsonpatch) and more.  A whole bunch of standards and related Python
libraries are mentioned.  If we decide to do an official REST API,
that would be a good time to examine what's out there and what we
could or should use that will make it easier for people / clients to
use our APIs.


Integrating Django with Identity Mangaement Systems - Fraser Tweedale
---------------------------------------------------------------------

https://www.youtube.com/watch?v=HhcotmeioT8

My take on the external authnz story for Django.  25 minutes is not
much time, and after a run-through at the BNE office I was
encouraged to focus on high-level motivations for external auth,
then present the demo, before focusing on the technical details.  If
you have time to watch it I would appreciate any feedback because
I've had this same topic accepted for Kiwi PyCon next month.

I had questions about:

- SAML (which only got a brief mention in my talk)
- Nginx remote auth support
- User sign-up support (community portal!)
- Single sign-out
- and of course that question about "why not a Python solution for X?"

In my talk I spoke about Django ticket #25164 which was rejected.
After the talk I had a deeper discussion with a Django dev about the
issue and he said he'd have a look at it and see if there's a case
for reopening it.  I hope it happens.


Cooking with Cryptography - Fraser Tweedale
-------------------------------------------

[VIDEO NOT UPLOADED YET]

My talk which was an introduction to the python-cryptography
library.  which is used in jwcrypto (used by Custodia) and IPA
Vault.  The talk includes (simplified) code from both projects as
case studies.  I also talk about the background and goals of the
project.


Lightning talk - BitID authentication - Chris Bevan
---------------------------------------------------

https://www.youtube.com/watch?v=MIRTtmjAKEw#t=1224

New authentication protocol that uses a Bitcoin client or wallet to
sign cryptographic challenges.  No passwords or shared secrets;
anonymous by default.  Seems similar to SQRL.
https://github.com/bitid/bitid.


Final notes
-----------

Overall it was a pretty good conference.  As usual I met a lot of
interesting people including Red Hatters from abroad and people
using or interested in using IdM.

I had a good chat with Jamie and another Keystone developer about
the factors behind their decision to move away from PKI tokens to
Fernet tokens, and the general architecture / role of Keystone.  I
still feel like I do not know much about it, though :)

There were talks and many discussions about type hinting / PEP 484.
Because types are documentation and a source of free theorems**,
once we have completed the move to Python 3 we should start using
PEP 484-compatible function annotations as much as possible.  If
static type-checking (or some semblance thereof) ever becomes a
reality, that will be an immediate additional benefit.

** oh yeah, I also did a lightning talk on Fast and Loose Reasoning
and Parametricity:
https://www.youtube.com/watch?v=f0FSPff_j94&t=2014
