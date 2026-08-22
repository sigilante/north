# North Word Reference

All words implemented as of Tier 21. Stack notation: `( before -- after )`.

`forth-true` is `0x7fff_ffff_ffff_ffff` (max direct atom in Vere64); `0` is false.

## Stack Manipulation

| Word | Stack | Description |
|---|---|---|
| `DUP` | `( n -- n n )` | duplicate TOS |
| `DROP` | `( n -- )` | discard TOS |
| `SWAP` | `( a b -- b a )` | swap top two |
| `OVER` | `( a b -- a b a )` | copy NOS to top |
| `ROT` | `( a b c -- b c a )` | rotate top three left |
| `-ROT` | `( a b c -- c a b )` | rotate top three right |
| `NIP` | `( a b -- b )` | drop NOS |
| `TUCK` | `( a b -- b a b )` | copy TOS below NOS |
| `PICK` | `( ... n -- ... xn )` | copy nth item to top (0=TOS) |
| `ROLL` | `( ... n -- ... )` | move nth item to top |
| `?DUP` | `( n -- n n \| 0 )` | DUP if nonzero, else leave 0 |
| `DEPTH` | `( -- n )` | number of items on stack |
| `2DUP` | `( a b -- a b a b )` | duplicate top pair |
| `2DROP` | `( a b -- )` | drop top pair |
| `2SWAP` | `( a b c d -- c d a b )` | swap top two pairs |
| `2OVER` | `( a b c d -- a b c d a b )` | copy second pair to top |

## Return Stack

| Word | Stack | Description |
|---|---|---|
| `>R` | `( n -- ) R:( -- n )` | move TOS to return stack |
| `R>` | `( -- n ) R:( n -- )` | move return stack TOS to data stack |
| `R@` | `( -- n ) R:( n -- n )` | copy return stack TOS |

## Arithmetic

| Word | Stack | Description |
|---|---|---|
| `+` | `( a b -- n )` | add |
| `-` | `( a b -- n )` | subtract |
| `*` | `( a b -- n )` | multiply |
| `/` | `( a b -- n )` | divide (unsigned) |
| `MOD` | `( a b -- n )` | modulo (unsigned) |
| `/MOD` | `( a b -- rem quot )` | unsigned divide with remainder |
| `1+` | `( n -- n+1 )` | increment |
| `1-` | `( n -- n-1 )` | decrement |
| `2*` | `( n -- n*2 )` | left shift by 1 |
| `2/` | `( n -- n/2 )` | right shift by 1 |
| `NEGATE` | `( n -- -n )` | signed negate, on a ZigZag value (see Signed Values) |
| `ABS` | `( n -- \|n\| )` | absolute value, on a ZigZag value |
| `MAX` | `( a b -- max )` | maximum |
| `MIN` | `( a b -- min )` | minimum |

## Comparison

| Word | Stack | Description |
|---|---|---|
| `=` | `( a b -- flag )` | equal |
| `<>` | `( a b -- flag )` | not equal |
| `<` | `( a b -- flag )` | **unsigned** less-than |
| `>` | `( a b -- flag )` | **unsigned** greater-than |
| `S<` | `( a b -- flag )` | signed less-than, on ZigZag values |
| `S>` | `( a b -- flag )` | signed greater-than, on ZigZag values |
| `0=` | `( n -- flag )` | zero test |
| `0<` | `( n -- flag )` | negative test, on a ZigZag value |
| `0>` | `( n -- flag )` | positive test, on a ZigZag value |
| `U<` | `( a b -- flag )` | unsigned less-than (currently identical to `<`) |
| `U>` | `( a b -- flag )` | unsigned greater-than (currently identical to `>`) |

## Signed Values

North's stack holds unsigned atoms. The signed word set — `NEGATE`, `ABS`,
`0<`, `0>`, `S<`, `S>` — reads an atom as a **ZigZag** encoding:

| signed | 0 | +1 | -1 | +2 | -2 | +3 | -3 |
|---|---|---|---|---|---|---|---|
| atom | 0 | 2 | 1 | 4 | 3 | 6 | 5 |

Write a negative value with a `-N` literal, which evaluates to that encoding,
and read one back with `S.`:

```
-5 S.              \  -5
-5 NEGATE S.       \  5
-5 NEGATE ABS S.   \  5
-5 -3 S<           \  true
```

Two things to be aware of, both inherited from the representation rather than
chosen:

- **Positive literals are raw.** `5` is the atom 5, not the encoding of +5.
  The signed words therefore read `5` as -3. Only `-N` literals produce an
  encoded value. Use `S.` to see what any atom means as a signed number.
- **`.` prints the raw atom**, not the signed reading. `-5 .` prints `9`;
  `-5 S.` prints `-5`.

`<` and `>` are unsigned despite the ANS convention, because the example
programs and the existing tests depend on that; `S<` and `S>` are the signed
pair.
| `TRUE` | `( -- forth-true )` | canonical true flag |
| `FALSE` | `( -- 0 )` | canonical false flag |

## Logic / Bitwise

| Word | Stack | Description |
|---|---|---|
| `AND` | `( a b -- n )` | bitwise AND |
| `OR` | `( a b -- n )` | bitwise OR |
| `XOR` | `( a b -- n )` | bitwise XOR |
| `INVERT` | `( n -- ~n )` | bitwise NOT |
| `NOT` | `( flag -- flag )` | logical NOT (alias for INVERT) |
| `LSHIFT` | `( n bits -- n' )` | left shift |
| `RSHIFT` | `( n bits -- n' )` | right shift |

## Memory

| Word | Stack | Description |
|---|---|---|
| `@` | `( addr -- n )` | fetch cell at address |
| `!` | `( n addr -- )` | store n at address |
| `+!` | `( n addr -- )` | add n to cell at address |
| `HERE` | `( -- addr )` | next free address |
| `ALLOT` | `( n -- )` | allocate n cells (initialised to 0) |
| `CELLS` | `( n -- n )` | scale by cell size (cell=1, identity on North) |
| `CHARS` | `( n -- n )` | scale by char size (char=1, identity on North) |
| `CELL` | `( -- 1 )` | push cell size in address units |
| `CELL+` | `( addr -- addr+1 )` | advance address by one cell |
| `,` | `( n -- )` | store n at HERE and advance HERE |

## Numeric Base

North stores the current print base as an aura tag rather than an integer.
`HEX`, `DECIMAL`, and `BINARY` switch the tag; `.` and `U.` respect it.
The `BASE` word pushes the equivalent integer (10, 16, or 2) for compatibility.
Output uses no prefix: `HEX  255 .` prints `FF `.

| Word | Stack | Description |
|---|---|---|
| `HEX` | `( -- )` | set print base to hexadecimal (`%ux`) |
| `DECIMAL` | `( -- )` | set print base to decimal (`%ud`) — default |
| `BINARY` | `( -- )` | set print base to binary (`%ub`) |
| `BASE` | `( -- n )` | push current numeric base (10, 16, or 2) |
| `AS-DATE` | `( -- )` | set print aura to date (`%da`); `.` prints as `~YYYY.M.D` |
| `AS-SHIP` | `( -- )` | set print aura to ship (`%p`); `.` prints as `~shipname` |
| `AS-CORD` | `( -- )` | set print aura to cord (`%t`); `.` prints raw UTF-8 text |

## Type Aura Output

Words for printing typed values in their natural format, regardless of current base.

| Word | Stack | Description |
|---|---|---|
| `INT.` | `( n -- )` | print TOS as decimal integer + space (ignores current base) |
| `DATE.` | `( n -- )` | print TOS as `@da` date (`~YYYY.M.D...`) + space |
| `SHIP.` | `( n -- )` | print TOS as `@p` ship name (`~shipname`) + space |
| `CORD.` | `( n -- )` | print TOS as `@t` cord (raw UTF-8 text) + space |
| `NOW` | `( -- n )` | push current time as `@da` atom (injected from Arvo) |
| `OUR` | `( -- n )` | push our ship address as `@p` atom (injected from Arvo) |

## Output

| Word | Stack | Description |
|---|---|---|
| `.` | `( n -- )` | print TOS unsigned in current base + space |
| `U.` | `( u -- )` | print TOS unsigned in current base + space (alias for `.`) |
| `TYPE` | `( addr cnt -- )` | print cnt chars from memory at addr |
| `EMIT` | `( char -- )` | emit one character |
| `CR` | `( -- )` | emit newline |
| `SPACE` | `( -- )` | emit one space |
| `SPACES` | `( n -- )` | emit n spaces |
| `BL` | `( -- 32 )` | push ASCII space character code |
| `." text"` | `( -- )` | (compile-time) emit string literal at runtime |
| `S" text"` | `( -- addr cnt )` | push string address and count |
| `EVALUATE` | `( addr cnt -- )` | parse and eval string from memory as Forth source |
| `INCLUDED` | `( addr cnt -- )` | load and eval a `.fs` file from Clay by path string (e.g. `S" /lib/utils" INCLUDED`) |
| `INCLUDE` | parsing word | `INCLUDE /lib/utils` — load a `.fs` file from the current desk (sugar for `S" ..." INCLUDED`) |

## Dictionary / Execution

| Word | Stack | Description |
|---|---|---|
| `FIND` | `( addr cnt -- name forth-true \| name 1 \| addr 0 )` | look up word by string; forth-true=immediate, 1=non-immediate, 0=not found |
| `EXECUTE` | `( xt -- )` | execute word named by execution token (cord) |
| `'` (tick) | `( -- xt )` | push execution token (cord) of next parsed word |
| `STATE` | `( -- flag )` | 0 = interpret mode, forth-true = compile mode |

## Control Flow

| Word | Notes |
|---|---|
| `IF ... THEN` | conditional; `IF ... ELSE ... THEN` also supported |
| `BEGIN ... UNTIL` | loop until TOS nonzero |
| `BEGIN ... WHILE ... REPEAT` | loop while TOS nonzero |
| `DO ... LOOP` | counted loop from start to limit; body always executes at least once |
| `DO ... +LOOP` | counted loop with arbitrary step (TOS) |
| `LEAVE` | `( -- )` exit innermost DO loop immediately |
| `I` | `( -- n )` current loop index |
| `J` | `( -- n )` outer loop index (inside nested DO loops) |
| `UNLOOP` | clean up r-stack entries after early exit from DO loop |
| `EXIT` | exit the current word immediately |
| `CASE ... OF ... ENDOF ... ENDCASE` | multi-way dispatch (ANSI) |

## Defining Words

| Word / Syntax | Description |
|---|---|
| `: NAME ... ;` | define a new word |
| `VARIABLE NAME` | allocate a cell and bind NAME to its address |
| `CONSTANT NAME` | bind TOS value as NAME (NAME pushes that value) |
| `RECURSE` | recursive call to the word currently being defined |
| `CREATE NAME` | create a named dictionary entry pointing to HERE |
| `DOES>` | set runtime behaviour of the most recently CREATEd word |
| `DEFER NAME` | create an indirection word; body can be set later with IS |
| `IS NAME` | `( xt -- )` set the execution token that DEFER'd word NAME dispatches to |
| `LITERAL` | `( n -- )` (compile-time) compile TOS value as a literal into current definition |
| `[` | switch to interpret mode mid-definition |
| `]` | switch back to compile mode |
| `IMMEDIATE` | mark most recently defined word as compile-time immediate |

## Exception Handling

| Word | Stack | Description |
|---|---|---|
| `CATCH` | `( xt -- 0 \| n )` | execute xt; push 0 on success, throw value n on exception |
| `THROW` | `( n -- )` | raise exception with value n (0 = no-op) |

## Text Input

| Word | Stack | Description |
|---|---|---|
| `WORD` | `( delim -- c-addr )` | read next token from current input; store as counted string at PAD; push address. In North, reads the next compiled token from the program stream rather than the live input buffer. |
| `COUNT` | `( c-addr -- c-addr+1 u )` | unpack counted string: advance address by 1 (past length byte), push character count |

## Character

| Word | Stack | Description |
|---|---|---|
| `[CHAR] x` | `( -- n )` | (compile-time) push ASCII code of the first character of the next token |

## Utility

| Word | Stack | Description |
|---|---|---|
| `NOOP` | `( -- )` | no operation |

## REPL Meta-Commands

Handled by the Gall agent before reaching the interpreter:

| Command | Description |
|---|---|
| `SON` | enable stack display after each `ok` |
| `SOFF` | disable stack display |

## Not Yet Implemented

| Word | Notes |
|---|---|
| `ACCEPT` | read a line of input into a buffer |
| `KEY` | read a single character from input |
| `MOVE` / `CMOVE` / `FILL` | bulk memory operations |
| `POSTPONE` | compile-time: compile the compilation semantics of the next word |
| `[']` | compile-time tick — push xt of a word at compile time |
| `REFILL` | refill the input buffer |
