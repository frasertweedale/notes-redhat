A taxonomy of causes of software defects
========================================

Goal
----

To have a way of describing the causes of software defects, so that
prevalence of particular causes can be **measured** and compared.
This can lead to improved decision make in determining project
priorities, tooling, architecture, etc.


Assumptions
-----------

A single defect may be attributable to one, more than one, or zero
notable causes.

Where a measure exists that *could have prevented* a defect, the
failure to apply this measure may be an attributable cause of the
defect.  For example: missing tests.

The taxonomy should not refer to causes specific to a language or
tool.

RFEs and parts of features not yet implemented are excluded from the
taxonomy, except where the absense of a behaviour is a critical
impediment to the use of a feature.


Taxonomy
--------

Programming errors:

``logic-error``
  The program does the wrong thing.  Example: incorrect boolean
  expression.

``type-error``
  A problem with types, typically an error that could be excluded by
  a static type system, or a more advanced type system.

``insufficient-generality``
  A defect was admitted where more general types/behaviour would have
  prevented it.

``corner-case``
  The defect arises because a corner case was overlooked.

``interface-misuse``
  The defect arises because some API or program interface is
  confusing or hard to use correctly (including internal
  interfaces).

``concurrency``
  Race conditions, deadlocks, etc.

``dependency``
  The defect is found in, or arises because of a change in a
  dependency.



Tests:

``incomplete-tests``
  A defect was admitted where a test that a reasonable engineer
  could have written, which would have prevent the defect, was not
  written.  Corner cases that the average engineer may not have
  considered are better attributed to ``corner-case``.

Related to requirements:

``requirements-changed``
  Defect/RFE due to changing requirements.  Example: use of
  deprecated cryptographic algorithms.

``ambiguous-requirements``
  Ambiguous requirements resulted in incorrect behaviour or
  interoperability problems.

``essential-behaviour-missing``
  Essential behavoiur in some feature is missing.
