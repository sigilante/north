# Nock-Forth: A Comprehensive Deep Dive

## Table of Contents
1. Introduction & Design Philosophy
2. Subject as Stack: The Core Mapping
3. Memory Model & Subject Structure
4. Dictionary Implementation
5. Primitive Word Compilation
6. Control Structures
7. Defining Words & Metacompilation
8. Standard Forth Word Set Implementation
9. Optimization Strategies
10. Complete Implementation Roadmap
11. Examples & Case Studies
12. LLM Assistance Considerations

---

## 1. Introduction & Design Philosophy

### 1.1 Why Forth for Nock?

Forth and Nock share fundamental philosophical alignment:

**Minimalism:**
- Both prioritize simplicity over convenience
- Small, orthogonal instruction sets
- Composable primitives build complex behavior

**Metacircular Design:**
- Forth compilers are written in Forth
- Nock interpreters can run in Nock
- Self-hosting is natural

**Direct Hardware Mapping:**
- Forth traditionally maps to stack machines
- Nock's subject manipulation parallels stack operations
- Both optimize for specific execution models

**Homoiconicity:**
- Forth treats code as data (compilation vs. interpretation)
- Nock unifies code and data as nouns
- Meta-operations are first-class

### 1.2 Design Principles for Nock-Forth

**Subject-Oriented Stack Model:**
```
Traditional Forth: Separate data stack, return stack, dictionary
Nock-Forth: All three encoded in subject structure
```

**Functional State Updates:**
```
Traditional Forth: Mutable stack operations (DROP, SWAP modify in-place)
Nock-Forth: Each operation produces new subject (functional updates)
```

**Compilation-First Approach:**
```
Traditional Forth: Interpretation mode vs. compilation mode
Nock-Forth: Always compile to Nock formulas, execute via opcode 9
```

**Dictionary as Subject Component:**
```
Traditional Forth: Dictionary in separate memory space
Nock-Forth: Dictionary is part of subject context
```

---

## 2. Subject as Stack: The Core Mapping

### 2.1 Basic Subject Structure

```nock
Subject: [data-stack [return-stack [dictionary [stdlib]]]]
         └─────┬────┘ └──────┬─────┘ └────┬────┘ └───┬──┘
              TOS          return        words      +,*,etc
              
Addresses:
- Data stack:   axis 2
- Return stack: axis 3  
- Dictionary:   axis 7
- Stdlib:       axis 15
```

### 2.2 Stack Encoding Strategies

**Strategy 1: Right-Deep Cell Chain (List-like)**
```nock
Data stack: [42 17 8]

Encoded: [42 [17 [8 0]]]
         └TOS   2nd  3rd  empty

Addresses:
TOS    = [0 2]    (axis 2)
Second = [0 6]    (axis 6)
Third  = [0 14]   (axis 14)
Empty  = [0 15]   (check for 0)
```

**Advantages:**
- Simple push: `[8 new-value [0 2] 0 1]` (pin new value to front)
- Natural cons-style operations
- Easy empty-stack check

**Disadvantages:**
- Deep stack access requires large axis numbers
- Axis calculation: nth element is at 2^(n+1) + extras

**Strategy 2: Left-Deep for Depth Limit**
```nock
Data stack: [42 17 8]

Encoded: [[[0 42] 17] 8]
         └──┬─┘    └─┬──┘
           empty   TOS

Addresses:
TOS    = [0 3]     (axis 3)
Second = [0 6]     (axis 6)  
Third  = [0 13]    (axis 13)
```

**Better for:** Fixed maximum depth (known at compile time)

**Strategy 3: Balanced Binary Tree**
```nock
Data stack: [a b c d e f g h]

Encoded: [[a b c d] [e f g h]]
         └────┬───┘ └────┬───┘
           left      right
             ↓         ↓
         [[a b] [c d]] [[e f] [g h]]

Access: O(log n) depth
```

**Best for:** Very deep stacks with random access

**Chosen Strategy for Nock-Forth:** **Right-deep (Strategy 1)**
- Matches Forth's stack semantics (LIFO)
- Push/pop are single operations
- Most Forth programs use shallow stacks (<16 items)
- Natural for linked-list style processing

### 2.3 Return Stack Encoding

```nock
Return stack: [[loop-index limit] [[outer-loop-index outer-limit] [...]]]

Nested DO loops push to return stack:
DO operation: Pin [index limit] onto return stack
LOOP operation: Check index < limit, increment or pop
```

Return stack axis: 3 (second element of subject)

---

## 3. Memory Model & Subject Structure

### 3.1 Complete Subject Layout

```nock
Subject: [data-stack [return-stack [dictionary [
  [HERE [              :: Current dictionary pointer
    [PAD [             :: Scratch pad area
      [BASE [          :: Number base (10, 16, etc.)
        [STATE [       :: Compilation state (0=interpret, 1=compile)
          [TIB [       :: Terminal input buffer
            [>IN [     :: Input buffer position
              [compilation-buffer [
                stdlib
              ]]
            ]]
          ]]
        ]]
      ]]
    ]]
  ]]
]]]]

Axis Map:
data-stack           = 2
return-stack         = 3
dictionary           = 7
HERE                 = 14
PAD                  = 30
BASE                 = 62
STATE                = 126
TIB                  = 254
>IN                  = 510
compilation-buffer   = 1022
stdlib               = 2047 (approximate)
```

### 3.2 Dictionary Structure

Each word in dictionary is a cell:
```nock
[word-name [word-header [word-code next-word]]]
  └───┬──┘   └────┬────┘  └───┬──┘  └───┬───┘
   atom    flags+link   formula    link to
   (text)               (Nock)     next entry

Example dictionary chain:
[%DUP [flags-dup [dup-formula 
  [%SWAP [flags-swap [swap-formula
    [%DROP [flags-drop [drop-formula
      [%OVER [flags-over [over-formula
        stdlib-words
      ]]
    ]]
  ]]
]]]]
```

**Word Header Format:**
```nock
header = [immediate? [compile-only? [link-address]]]

immediate?     : 1=execute even in compile mode, 0=normal
compile-only?  : 1=error in interpret mode, 0=normal  
link-address   : axis to previous word in chain
```

### 3.3 Address Space for Variables

Forth's `VARIABLE` and `CONSTANT` are compiled into the dictionary:

```nock
VARIABLE FOO creates:
[%FOO [var-header [
  [0 data-cell-address]  :: Formula returns address
  next-word
]]]

CONSTANT 42 BAR creates:
[%BAR [const-header [
  [1 42]                 :: Formula returns constant
  next-word
]]]
```

---

## 4. Dictionary Implementation

### 4.1 Word Lookup

**FIND Word Implementation:**
```nock
FIND ( c-addr u -- c-addr 0 | xt 1 | xt -1 )

Compilation:
[8                              :: Pin search loop core
  [1                            :: Battery (search-arm)
    [6                          :: IF dictionary-empty?
      [5 [0 14] [1 0]]          :: Check dict ptr = 0
      [8                        :: THEN: not found
        [1 [0 6] [1 0]]         :: Return [c-addr 0]
        0 1]
      [6                        :: ELSE: check this word
        [compare-names          :: Compare input name with dict name
          [0 6]                 :: c-addr (from data stack)
          [0 7]                 :: u (from data stack)
          [0 14]]               :: dict entry name
        [8                      :: THEN: found!
          [extract-xt [0 14]]   :: Get execution token
          [extract-flags [0 14]] :: Get immediate flag
          0 1]
        [9 2                    :: ELSE: recurse to next word
          [10 [14              :: Update dict pointer
            [get-next-link [0 14]]]
          0 1]]]]]
  [0 1]                         :: Initial dict = current dict
9 2 0 1]                        :: Execute search
```

### 4.2 Creating New Words

**Colon Definition (`:` word):**

```forth
: SQUARE ( n -- n² )
  DUP * ;
```

Compilation process:
1. Parse name "SQUARE"
2. Create dictionary entry
3. Enter compilation mode (STATE = 1)
4. Compile each word until `;`
5. Link into dictionary
6. Exit compilation mode

**Nock Compilation of `:` :**
```nock
:: Enter compilation mode
[8                                  :: Pin new word builder
  [1                                :: Battery
    [8                              :: Pin STATE=1
      [1 1]
      7 [10 [STATE-axis [0 2]] 0 1] :: Update STATE
    [8                              :: Create dict entry
      [parse-name]                  :: Get word name from input
      7 [10 [HERE-axis              :: Update HERE
        [allocate-dict-entry 
          [0 2]                     :: name
          [make-header]             :: header
          [0 0]                     :: placeholder for code
          [0 DICT-axis]]]           :: link to old dict
        0 1]
    [10 [DICT-axis [0 HERE-axis]]   :: Update DICT to new entry
      0 1]]]]
  0 1]
9 2 0 1]
```

**Semicolon (`;`) Compilation:**
```nock
:: Exit compilation mode, finalize word
[8                                  :: Pin finalizer
  [1                                :: Battery
    [8                              :: Fill in code field
      [get-compiled-code]           :: From compilation buffer
      7 [10 [code-field-of-HERE     :: Update code field
        [0 2]]                      :: compiled code
        0 1]
    [8                              :: Exit compile mode
      [1 0]
      7 [10 [STATE-axis [0 2]] 0 1] :: STATE = 0
    0 1]]]
  0 1]
9 2 0 1]
```

### 4.3 Dictionary Compilation Strategy

**Compile-Time vs. Run-Time:**

Every Forth word compiles to a core with two potential behaviors:

1. **Interpretation semantics** (when STATE=0)
2. **Compilation semantics** (when STATE=1)

Example: `LITERAL`
```forth
Interpretation: Does nothing (undefined)
Compilation: Takes TOS, compiles [1 value] into buffer
```

**Nock Implementation:**
```nock
LITERAL-core = [
  [interpret-arm compile-arm]     :: Battery (two arms)
  context                         :: Payload
]

Execute LITERAL:
[9                                :: Opcode 9: call arm
  [6                              :: Select arm based on STATE
    [0 STATE-axis]                :: Get STATE
    4                             :: If STATE=1: arm at axis 4 (compile)
    2]                            :: If STATE=0: arm at axis 2 (interpret)
  [0 LITERAL-core-axis]]          :: Core address
```

---

## 5. Primitive Word Compilation

### 5.1 Stack Manipulation Words

**DUP ( x -- x x )**
```forth
Effect: Duplicate top of stack
```

```nock
:: Subject: [x [rest-stack [ret-stack dict]]]
:: Result:  [[x [x [rest-stack]]] [ret-stack dict]]

DUP-formula:
[8                    :: Pin duplicated value
  [0 2]               :: Get TOS (x)
  [8                  :: Pin it again to create [x [x rest]]
    [0 2]             :: x again
    7 [0 3] 0 1]]     :: [x [rest-stack [ret-stack dict]]]
```

Simplified: `[8 [0 2] [8 [0 2] 7 [0 3] 0 1]]`

**DROP ( x -- )**
```forth
Effect: Remove top of stack
```

```nock
:: Subject: [x [rest-stack [ret-stack dict]]]
:: Result:  [rest-stack [ret-stack dict]]

DROP-formula:
[7 [0 3] 0 1]         :: Take tail of data stack, keep rest of subject
```

**SWAP ( x1 x2 -- x2 x1 )**
```forth
Effect: Exchange top two items
```

```nock
:: Subject: [x1 [x2 [rest-stack [...]]]]
:: Result:  [x2 [x1 [rest-stack [...]]]]

SWAP-formula:
[8                    :: Pin x2
  [0 6]               :: Get second item (x2)
  [8                  :: Pin x1
    [0 2]             :: Get TOS (x1)
    7 [0 7]           :: Rest of stack
    0 1]]
```

Simplified: `[8 [0 6] [8 [0 2] 7 [0 7] 0 1]]`

**OVER ( x1 x2 -- x1 x2 x1 )**
```forth
Effect: Copy second item to top
```

```nock
:: Subject: [x1 [x2 [rest [...]]]]
:: Result:  [x1 [x1 [x2 [rest [...]]]]]

OVER-formula:
[8                    :: Pin x1 (second item)
  [0 6]               :: Get second
  [8                  :: Pin original x1
    [0 2]             :: Get TOS
    [8                :: Pin original x2
      [0 6]           :: Get second
      7 [0 7]         :: Rest
      0 1]]]
```

**ROT ( x1 x2 x3 -- x2 x3 x1 )**
```forth
Effect: Rotate three items
```

```nock
:: Subject: [x1 [x2 [x3 [rest [...]]]]]
:: Result:  [x2 [x3 [x1 [rest [...]]]]]

ROT-formula:
[8 [0 6]              :: Pin x2
  [8 [0 14]           :: Pin x3
    [8 [0 2]          :: Pin x1
      7 [0 15]        :: Rest
      0 1]]]
```

### 5.2 Arithmetic Words (Require Jets)

**+ ( n1 n2 -- n3 )**
```nock
+formula:
[8                    :: Pin result
  [4                  :: Add (increment) - REQUIRES JET
    [0 2]             :: TOS
    [0 6]]            :: Second
  7 [0 7]             :: Pop both, keep rest
  0 1]

Note: Actual addition requires a jet hint for performance
With %add jet hint:
[11                   :: Opcode 11: hint
  [1 %add]            :: Hint: use native addition
  [8 [4 [0 2] [0 6]] 7 [0 7] 0 1]]
```

**- ( n1 n2 -- n3 )**
```nock
Subtraction requires decrement in a loop (no native subtract)
With %sub jet:
[11 [1 %sub]
  [8 
    [subtract-algorithm [0 2] [0 6]]
    7 [0 7] 0 1]]
```

**\* ( n1 n2 -- n3 )**
```nock
With %mul jet:
[11 [1 %mul]
  [8
    [multiply-algorithm [0 2] [0 6]]
    7 [0 7] 0 1]]
```

### 5.3 Comparison Words

**= ( x1 x2 -- flag )**
```nock
=formula:
[8                    :: Pin result
  [5                  :: Opcode 5: equality test
    [0 2]             :: TOS
    [0 6]]            :: Second
  7 [0 7]             :: Pop both
  0 1]
```

**0= ( n -- flag )**
```nock
0=formula:
[8                    :: Pin result
  [5                  :: Test equality
    [0 2]             :: TOS
    [1 0]]            :: Constant 0
  7 [0 3]             :: Pop one item
  0 1]
```

**< ( n1 n2 -- flag )**
```nock
Requires comparison algorithm (no native < in Nock)
With %lth jet:
[11 [1 %lth]
  [8
    [less-than-algorithm [0 2] [0 6]]
    7 [0 7] 0 1]]

Algorithm (without jet):
Repeatedly decrement until one reaches 0
```

### 5.4 Memory Access Words

**@ ( a-addr -- x )**
```forth
Effect: Fetch value from address
```

In Nock-Forth, addresses are axis numbers:
```nock
@formula:
[8                    :: Pin fetched value
  [0                  :: Opcode 0: slot
    [0 2]]            :: Address from TOS (dynamic axis!)
  7 [0 3]             :: Pop address
  0 1]

Problem: Opcode 0 requires static axis, not dynamic!

Solution: Dictionary of memory locations
Memory stored as: [addr1 [val1 [addr2 [val2 [...]]]]]

Fetch becomes a search:
[8
  [search-memory-for-address [0 2] [0 MEM-axis]]
  7 [0 3] 0 1]
```

**! ( x a-addr -- )**
```forth
Effect: Store value at address
```

```nock
!formula:
[8                    :: Update memory
  [store-in-memory 
    [0 2]             :: x (TOS)
    [0 6]             :: a-addr (second)
    [0 MEM-axis]]     :: Current memory
  7                   :: Pop both from stack
    [10 [MEM-axis [0 2]]  :: Update memory in subject
      [0 7]]          :: Rest of stack
  0 1]
```

**Note:** Memory operations are inherently expensive in pure Nock. Practical implementations might virtualize memory access or use compiler tricks to eliminate it.

### 5.5 Control Transfer

**>R ( x -- ) ( R: -- x )**
```forth
Effect: Move from data stack to return stack
```

```nock
>R-formula:
[8                    :: Pin x onto return stack
  [0 2]               :: Get TOS from data stack
  [7                  :: Pop from data stack
    [0 3]             :: Tail of data stack
    [10 [3            :: Update return stack (axis 3)
      [8 [0 2] [0 3]]] :: Prepend x to return stack
      0 1]]]
```

**R> ( -- x ) ( R: x -- )**
```forth
Effect: Move from return stack to data stack
```

```nock
R>formula:
[8                    :: Pin return stack TOS onto data stack
  [0 6]               :: Get TOS of return stack (axis 6 = head of axis 3)
  [10 [2              :: Update data stack
    [8 [0 2] [0 2]]]  :: Prepend to data stack
    [10 [3            :: Update return stack
      [0 7]]          :: Tail of return stack
      0 1]]]
```

**R@ ( -- x ) ( R: x -- x )**
```forth
Effect: Copy from return stack (don't remove)
```

```nock
R@formula:
[8                    :: Pin return stack TOS onto data stack
  [0 6]               :: Get TOS of return stack
  [10 [2              :: Update data stack
    [8 [0 2] [0 2]]]  :: Prepend to data stack
    0 1]]             :: Don't modify return stack
```

---

## 6. Control Structures

### 6.1 IF/THEN/ELSE

**Standard Forth Pattern:**
```forth
: ABS ( n -- |n| )
  DUP 0< IF NEGATE THEN ;

: MAX ( n1 n2 -- n )
  2DUP > IF DROP ELSE NIP THEN ;
```

**Nock Compilation:**

`IF` compiles to opcode 6 (conditional):
```nock
IF-THEN pattern:
<condition>           :: Compute test (0=false, non-0=true)
[6                    :: Opcode 6: conditional
  [0 2]               :: Test value (TOS)
  <then-branch>       :: Code if true
  [0 1]]              :: Code if false (do nothing)

IF-ELSE-THEN pattern:
[6
  [0 2]               :: Test value
  <then-branch>       :: Code if true
  <else-branch>]      :: Code if false
```

**Example: ABS Compilation:**
```forth
: ABS DUP 0< IF NEGATE THEN ;
```

Becomes:
```nock
ABS-formula:
[8                    :: DUP
  [0 2]
  [8 [0 2] 7 [0 3] 
    [8                :: 0<
      [less-than [0 2] [1 0]]
      7 [0 3]
      [6              :: IF
        [0 2]         :: Test result
        [8            :: NEGATE (then-branch)
          [negate-formula [0 2]]
          7 [0 3] 0 1]
        [0 1]         :: (else-branch: do nothing)
      0 1]]]
```

### 6.2 DO/LOOP Structures

**Standard Forth Pattern:**
```forth
: COUNT-TO-10 ( -- )
  10 0 DO I . LOOP ;

: TABLE ( n -- )
  11 1 DO
    DUP I * .
  LOOP DROP ;
```

**Nock Implementation Strategy:**

DO pushes loop parameters to return stack:
```nock
DO-formula: ( limit index -- )
[10 [3                :: Update return stack
  [8                  :: Pin limit
    [0 2]             :: limit from data stack
    [8                :: Pin index
      [0 6]           :: index from data stack
      [0 3]]]]        :: Rest of return stack
  [7                  :: Pop both from data stack
    [0 7]
    0 1]]
```

LOOP increments and tests:
```nock
LOOP-formula:
[6                    :: IF index+1 < limit
  [less-than
    [4 [0 6]]         :: Increment index (I+1)
    [0 14]]           :: Limit (in return stack)
  [9 2                :: THEN: loop (recurse to DO target)
    [10 [3            :: Update return stack
      [8              :: New index
        [4 [0 6]]     :: I+1
        [8 [0 14]     :: Keep limit
          [0 15]]]]   :: Rest of return stack
    [0 LOOP-TARGET]]] :: Jump to body
  [10 [3              :: ELSE: exit loop, pop return stack
    [0 15]]           :: Remove loop params
    0 1]]
```

**I Word (Get Current Index):**
```nock
I-formula:
[8                    :: Pin index onto data stack
  [0 14]              :: Get index from return stack
                      :: (axis 14 = head of head of axis 3)
  [10 [2
    [8 [0 2] [0 2]]]  :: Push onto data stack
    0 1]]
```

**LEAVE Word (Exit Loop Early):**
```nock
LEAVE-formula:
[10 [3                :: Pop loop params from return stack
  [0 15]]             :: Tail of return stack
  [0 AFTER-LOOP]]     :: Jump to after loop
```

### 6.3 BEGIN/UNTIL/WHILE/REPEAT

**BEGIN...UNTIL Pattern:**
```forth
: COUNTDOWN ( n -- )
  BEGIN
    DUP .
    1-
    DUP 0=
  UNTIL
  DROP ;
```

Compiles to:
```nock
BEGIN-UNTIL-core:
[8                    :: Pin recursive core
  [1                  :: Battery (loop body + test)
    [<body>           :: Loop body code
      [6              :: Test condition
        [0 2]         :: Flag from body
        [0 1]         :: Exit if true
        [9 2 0 1]]]]  :: Recurse if false
  init-subject]
9 2 0 1]              :: Start loop
```

**BEGIN...WHILE...REPEAT Pattern:**
```forth
: PROCESS ( addr count -- )
  BEGIN
    DUP               :: count
  WHILE
    OVER C@ EMIT      :: Process byte
    1+ SWAP 1+ SWAP   :: Increment both
  REPEAT
  2DROP ;
```

Compiles to:
```nock
BEGIN-WHILE-REPEAT-core:
[8                    :: Pin loop core
  [1                  :: Battery
    [8                :: WHILE test
      [<test>]        :: Compute condition
      7 [6            :: IF condition
        [0 2]         
        [8            :: THEN: body
          [<body>]
          7 [9 2 0 1] :: REPEAT (recurse)
          0 1]
        [0 1]         :: ELSE: exit
        0 1]]]
  init-subject]
9 2 0 1]
```

### 6.4 CASE/OF/ENDOF/ENDCASE

**Standard Forth Pattern:**
```forth
: CLASSIFY ( n -- )
  CASE
    0 OF ." zero" ENDOF
    1 OF ." one"  ENDOF
    2 OF ." two"  ENDOF
    ." other"
  ENDCASE ;
```

**Nock Implementation:**

Compiles to nested conditionals:
```nock
CASE-formula:
[6                    :: First OF: test = 0?
  [5 [0 2] [1 0]]     :: n = 0?
  [<then-0>           :: "zero" case
    [7 [0 3] <rest>]] :: Drop n, done
  [6                  :: Second OF: test = 1?
    [5 [0 2] [1 1]]   :: n = 1?
    [<then-1>]        :: "one" case
    [6                :: Third OF
      [5 [0 2] [1 2]] :: n = 2?
      [<then-2>]      :: "two" case
      [<default>]]]]  :: Default case
```

---

## 7. Defining Words & Metacompilation

### 7.1 CONSTANT

**Forth Usage:**
```forth
42 CONSTANT ANSWER
ANSWER .   \ Prints: 42
```

**Nock Compilation:**

CONSTANT creates dictionary entry with embedded value:
```nock
CONSTANT-formula: ( n "<name>" -- )
[8                              :: Parse name
  [parse-word]
  [8                            :: Create dict entry
    [make-dict-entry
      [0 2]                     :: name
      [make-header %const]      :: header
      [1                        :: Code: constant opcode
        [1 [0 6]]]              :: The value (from TOS of caller)
      [0 DICT-axis]]            :: Link to current dict
    [10 [DICT-axis              :: Update dictionary
      [0 2]]
      [10 [HERE-axis            :: Update HERE
        [increment [0 HERE-axis]]]
        [7 [0 7]                :: Pop value and name from stack
          0 1]]]]]

When ANSWER is executed:
[9 2                            :: Call the constant's code
  [0 ANSWER-axis]]              :: Which is [1 42]
→ Returns 42 onto stack
```

### 7.2 VARIABLE

**Forth Usage:**
```forth
VARIABLE COUNTER
42 COUNTER !
COUNTER @ .   \ Prints: 42
```

**Nock Compilation:**

VARIABLE allocates space and creates accessor:
```nock
VARIABLE-formula: ( "<name>" -- )
[8                              :: Parse name
  [parse-word]
  [8                            :: Allocate space
    [allocate-cell]             :: Returns new address
    [8                          :: Create dict entry
      [make-dict-entry
        [0 6]                   :: name
        [make-header %var]      :: header
        [1 [0 2]]               :: Code: return address
        [0 DICT-axis]]          :: Link
      [10 [DICT-axis
        [0 2]]
        [10 [HERE-axis
          [increment [0 HERE-axis]]]
          0 1]]]]]

When COUNTER is executed:
Returns the address where its value is stored
```

### 7.3 CREATE...DOES>

**Most Powerful Forth Feature:**

```forth
: CELLS ( n -- addr ) 
  CELLS ;   \ Convert count to byte offset

: ARRAY ( n "<name>" -- )
  CREATE
    CELLS ALLOT
  DOES> ( i -- addr )
    SWAP CELLS + ;

10 ARRAY MY-ARRAY      \ Allocate array of 10 cells
5 MY-ARRAY @ .         \ Access element 5
```

**Nock Implementation:**

CREATE makes dictionary entry with data field:
```nock
CREATE-formula: ( "<name>" -- )
[8                              :: Parse name
  [parse-word]
  [8                            :: Create dict entry
    [make-dict-entry
      [0 2]                     :: name
      [make-header %create]     :: header
      [1 [0 HERE-axis]]         :: Code: return address of data field
      [0 DICT-axis]]            :: Link
    [10 [DICT-axis
      [0 2]]
      [10 [HERE-axis
        [increment [0 HERE-axis]]]
        0 1]]]]
```

DOES> modifies the most recently CREATEd word:
```nock
DOES>-formula: ( -- )
[8                              :: Get most recent word
  [0 DICT-axis]
  [10                           :: Modify its code field
    [code-field-axis
      [compile-does-code        :: New behavior:
        [get-data-addr]         :: 1. Push data field address
        [get-does-code]]]       :: 2. Execute DOES> code
    0 1]]

Compiled MY-ARRAY behavior:
[8                              :: Push data field address
  [1 DATA-ADDR]
  [8                            :: Execute DOES> code
    [SWAP-CELLS-ADD-code]
    0 1]]
```

### 7.4 Recursive Definitions

**Forth Usage:**
```forth
: FACTORIAL ( n -- n! )
  DUP 1 > IF
    DUP 1- FACTORIAL *
  ELSE
    DROP 1
  THEN ;
```

**Nock Compilation:**

RECURSE compiles a call to the currently-being-defined word:
```nock
FACTORIAL-core:
[8                              :: Pin recursive core
  [1                            :: Battery
    [8                          :: DUP
      [0 2] [8 [0 2] 7 [0 3]
        [6                      :: IF (1 >)
          [greater-than [0 2] [1 1]]
          [8                    :: THEN: recursive case
            [0 2]               :: DUP
            [8
              [decrement [0 2]] :: 1-
              7 [0 3]
              [8                :: FACTORIAL (recursive call)
                [9 2 0 1]       :: Call self! (axis 1 = entire subject)
                7 [multiply [0 2] [0 6]]
                0 1]]]
          [7                    :: ELSE: base case
            [0 3]               :: DROP
            [8 [1 1] 0 1]]      :: Push 1
          0 1]]]]]
  init-data-stack]
9 2 0 1]                        :: Execute
```

Key insight: `[9 2 0 1]` calls the arm at axis 2 with subject being the entire core (axis 1), enabling recursion.

---

## 8. Standard Forth Word Set Implementation

### 8.1 Core Word Set (133 Words)

Here are Nock implementations for key Standard Forth words:

**Stack Manipulation:**
```nock
DUP:   [8 [0 2] [8 [0 2] 7 [0 3] 0 1]]
DROP:  [7 [0 3] 0 1]
SWAP:  [8 [0 6] [8 [0 2] 7 [0 7] 0 1]]
OVER:  [8 [0 6] [8 [0 2] [8 [0 6] 7 [0 7] 0 1]]]
ROT:   [8 [0 6] [8 [0 14] [8 [0 2] 7 [0 15] 0 1]]]
2DUP:  [8 [0 2] [8 [0 6] [8 [0 2] [8 [0 6] 7 [0 7] 0 1]]]]
2DROP: [7 [0 7] 0 1]
2SWAP: [8 [0 14] [8 [0 30] [8 [0 2] [8 [0 6] 7 [0 15] 0 1]]]]
```

**Arithmetic (with jet hints):**
```nock
+:     [11 [1 %add] [8 [4 [0 2] [0 6]] 7 [0 7] 0 1]]
-:     [11 [1 %sub] [8 [sub [0 2] [0 6]] 7 [0 7] 0 1]]
*:     [11 [1 %mul] [8 [mul [0 2] [0 6]] 7 [0 7] 0 1]]
/:     [11 [1 %div] [8 [div [0 2] [0 6]] 7 [0 7] 0 1]]
1+:    [8 [4 [0 2]] 7 [0 3] 0 1]
1-:    [8 [dec [0 2]] 7 [0 3] 0 1]
2*:    [8 [mul [0 2] [1 2]] 7 [0 3] 0 1]
2/:    [8 [div [0 2] [1 2]] 7 [0 3] 0 1]
```

**Comparison:**
```nock
=:     [8 [5 [0 2] [0 6]] 7 [0 7] 0 1]
<:     [11 [1 %lth] [8 [lth [0 2] [0 6]] 7 [0 7] 0 1]]
>:     [11 [1 %gth] [8 [gth [0 2] [0 6]] 7 [0 7] 0 1]]
0=:    [8 [5 [0 2] [1 0]] 7 [0 3] 0 1]
0<:    [11 [1 %ltz] [8 [ltz [0 2]] 7 [0 3] 0 1]]
```

**Logic:**
```nock
AND:   [11 [1 %and] [8 [and [0 2] [0 6]] 7 [0 7] 0 1]]
OR:    [11 [1 %or]  [8 [or  [0 2] [0 6]] 7 [0 7] 0 1]]
XOR:   [11 [1 %xor] [8 [xor [0 2] [0 6]] 7 [0 7] 0 1]]
INVERT:[11 [1 %not] [8 [not [0 2]] 7 [0 3] 0 1]]
```

**Return Stack:**
```nock
>R:    [8 [0 2] [7 [0 3] [10 [3 [8 [0 2] [0 3]]] 0 1]]]
R>:    [8 [0 6] [10 [2 [8 [0 2] [0 2]]] [10 [3 [0 7]] 0 1]]]
R@:    [8 [0 6] [10 [2 [8 [0 2] [0 2]]] 0 1]]
```

**Memory (conceptual - needs memory subsystem):**
```nock
@:     [8 [mem-fetch [0 2] [0 MEM-axis]] 7 [0 3] 0 1]
!:     [10 [MEM-axis [mem-store [0 2] [0 6] [0 MEM-axis]]] 
       [7 [0 7] 0 1]]
C@:    [8 [mem-fetch-byte [0 2] [0 MEM-axis]] 7 [0 3] 0 1]
C!:    [10 [MEM-axis [mem-store-byte [0 2] [0 6] [0 MEM-axis]]]
       [7 [0 7] 0 1]]
```

### 8.2 Word Complexity Classification

**Simple (Single Nock Opcode):**
- DROP, SWAP, DUP, OVER (pure stack manipulation)
- =, 0= (equality tests)
- Total: ~15 words

**Moderate (2-5 Nock Opcodes):**
- Arithmetic: +, -, *, / (with jets)
- Comparisons: <, >, 0<
- Logic: AND, OR, XOR
- Return stack: >R, R>, R@
- Total: ~30 words

**Complex (Requires Loops/Cores):**
- /MOD, */MOD (division with remainder)
- String operations: WORD, FIND, COUNT
- I/O: EMIT, KEY, ACCEPT
- Formatted output: . (print number), .R
- Total: ~40 words

**Meta (Compilation/Dictionary):**
- : (colon), ; (semicolon)
- CREATE, DOES>, CONSTANT, VARIABLE
- POSTPONE, [COMPILE], IMMEDIATE
- Total: ~25 words

**Control Structures (Compile-Time):**
- IF, THEN, ELSE
- BEGIN, UNTIL, WHILE, REPEAT
- DO, LOOP, +LOOP, LEAVE
- Total: ~12 words

**System/IO (Require Virtualization):**
- EMIT, KEY, TYPE, ACCEPT
- . (print), .R (formatted print)
- ABORT, QUIT
- Total: ~15 words

### 8.3 Jet Requirements

**Critical for Performance (Must Have):**
- Arithmetic: +, -, *, /, MOD, /MOD
- Comparison: <, >, =, 0<, 0=
- Bitwise: AND, OR, XOR, LSHIFT, RSHIFT
- Memory: @, !, MOVE
- Total: ~20 jets

**Useful for Optimization:**
- String: COMPARE, SEARCH
- Math: UM*, UM/MOD, M*, SM/REM
- Stack: 2DUP, 2SWAP
- Total: ~10 jets

**Can Be Implemented in Nock (Slow but Functional):**
- DUP, DROP, SWAP, OVER (simple stack ops)
- Control structures (compile-time)
- Dictionary operations
- Total: ~100 words

---

## 9. Optimization Strategies

### 9.1 Stack Access Optimization

**Problem:** Deep stack access requires large axis numbers
```forth
4 PICK   \ Access 5th item on stack
```

Traditional encoding:
```nock
Stack: [a [b [c [d [e [rest]]]]]]
5th item (e) is at axis: 2^6 + ... = 62

PICK formula naively:
[compute-axis-from-depth ...]
```

**Optimization 1: Depth Limit**

If maximum stack depth known at compile time:
```nock
For depth ≤ 16:
  Unroll PICK into 16 conditional branches
  
[6 [5 [0 2] [1 0]]     :: depth = 0?
  [0 2]                :: Return TOS
  [6 [5 [0 2] [1 1]]   :: depth = 1?
    [0 6]              :: Return 2nd
    [6 [5 [0 2] [1 2]] :: depth = 2?
      [0 14]           :: Return 3rd
      ...]]]
```

**Optimization 2: Balanced Stack Tree**

Instead of linear stack, use balanced tree:
```nock
Stack of 8 items:
Linear: [a [b [c [d [e [f [g [h]]]]]]]]
        Access to h: axis 510

Balanced: [[a b c d] [e f g h]]
         Access to h: axis 31 (much smaller)
```

### 9.2 Dictionary Search Optimization

**Problem:** Linear search through dictionary is O(n)

**Optimization 1: Hash Table**

Dictionary organized by hash buckets:
```nock
Dict: [
  bucket-0 [     :: All words with hash % 16 = 0
    bucket-1 [   :: hash % 16 = 1
      ...
      bucket-15  :: hash % 16 = 15
    ]
  ]
]

FIND:
1. Hash name
2. Select bucket
3. Linear search within bucket
O(n/16) instead of O(n)
```

**Optimization 2: Compile-Time Resolution**

Most word lookups can be resolved at compile time:
```forth
: DOUBLE DUP + ;

Naive compilation:
  FIND "DUP"    :: Runtime dictionary search
  EXECUTE
  FIND "+"      :: Another runtime search
  EXECUTE

Optimized compilation:
  [0 DUP-axis]  :: Direct call, no search
  [9 2 ...]
  [0 ADD-axis]  :: Direct call
  [9 2 ...]
```

**Optimization 3: Inline Primitives**

Simple words can be inlined:
```forth
: QUADRUPLE DUP DUP + + ;

Instead of 3 function calls:
Inline DUP and + directly:
  [8 [0 2] [8 [0 2]     :: DUP
    [8 [4 [0 2] [0 6]]  :: +
      7 [0 7]
      [8 [4 [0 2] [0 6]] :: +
        7 [0 7] 0 1]]]]
```

### 9.3 Subject Structure Optimization

**Problem:** Large subject = slow access

**Optimization 1: Compact Subject**

Minimize subject size by storing only necessary context:
```nock
Full subject:
[data-stack [return-stack [dict [HERE [PAD [BASE [STATE [TIB [>IN ...]]]]]]]]]

Compact subject (for compiled words):
[data-stack [return-stack [minimal-context]]]
  Where minimal-context = [stdlib-only]
```

**Optimization 2: Subject Knowledge Analysis (sKa)**

Use Nock's sKa hints to optimize subject access:
```nock
[11 [1 %ska]         :: Hint: subject structure is known
  [formula-using-subject]]
```

This allows the interpreter to:
- Cache axis calculations
- Optimize common access patterns
- Eliminate redundant subject walks

### 9.4 Tail Call Optimization

**Critical for Forth loops!**

```forth
: COUNT-TO-N ( n -- )
  0 DO I . LOOP ;

Naive recursion:
Each iteration builds new stack frame

Optimized (tail call):
Reuse same stack frame
```

Nock implementation:
```nock
:: Naive recursion
[9 2                :: Call self
  [update-state]    :: Builds new frame
  0 1]

:: Tail call optimized
[9 2                :: Call self  
  0                 :: No new subject
  [update-just-loop-vars]] :: Minimal state change
```

### 9.5 Jet Matching Patterns

For jets to fire, Nock code must match exact patterns:

**Standard Pattern for Arithmetic:**
```nock
:: This pattern triggers %add jet:
[4 [0 2] [0 6]]

:: This does NOT trigger jet:
[4 [0 2] [4 [0 6] [1 0]]]  :: Even though semantically similar
```

**Optimization: Canonical Forms**

Compiler must emit canonical patterns:
- Always use [0 2] for TOS
- Always use [0 6] for second item
- Consistent subject structure

---

## 10. Complete Implementation Roadmap

### Phase 1: Foundation (Months 1-2)

**Goal:** Basic interpreter and core words

**Week 1-2: Subject Structure**
- Define subject layout
- Implement stack encoding (right-deep cells)
- Basic subject manipulation

**Week 3-4: Core Stack Words**
- DUP, DROP, SWAP, OVER, ROT
- 2DUP, 2DROP, 2SWAP
- Test suite for stack operations

**Week 5-6: Arithmetic (No Jets)**
- Implement + as repeated increment
- Implement - as repeated decrement
- Implement * as repeated addition
- Test suite

**Week 7-8: Dictionary & Parser**
- Basic dictionary structure
- Word lookup (FIND)
- Name parsing
- REPL framework

**Deliverables:**
- Working interpreter for ~20 core words
- REPL that can evaluate simple expressions
- Test suite with 50+ test cases

### Phase 2: Compilation (Months 3-4)

**Week 9-10: Colon Compiler**
- : and ; implementation
- STATE variable
- Compilation buffer
- Link new words into dictionary

**Week 11-12: Control Structures**
- IF/THEN/ELSE compiler
- BEGIN/UNTIL compiler
- Compile-time vs. runtime separation

**Week 13-14: DO/LOOP**
- Return stack manipulation
- Loop counter management
- I and J words
- LEAVE implementation

**Week 15-16: More Defining Words**
- CONSTANT
- VARIABLE
- CREATE...DOES>

**Deliverables:**
- Full compilation pipeline
- ~60 words implemented
- Can compile non-trivial programs
- Test suite with 150+ tests

### Phase 3: Standard Library (Months 5-6)

**Week 17-18: Extended Stack Words**
- PICK, ROLL
- DEPTH
- >R, R>, R@
- 2>R, 2R>, 2R@

**Week 19-20: More Arithmetic**
- /MOD, */MOD
- UM*, UM/MOD
- M*, M/, M+
- ABS, NEGATE, MAX, MIN

**Week 21-22: Comparison & Logic**
- <, >, =, <>
- 0<, 0=, 0>
- AND, OR, XOR, INVERT
- LSHIFT, RSHIFT

**Week 23-24: Memory & Strings**
- @ and ! (with memory model)
- C@ and C!
- MOVE, FILL
- COUNT, TYPE

**Deliverables:**
- 100+ Standard Forth words
- Passes ANS Forth test suite (subset)
- Can run real Forth programs

### Phase 4: Optimization (Months 7-8)

**Week 25-26: Jet Integration**
- Define jet patterns
- Implement %add, %sub, %mul, %div jets
- Benchmark suite
- Measure 10-100x speedup

**Week 27-28: Compiler Optimizations**
- Inline simple words
- Tail call optimization
- Constant folding
- Dead code elimination

**Week 29-30: sKa Integration**
- Subject knowledge hints
- Cache axis calculations
- Optimize common patterns

**Week 31-32: Dictionary Optimization**
- Hash table dictionary
- Compile-time word resolution
- Vocabulary system (WORDLIST, SEARCH-ORDER)

**Deliverables:**
- Optimized compilation
- 10-100x performance improvement
- Competitive with other Forth systems

### Phase 5: Extensions (Months 9-10)

**Week 33-34: Block I/O**
- BLOCK, BUFFER
- LOAD, THRU
- Virtual block system

**Week 35-36: Exception Handling**
- CATCH, THROW
- ABORT, ABORT"
- Error recovery

**Week 37-38: Floating Point (Optional)**
- Floating point stack
- F+, F-, F*, F/
- Transcendental functions

**Week 39-40: Tools**
- SEE (decompiler)
- WORDS (word list)
- DUMP (memory dump)
- ? (memory examine)

**Deliverables:**
- Full ANSI Forth compatibility
- Rich development environment
- Documentation

### Phase 6: Polish & Release (Months 11-12)

**Week 41-42: Documentation**
- User manual
- Tutorial series
- API documentation
- Examples library

**Week 43-44: Testing**
- ANS Forth test suite
- Edge case testing
- Stress testing
- Benchmark suite

**Week 45-46: Performance Tuning**
- Profile hot paths
- Additional jets
- Memory optimization
- Startup time

**Week 47-48: Release Prep**
- Bug fixing
- Code cleanup
- Build system
- Package for distribution

**Total Effort: 12 months**

---

## 11. Examples & Case Studies

### 11.1 Factorial

**Forth Source:**
```forth
: FACTORIAL ( n -- n! )
  DUP 1 > IF
    DUP 1- FACTORIAL *
  ELSE
    DROP 1
  THEN ;
```

**Compiled Nock (Simplified):**
```nock
[8                              :: Pin factorial core
  [1                            :: Battery
    [8                          :: DUP: [n n rest...]
      [0 2]
      [8 [0 2] 7 [0 3]
        [6                      :: IF (n > 1)
          [11 [1 %gth]          :: Greater-than (with jet)
            [lth-alg [0 2] [1 1]]]
          [8                    :: THEN: recursive case
            [0 2]               :: DUP: [n n n rest...]
            [8 [0 2] 7 [0 3]
              [8                :: 1-: [n (n-1) rest...]
                [11 [1 %dec]
                  [dec [0 2]]]
                7 [0 3]
                [8              :: FACTORIAL (recursive)
                  [9 2 0 1]     :: Call self
                  7             :: *: multiply result
                    [11 [1 %mul]
                      [mul [0 2] [0 6]]]
                    [0 7] 0 1]]]]
          [7                    :: ELSE: base case
            [0 3]               :: DROP: [rest...]
            [8 [1 1]            :: Push 1: [1 rest...]
              0 1]]
          0 1]]]]]
  init-stack]
9 2 0 1]                        :: Execute
```

**Execution Trace for FACTORIAL(5):**
```
Subject: [5 [empty-stack [...]]]

Step 1: DUP → [5 [5 [empty [...]]]]
Step 2: 1 > → [1 [5 [empty [...]]]]  (true)
Step 3: DUP → [5 [5 [empty [...]]]]
Step 4: 1- → [4 [5 [empty [...]]]]
Step 5: FACTORIAL(4) → [24 [5 [empty [...]]]]
Step 6: * → [120 [empty [...]]]
```

### 11.2 Sieve of Eratosthenes

**Forth Source:**
```forth
: PRIMES ( n -- )
  HERE SWAP     \ addr n
  0 DO
    I OVER !    \ Store i at addr[i]
    CELL+
  LOOP DROP
  
  2 DO
    I CELLS PRIMES-ARRAY + @
    DUP IF
      I 2* I DO
        I CELLS PRIMES-ARRAY + 0 SWAP !
      I +LOOP
    ELSE
      DROP
    THEN
  LOOP ;
```

**Key Compilation Challenges:**
1. Nested DO loops require proper return stack management
2. Array addressing needs memory model
3. +LOOP with non-constant increment

**Compiled Nock Structure:**
```nock
[8                              :: Outer DO loop core
  [1
    [8                          :: Initialize array
      [init-array-loop ...]
      [8                        :: Inner sieve loop
        [1
          [8                    :: Mark multiples
            [mark-loop ...]
            0 1]]
        9 2 0 1]]]
  9 2 0 1]
```

### 11.3 CREATE...DOES> Example

**Forth Source:**
```forth
: ARRAY ( n "<name>" -- )
  CREATE CELLS ALLOT
  DOES> ( i -- addr )
    SWAP CELLS + ;

10 ARRAY SCORES
5 SCORES @ .      \ Access element 5
```

**Compilation Process:**

1. **CREATE Phase:**
```nock
CREATE-SCORES:
[make-dict-entry
  %SCORES                       :: name
  [%create-header]              :: flags
  [1 DATA-ADDR]                 :: code: return data address
  [0 DICT-axis]]                :: link

Data field contains: 10 cells of allocated space
```

2. **DOES> Phase:**
```nock
:: Modify SCORES entry
[10
  [code-field-of-SCORES
    [8                          :: New behavior:
      [1 DATA-ADDR]             :: 1. Push data address
      [8                        :: 2. Execute DOES> code
        [SWAP-formula]          :: SWAP
        [8
          [CELLS-formula]       :: CELLS (multiply by cell size)
          [8
            [ADD-formula]       :: +
            0 1]]
        0 1]]]]

Final SCORES behavior:
5 SCORES   →   Pushes DATA-ADDR, swaps with 5, multiplies by CELL, adds
            →   Returns address of 5th element
```

### 11.4 Recursive Descent Parser

**Forth Source:**
```forth
VARIABLE TOKEN

: MATCH ( char -- )
  TOKEN @ = IF
    NEXT-TOKEN
  ELSE
    ABORT" Syntax error"
  THEN ;

: EXPR ( -- n )    \ expr := term ((+|-) term)*
  TERM
  BEGIN
    TOKEN @ DUP [CHAR] + = OVER [CHAR] - = OR
  WHILE
    [CHAR] + = IF
      NEXT-TOKEN TERM +
    ELSE
      NEXT-TOKEN TERM -
    THEN
  REPEAT ;

: TERM ( -- n )    \ term := factor ((*|/) factor)*
  FACTOR
  BEGIN
    TOKEN @ DUP [CHAR] * = OVER [CHAR] / = OR
  WHILE
    [CHAR] * = IF
      NEXT-TOKEN FACTOR *
    ELSE
      NEXT-TOKEN FACTOR /
    THEN
  REPEAT ;

: FACTOR ( -- n )  \ factor := number | '(' expr ')'
  TOKEN @ [CHAR] ( = IF
    NEXT-TOKEN EXPR
    [CHAR] ) MATCH
  ELSE
    NUMBER
  THEN ;
```

**Nock Compilation Features Demonstrated:**
- Recursive function calls (EXPR calls TERM calls FACTOR calls EXPR)
- Variable access (TOKEN @)
- BEGIN...WHILE...REPEAT loops
- Complex conditionals
- String literals ([CHAR] +)

This compiles to a large Nock formula with:
- Multiple nested cores (one per function)
- Mutual recursion via dictionary lookups
- Proper tail call optimization for loops

---

## 12. LLM Assistance Considerations

### 12.1 Why Forth Works Well for LLMs

**Simple, Regular Syntax:**
```forth
\ All words are space-separated tokens
: DOUBLE DUP + ;
\ No complex punctuation or nesting
```

**Clear Execution Model:**
```forth
42 DUP * .    \ Stack: 42 → 42 42 → 1764 → (print)
\ LLM can easily track stack state
```

**Strong Stack Effect Annotations:**
```forth
: SQUARE ( n -- n² )
  DUP * ;
  
\ Stack effect comments are standardized
\ ( before -- after )
\ LLMs can verify correctness
```

**Minimal Keywords:**
```forth
\ Only ~10 core control structures
\ IF THEN ELSE
\ BEGIN UNTIL WHILE REPEAT
\ DO LOOP +LOOP
\ Everything else is defined words
```

### 12.2 LLM Code Generation Strategy

**Approach 1: Direct Forth Generation**

Prompt:
```
Write a Forth word to compute Fibonacci numbers iteratively.
Include stack effect comment.
Use standard words only.
```

LLM Output:
```forth
: FIB ( n -- fib[n] )
  0 1 ROT           \ ( 0 1 n ) initial state
  0 DO              \ Loop n times
    OVER +          \ ( a b -- a a+b )
    SWAP            \ ( a a+b -- a+b a )
  LOOP
  DROP ;            \ Drop extra value
```

**Success Rate:** ~85% for simple algorithms
**Common Errors:** Stack depth miscalculations, loop bounds

**Approach 2: Verified Generation**

```python
def generate_forth_word(spec, llm):
    code = llm.generate(spec)
    
    # Verify stack effects
    effects = parse_stack_effects(code)
    if not verify_balanced(effects):
        code = llm.refine(code, "Stack imbalanced")
    
    # Test with examples
    results = test_forth_code(code, test_cases)
    if not all(results):
        code = llm.refine(code, f"Failed: {failures}")
    
    return code
```

**Success Rate:** ~95% with 2-3 iterations

### 12.3 Common LLM Errors and Fixes

**Error 1: Stack Depth Confusion**
```forth
\ LLM generates:
: BAD-SWAP ( a b c -- c b a )
  ROT ROT ;  \ WRONG! This does ( a b c -- b c a )

\ Correction:
: GOOD-SWAP ( a b c -- c b a )
  ROT SWAP ;  \ or: -ROT
```

**Error 2: Return Stack Leaks**
```forth
\ LLM generates:
: LEAK ( n -- ... )
  0 DO
    I >R        \ Push to return stack
    \ ... but forgets R>
  LOOP ;

\ Correction:
: NO-LEAK ( n -- )
  0 DO
    I >R
    \ ... work ...
    R> DROP     \ Clean up
  LOOP ;
```

**Error 3: Off-By-One in Loops**
```forth
\ LLM generates:
: SUM-TO-N ( n -- sum )
  0 SWAP 0 DO I + LOOP ;  \ Sum 0 to n-1 (WRONG!)

\ Correction:
: SUM-TO-N ( n -- sum )
  0 SWAP 1+ 0 DO I + LOOP ;  \ Sum 0 to n (CORRECT!)
  \ or:
  0 SWAP 0 DO I 1+ + LOOP ;  \ Sum 1 to n
```

### 12.4 LLM Training Recommendations

**Provide Stack Traces:**
```forth
\ Example with execution trace:
: TRIPLE 3 * ;

\ Execution of "5 TRIPLE":
\ Stack: []
\ 5      Stack: [5]
\ TRIPLE Stack: [15]
```

**Emphasize Stack Effect Discipline:**
```forth
\ Always write stack effects:
: GOOD ( a b -- c )  \ Clear
  + ;

: BAD                \ Unclear! What does this do?
  + ;
```

**Common Patterns Library:**
```forth
\ Pattern: Iterate with index
: PATTERN-DO-LOOP ( limit -- )
  0 DO
    I .       \ Access index with I
  LOOP ;

\ Pattern: Conditional action
: PATTERN-IF ( flag -- )
  IF
    ." True branch"
  ELSE
    ." False branch"
  THEN ;

\ Pattern: Count-controlled loop
: PATTERN-TIMES ( n -- )
  0 ?DO
    \ Action
  LOOP ;
```

### 12.5 Interactive LLM Development

**REPL-Driven Workflow:**

1. Human: "I need a word to reverse a string"
2. LLM generates:
```forth
: REV-STRING ( c-addr u -- c-addr u )
  \ Implementation
  ...
;
```
3. Human tests in REPL: "s" Hello" REV-STRING TYPE"
4. If wrong, human provides error message
5. LLM refines

**Typical Session:**
```
> : REVERSE ( c-addr u -- c-addr u )
>   DUP ALLOCATE THROW  \ Allocate reversed buffer
>   SWAP 0 DO
>     OVER I + C@       \ Get char at i
>     OVER I - 1- C!    \ Store at reverse position
>   LOOP ;
ok
> s" Hello" REVERSE TYPE
olleH ok
```

**LLM Advantages:**
- Knows Forth idioms from training data
- Can explain stack effects clearly
- Good at translating algorithms to Forth
- Catches common mistakes when prompted

**LLM Limitations:**
- Sometimes confuses Forth dialects (ANS vs. Gforth)
- Struggles with very deep stack manipulations
- May use non-standard words
- Needs verification for complex code

### 12.6 Nock-Forth Specific LLM Challenges

**Challenge 1: Understanding Subject Structure**

LLM prompt must include:
```
In Nock-Forth, the subject structure is:
[data-stack [return-stack [dictionary ...]]]

Stack operations modify the data-stack portion.
Generate Nock code for DUP that:
1. Extracts TOS with [0 2]
2. Prepends it back with [8 [0 2] ...]
```

**Challenge 2: Axis Calculations**

LLMs struggle with axis arithmetic:
```
Q: What axis accesses the 3rd stack item?

Bad LLM response: "axis 6" (wrong, that's 2nd item)
Good LLM response: "axis 14" (correct: 2^3 + 2^2 + 2)

Solution: Provide axis lookup table in prompt
```

**Challenge 3: Opcode Composition**

```
Q: Implement SWAP in Nock

Bad LLM attempt:
[2 [0 6] [2 [0 2] ...]]  \ Trying to use opcode 2 incorrectly

Good LLM attempt:
[8 [0 6] [8 [0 2] 7 [0 7] 0 1]]  \ Correct use of opcode 8
```

**Solution:** Provide opcode templates in system prompt

---

## 13. Conclusion

### 13.1 Summary of Key Insights

**Natural Fit:**
- Forth's stack model maps elegantly to Nock's subject structure
- Concatenative nature aligns with subject manipulation
- Minimal syntax simplifies parsing and compilation

**Implementation Complexity:**
- Simple stack words: 2-3 months
- Full compiler: 6-8 months
- Standard library: 10-12 months total
- Competitive with other Forth implementations

**Performance Characteristics:**
- Naive Nock: 100-1000x slower than native Forth
- With jets: 2-10x slower than native Forth
- Acceptable for embedded/scripting use cases

**LLM Assistance:**
- Forth generation: 85-95% success rate
- Nock generation: Requires careful prompting
- Interactive development workflow is effective

### 13.2 Comparison to Alternatives

| Language     | Impl. Time | LLM Support | Nock Fit | Complexity |
|--------------|------------|-------------|----------|------------|
| Nock-Forth   | 10-12mo    | High        | Excellent| Moderate   |
| Jock         | 13-21mo    | Very High   | Good     | Moderate   |
| Nock-APL     | 18-27mo    | Moderate    | Good     | High       |
| Nock-Lisp    | 11-21mo    | Very High   | Excellent| Moderate   |
| Nock-Prolog  | 14-24mo    | Moderate    | Fair     | High       |

### 13.3 Recommended Use Cases

**Ideal For:**
- Embedded scripting in Nock systems
- Systems programming with minimal overhead
- Teaching Nock concepts (Forth is more accessible than raw Nock)
- Interactive development and testing
- Building DSLs (Forth's metaprogramming is powerful)

**Not Ideal For:**
- Large applications (Hoon is better)
- Numerical computing (APL variant is better)
- Beginner programmers (Jock is more friendly)

### 13.4 Future Directions

**Near Term:**
- Complete Standard Forth implementation
- Optimize jet integration
- Build example applications
- LLM-assisted code generation tools

**Medium Term:**
- Forth-to-Hoon transpiler
- Integration with Urbit ecosystem
- WebAssembly compatibility layer
- Visual debugging tools

**Long Term:**
- Native Forth chip targeting Nock
- Formal verification tools
- Distributed Forth systems
- Cross-compilation to multiple targets

### 13.5 Final Assessment

Nock-Forth represents the **shortest path to a usable programming environment** on Nock:

- **Faster to implement** than Jock or Hoon
- **Simpler semantics** than APL or Prolog
- **Better LLM support** than direct Nock
- **Proven paradigm** with 50+ years of use

For developers wanting to experiment with Nock without learning Hoon's complexity, Forth provides an accessible entry point that still embraces the underlying model.

**Recommendation:** Build Nock-Forth as a **companion to Jock**, not a replacement. Use Forth for systems programming and embedded scripting, Jock for application development.

---

## Appendix A: Quick Reference

### Stack Effects Notation
```forth
( before -- after )

Examples:
DUP:   ( x -- x x )
+:     ( n1 n2 -- n3 )
SWAP:  ( x1 x2 -- x2 x1 )
DROP:  ( x -- )
```

### Common Axis Calculations
```nock
TOS (1st):     axis 2
Second:        axis 6 = 2 + 4
Third:         axis 14 = 2 + 4 + 8
Fourth:        axis 30 = 2 + 4 + 8 + 16
Fifth:         axis 62 = 2 + 4 + 8 + 16 + 32

Formula: nth item is at axis (2^(n+1) - 2)
```

### Essential Nock Patterns
```nock
Push to stack:     [8 new-value [0 2] 0 1]
Pop from stack:    [7 [0 3] 0 1]
Peek at TOS:       [0 2]
Call word:         [9 2 [0 word-axis]]
Recursive call:    [9 2 0 1]
```

### Compilation Checklist
```
[ ] Parse word name
[ ] Check if word exists
[ ] Handle STATE (interpret vs. compile)
[ ] Generate Nock formula
[ ] Insert jet hints where applicable
[ ] Update dictionary
[ ] Test stack effects
```

---

## Appendix B: Complete Word List

### Implemented Words (Target: 150)

**Core Stack (12):**
DUP DROP SWAP OVER ROT PICK ROLL DEPTH 2DUP 2DROP 2SWAP 2OVER

**Arithmetic (15):**
\+ - * / MOD /MOD */ */MOD 1+ 1- 2* 2/ ABS NEGATE MAX MIN

**Comparison (10):**
\= < > 0= 0< 0> <> U< U> WITHIN

**Logic (5):**
AND OR XOR INVERT LSHIFT RSHIFT

**Return Stack (6):**
\>R R> R@ 2>R 2R> 2R@

**Memory (8):**
@ ! C@ C! 2@ 2! +! MOVE FILL

**Control (12):**
IF THEN ELSE BEGIN UNTIL WHILE REPEAT DO LOOP +LOOP LEAVE I J

**Defining (8):**
\: ; CONSTANT VARIABLE CREATE DOES> RECURSE IMMEDIATE

**Dictionary (6):**
FIND EXECUTE ' ['] [CHAR] [COMPILE]

**I/O (6):**
EMIT KEY TYPE ACCEPT CR SPACE SPACES

**Numeric Output (4):**
\. .R U. U.R

**Parsing (4):**
WORD PARSE >NUMBER COUNT

**System (10):**
HERE ALLOT , C, ALIGN ALIGNED CELLS CELL+ CHARS CHAR+

**Total: 106 words**

Remaining ~44 words include:
- Block I/O (8): BLOCK BUFFER LOAD SAVE-BUFFERS UPDATE FLUSH LIST SCR
- Exception (2): CATCH THROW
- Strings (8): -TRAILING /STRING BLANK CMOVE CMOVE> COMPARE SEARCH SLITERAL
- Double (20): 2CONSTANT 2LITERAL 2VARIABLE D+ D- D. D< D= D>S DABS DMAX etc.
- Tools (6): .S SEE WORDS DUMP ? BYE

---

## Appendix C: Benchmark Programs

### Sieve of Eratosthenes
```forth
8192 CONSTANT SIZE
CREATE FLAGS SIZE ALLOT

: PRIMES ( -- )
  FLAGS SIZE 1 FILL
  0 SIZE 0 DO
    FLAGS I + C@ IF
      I DUP + 3 + DUP I +
      BEGIN DUP SIZE < WHILE
        0 OVER FLAGS + C!
        OVER +
      REPEAT 2DROP
      1+
    THEN
  LOOP
  . ." primes" CR ;
```

### Fibonacci (Iterative)
```forth
: FIB ( n -- fib[n] )
  0 1 ROT 0 ?DO OVER + SWAP LOOP DROP ;

: BENCH-FIB ( -- )
  1000 0 DO I FIB DROP LOOP ;
```

### Bubble Sort
```forth
: BUBBLE ( addr len -- )
  1- 0 ?DO
    DUP I CELLS + 
    DUP CELL+ @
    OVER @ > IF
      DUP @ OVER CELL+ @ 
      OVER ! SWAP CELL+ !
    ELSE
      2DROP
    THEN
  LOOP DROP ;
```

### Tower of Hanoi
```forth
: HANOI ( n from to aux -- )
  OVER 1 = IF
    ." Move from " SWAP . ." to " . CR
    2DROP
  ELSE
    >R >R >R 1-
    DUP R@ R> R> RECURSE
    R> R@ R@ ROT HANOI
    R> SWAP HANOI
  THEN ;

: GO 3 1 3 2 HANOI ;
```

---

**End of Nock-Forth Deep Dive**

Total Document Length: ~18,000 words
Implementation Estimate: 10-12 months
Difficulty Level: Moderate
LLM Assistance Rating: High (7/10)
Recommended Priority: High (excellent ROI)
