# North
### Forth on Nock

![](./img/hero.jpg)

An experiment in building a Forth interpreter in Hoon, targeting the Nock/Urbit
runtime.  The long-term goal is a self-hosting Forth that compiles to Nock nouns.

North aims for broad ANSI Standard Forth compatibility, adapting features like
memory management to the noun-based Nock model where appropriate.

## Installation

On a local fakeship (steps assume your pier lives at `~/urbit/zod`; adjust
paths to match your setup).  From the ship's dojo:

```
|new-desk %north
|mount %north
```

In a shell, copy the desk source into the mounted directory:

```sh
cp -r path/to/north/desk/* ~/urbit/zod/north/
```

Back in the dojo, commit and install:

```
|commit %north
|install our %north
```

For shared or hosted ships without filesystem access to the pier, distribute
the desk via the usual Urbit channels (a syndicate merge, a glob, etc.).

## Quick Start

North runs as a Gall `%shoe` agent.  After installing the desk, connect to
the REPL from the dojo:

```
|dojo/link %north
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

## Jupyter notebooks

You can also drive North from a Jupyter notebook via
[Jupytur](https://github.com/sigilante/jupytur):

```sh
git clone https://github.com/sigilante/jupytur.git
cd jupytur && pip install -e .
jupytur-install --variant north
jupyter notebook
```

Pick **Jupytur (North)** from the kernel picker, then configure the connection
in the first cell:

```
%config url=http://localhost:8080 ship=zod code=<+code> agent=north
```

The kernel clears the Forth data stack on every connect, so each notebook
starts with an empty stack.

## Documentation

- [**Architecture**](docs/architecture.md) — state structure, eval loop, token IR, tier progression
- [**Word Reference**](docs/words.md) — all implemented Forth words with stack effects
- [**Design Notes**](docs/WORKING.md) — open questions (memory model, Nock-native addressing)
- [**Deep Dive**](docs/nock-forth-deep-dive.md) — comprehensive design research

## Repository Layout

```
desk/
  lib/north.hoon     — interpreter: types, tokenizer, eval loop (~1300 lines)
  app/north.hoon     — Gall %shoe REPL agent
tests/
  test-north.sh      — shell test harness (~290 tests, Tiers 0–21)
  nock.fs            — Nock interpreter written in North Forth
  test-nock.sh       — 34 tests for the Nock interpreter (make test)
  test-nock-long.sh  — long-running benchmark tests (make test-long)
examples/
  fibonacci.fs       — iterative Fibonacci
  ackermann.fs       — recursive Ackermann-Péter function
  sieve.fs           — Sieve of Eratosthenes
  charclass.fs       — isdigit / isalpha / isalnum / toupper / tolower
  wordcount.fs       — word count over a memory buffer
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
- **Tier 21**: `DEFER`/`IS` deferred words, `EXIT`, `-ROT`, `CELL`, `CHARS`, `[CHAR]`, `NOOP`

## Nock Interpreter

`tests/nock.fs` is a complete Nock interpreter written in North Forth, ported from
[forth-nock](https://github.com/mopfel-winrux/forth-nock).  It exercises virtually
all of North's runtime: DEFER, recursive words, memory allocation, R-stack usage,
and the full control-flow repertoire.  All 11 Nock opcodes (0–11) are implemented
and tested.

## Roadmap

- **Example programs**: fibonacci, Ackermann, sieve, character classification,
  word count — demonstrating North as a general-purpose language
- **Missing standard words**: `MOVE`/`CMOVE`/`FILL`, `HEX`/`DECIMAL`/`U.`,
  `EVALUATE`, `POSTPONE`, `[']`
- **Nock compiler**: emit Nock nouns from Forth definitions (self-hosting goal)
- **Jets**: once a stable Nock output exists, replace hot paths with native code
