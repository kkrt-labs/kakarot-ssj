# Contributing

When contributing to this repository, please first discuss the change you wish
to make via issue, email, or any other method with the owners of this repository
before making a change. Please note we have a
[code of conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions
with the project.

## Development environment setup

> **[?]** Proceed to describe how to setup local development environment. e.g:

To set up a development environment, please follow the steps from
[the README.md](../README.md#installation).

## Issues and feature requests

You've found a bug in the source code, a mistake in the documentation or maybe
you'd like a new feature?Take a look at
[GitHub Discussions](https://github.com/sayajin-labs/kakarot-ssj/discussions) to
see if it's already being discussed. You can help us by
[submitting an issue on GitHub](https://github.com/sayajin-labs/kakarot-ssj/issues).
Before you create an issue, make sure to search the issue archive -- your issue
may have already been addressed!

Please try to create bug reports that are:

- _Reproducible._ Include steps to reproduce the problem.
- _Specific._ Include as much detail as possible: which version, what
  environment, etc.
- _Unique._ Do not duplicate existing opened issues.
- _Scoped to a Single Bug._ One bug per report.

**Even better: Submit a pull request with a fix or new feature!**

### How to submit a Pull Request

1. Search our repository for open or closed
   [Pull Requests](https://github.com/sayajin-labs/kakarot-ssj/pulls) that
   relate to your submission. You don't want to duplicate effort.
2. Fork the project
3. Create your feature branch (`git checkout -b feat/amazing_feature`)
4. Commit your changes (`git commit -m 'feat: add amazing_feature'`)
5. Push to the branch (`git push origin feat/amazing_feature`)
6. [Open a Pull Request](https://github.com/sayajin-labs/kakarot-ssj/compare?expand=1)

### Migrating from Cairo Zero to Cairo

Kakarot SSJ is a rewrite of
[Kakarot Zero](https://github.com/kkrt-labs/kakarot), an implementation of the
Ethereum Virtual Machine in Cairo Zero. As such, most logic has already been
written. As part of the migration path, this business logic will be either
ported and translated as is or improved.

Here is a quick checklist when building on Kakarot SSJ and taking on issues.

#### Working on Opcodes

When working on opcodes, make sure to check several things:

- The issue's specs, always start with the issue.
- The
  [Ethereum yellow paper's](https://ethereum.github.io/yellowpaper/paper.pdf)
  paragraph for the issue, there is a non-zero probability that the early
  implementation missed a specific edge case.
- The [EVM playground](https://www.evm.codes/) to be able to read the specs and
  play around directly on the [playground](https://www.evm.codes/playground).
- The [Cairo Zero implementation](https://github.com/kkrt-labs/kakarot) that
  already exists in the above mentioned repo.

Now, here are things to pay attention to:

- The types: we **should avoid using felt252 type as much as possible**. In some
  cases, enums, structs and trait might be a good idea to write more idiomatic
  Cairo.
- The tests: we need extensive testing. Unit tests and integration tests.
- The gas: we need our code to be lean. When possible, test different ways to
  implement the same feature and argue which one is least gas expensive. But be
  careful, _first make it work, then make it fast_. No need to over-engineer and
  prematurely optimise.

#### Working on utils

When working on test utils, script & practical helpers, remember to:

- Check if the util is still relevant, a lot of new features make Cairo very
  powerful and make old utils obsolete.
- Check if the utility function can be refactored into a trait for a specific
  type, e.g. as
  [per this PR](https://github.com/kkrt-labs/kakarot-ssj/pull/74/files#diff-888cfc6a9147d3727c6f8c083b5d0890ed686240e5dc4da1a741e025bdbd81f7R282)
- Check if the type is still relevant, don't forget: we **should avoid using
  felt252 type as much as possible** and **use unsigned integers as much as
  possible**.

#### Working on precompiles

Precompiles are a tricky bunch! We used to implement most of our precompiles
using Cairo Zero so-called _hints_. They allowed us to insert arbitrary Python
code into our Cairo process!

Magic, right? The problem was that this process was not safe for the soundness
of the chain. It was impossible to prove the failure of a Cairo program, only
the success. This is a problem for DOS reasons and making people pay for
reverted transactions (you don't want your sequencer to work for free).

When working with precompiles, one has two options:

1. Implement the precompile in Cairo, fully. This is not optimised and will
   prove cumbersome, but is the simplest approach. Follow the approach below:

   a. Read the issue's specs, always start with the issue.

   b. Go through the
   [Ethereum yellow paper's](https://ethereum.github.io/yellowpaper/paper.pdf)
   paragraph for the issue, there is a non-zero probability that the early
   implementation missed a specific edge case.

   c. Check the [EVM playground](https://www.evm.codes/precompiled) to be able
   to read the specs and play around directly on the
   [playground](https://www.evm.codes/playground).

   d. Read the [Cairo Zero implementation](https://github.com/kkrt-labs/kakarot)
   that already exists in the above mentioned repo.

2. Implement the precompile as a libfunc. Involvement from the Starkware team is
   needed here (for whitelist but also support).

When going with option no. 2, one has to first approach the Starkware team with
the precompile project. That way, they can inform us whether they plan to
implement the libfunc themselves (e.g. Keccak, Sha2). Otherwise, they can help
us implement the libfunc ourselves (e.g. RIPEMD-160).

#### Working on data structures

Kakarot has many data structures, e.g. an Ethereum Transaction (struct), a Stack
(Cairo dict), a Memory (Cairo dict), etc. When porting over the data structures,
pay attention:

- Should it be a struct?
- Should it be an enum: this is a new type made availabe in Cairo.
- Which types to use? Remember! **use unsigned integers as much as possible**.
- Remember to add traits for specific types instead of utils to write Cairo (&
  Rust) idiomatic code.
- Test everything! Even small traits for specific types.
