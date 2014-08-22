PyCon Australia 2014
====================

I attended PyCon Australia in Brisbane a few weeks ago.  Here's a
recap of some of the interesting talks - some are about topics that
may be relevant or useful to the Red Hat IdM team.

They appear in no particular order.


Accessibility: Myths and Delusions by Katie Cunningham
------------------------------------------------------

https://www.youtube.com/watch?v=HQxBKnrjl1w

Always good to be reminded about the importance of knowing what
accessibility means and how to write software that is accessible.

The big takeaway for me was that a lot of governments are taking
accessibility very seriously now, and will therefore look for
solutions that do.  We must care about accessibility, particularly
for end-user interfaces (FreeOTP, user self-service in FreeIPA web
UI, etc).


OpenStack Identity and Federation by Jamie Lennox
-------------------------------------------------

https://www.youtube.com/watch?v=M2KOzgMx2tI

Jamie's talk on Keystone IdM and how various identity assertion
standards are being used, or may be used, in Keystone.  Relevant to
us for obvious reasons.


OpenStack Security by Grant Murphy
----------------------------------

https://www.youtube.com/watch?v=VrXup6wr7EQ

Good introduction to how security vulnerabilities are dealt with in
the OpenStack project.  Some interesting metrics on what kinds of
vulnerabilities have affected what components of OpenStack.

The last part of the talk is about common Python mistakes that may
lead to security issues.  I look forward to auditing FreeIPA for
these things he mentions, unless someone beats me to it!


Python Build Reasonableness and Semantic Versioning by Robert Collins
---------------------------------------------------------------------

https://www.youtube.com/watch?v=RcwLcKhbVSk

This talk reminded me of our recent discussion on versioning.
``semver`` is a tool that looks in commit messages for certain
pragmata that (the developer includes to) declare the impact of a
change, and *calculates* an appropriate version number based on
these, and the previous version number (which it presumably knows
from git tag).

Not sure if this would be useful for us but it's certainly an
interesting approach.


Descriptors: attribute access redefined by Fraser Tweedale
----------------------------------------------------------

https://www.youtube.com/watch?v=xYBVjVEJtEg

My talk about descriptors - what motivates them and how to implement
and use them - and showing off Elk_, a Moose-like object system for
Python that makes heavy use of descriptors.

There are definitely a few places in our code where it could be
beneficial to use descriptors, e.g. the JSON object abstractions in
the Dogtag Python API.

.. _Elk: https://github.com/frasertweedale/elk

Feedback on my talk or on Elk is welcome!


Django Miniconf: Closing Keynote by Tony Morris
------------------------------------------------

https://www.youtube.com/watch?v=uqsZa36Io2M

Tony is big on strongly-typed functional programming and was invited
to give the closing keynote for the DjangoCon miniconf and challenge
us on why on earth are we writing Python?

His main point is that the ability to use equational reasoning is
important in programming, and Python doesn't give you that ability,
but there are ancillary points about other nice things that
languages like Haskell give you (or nasty things they take away),
and he busts a few myths about statically typed languages.

I'm big on types and Haskell myself and pretty much agree with
everything Tony says, by the way :)


Other talks
-----------

Some other talks I found quite interesting:

- TripleO introduction by James Polley:
  https://www.youtube.com/watch?v=40NrzoXu0bU
- Here be dragons: some elegant and ugly hacks in CPython by Nick
  Coghlan: https://www.youtube.com/watch?v=VIBmWnlDjXc
- Wheel packaging format by Russell Keith-Magee:
  https://www.youtube.com/watch?v=UtFHIpNPMPA
- Changing the world with ZeroVM and Swift by Jakub Krajcovic:
  https://www.youtube.com/watch?v=e8Jui4EQbB8
- Introduction to the NetworkX graph (data structure) library:
  https://www.youtube.com/watch?v=1q7FBxy1Rds
