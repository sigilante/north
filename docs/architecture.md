# North Architecture

North is a Forth interpreter written in Hoon, running as a Gall agent on Urbit.
The long-term goal is a self-hosting Forth that compiles to Nock.

## Repository Layout

```
desk/
  lib/north.hoon     — the complete interpreter (types + eval loop + tokenizer)
  app/north.hoon     — the %shoe REPL agent
  desk.bill          — auto-starts %north on commit
tests/
  test-north.sh      — shell test harness (~270 tests)
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

```
+$  north
  $:  dict=lexi          ::  word dictionary (map @t prog)
      settings=settings-map
      buffers=buffer-map
      mem=stak           ::  linear memory (list of cells)
      r-stack=stak       ::  return stack
  ==
```

The data stack is `d-stack` inside `settings-map`. Every Forth operation returns a
new `north` value; nothing is mutated in place.

### Key sub-types

| Type | Hoon | Notes |
|---|---|---|
| `stak` | `(list @)` | data/return stack; TOS = head |
| `lexi` | `(map @t prog)` | word dictionary; cord keys |
| `prog` | `(list token)` | compiled word body |
| `token` | union | see `+$ token` in lib |

### Token union

Tokens are the IR between the tokenizer and the eval loop:

| Tag | Meaning |
|---|---|
| `%num n` | push literal number |
| `%word w` | look up and execute word `w` |
| `%colon name` | begin word definition |
| `%semi` | end word definition |
| `%if / %else / %then` | conditional branch |
| `%do / %loop / %ploop` | counted loop |
| `%begin / %until / %while / %repeat` | indefinite loop |
| `%case / %of-branch / %endof / %endcase` | CASE dispatch |
| `%variable name` | allocate and name a variable cell |
| `%constant name` | bind TOS value as a named constant |
| `%does-gt` | DOES> runtime split marker |
| `%recurse` | recursive call to current definition |
| `%zbranch offset` | conditional jump (0BRANCH) |
| `%branch offset` | unconditional jump (BRANCH) |
| `%str-lit text` | S" string — push addr+count |
| `%dot-str text` | ." string — append to output buffer |
| `%tick name` | push execution token (xt) for word |

## Eval Loop

`++  eval` in `lib/north.hoon` is a gate `|=  [prog north]  north`. It runs a
simple interpreter loop (trap + `$(ip ...)`) over the token array using an
instruction pointer `ip`. Words are dispatched with `?:  =(w 'WORD')` chains.

`++  parse` tokenizes a tape into a `prog` (list of tokens).  `++  eval` then
executes that prog against the interpreter state.

## Gall Agent

`app/north.hoon` wraps the interpreter in a `%shoe` agent:

- **State**: `[%0 forth=north:vm  show-stack=?]`
  - `forth` persists across commands (dictionary and stacks survive between
    REPL lines)
  - `show-stack` is toggled by the meta-commands `SON` / `SOFF`
- **`on-command`**: receives a tape from the REPL, runs it through
  `(eval:vm (parse:vm cmd) forth)`, drains the output buffer, emits `  ok`
- **Error handling**: `mule` wraps eval; crashes render as `! <message>`
- **Meta-commands** (handled before eval):
  - `SON` — turn on stack display after each `ok`
  - `SOFF` — turn it off

## Memory Model

Memory (`mem=stak`) is a flat `(list @)` acting as an indexed array.  Address 0
is the head of the list.  `HERE` points to the next free cell index.  `ALLOT`
extends the list.

A Nock-native tree-addressed model is under consideration (see `docs/WORKING.md`)
but deferred until the self-hosting goal makes it clearly preferable.

## Dictionary

The dictionary is `(map cord prog)`.  Lookups are O(log n) by cord key.
Redefinition simply overwrites the entry; old definitions are gone (unlike a
traditional Forth wordlist which keeps old entries for already-compiled words).

## Tier Progression

North was built tier-by-tier, each tier adding a set of words or features:

| PR | Tier | Feature set |
|---|---|---|
| 1 | 0–3 | Stack ops, control flow, bitwise |
| 2 | 4 | Return stack (>R R> R@) |
| 3 | 5 | Memory (@, !, +!) |
| 4 | 6–7 | Dictionary, EXECUTE, FIND, tick |
| 5 | 8 | Colon definitions, compile mode, STATE |
| 6–7 | 9 | Text parser, index-based eval, case folding |
| 8 | 10 | ANSI standard words |
| 9 | 11 | DO/LOOP/+LOOP/LEAVE/I/J/UNLOOP |
| 10 | 12 | VARIABLE, CONSTANT, RECURSE |
| 11 | 13 | `.` and `TYPE` output |
| 12 | 14 | `[` `]` LITERAL metaprogramming |
| 13 | 15 | CREATE / DOES> defining words |
| 14 | 16 | CATCH / THROW exception handling |
| 15 | 17 | String literals (S" / ."), CASE/OF/ENDOF/ENDCASE |
| 16–17 | 18 | Library flatten + Gall %shoe REPL agent |

**Next:** Tier 19 (`WORD` / text input), Tier 20 (`IMMEDIATE` / dict flags),
Tier 21+ (Nock code generation).
