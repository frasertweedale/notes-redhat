Early in September I crossed the ditch and attended Kiwi PyCon 2015
in Christchurch, New Zealand.

Overall it was a good conference although I was a bit unwell.  There
was not a big focus on security and unlike PyCon Australia there was
virtually nothing about OpenStack, but I still had plenty of
opportunities to talk to people about IdM and hear about their use
cases and experiences with identity management.

Several talks were similar to talks given at PyCon Australia so if
you have not reviewed my notes for `PyCon AU 2015`_ I encourage you
to do so.  Read on for highlights of Kiwi PyCon.

.. _PyCon AU 2015: https://github.com/frasertweedale/notes-redhat/blob/master/conf/pyconau2015.rst


Integrating Python Apps with Centralised IdM - Fraser Tweedale (Red Hat)
------------------------------------------------------------------------

Basically a rehash of my PyCon Australia talk with some slight
generalisation from Django to Python as a whole.  The same Django
app (thanks Jan!) was demonstrated but I also talked about the
general approach to adapting an app to use external auth
(middlewares, group mapping, transient or persisted users, tweaking
views).

I was asked about nginx support.  We had a student or intern working
on modules for nginx, right?  Where can I find out more about that
effort and its outcome?  I need to know so I can answer these
questions :)

I was also asked about how to keep app's view of user in sync with
IdM.  I explained that the middleware can observe changes and sync
it but if it possible to have transient users (user info obtained
from variables and stored in session data) the problem goes away.

The talk was well attended and I think it clicked with a lot of
people - I was approached by several people afterwards not so much
with questions but comments along the lines of "thanks for your
talk; we need to do this at my company and now we know how".

Video: https://www.youtube.com/watch?v=YwWC7DOC3tE


Lightning talk: Decrypting TLS keys with Deo - Fraser Tweedale
--------------------------------------------------------------

I hacked up an Apache/mod_ssl helper that uses Deo to supply the
passphrase for private key decryption and demo'd it in a lightning
talk.  That part went well and people seemed impressed.

Then I tried to also show the disk encryption and epically failed,
partly because I forgot to ``sudo`` but also there would not have
been enough time and afterwards it didn't work anyway!  I need to
learn more about ``dracut`` and ``initramfs`` and perhaps some Deo
documentation improvements will emerge as well.

Anyway, you can watch the video here:
https://www.youtube.com/watch?v=_35tn0KrVMo&feature=youtu.be&t=4150

I also blogged about the TLS private key decryption implementation:
https://blog-ftweedal.rhcloud.com/2015/09/automatic-decryption-of-tls-private-keys-with-deo/


Blind analytics - Brain Thorne (Data61)
---------------------------------------

Brain Thorne of Data61 (f.k.a. NICTA), an Australian tech research
institute, spoke about privacy-preserving data analytics.  Touches
upon such topics as homomorphic and partially homomorphic
encryption, Secure Multiparty Communication, differential privacy (a
knob between accuracy and privacy) and the `Paillier cryptosystem`_
which supports addition of encrypted numbers and addition and
multiplication of encrypted numbers by scalars.  There is a `Python
implementation`_.

Perhaps there are some good use cases in IdM for this sort of
privacy-preserving computation.  Already we have seen an application
of the homomorphic property of group multiplication in the new Deo
protocol!

.. _Paillier cryptosystem: https://en.wikipedia.org/wiki/Paillier_cryptosystem
.. _Python implementation: https://github.com/NICTA/python-paillier

Video: https://www.youtube.com/watch?v=zgCCtof4kkY
My notes: https://github.com/frasertweedale/notes-conf/blob/master/kiwipycon2015/blind-analytics.rst


Connascence - Thomi Richards (Canonical)
----------------------------------------

Definition:

  Two components are *connascent* if a change in one would require the
  other to be modified in order to maintain the overall correctness of
  the system.

Thomi explained connascence and presented a taxonomy of coupling.
Connascences can vary in *strength* (how easy it is to change
something), *locality* (how close connascent elements are) and
*degree* (how many elements are affected).  Kinds of connascenses
include connascence of name, type, position, algorithm, execution
order, timing, identity and others.

This was a *fascinating* talk.  A concise vocabulary to talk about
couplings with more specificity than just "tight" or "loose" seems
very useful!  Anecdotally, this was the #1 talk at the conference
according to almost everyone who saw it.

Video: https://www.youtube.com/watch?v=iwADIlIgDNA
My notes: https://github.com/frasertweedale/notes-conf/blob/master/kiwipycon2015/connascence.rst


Functionalish programming with Effect - Robert Collins (HP)
-----------------------------------------------------------

A library for explicitly encoding "actions" and supplying an
*interpreter* to run a computation and execute its actions.  Doing
it this way decouples abstract actions from a concrete
implementation, making it possible to run the same computation or
procedure under different interpreters.  This can avoid the need for
monkey patching, IO redirection and other testing hacks.

A generator coroutine API makes it appear reasonably nice to use.
It's basically a poor man's free monad for Python but it's a
commendable effort to bring some sanity to to side-effectful Python.

Video: https://www.youtube.com/watch?v=LThHSQq-6hQ
My notes: https://github.com/frasertweedale/notes-conf/blob/master/kiwipycon2015/functionalish-programming-with-effect.rst


Keynote: Python as a Teaching Language - Katie Bell (GrokLearning)
------------------------------------------------------------------

Katie Bell is a former Googler now working in programming education
at GrokLearning.  She talked about her experiences teaching
programming to children and observing their progress and
difficulties they faced.  Admitted programs failing at runtime with
errors that a type system could have prevented seems to be a common
problem!  Naturally, I heckled about this during question time :)

National programming curricula of UK and Austrlia were explained in
brief.  A discussion of the different things that motivate children
to learn programming showed that there is no single approach that
works for all or even a majority of students. She then talked about
some of the hard problems educators face including deficiencies in
IDEs, lack of simple and powerful GUI toolkit, poor mobile support
for Python, and training teachers.

Video: https://www.youtube.com/watch?v=cO7Nx3Sb1MA
My notes: https://github.com/frasertweedale/notes-conf/blob/master/kiwipycon2015/keynote-taking-magic-out-of-software.rst


Keynote: Effective Learning - Allison Kaptur (Dropbox)
------------------------------------------------------

Allison Kaptur is an engineer at Dropbox and is involved in `The
Recurse Centre`_ (f.k.a. Hacker School).  She explained and
contrasted *fixed* and *growth* mindset and laid out strategies both
for developing a growth mindset and for more effective learning.
She mentions several books and papers that go deeper into these
topics - anyone who wants to improve their learning should check it
out!

.. _The Recurse Centre: https://www.recurse.com/

Video: https://www.youtube.com/watch?v=Mcc6JEhDSpo
My notes: https://github.com/frasertweedale/notes-conf/blob/master/kiwipycon2015/keynote-effective-learning.rst
