Graphs, Networks and Python - Lachlan Blackhall (RepositPower)
==============================================================

- networks go down to the tiniest details of life; proteins, cells,
  etc.

- graphs are pervasive in computing
  - computer networks
  - call graphs
  - social networks


NetworkX
========

- excellent graph lib for python
- there are other graph libs with python bindings
- NetworkX is made for python thus very nice to use

- nodes can be any hashable object.
- edges are tuple of nodes with optional edge data which is stored
  in a dictionary.
- well maintained package
- been around for ~12y.
- excellent documentation

Some example graph models included:

Erdos-Renyi
-----------

- named for Paul Erdős and Alfréd Rényi.
- a model for generating random graphs
- model sets an edge between each pair of nodes with equal
  (an independent) probability.


Watts-Strogatz
--------------

- named for Duncan J. Watts and Steven Strogatz.
- model produces graphs with small-world properties, including short
  average path lengths and high clustering.
- most nodes are not neighbours.
- describes human social networks well.


Barabasi-Albert
---------------

- named for Albert-László Barabási and Réka Albert.
- model is an algorithm for generated random scale-free networks
- Scale-free describes the distribution of nodes degrees of the
  network.
- Good model for computer networks.
- can tell you a lot about robustness and fragility
  - some "hubs" with few connections that join large parts of the
    graph


Social network analysis
=======================

Enron data

- Enron declared bankruptcy in 2001
- Enron email corpus contains data from about 150 users, mostly
  senior management of Enron.
- Converted the corpus to a TSV file of the form
  ``(Sender, [Recipient], Body)``
- 300 - 500 thousand email

Building the graph
------------------

- an email implies a relationship of some sort between two people in
  the company
- start with undirected graph.

Visualisation
-------------

- Gephi_ output
- really good layout algorithms

Degree
------
- sort nodes by node degree (number of connections)
- top 10 are "persons of interest"
- revealed Chairman, CEO, COO, Vice President, Senior Legal
  Specialist and Government Relation Executive.

Subgraphs
---------

- connectedness of the top 10 (i.e., they were all talking to *each
  other*)


MultiGraphs
===========

- multiple edges between nodes, e.g. one edge per email message
- ``nx.MultiGraph``
- can store the content of an email on the edge itself
- ``G.neighbours(node)`` -> ``list``
- ``G.neighbours_iter(node)`` -> iterable
- ``nx.find_cliques(G) -> [[node]]``
  - a completely connected subgraph
  - hard problem.  will take down the mightiest of computers.


Resourecs
=========

- Gephi_

.. _Gephi: http://gephi.github.io/
