# North Word Reference

All words implemented as of Tier 20. Stack notation: `( before -- after )`.

## Stack Manipulation

| Word | Stack | Description |
|---|---|---|
| `DUP` | `( n -- n n )` | duplicate TOS |
| `DROP` | `( n -- )` | discard TOS |
| `SWAP` | `( a b -- b a )` | swap top two |
| `OVER` | `( a b -- a b a )` | copy NOS to top |
| `ROT` | `( a b c -- b c a )` | rotate top three |
| `NIP` | `( a b -- b )` | drop NOS |
| `TUCK` | `( a b -- b a b )` | copy TOS below NOS |
| `PICK` | `( ... n -- ... xn )` | copy nth item to top |
| `ROLL` | `( ... n -- ... )` | move nth item to top |
| `?DUP` | `( n -- n n \| 0 )` | DUP if nonzero |
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
| `MOD` | `( a b -- n )` | modulo |
| `/MOD` | `( a b -- rem quot )` | divide with remainder |
| `1+` | `( n -- n+1 )` | increment |
| `1-` | `( n -- n-1 )` | decrement |
| `2*` | `( n -- n*2 )` | left shift by 1 |
| `2/` | `( n -- n/2 )` | right shift by 1 |
| `NEGATE` | `( n -- -n )` | negate (signed) |
| `ABS` | `( n -- \|n\| )` | absolute value |
| `MAX` | `( a b -- max )` | maximum |
| `MIN` | `( a b -- min )` | minimum |

## Comparison

| Word | Stack | Description |
|---|---|---|
| `=` | `( a b -- flag )` | equal |
| `<>` | `( a b -- flag )` | not equal |
| `<` | `( a b -- flag )` | signed less-than |
| `>` | `( a b -- flag )` | signed greater-than |
| `0=` | `( n -- flag )` | zero test |
| `0<` | `( n -- flag )` | negative test (signed) |
| `0>` | `( n -- flag )` | positive test (signed) |
| `U<` | `( a b -- flag )` | unsigned less-than |
| `U>` | `( a b -- flag )` | unsigned greater-than |
| `TRUE` | `( -- -1 )` | canonical true flag |
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
| `ALLOT` | `( n -- )` | allocate n cells |
| `CELLS` | `( n -- n*cell )` | scale by cell size (1 on North) |
| `CELL+` | `( addr -- addr+1 )` | advance by one cell |

## Dictionary / Execution

| Word | Stack | Description |
|---|---|---|
| `FIND` | `( addr cnt -- xt 1 \| xt -1 \| 0 )` | look up word by string; 1=immediate, -1=normal |
| `EXECUTE` | `( xt -- )` | execute word at execution token |
| `'` (tick) | `( -- xt )` | push xt of next word in input |
| `STATE` | `( -- addr )` | address of compile/interpret flag |

## Control Flow

| Word | Notes |
|---|---|
| `IF ... THEN` | conditional; `IF ... ELSE ... THEN` also supported |
| `BEGIN ... UNTIL` | loop until TOS nonzero |
| `BEGIN ... WHILE ... REPEAT` | loop while TOS nonzero |
| `DO ... LOOP` | counted loop; `DO ... +LOOP` for stepped loops |
| `LEAVE` | exit innermost DO loop immediately |
| `I` | `( -- n )` current loop index |
| `J` | `( -- n )` outer loop index |
| `UNLOOP` | clean up return stack after early exit from DO loop |
| `CASE ... OF ... ENDOF ... ENDCASE` | multi-way dispatch (ANSI) |

## Output

| Word | Stack | Description |
|---|---|---|
| `.` | `( n -- )` | print TOS as unsigned decimal + space |
| `TYPE` | `( addr cnt -- )` | print cnt chars from memory at addr |
| `EMIT` | `( char -- )` | emit one character |
| `CR` | `( -- )` | emit newline |
| `SPACE` | `( -- )` | emit one space |
| `SPACES` | `( n -- )` | emit n spaces |
| `." text"` | `( -- )` | compile: emit string literal at runtime |
| `S" text"` | `( -- addr cnt )` | push string address and count |

## Defining Words

| Word / Syntax | Description |
|---|---|
| `: NAME ... ;` | define a new word |
| `VARIABLE NAME` | allocate a cell and bind NAME to its address |
| `CONSTANT NAME` | bind TOS value as NAME |
| `RECURSE` | recursive call to the word being defined |
| `CREATE NAME` | create a named dictionary entry pointing to HERE |
| `DOES>` | set runtime behavior of the most recently CREATEd word |
| `LITERAL` | compile TOS value into the current definition |
| `[` | switch to interpret mode mid-definition |
| `]` | switch back to compile mode |

## Exception Handling

| Word | Stack | Description |
|---|---|---|
| `CATCH` | `( xt -- 0 \| n )` | execute xt; 0 on success, throw value on exception |
| `THROW` | `( n -- )` | raise exception with value n (0 = no-op) |

## REPL Meta-Commands

These are handled by the Gall agent before reaching the interpreter:

| Command | Description |
|---|---|
| `SON` | enable stack display after each `ok` |
| `SOFF` | disable stack display |

## Text Input

| Word | Stack | Description |
|---|---|---|
| `BL` | `( -- 32 )` | push ASCII space character |
| `WORD` | `( delim -- c-addr )` | read next token from input; store as counted string at HERE; push address. Note: in North, reads the next compiled token from the program rather than the live input stream. |
| `COUNT` | `( c-addr -- c-addr+1 u )` | unpack counted string: push char address and length |

## Defining Word Flags

| Word | Stack | Description |
|---|---|---|
| `IMMEDIATE` | `( -- )` | mark most recently defined word as compile-time immediate |

Immediate words execute during compilation instead of being compiled into the current definition. This enables compile-time macros. `FIND` returns `forth-true` for immediate words and `1` for normal words.

## Not Yet Implemented

| Word | Notes |
|---|---|
| `ACCEPT` | read a line of input |
| `KEY` | read a single character |
| `HEX` / `DECIMAL` | change numeric base |
| `REFILL` | refill the input buffer |
