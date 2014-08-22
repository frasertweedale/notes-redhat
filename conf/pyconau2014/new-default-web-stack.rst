A New Default Web Stack - Simon Willisson (Eventbrite)
======================================================

- Help handle *scaling surprises*
- provide *platform capabilities* that make features cheaper to build.
- encourage us to build things the *right* way


Varnish
=======

- Address the surprise scaling problem
- caching technology
- from 50 reqs/second to 50k reqs/second
- VCL (Varnish Configuration Language)
  - compiles down to machine code

- nginx in front of Varnish
  - Varnish does not handle SSL termination
  - Varnish does not log (by default)

- fastly
  - gives you a Varnish-powered global CDN


Offline tasks
=============

- Celery (works fine; scales up surprisingly well)
- example tasks:
  - image resizing
  - url fetching
  - email sending
  - denormalizing
  - search updating
  - push notifications
  - ...
  - Solr

A smart way of denormalizing your data.


haproxy
=======

- Load balancing


Solr or ElasticSearch
=====================

- Both have REST API
- Solr is the more mature choice (been around for >10y)
- Solr is from an era of XML configuration
- ElasticSearch is newer; JSON data.  If Solr were designed today.


django-haystack
===============

- interact with your search engine almost like you were using the
  Django ORM.


redis
=====

- in-memory data structure store
- an enormous array of data structures and algorithms implemented
- use cases:
  - celery backend (queue)
  - srandmember() for random features
  - zsets for scoreboards / most popular
  - "inboxes" for activity streams (e.g. Twitter)
  - set intersections; set membership
  - autocomplete backends (via lexical searches)
  - scriptable in Lua


statsd + graphite
=================

- graphs are the best way to visualise the health of your
  application


Conclusion
==========

- tame your inner magpie
- good rule: everytime you add something to the stack, take
  something else out
