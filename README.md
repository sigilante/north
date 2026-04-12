# North
### Forth on Nock

![](./img/hero.jpg)

An experiment in building a Forth interpreter in Hoon, targeting the Nock/Urbit
runtime.  The long-term goal is a self-hosting Forth that compiles to Nock nouns.

North aims for broad ANSI Standard Forth compatibility, adapting features like
memory management to the noun-based Nock model where appropriate.

## Quick Start

North runs as a Gall `%shoe` agent on an Urbit ship.  After installing the desk,
connect to the REPL from the dojo:

```
|link %north
```

Then type Forth expressions at the `> ` prompt:

```forth
2 3 + .         \ prints 5
: SQUARE DUP * ;
5 SQUARE .      \ prints 25
SON             \ enable stack display
10 20 +         \ prints   ok  ~[30]
SOFF            \ disable stack display
```

Errors are caught and displayed as `! <message>` without crashing the agent.

## Documentation

- [**Architecture**](docs/architecture.md) — state structure, eval loop, token IR, tier progression
- [**Word Reference**](docs/words.md) — all implemented Forth words with stack effects
- [**Design Notes**](docs/WORKING.md) — open questions (memory model, Nock-native addressing)
- [**Deep Dive**](docs/nock-forth-deep-dive.md) — comprehensive design research

## Repository Layout

```
desk/
  lib/north.hoon     — interpreter: types, tokenizer, eval loop (~1000 lines)
  app/north.hoon     — Gall %shoe REPL agent
tests/
  test-north.sh      — shell test harness (~270 tests, 0 failures through Tier 17)
docs/
  architecture.md    — architecture overview
  words.md           — word reference
  WORKING.md         — design notes
  nock-forth-deep-dive.md
  DPANS94.txt        — ANSI Forth standard
  lbForth.c          — reference C implementation
```

## Implemented Features

- **Tiers 0–9**: stack ops, arithmetic, bitwise, return stack, memory, dictionary,
  interpreter core, compilation, text parser
- **Tiers 10–12**: full ANSI word set, DO/LOOP counted loops, VARIABLE/CONSTANT/RECURSE
- **Tiers 13–15**: output words, `[` `]` LITERAL, CREATE/DOES> defining words
- **Tiers 16–17**: CATCH/THROW exceptions, S"/." string literals, CASE/OF/ENDOF/ENDCASE
- **Tier 18**: Gall `%shoe` REPL agent with persistent state, SON/SOFF stack display
- **Tier 19**: `WORD`, `BL`, `COUNT` — text input words
- **Tier 20**: `IMMEDIATE` — compile-time word flag; FIND returns ANSI-compliant flags

## Roadmap

- **Tier 21+**: Nock code generation — emit Nock nouns from Forth definitions
