# North Design Notes

## Memory Model

The current `mem=stak` field uses a `(list *)` as a flat indexed array, with
addresses as list indices.  `HERE` returns the next free index; `ALLOT n` appends
n zero cells; `@`/`!` read/write by index.  Cell size is 1 on all axes
(`CELLS`, `CHARS` are identity; `CELL+` increments by 1).

An alternative under consideration is **Nock-style tree addressing**: memory
would be a single noun (cell tree) and addresses would be Nock axes (1=root,
2=head, 3=tail, …).  Fetch and store would use Nock's natural tree navigation
rather than list index arithmetic.

**Tradeoffs:**

- Tree addressing maps naturally onto Nock's noun structure and would make North's
  memory model a first-class Nock citizen
- List indexing is simpler to reason about and matches flat-memory Forth
- Tree addressing makes HERE/ALLOT semantics less obvious (what does "allocating"
  a tree cell mean?)
- List model is O(n) for random access; tree model is O(log n) by axis depth

**Decision deferred.** The list model will remain until the self-hosting Nock noun
goal makes tree addressing clearly preferable.

## Dictionary

The dictionary is `lexi = (list (pair cord prog))`.  Word lookup scans the list
linearly from head to tail, so the most recently defined word shadows older
definitions.  This gives correct Forth shadowing semantics but O(n) lookup.

A persistent association map (`(map cord prog)`) would give O(log n) lookup but
would lose the shadowing property without additional indirection.  Deferred until
the performance profile warrants it.

## Nock Code Generation

The long-term goal is for `:` definitions to emit Nock formulas rather than
(or in addition to) being interpreted.  This requires:

1. A stable representation for compiled words as Nock nouns
2. A calling convention: how does a Nock formula call another named word?
3. A way to represent the data stack and return stack as Nock subjects
4. Jets: once the Nock output is stable, hot paths can be replaced with native
   Hoon/C implementations

The Nock interpreter in `tests/nock.fs` (written in North Forth) will serve as
a reference and test bed once the compiler exists.

## forth-true

North uses `0x7fff_ffff_ffff_ffff` (the largest direct atom in Vere64, i.e. 2^63−1)
as the canonical true value rather than the ANSI `-1` (all-bits-set).  This is
because Urbit atoms are unsigned; `-1` in a 64-bit Urbit atom would be the same
huge number anyway when treated as `@ud`, but using the Vere64 maximum avoids
sign-extension confusion.

The practical effect: `AND`, `OR`, `INVERT`, and boolean results all behave
correctly as long as you treat flags as opaque booleans.  Code that expects the
specific value `-1` (e.g., checking `= -1`) will need adjustment.
