:: North Core Primitives (40 words)
=>
|%
::  Stacks are rightwards-growing lists.
+$  stak  (list *)
::  Lexicons are ordered words with code.
+$  lexi  (list [term *])
::  state structure
+$  state
  $:  %uno
      dict=lexi
      settings=settings-map
      buffers=buffer-map
      r-stack=stak
      d-stack=stak
  ==

+$  word-entry
  $:  name=term                       ::  word name
      flags=word-flags
      formula=nock                    ::  executable Nock formula
  ==

+$  word-flags
  $:  immediate=?                     ::  execute even in compile mode
      hidden=?                        ::  hide during search
  ==

+$  settings-map
  $:  state=?                         ::  0=interpret, 1=compile
      base=@ud                        ::  number base (10, 16, etc.)
      >in=@ud                         ::  position in TIB
      #tib=@ud                        ::  length of TIB
      here=@ud                        ::  next free dict position
      depth=@ud                       ::  data stack depth
  ==

+$  buffer-map
  $:  tib=tape                        ::  terminal input buffer
      word-buffer=tape                ::  parsed word
      pad=tape                        ::  scratch pad
      pic-buffer=tape                 ::  pictured numeric output
      comp-buffer=(list @)            ::  compilation buffer
  ==

+$  effect
  $%  [%read-line ~]                  ::  request input
      [%write-char c=@t]              ::  output char
      [%write-line t=tape]            ::  output line
  ==
--
::
|_  =stak
:: Tier 0: Stack Manipulation (5) - Fundamental, pure subject operations
:: WELD
++  weld
  |=  [a=^stak b=^stak]
  ^-  ^stak
  ?:  =(0 (len a))  b
  ?:  =(0 (len b))  a
  |-
  ?~  a  b
  [i.a $(a t.a)]
:: REAR
++  rear
  |=  =^stak
  ^-  ^^stak
  ?>  ?=(^ a)
  ?:  =(~ t.a)  i.a
  $(a t.a)
:: PUSH    ( a -- a a )           Navigate to TOS, snoc back
++  push
  |=  a=*
  ^-  ^stak
  ?:  =(0 (len stak))  ~[a]
  :: In pure Nock terms, the most efficient thing to do is get the length
  :: of the list and directly append at the address.
  (weld stak ~[a])
:: DUP     ( a -- a a )           Navigate to TOS, snoc back
++  dup
  |.
  ^-  ^stak
  ?:  =(0 (len stak))  stak
  (weld stak (rear stak))
:: DROP    ( a -- )               Remove last element
++  drop
  |.
  ^-  ^stak
  ?~  stak  ~
  ?:  =(~ t.stak)  ~
  [i.stak $(stak t.stak)]
:: SWAP    ( a b -- b a )         Rebuild last two swapped
++  swap
  |.
  ^-  ^stak
  ?:  =(0 (len stak))  stak  :: TODO should crash?
  ?:  =(1 (len stak))  stak
  =/  ult=*  (rear stak)
  =.  stak  (drop stak)
  =/  pen=*  (rear stak)
  =.  stak  (drop stak)
  (push ult (push pen))
:: OVER    ( a b -- a b a )       Copy second, snoc to end
++  over
  |.
  ^-  ^stak
  ?:  =(0 (len stak))  stak
  ?:  =(1 (len stak))  stak
  =/  ult=*  (rear stak)
  =.  stak  (drop stak)
  =/  pen=*  (rear stak)
  =.  stak  (drop stak)
  (push pen (push ult))  :: TODO inefficient and a bit wrong still
:: ROT     ( a b c -- b c a )     Rotate top three
++  rot  !!
:: Tier 1: Unsigned Arithmetic - Forth ints are signed, but we start somewhere
++  ua
  |%
  :: 1+      ( a -- a+1 )           Increment (opcode 4)
  ++  inc
    |=  a=@
    ^-  @
    +(a)
  :: =       ( a b -- f )           Equal (opcode 5)
  ++  eq
    |=  [a=@ b=@]
    ^-  ?
    =(a b)
  :: 0=      ( a -- f )             Zero test (0 =)
  ++  zeq
    |=  a=@
    ^-  ?
    =(0 a)
  ::
  :: 1-      ( a -- a-1 )           Decrement
  ++  dec
    |=  a=@
    ?<  =(0 a)
    =+  b=0
    |-  ^-  @
    ?:  =(a +(b))  b
    $(b +(b))
  ::
  :: +       ( a b -- c )           Add
  ++  add
    |=  [a=@ b=@]
    ^-  @
    ?:  =(0 a)  b
    $(a (dec a), b +(b))
  :: <       ( a b -- f )           Less than (jet: %lth)
  ++  lt
    |=  [a=@ b=@]
    ^-  ?
    ?&  !=(a b)
        |-
        ?|  =(0 a)
            ?&  !=(0 b)
                $(a (dec a), b (dec b))
    ==  ==  ==
  :: >       ( a b -- f )           Greater (derived: SWAP <)
  ++  gt
    |=  [a=@ b=@]
    ^-  ?
    ?&  !=(a b)
        |-  
        ?|  =(0 b)
            ?&  !=(0 a)
                $(a (dec a), b (dec b))
    ==  ==  ==
  :: <=      ( a b -- f )           Less than or equal
  ++  lte
    |=  [a=@ b=@]
    ^-  ?
    ?:  =(a b)  %&
    ?|  =(0 a)
        ?&  !=(0 b)
            $(a (dec a), b (dec b))
    ==  ==
  :: >=      ( a b -- f )           Greater than or equal
  ++  gte
    |=  [a=@ b=@]
    ^-  ?
    ?:  =(a b)  %&
    ?|  =(0 b)
        ?&  !=(0 a)
            $(a (dec a), b (dec b))
    ==  ==
  :: -       ( a b -- c )           Subtract
  ++  sub
    |=  [a=@ b=@]
    ^-  @
    ?:  =(0 b)  a
    $(a (dec a), b (dec b))
  :: *       ( a b -- c )           Multiply
  ++  mul
    |:  [a=`@`1 b=`@`1]
    ^-  @
    =+  c=0
    |-
    ?:  =(0 a)  c
    $(a (dec a), c (add b c))
  :: /MOD    ( a b -- r q )         Divide with remainder
  ++  divmod
    |:  [a=`@`1 b=`@`1]
    ^-  [p=@ q=@]
    ?<  =(0 b)
    =+  c=0
    |-
    ?:  (lth a b)  [c a]
    $(a (sub a b), c +(c))
  :: /       ( a b -- q )           Divide
  ++  div
    |:  [a=`@`1 b=`@`1]
    ^-  @
    ?<  =(0 b)
    =+  c=0
    |-
    ?:  (lth a b)  c
    $(a (sub a b), c +(c))
  :: bex     ( a -- b )           Bit-exponentiate
  ++  bex
    |=  a=@
    ^-  @
    ?:  =(0 a)  1
    (mul 2 $(a (dec a)))
  :: rsh     ( a b -- c )           Right shift
  ++  rsh
    |=  [a=@ b=@]
    (div b (bex (mul (bex a) 1)))
  :: met     ( a b -- c )           Bit width
  ++  met
    |=  [a=@ b=@]
    ^-  @
    =+  c=0
    |-
    ?:  =(0 b)  c
  $(b (rsh a b), c +(c))
  :: even?   ( a -- f )           Even test
  ++  even
    |=  a=@
    ^-  ?
    =(0 (cut 0 [(met a 0) 1] a))
  --
:: Tier 2: Signed Arithmetic (ZigZag @sd)
++  zz
  :: 1+      ( a -- a+1 )           Increment (opcode 4)
  ++  inc
    |=  a=@
    ^-  @
    ?:  (even:ua a)  +(+(a))
    ?:  =(1 a)  0
    (sub:ua a 2)
  :: 1-      ( a -- a-1 )           Decrement (jet or derived)
  ++  dec
    |=  a=@
    ^-  @
    ?:  =(0 a)  1
    ?:  (even:ua a)  (sub:ua a 2)
    +(+(a))
  :: NEGATE  ( a -- -a )            Negate (jet or 0 SWAP -)
  ++  negate
    |=  a=@
    ^-  @
    ?:  =(0 a)  0
    ?:  (even:ua a)  (dec a)
    +(a)
  :: decode  ( a -- s b )             Decode
  ++  decode
    |=  a=@
    ^-  [? @]
    ?:  =(0 a)  [%& 0]
    ?:  (even:ua a)  [%& (div a 2)]
    [%| (div +(a) 2)]
  :: encode  ( s a -- b )             Encode
  ++  encode
    |=  [s=? a=@]
    ^-  @
    ?:  =(0 a)  0
    ?:  s  (mul 2 a)
    (dec (mul 2 a))
  :: +       ( a b -- c )           Add 
  ++  add
    |=  [a=@ b=@]
    ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?:  =(0 ma)  (encode sb mb)
    ?:  =(0 mb)  (encode sa ma)
    %-  encode
    ?:  =(sa sb)  [sa (add:ua ma mb)]          :: |a| + |b|
    ?:  (gt:ua ma mb)  [sa (sub:ua ma mb)]     :: |a| - |b|
    ?:  (lt:ua ma mb)  [sb (sub:ua mb ma)]     :: |b| - |a|
    [%.y 0]
  :: -       ( a b -- c )           Subtract
  ++  sub
    |=  [a=@ b=@]
    ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?:  =(0 ma)  (encode !sb mb)
    ?:  =(0 mb)  (encode sa ma)
    %-  encode
    ?:  =(sa sb)
      ?:  (gt:ua ma mb)  [sa (sub:ua ma mb)]   :: |a| > |b|: keep sign of a
      ?:  (lt:ua ma mb)  [!sa (sub:ua mb ma)]  :: |a| < |b|: flip sign
      [%.y 0]                                  :: |a| = |b|: zero
    ::  Different signs: add magnitudes, keep sign of a
    [sa (add:ua ma mb)]
  :: *       ( a b -- c )           Multiply
  ++  mul
    |=  [a=@ b=@]
    ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ::  Zero cases
    ?:  |(=(0 ma) =(0 mb))  0
    %-  encode
    :-  =(sa sb)
    (mul:ua ma mb)
  :: /MOD    ( a b -- r q )         Divide with remainder
  ++  divmod
    |=  [a=@ b=@]
    ^-  [r=@ q=@]
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?<  =(0 mb)
    ?:  =(0 ma)  [%& 0]
    =/  [ur=@ uq=@]  (divmod:ua ma mb)
    :-  (encode sa ur)
    (encode =(sa sb) uq)
  :: /       ( a b -- q )           Divide (derived from /MOD)
  ++  div
    |=  [a=@ b=@]
    ^-  [r=@ q=@]
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?<  =(0 mb)
    ?:  =(0 ma)  [%& 0]
    =/  [ur=@ uq=@]  (divmod:ua ma mb)
    (encode sa ur)
  :: =       ( a b -- f )           Equal
  ++  eq
    |=  [a=@ b=@]
    ^-  ?
    =(a b)
  :: <       ( a b -- f )           Less than (jet: %lth)
  ++  lt
    |=  [a=@ b=@]
    ^-  ?
    =/  pa  (even:ua a)
    =/  pb  (even:ua b)
    ?:  ?&(pa pb)  (lt:ua a b)
    ?:  ?&(!pa !pb)  (gt:ua a b)
    ?:  ?&(!pa pb)  %&
    ?>  ?&(pa !pb)  %|
  :: >       ( a b -- f )           Greater (derived: SWAP <)
  ++  gt
    |=  [a=@ b=@]
    ^-  ?
    =/  pa  (even:ua a)
    =/  pb  (even:ua b)
    ?:  ?&(pa pb)  (gt:ua a b)
    ?:  ?&(!pa !pb)  (lt:ua a b)
    ?:  ?&(!pa pb)  %|
    ?>  ?&(pa !pb)  %&
  :: 0=      ( a -- f )             Zero test (0 =)
  ++  zeq
    |=  a=@
    ^-  ?
    =(0 a)
  :: 0<      ( a -- f )             Negative test (0 <)
  ++  zlt
    |=  a=@
    ^-  ?
    !(even:ua a)
  --
:: Tier 3: Bitwise Logic (4) - Bit manipulation
:: AND     ( a b -- c )           Bitwise AND (jet)
++  and  !!
:: OR      ( a b -- c )           Bitwise OR (jet)
++  or  !!
:: XOR     ( a b -- c )           Bitwise XOR (jet)
++  xor  !!
:: NOT     ( a -- b )             Bitwise NOT (jet or -1 XOR)
++  not  !!
:: Tier 4: Return Stack (3) - Control flow support
:: >R      ( a -- ) (R: -- a )    Push to return stack
++  push  !!
:: R@      ( -- a ) (R: a -- a )  Copy from return stack
:: Tier 5: Memory/Tree Navigation (2) - Core to Forth model
:: @       ( addr -- value )      Fetch (navigate-to-axis)
++  fetch  !!
:: !       ( value addr -- )      Store (update-at-axis)
++  store  !!
:: Tier 6: Dictionary Basics (4) - Essential for definitions
:: HERE    ( -- addr )            Dictionary pointer (from settings)
++  here  !!
:: ,       ( value -- )           Append to dictionary (comma)
++  comma  !!
:: CELL    ( -- n )               Cell size constant (1 for Nock)
++  cell  !!
:: ALLOT   ( n -- )               Allocate space (move HERE)
++  allot  !!
:: Tier 7: Interpreter Core (4) - The heart of Forth
:: WORD    ( char -- c-addr )     Parse next word from TIB
++  word  !!
:: FIND    ( c-addr -- xt | 0 )   Search dictionary
++  find  !!
:: EXECUTE ( xt -- ... )          Execute word at xt
++  execute  !!
:: '       ( -- xt )              Get next word's xt (tick)
++  tick  !!
:: Tier 8: Compilation (5) - Building new words
:: :       ( -- )                 Start definition (colon)
++  colon  !!
:: ;       ( -- )                 End definition (semicolon) IMMEDIATE
++  semicolon  !!
:: STATE   ( -- addr )            Compilation mode flag
++  state  !!
:: IMMEDIATE ( -- )               Mark last word immediate
++  immediate  !!
:: CREATE  ( -- )                 Create dictionary entry
++  create  !!
--
