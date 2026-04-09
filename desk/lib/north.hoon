:: North Core Primitives
=>
|%
+$  stak  (list *)
+$  lexi  (list [term *])
+$  north
  $:  %uno
      dict=lexi
      settings=settings-map
      buffers=buffer-map
      r-stack=stak
      d-stack=stak
  ==
+$  word-entry
  $:  name=term
      flags=word-flags
      formula=nock
  ==
+$  word-flags
  $:  immediate=?
      hidden=?
  ==
+$  settings-map
  $:  state=?
      base=@ud
      tin=@ud
      ntib=@ud
      here=@ud
      depth=@ud
  ==
+$  buffer-map
  $:  tib=tape
      word-buffer=tape
      pad=tape
      pic-buffer=tape
      comp-buffer=(list @)
  ==
+$  effect
  $%  [%read-line ~]
      [%write-char c=@t]
      [%write-line t=tape]
  ==
::  Token-list evaluator
::  words use cord names so Forth symbols (+, *, etc.) are valid
+$  token
  $%  [%num n=@]           ::  unsigned literal
      [%word w=@t]         ::  word name
      [%zbranch offset=@]  ::  0BRANCH: pop flag; if 0 skip forward by offset
      [%branch offset=@]   ::  BRANCH: unconditional skip forward by offset
  ==
+$  prog  (list token)
--
::
|%
:: Tier 0: Stack Manipulation
:: WELD - concatenate two stacks
++  weld
  |=  [a=stak b=stak]
  ^-  stak
  |-
  ?~  a  b
  [i.a $(a t.a)]
:: REAR - get TOS (last element)
++  rear
  |=  a=stak
  ^-  *
  ?>  ?=(^ a)
  ?:  =(~ t.a)  i.a
  $(a t.a)
:: PUSH ( s a -- s' )  Append a onto stack s
++  push
  |=  [s=stak a=*]
  ^-  stak
  (weld s ~[a])
:: DUP ( s -- s' )  Duplicate TOS
++  dup
  |=  s=stak
  ^-  stak
  ?~  s  s
  (push s (rear s))
:: DROP ( s -- s' )  Remove TOS
++  drop
  |=  s=stak
  ^-  stak
  ?~  s  ~
  ?:  =(~ t.s)  ~
  [i.s $(s t.s)]
:: SWAP ( s -- s' )  ( a b -- b a )
++  swap
  |=  s=stak
  ^-  stak
  ?:  (lth (lent s) 2)  s
  =/  ult  (rear s)
  =/  s1   (drop s)
  =/  pen  (rear s1)
  =/  s2   (drop s1)
  (push (push s2 ult) pen)
:: OVER ( s -- s' )  ( a b -- a b a )
++  over
  |=  s=stak
  ^-  stak
  ?:  (lth (lent s) 2)  s
  =/  ult  (rear s)
  =/  s1   (drop s)
  =/  pen  (rear s1)
  =/  s2   (drop s1)
  (push (push (push s2 pen) ult) pen)
:: ROT ( s -- s' )  ( a b c -- b c a )
++  rot
  |=  s=stak
  ^-  stak
  ?:  (lth (lent s) 3)  s
  =/  c    (rear s)
  =/  s1   (drop s)
  =/  b    (rear s1)
  =/  s2   (drop s1)
  =/  a    (rear s2)
  =/  s3   (drop s2)
  (push (push (push s3 b) c) a)
:: FORTH-TRUE - max direct atom in Vere64 (2^63-1); avoids indirect atom heap lookup
++  forth-true  0x7fff.ffff.ffff.ffff
:: POP - remove TOS, assert atom, return [atom new-stack]
++  pop
  |=  s=stak
  ^-  [@ stak]
  ?>  ?=(^ s)
  =/  v  (rear s)
  ?>  ?=(@ v)
  [v (drop s)]
:: RUN-WORD - execute a named word against the interpreter state
++  run-word
  |=  [w=@t st=north]
  ^-  north
  =/  ds  d-stack.st
  =/  rs  r-stack.st
  ::  Stack ops ( d-stack only )
  ?:  =(w 'dup')    st(d-stack (dup ds))
  ?:  =(w 'drop')   st(d-stack (drop ds))
  ?:  =(w 'swap')   st(d-stack (swap ds))
  ?:  =(w 'over')   st(d-stack (over ds))
  ?:  =(w 'rot')    st(d-stack (rot ds))
  ?:  =(w 'depth')  st(d-stack (push ds (lent ds)))
  ::  Binary arithmetic ( a b -- c ), b=TOS
  ?:  =(w '+')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (add:ua a b)))
  ?:  =(w '-')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (sub:ua a b)))
  ?:  =(w '*')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mul:ua a b)))
  ?:  =(w '/')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (div:ua a b)))
  ?:  =(w 'mod')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds q:(divmod:ua a b)))
  ?:  =(w '/mod')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    =/  r  (divmod:ua a b)
    st(d-stack (push (push ds q.r) p.r))
  ::  Unary arithmetic ( a -- b )
  ?:  =(w '1+')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (inc:ua a)))
  ?:  =(w '1-')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (dec:ua a)))
  ::  Comparisons ( a b -- flag ), b=TOS; Forth: forth-true=true, 0=false
  ?:  =(w '=')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((eq:ua a b) forth-true 0)))
  ?:  =(w '<')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((lt:ua a b) forth-true 0)))
  ?:  =(w '>')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((gt:ua a b) forth-true 0)))
  ?:  =(w '0=')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((zeq:ua a) forth-true 0)))
  ::  Bitwise ( a b -- c ), b=TOS
  ?:  =(w 'and')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (dis a b)))
  ?:  =(w 'or')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (con a b)))
  ?:  =(w 'xor')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mix a b)))
  ?:  =(w 'invert')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mix a forth-true)))
  ::  Tier 4: Return stack
  ?:  =(w '>r')
    =^  a=@  ds  (pop ds)
    st(d-stack ds, r-stack (push rs a))
  ?:  =(w 'r>')
    =^  a=@  rs  (pop rs)
    st(d-stack (push ds a), r-stack rs)
  ?:  =(w 'r@')
    st(d-stack (push ds (rear rs)))
  ~|([%unknown-word w] !!)
:: EVAL - run a token program against the interpreter state
++  eval
  |=  [p=prog st=north]
  ^-  north
  ?~  p  st
  ?-  -.i.p
    %num      $(p t.p, st st(d-stack (push d-stack.st n.i.p)))
    %word     $(p t.p, st (run-word w.i.p st))
    %zbranch
      =/  ds  d-stack.st
      =^  flag=@  ds  (pop ds)
      ?:  =(0 flag)
        $(p (slag offset.i.p t.p), st st(d-stack ds))
      $(p t.p, st st(d-stack ds))
    %branch    $(p (slag offset.i.p t.p))
  ==
:: Tier 1: Unsigned Arithmetic
++  ua
  |%
  ++  inc
    |=  a=@  ^-  @
    +(a)
  ++  eq
    |=  [a=@ b=@]  ^-  ?
    =(a b)
  ++  zeq
    |=  a=@  ^-  ?
    =(0 a)
  ++  dec
    |=  a=@
    ?<  =(0 a)
    =+  b=0
    |-  ^-  @
    ?:  =(a +(b))  b
    $(b +(b))
  ++  add
    |=  [a=@ b=@]  ^-  @
    ?:  =(0 a)  b
    $(a (dec a), b +(b))
  ++  lt
    |=  [a=@ b=@]  ^-  ?
    ?&  !=(a b)
        |-
        ?|  =(0 a)
            ?&  !=(0 b)
                $(a (dec a), b (dec b))
    ==  ==  ==
  ++  gt
    |=  [a=@ b=@]  ^-  ?
    ?&  !=(a b)
        |-
        ?|  =(0 b)
            ?&  !=(0 a)
                $(a (dec a), b (dec b))
    ==  ==  ==
  ++  lte
    |=  [a=@ b=@]  ^-  ?
    ?:  =(a b)  %&
    ?|  =(0 a)
        ?&  !=(0 b)
            $(a (dec a), b (dec b))
    ==  ==
  ++  gte
    |=  [a=@ b=@]  ^-  ?
    ?:  =(a b)  %&
    ?|  =(0 b)
        ?&  !=(0 a)
            $(a (dec a), b (dec b))
    ==  ==
  ++  sub
    |=  [a=@ b=@]  ^-  @
    ?:  =(0 b)  a
    $(a (dec a), b (dec b))
  ++  mul
    |:  [a=`@`1 b=`@`1]  ^-  @
    =+  c=0
    |-
    ?:  =(0 a)  c
    $(a (dec a), c (add b c))
  :: divmod returns [quotient remainder]
  ++  divmod
    |:  [a=`@`1 b=`@`1]  ^-  [p=@ q=@]
    ?<  =(0 b)
    =+  c=0
    |-
    ?:  (lth a b)  [c a]
    $(a (sub a b), c +(c))
  ++  div
    |:  [a=`@`1 b=`@`1]  ^-  @
    ?<  =(0 b)
    =+  c=0
    |-
    ?:  (lth a b)  c
    $(a (sub a b), c +(c))
  ++  bex
    |=  a=@  ^-  @
    ?:  =(0 a)  1
    (mul 2 $(a (dec a)))
  ++  rsh
    |=  [a=@ b=@]
    (div b (bex (mul (bex a) 1)))
  ++  met
    |=  [a=@ b=@]  ^-  @
    =+  c=0
    |-
    ?:  =(0 b)  c
    $(b (rsh a b), c +(c))
  ++  even
    |=  a=@  ^-  ?
    =(0 (cut 0 [0 1] a))
  --
:: Tier 2: Signed Arithmetic (ZigZag encoding)
++  zz
  |%
  ++  inc
    |=  a=@  ^-  @
    ?:  (even:ua a)  +(+(a))
    ?:  =(1 a)  0
    (sub:ua a 2)
  ++  dec
    |=  a=@  ^-  @
    ?:  =(0 a)  1
    ?:  (even:ua a)  (sub:ua a 2)
    +(+(a))
  ++  negate
    |=  a=@  ^-  @
    ?:  =(0 a)  0
    ?:  (even:ua a)  (dec:ua a)
    +(a)
  ++  decode
    |=  a=@  ^-  [? @]
    ?:  =(0 a)  [%& 0]
    ?:  (even:ua a)  [%& (div:ua a 2)]
    [%| (div:ua +(a) 2)]
  ++  encode
    |=  [s=? a=@]  ^-  @
    ?:  =(0 a)  0
    ?:  s  (mul:ua 2 a)
    (dec:ua (mul:ua 2 a))
  ++  add
    |=  [a=@ b=@]  ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?:  =(0 ma)  (encode sb mb)
    ?:  =(0 mb)  (encode sa ma)
    %-  encode
    ?:  =(sa sb)        [sa (add:ua ma mb)]
    ?:  (gt:ua ma mb)   [sa (sub:ua ma mb)]
    ?:  (lt:ua ma mb)   [sb (sub:ua mb ma)]
    [%.y 0]
  ++  sub
    |=  [a=@ b=@]  ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?:  =(0 ma)  (encode !sb mb)
    ?:  =(0 mb)  (encode sa ma)
    %-  encode
    ?:  =(sa sb)
      ?:  (gt:ua ma mb)  [sa (sub:ua ma mb)]
      ?:  (lt:ua ma mb)  [!sa (sub:ua mb ma)]
      [%.y 0]
    [sa (add:ua ma mb)]
  ++  mul
    |=  [a=@ b=@]  ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?:  |(=(0 ma) =(0 mb))  0
    %-  encode
    :-  =(sa sb)
    (mul:ua ma mb)
  :: divmod returns [remainder quotient] (FORTH /MOD order: TOS=quotient)
  ++  divmod
    |=  [a=@ b=@]  ^-  [r=@ q=@]
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?<  =(0 mb)
    ?:  =(0 ma)  [0 0]
    =/  [uq=@ ur=@]  (divmod:ua ma mb)
    :-  (encode sa ur)
    (encode =(sa sb) uq)
  ++  div
    |=  [a=@ b=@]  ^-  @
    =/  [sa=? ma=@]  (decode a)
    =/  [sb=? mb=@]  (decode b)
    ?<  =(0 mb)
    ?:  =(0 ma)  0
    =/  [uq=@ ur=@]  (divmod:ua ma mb)
    (encode =(sa sb) uq)
  ++  eq
    |=  [a=@ b=@]  ^-  ?
    =(a b)
  ++  lt
    |=  [a=@ b=@]  ^-  ?
    =/  pa  (even:ua a)
    =/  pb  (even:ua b)
    ?:  ?&(pa pb)   (lt:ua a b)
    ?:  ?&(!pa !pb)  (gt:ua a b)
    ?:  ?&(!pa pb)  %&
    ?>  ?&(pa !pb)  %|
  ++  gt
    |=  [a=@ b=@]  ^-  ?
    =/  pa  (even:ua a)
    =/  pb  (even:ua b)
    ?:  ?&(pa pb)   (gt:ua a b)
    ?:  ?&(!pa !pb)  (lt:ua a b)
    ?:  ?&(!pa pb)  %|
    ?>  ?&(pa !pb)  %&
  ++  zeq
    |=  a=@  ^-  ?
    =(0 a)
  ++  zlt
    |=  a=@  ^-  ?
    !(even:ua a)
  --
:: Tier 3: Bitwise Logic
++  and     |=([a=@ b=@] ^-(@ (dis a b)))
++  or      |=([a=@ b=@] ^-(@ (con a b)))
++  xor     |=([a=@ b=@] ^-(@ (mix a b)))
++  invert  |=(a=@ ^-(@ (mix a forth-true)))
:: Tier 4: Return Stack
:: RPUSH ( st a -- st' )  Push atom onto return stack
++  rpush
  |=  [st=north a=@]
  ^-  north
  st(r-stack (push r-stack.st a))
:: Tier 5: Memory/Tree Navigation
++  fetch  !!
++  store  !!
:: Tier 6: Dictionary Basics
++  here      !!
++  comma     !!
++  cell      !!
++  allot     !!
:: Tier 7: Interpreter Core
++  word      !!
++  find      !!
++  execute   !!
++  tick      !!
:: Tier 8: Compilation
++  colon     !!
++  semicolon  !!
++  state      !!
++  immediate  !!
++  create     !!
--
