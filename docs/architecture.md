# North Architecture

North is a Forth interpreter written in Hoon, running as a Gall agent on Urbit.
The long-term goal is a self-hosting Forth that compiles to Nock.

## Repository Layout

```
desk/
  lib/north.hoon     — the complete interpreter (types + tokenizer + eval loop)
  app/north.hoon     — the %shoe REPL agent
  desk.bill          — auto-starts %north on commit
tests/
  test-north.sh      — shell test harness (~290 tests, Tiers 0–21)
  nock.fs            — Nock interpreter written in North Forth
  test-nock.sh       — 34 tests for the Nock interpreter
  test-nock-long.sh  — long-running Nock benchmark tests
examples/
  fibonacci.fs       — iterative Fibonacci
  ackermann.fs       — recursive Ackermann-Péter function
  sieve.fs           — Sieve of Eratosthenes
  charclass.fs       — character classification (isdigit, isalpha, etc.)
  wordcount.fs       — word count over a memory buffer
docs/
  architecture.md    — this file
  words.md           — implemented word reference
  WORKING.md         — open design questions (memory model)
  nock-forth-deep-dive.md — comprehensive design research doc
  DPANS94.txt        — ANSI Forth standard (reference)
  lbForth.c          — reference C implementation (lbForth)
```

## State Structure

The interpreter state (`+$  north`) is a plain Hoon core (no mutable cells):

```hoon
+$  stak  (list *)

+$  north
  $:  %uno
      dict=lexi          ::  word dictionary: (list (pair cord prog))
      settings=settings-map
      buffers=buffer-map
      mem=stak           ::  linear memory (list of nouns, indexed by HERE)
      r-stack=stak       ::  return stack
      d-stack=stak       ::  data stack (TOS = head of list)
  ==
```

Every Forth operation returns a new `north` value; nothing is mutated in place.

### Key sub-types

| Type | Hoon | Notes |
|---|---|---|
| `stak` | `(list *)` | data/return/memory stack; TOS = head |
| `lexi` | `(list (pair cord prog))` | word dictionary; linear search by cord key |
| `prog` | `(list token)` | compiled word body |
| `token` | union | see `+$ token` in lib |

### Token union

Tokens are the IR between the tokenizer (`++  parse`) and the eval loop (`++  eval`):

| Tag | Fields | Meaning |
|---|---|---|
| `%num` | `n=@` | push literal number |
| `%word` | `w=@t` | look up and execute word `w` |
| `%tick` | `w=@t` | push execution token (cord) for word `w` without executing |
| `%colon` | `name=cord` | begin word definition (`: NAME`) |
| `%zbranch` | `offset=@s` | 0BRANCH: pop flag; if zero, jump forward by offset |
| `%branch` | `offset=@s` | BRANCH: unconditional forward/backward jump |
| `%do` | | DO: pop start (TOS) and limit (NOS), push both onto r-stack |
| `%loop` | `offset=@s` | LOOP: increment index; exit if index ≥ limit, else jump back |
| `%ploop` | `offset=@s` | +LOOP: step index by TOS; exit or jump back |
| `%variable` | `name=cord` | allocate one cell at HERE; bind name to address |
| `%constant` | `name=cord` | pop TOS; bind name to that value |
| `%defer` | `name=cord` | allocate xt cell at HERE; define indirect dispatch word |
| `%does-gt` | | DOES>: runtime split — remaining tokens go to last CREATEd word |
| `%of-branch` | `offset=@s` | OF: compare TOS selector with NOS value; match→drop+proceed, else→jump |
| `%str-lit` | `text=tape` | S" text" — store string in memory, push addr and count |
| `%dot-str` | `text=tape` | ." text" — append string to output buffer at runtime |

Control flow words (IF/ELSE/THEN, BEGIN/WHILE/REPEAT, etc.) compile to
`%zbranch` and `%branch` tokens with backpatched signed offsets; they are not
separate token tags.

## Eval Loop

`++  eval` in `lib/north.hoon` is a gate `|=  [prog north]  north`. It runs a
trap-based interpreter loop over the token list using an instruction pointer `ip`.
Branching is done by adjusting `ip` via `ip-advance`.  Word dispatch uses
`?:  =(w 'WORD')` chains inside `++  run-word`.

`++  parse` tokenizes a tape into a `prog`.  Control-flow words are compiled with
forward and backward offset backpatching during parsing.

## Gall Agent

`app/north.hoon` wraps the interpreter in a `%shoe` agent:

- **State**: `[%0 forth=north:vm  show-stack=?]`
  - `forth` persists across commands (dictionary, stacks, and memory survive
    between REPL lines)
  - `show-stack` is toggled by the meta-commands `SON` / `SOFF`
- **`on-command`**: receives a tape from the REPL, runs it through
  `(eval:vm (parse:vm cmd) forth)`, drains the output buffer, emits `  ok`
- **Error handling**: `mule` wraps eval; crashes render as `! <message>`
- **Meta-commands** (handled before eval):
  - `SON` — turn on stack display after each `ok`
  - `SOFF` — turn it off

## Memory Model

Memory (`mem=stak`) is a flat `(list *)` acting as an indexed array.  Address 0
is the head of the list.  `HERE` returns the next free cell index.  `ALLOT n`
extends the list by n cells (initialised to 0).  Cell size is 1: `CELLS`, `CHARS`,
and `CELL+` are trivially identity/increment operations.

A Nock-native tree-addressed model is under consideration (see `docs/WORKING.md`)
but deferred until the self-hosting goal makes it clearly preferable.

## Dictionary

The dictionary (`lexi`) is a `(list (pair cord prog))`.  Lookups scan the list
from head to tail, so the most recently defined word shadows older definitions.
This is the standard Forth behaviour (new definitions shadow old ones), achieved
here with O(n) linear search rather than a hash map.

## Tier Progression

North was built tier-by-tier, each tier adding a set of words or features:

| PR | Tier | Feature set |
|---|---|---|
| 1 | 0–3 | Stack ops, arithmetic, bitwise, branching |
| 2 | 4 | Return stack (>R R> R@) |
| 3 | 5 | Memory (@, !, +!, HERE, ALLOT) |
| 4 | 6–7 | Dictionary, EXECUTE, FIND, tick (') |
| 5 | 8 | Colon definitions, compile mode, STATE |
| 6–7 | 9 | Text parser, index-based eval, case folding |
| 8 | 10 | ANSI standard words (NIP, TUCK, ?DUP, 2DUP, …) |
| 9 | 11 | DO/LOOP/+LOOP/LEAVE/I/J/UNLOOP |
| 10 | 12 | VARIABLE, CONSTANT, RECURSE |
| 11 | 13 | `.` and `TYPE` output |
| 12 | 14 | `[` `]` LITERAL metaprogramming |
| 13 | 15 | CREATE / DOES> defining words |
| 14 | 16 | CATCH / THROW exception handling |
| 15 | 17 | String literals (S" / ."), CASE/OF/ENDOF/ENDCASE |
| 16–17 | 18 | Library flatten + Gall %shoe REPL agent |
| 18 | 19 | `WORD`, `BL`, `COUNT` — text input words |
| 19 | 20 | `IMMEDIATE` — compile-time word flag |
| 21 | 21 | `DEFER`/`IS`, `EXIT`, `-ROT`, `CELL`, `CHARS`, `[CHAR]`, `NOOP` |

**Next:** Nock code generation — emit Nock nouns from Forth definitions.
