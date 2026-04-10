:: North Core Primitives
=>
|%
+$  stak  (list *)
+$  lexi  (list (pair cord prog))
+$  north
  $:  %uno
      dict=lexi
      settings=settings-map
      buffers=buffer-map
      mem=stak
      r-stack=stak
      d-stack=stak
  ==
+$  settings-map
  $:  state=?           ::  %.y = interpret mode (bunt), %.n = compile mode
      base=@ud
      tin=@ud
      ntib=@ud
      here=@ud
      depth=@ud
      current-def=cord  ::  name being compiled; '' when not compiling
  ==
+$  buffer-map
  $:  tib=tape
      word-buffer=tape
      pad=tape
      pic-buffer=tape
      comp-buffer=prog  ::  token accumulator during : ... ; compilation
      output=tape       ::  EMIT/CR/SPACE output accumulator
  ==
+$  effect
  $%  [%read-line ~]
      [%write-char c=@t]
      [%write-line t=tape]
  ==
::  Token-list evaluator
::  words use cord names so Forth symbols (+, *, etc.) are valid
+$  token
  $%  [%num n=@]            ::  unsigned literal
      [%word w=@t]          ::  word name (execute immediately)
      [%tick w=@t]          ::  ' WORD: push xt (cord) without executing
      [%colon name=cord]    ::  : NAME — begin word definition
      [%zbranch offset=@s]  ::  0BRANCH: pop flag; if 0 jump by offset (signed)
      [%branch offset=@s]   ::  BRANCH: unconditional jump by offset (signed)
      [%do ~]               ::  DO: pop limit and start, init counted loop
      [%loop offset=@s]     ::  LOOP: step by 1; loop or exit
      [%ploop offset=@s]    ::  +LOOP: step by n (popped); loop or exit
      [%variable name=cord] ::  VARIABLE: allocate cell, bind name to its address
      [%constant name=cord] ::  CONSTANT: pop TOS, bind name to that value
  ==
+$  prog  (list token)
--
::
|%
:: Tier 0: Stack Manipulation
:: WELD - concatenate two lists (wet for list polymorphism)
++  weld
  |*  [a=(list) b=(list)]
  ^+  a
  |-
  ?~  a  b
  [i.a $(a t.a)]
:: LENT - list length (stdlib replacement)
++  lent
  |=  a=(list *)
  ^-  @
  =/  n  0
  |-
  ?~  a  n
  $(a t.a, n +(n))
:: SLAG - drop first n elements (stdlib replacement, wet for list polymorphism)
++  slag
  |*  [n=@ a=(list)]
  ^+  a
  |-
  ?:  =(0 n)  a
  ?~  a  ~
  $(n (dec:ua n), a t.a)
:: SNAG - get element at index (wet: works on stak and prog)
++  snag
  |*  [n=@ a=(list)]
  ?.  ?=(^ a)  !!
  ?:  =(0 n)  i.a
  $(n (dec:ua n), a t.a)
:: SNAG-PROG - typed snag returning token (for index-based eval)
++  snag-prog
  |=  [n=@ p=prog]
  ^-  token
  |-
  ?>  ?=(^ p)
  ?:  =(0 n)  i.p
  $(n (dec:ua n), p t.p)
:: PATCH-PROG - replace token at index (for backpatching branch offsets)
++  patch-prog
  |=  [p=prog n=@ tok=token]
  ^-  prog
  |-
  ?~  p  ~
  ?:  =(0 n)  [tok t.p]
  [i.p $(p t.p, n (dec:ua n))]
:: IP-ADVANCE - compute next ip from current ip and signed offset
::  ZigZag: non-negative @s atom n represents unsigned n/2; so convert back with div 2
++  ip-advance
  |=  [ip=@ offset=@s]
  ^-  @
  =/  new=@s  (sum:si (sun:si +(ip)) offset)
  ?>  (syn:si new)
  (div:ua new 2)
:: SNAP - replace element at index (for memory store)
++  snap
  |=  [a=stak n=@ v=*]
  ^-  stak
  |-
  ?~  a  ~
  ?:  =(0 n)  [v t.a]
  [i.a $(a t.a, n (dec:ua n))]
:: REAP - make list of n copies of v (for ALLOT)
++  reap
  |=  [n=@ v=*]
  ^-  stak
  |-
  ?:  =(0 n)  ~
  [v $(n (dec:ua n))]
:: TAPE-REAP - make tape of n copies of char c (for SPACES)
++  tape-reap
  |=  [n=@ c=@t]
  ^-  tape
  |-
  ?:  =(0 n)  ~
  [c $(n (dec:ua n))]
:: ROLL-REMOVE - delete element at snag-index idx (leftmost=0) from stack
++  roll-remove
  |=  [s=stak idx=@]
  ^-  stak
  =/  n  0
  |-
  ?~  s  ~
  ?:  =(n idx)  t.s
  [i.s $(s t.s, n +(n))]
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
  ?:  (lt:ua (lent s) 2)  s
  =/  ult  (rear s)
  =/  s1   (drop s)
  =/  pen  (rear s1)
  =/  s2   (drop s1)
  (push (push s2 ult) pen)
:: OVER ( s -- s' )  ( a b -- a b a )
++  over
  |=  s=stak
  ^-  stak
  ?:  (lt:ua (lent s) 2)  s
  =/  ult  (rear s)
  =/  s1   (drop s)
  =/  pen  (rear s1)
  =/  s2   (drop s1)
  (push (push (push s2 pen) ult) pen)
:: ROT ( s -- s' )  ( a b c -- b c a )
++  rot
  |=  s=stak
  ^-  stak
  ?:  (lt:ua (lent s) 3)  s
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
:: FIND-DICT - look up a word in the user dictionary; case-insensitive
++  find-dict
  |=  [w=cord d=lexi]
  ^-  (unit prog)
  =/  wu  (crip (cuss (trip w)))
  |-
  ?~  d  ~
  ?:  =((crip (cuss (trip p.i.d))) wu)  `q.i.d
  $(d t.d)
:: NUM-TO-TAPE - convert unsigned atom to decimal tape (no dot separators)
::  Recurse to most-significant digit first, then cons the digit for this level.
::  n=0 handled at entry so the trap never receives 0 except in the "0" case.
++  num-to-tape
  |=  n=@
  ^-  tape
  ?:  =(0 n)  "0"
  |-  ^-  tape
  ?:  =(0 n)  ~
  =/  qr  (divmod:ua n 10)
  (weld $(n p.qr) ~[^-(@t (add:ua q.qr 48))])
:: READ-CHARS - read cnt chars from stak at addr, produce tape
++  read-chars
  ::  Extract cnt chars from stak starting at addr, produce tape
  ::  Uses turn+scag+slag to avoid fuse-loop from ?@ on (list *) elements
  |=  [addr=@ cnt=@ m=stak]
  ^-  tape
  =/  slice  (scag cnt (slag addr m))
  %+  turn  slice
  |=  c=*
  ?>  ?=(@ c)
  ^-(@t c)
:: RUN-WORD - execute a named word against the interpreter state
++  run-word
  |=  [w=@t st=north]
  ^-  north
  =/  w  (crip (cuss (trip w)))   ::  fold to uppercase at entry
  =/  ds  d-stack.st
  =/  rs  r-stack.st
  ::  User dictionary takes precedence over primitives
  =/  body  (find-dict w dict.st)
  ?^  body  (eval u.body st)
  ::  Stack ops ( d-stack only )
  ?:  =(w 'DUP')    st(d-stack (dup ds))
  ?:  =(w 'DROP')   st(d-stack (drop ds))
  ?:  =(w 'SWAP')   st(d-stack (swap ds))
  ?:  =(w 'OVER')   st(d-stack (over ds))
  ?:  =(w 'ROT')    st(d-stack (rot ds))
  ?:  =(w 'DEPTH')  st(d-stack (push ds (lent ds)))
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
  ?:  =(w 'MOD')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds q:(divmod:ua a b)))
  ?:  =(w '/MOD')
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
  ?:  =(w 'AND')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (dis a b)))
  ?:  =(w 'OR')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (con a b)))
  ?:  =(w 'XOR')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mix a b)))
  ?:  =(w 'INVERT')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mix a forth-true)))
  ::  Tier 4: Return stack
  ?:  =(w '>R')
    =^  a=@  ds  (pop ds)
    st(d-stack ds, r-stack (push rs a))
  ?:  =(w 'R>')
    =^  a=@  rs  (pop rs)
    st(d-stack (push ds a), r-stack rs)
  ?:  =(w 'R@')
    st(d-stack (push ds (rear rs)))
  ::  Tier 5: Memory ( addr -- x ) and ( x addr -- )
  ?:  =(w '@')
    =^  addr=@  ds  (pop ds)
    st(d-stack (push ds (fetch addr mem.st)))
  ?:  =(w '!')
    =^  addr=@  ds  (pop ds)
    =/  val  (rear ds)
    st(d-stack (drop ds), mem (store mem.st addr val))
  ?:  =(w '+!')
    =^  addr=@  ds  (pop ds)
    =^  n=@     ds  (pop ds)
    =/  raw  (fetch addr mem.st)
    ?>  ?=(@ raw)
    st(d-stack ds, mem (store mem.st addr (add:ua raw n)))
  ::  Tier 6: Dictionary basics
  ?:  =(w 'HERE')
    st(d-stack (push ds here.settings.st))
  ?:  =(w 'ALLOT')
    =^  n=@  ds  (pop ds)
    (allot n st(d-stack ds))
  ?:  =(w ',')
    =/  v  (rear ds)
    (comma v st(d-stack (drop ds)))
  ::  CELLS: cell size is 1, so n CELLS = n (identity)
  ?:  =(w 'CELLS')  st
  ::  CELL+: add one cell size (1) to address
  ?:  =(w 'CELL+')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (inc:ua a)))
  ::  Tier 7: Interpreter core
  ::  EXECUTE ( xt -- ) run the word named by xt
  ?:  =(w 'EXECUTE')
    =^  xt=cord  ds  (pop ds)
    (run-word xt st(d-stack ds))
  ::  FIND ( cord -- cord 0 | xt forth-true ) search user dict
  ?:  =(w 'FIND')
    =^  name=cord  ds  (pop ds)
    =/  body  (find-dict name dict.st)
    ?~  body
      st(d-stack (push (push ds name) 0))
    st(d-stack (push (push ds name) forth-true))
  ::  Tier 8: Compilation
  ::  STATE ( -- flag ) 0=interpret, forth-true=compile (standard Forth convention)
  ?:  =(w 'STATE')
    st(d-stack (push ds ?:(state.settings.st 0 forth-true)))
  ::  Tier 10: Extended stack
  ?:  =(w '2DUP')
    st(d-stack (over (over ds)))
  ?:  =(w '2DROP')
    st(d-stack (drop (drop ds)))
  ?:  =(w '2SWAP')
    =^  d=@  ds  (pop ds)
    =^  c=@  ds  (pop ds)
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push (push (push (push ds c) d) a) b))
  ?:  =(w '2OVER')
    =/  len  (lent ds)
    ?>  (gte:ua len 4)
    =/  b  (snag (sub:ua (dec:ua len) 2) ds)
    =/  a  (snag (sub:ua (dec:ua len) 3) ds)
    st(d-stack (push (push ds a) b))
  ?:  =(w 'NIP')
    =^  b=@  ds  (pop ds)
    st(d-stack (push (drop ds) b))
  ?:  =(w 'TUCK')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push (push (push ds b) a) b))
  ?:  =(w '?DUP')
    =^  n=@  ds  (pop ds)
    ?:  =(0 n)
      st(d-stack (push ds n))
    st(d-stack (push (push ds n) n))
  ?:  =(w 'PICK')
    =^  n=@  ds  (pop ds)
    =/  len  (lent ds)
    ?>  (gt:ua len n)
    st(d-stack (push ds (snag (sub:ua (dec:ua len) n) ds)))
  ?:  =(w 'ROLL')
    =^  n=@  ds  (pop ds)
    ?:  =(0 n)  st(d-stack ds)
    =/  len  (lent ds)
    ?>  (gt:ua len n)
    =/  idx  (sub:ua (dec:ua len) n)
    st(d-stack (push (roll-remove ds idx) (snag idx ds)))
  ::  Tier 10: Arithmetic
  ?:  =(w 'NEGATE')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (negate:zz a)))
  ?:  =(w 'ABS')
    =^  a=@  ds  (pop ds)
    =/  [s=? m=@]  (decode:zz a)
    st(d-stack (push ds (encode:zz %.y m)))
  ?:  =(w 'MIN')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((lt:ua a b) a b)))
  ?:  =(w 'MAX')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((gt:ua a b) a b)))
  ?:  =(w '2*')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (mul:ua 2 a)))
  ?:  =(w '2/')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds (div:ua a 2)))
  ?:  =(w 'LSHIFT')
    =^  u=@  ds  (pop ds)
    =^  n=@  ds  (pop ds)
    st(d-stack (push ds (mul:ua n (bex:ua u))))
  ?:  =(w 'RSHIFT')
    =^  u=@  ds  (pop ds)
    =^  n=@  ds  (pop ds)
    st(d-stack (push ds (div:ua n (bex:ua u))))
  ::  Tier 10: Comparison and logical
  ?:  =(w '0<')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((zlt:zz a) forth-true 0)))
  ?:  =(w '0>')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:(?&(!=(0 a) (even:ua a)) forth-true 0)))
  ?:  =(w '<>')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((eq:ua a b) 0 forth-true)))
  ?:  =(w 'NOT')
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((zeq:ua a) forth-true 0)))
  ?:  =(w 'TRUE')
    st(d-stack (push ds forth-true))
  ?:  =(w 'FALSE')
    st(d-stack (push ds 0))
  ?:  =(w 'U<')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((lt:ua a b) forth-true 0)))
  ?:  =(w 'U>')
    =^  b=@  ds  (pop ds)
    =^  a=@  ds  (pop ds)
    st(d-stack (push ds ?:((gt:ua a b) forth-true 0)))
  ::  Tier 10: Output buffer
  ?:  =(w 'EMIT')
    =^  c=@  ds  (pop ds)
    st(d-stack ds, buffers buffers.st(output (weld output.buffers.st ~[^-(@t c)])))
  ?:  =(w 'CR')
    ::  newline char: @ud 10 → @ → @t via double-cast (aura nesting rule)
    st(buffers buffers.st(output (weld output.buffers.st ~[^-(@t ^-(@ 10))])))
  ?:  =(w 'SPACE')
    st(buffers buffers.st(output (weld output.buffers.st ~[' '])))
  ?:  =(w 'SPACES')
    =^  n=@  ds  (pop ds)
    st(d-stack ds, buffers buffers.st(output (weld output.buffers.st (tape-reap n ' '))))
  ::  Tier 13: Number and string output
  ?:  =(w '.')
    ::  ( n -- )  print TOS as unsigned decimal followed by a space
    =^  n=@  ds  (pop ds)
    =/  str  (weld (num-to-tape n) ~[' '])
    st(d-stack ds, buffers buffers.st(output (weld output.buffers.st str)))
  ?:  =(w 'TYPE')
    ::  ( addr cnt -- )  print cnt chars from mem starting at addr
    =^  cnt=@   ds  (pop ds)
    =^  addr=@  ds  (pop ds)
    =/  chars  (read-chars addr cnt mem.st)
    st(d-stack ds, buffers buffers.st(output (weld output.buffers.st chars)))
  ::  Tier 11: Counted loop control words
  ::  r-stack layout inside DO loop: [..., limit, index] (index=TOS)
  ?:  =(w 'I')
    st(d-stack (push ds (rear rs)))
  ?:  =(w 'J')
    ::  Outer loop index: TOS-2 in rightward stack
    =/  len  (lent rs)
    ?>  (gte:ua len 3)
    st(d-stack (push ds (snag (sub:ua (dec:ua len) 2) rs)))
  ?:  =(w 'LEAVE')
    ::  Force exit: set current index = limit (LOOP will exit next iteration)
    ?>  (gte:ua (lent rs) 2)
    =/  lim  (rear (drop rs))
    st(r-stack (push (drop rs) lim))
  ?:  =(w 'UNLOOP')
    ::  Clean up loop params from r-stack without exiting the word
    ?>  (gte:ua (lent rs) 2)
    st(r-stack (drop (drop rs)))
  ::  Tier 14: Metaprogramming — [ ] LITERAL
  ?:  =(w '[')
    ::  [ in interpret mode is a no-op (already interpreting)
    st
  ?:  =(w ']')
    ::  ] switches back to compile mode
    st(settings settings.st(state %.n))
  ?:  =(w 'LITERAL')
    ::  LITERAL in interpret mode is a no-op (value already on stack)
    st
  ~|([%unknown-word w] !!)
:: EVAL - run a token program against the interpreter state (index-based)
++  eval
  |=  [p=prog st=north]
  ^-  north
  =/  n  (lent p)
  =|  ip=@
  |-
  ^-  north
  ?:  (gte:ua ip n)  st
  =/  tok  (snag-prog ip p)
  ::  Compile mode (state=%.n): accumulate tokens into comp-buffer
  ::  ';' (as %word) is the only token that ends compilation
  ?.  state.settings.st
    ?:  ?=([%word *] tok)
      ?:  =(';' w.tok)
        ::  End of definition: store body in dict, return to interpret
        =/  name  current-def.settings.st
        =/  body  comp-buffer.buffers.st
        =/  st2   st(dict (dict-add name body dict.st), settings settings.st(state %.y, current-def ''), buffers buffers.st(comp-buffer ~))
        $(ip +(ip), st st2)
      ::  '[' is immediate: switch to interpret mode mid-definition
      ?:  =(w.tok '[')
        $(ip +(ip), st st(settings settings.st(state %.y)))
      ::  LITERAL: pop TOS and emit as number literal into comp-buffer
      ?:  =(w.tok 'LITERAL')
        =/  ds  d-stack.st
        =^  val=@  ds  (pop ds)
        $(ip +(ip), st st(d-stack ds, comp-buffer.buffers (weld comp-buffer.buffers.st ~[[%num n=val]])))
      ::  RECURSE: emit a call to the word currently being defined
      ?:  =(w.tok 'RECURSE')
        =/  self  current-def.settings.st
        $(ip +(ip), st st(comp-buffer.buffers (weld comp-buffer.buffers.st ~[[%word w=self]])))
      ::  Compile this word token into body
      $(ip +(ip), st st(comp-buffer.buffers (weld comp-buffer.buffers.st ~[tok])))
    ::  Compile any non-word token (num, tick, zbranch, branch) into body
    $(ip +(ip), st st(comp-buffer.buffers (weld comp-buffer.buffers.st ~[tok])))
  ::  Interpret mode (state=%.y)
  ?-  -.tok
    %num
      $(ip +(ip), st st(d-stack (push d-stack.st n.tok)))
    %word
      $(ip +(ip), st (run-word w.tok st))
    %tick
      $(ip +(ip), st st(d-stack (push d-stack.st w.tok)))
    %colon
      ::  Begin definition: switch to compile mode, clear comp-buffer
      ?>  state.settings.st
      =/  st2  st(settings settings.st(state %.n, current-def name.tok), buffers buffers.st(comp-buffer ~))
      $(ip +(ip), st st2)
    %zbranch
      =/  ds  d-stack.st
      =^  flag=@  ds  (pop ds)
      ?:  =(0 flag)
        $(ip (ip-advance ip offset.tok), st st(d-stack ds))
      $(ip +(ip), st st(d-stack ds))
    %branch
      $(ip (ip-advance ip offset.tok))
    %do
      ::  Pop start(TOS) and limit from d-stack; push limit then start onto r-stack
      =/  ds  d-stack.st
      =^  start=@  ds  (pop ds)
      =^  lim=@    ds  (pop ds)
      $(ip +(ip), st st(d-stack ds, r-stack (push (push r-stack.st lim) start)))
    %loop
      ::  Increment index; exit if new-index >= limit, else loop back
      =/  idx  (rear r-stack.st)
      ?>  ?=(@ idx)
      =/  rs1  (drop r-stack.st)
      =/  lim  (rear rs1)
      ?>  ?=(@ lim)
      =/  new-idx  (inc:ua ^-(@ idx))
      ?:  (gte:ua new-idx ^-(@ lim))
        $(ip +(ip), st st(r-stack (drop rs1)))
      $(ip (ip-advance ip offset.tok), st st(r-stack (push rs1 new-idx)))
    %ploop
      ::  Step by n (popped from d-stack); exit if new-index >= limit, else loop
      =/  ds   d-stack.st
      =^  step=@  ds  (pop ds)
      =/  idx  (rear r-stack.st)
      ?>  ?=(@ idx)
      =/  rs1  (drop r-stack.st)
      =/  lim  (rear rs1)
      ?>  ?=(@ lim)
      =/  new-idx  (add:ua ^-(@ idx) step)
      ?:  (gte:ua new-idx ^-(@ lim))
        $(ip +(ip), st st(d-stack ds, r-stack (drop rs1)))
      $(ip (ip-advance ip offset.tok), st st(d-stack ds, r-stack (push rs1 new-idx)))
    %variable
      ::  Allocate one cell at HERE; bind name to its address
      =/  addr  here.settings.st
      =/  st2   (allot 1 st)
      $(ip +(ip), st st2(dict (dict-add name.tok ~[[%num n=addr]] dict.st2)))
    %constant
      ::  Pop TOS; bind name to that value
      =/  ds  d-stack.st
      =^  val=@  ds  (pop ds)
      $(ip +(ip), st st(d-stack ds, dict (dict-add name.tok ~[[%num n=val]] dict.st)))
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
:: FETCH ( addr -- x )  Read noun from mem at addr
++  fetch
  |=  [n=@ mem=stak]
  ^-  *
  (snag n mem)
:: STORE ( x addr mem -- mem' )  Write noun into mem at addr
++  store
  |=  [mem=stak n=@ v=*]
  ^-  stak
  (snap mem n v)
:: Tier 6: Dictionary Basics
:: COMMA ( v st -- st' )  Store v at HERE, advance HERE by one cell
++  comma
  |=  [v=* st=north]
  ^-  north
  =/  h  here.settings.st
  =/  m  ?:  (lt:ua h (lent mem.st))
           (store mem.st h v)
         (weld mem.st ~[v])
  st(mem m, settings settings.st(here (inc:ua h)))
:: ALLOT ( n st -- st' )  Append n zero cells to mem, advance HERE by n
++  allot
  |=  [n=@ st=north]
  ^-  north
  st(mem (weld mem.st (reap n 0)), settings settings.st(here (add:ua here.settings.st n)))
:: Tier 7: Interpreter Core
:: DICT-ADD ( name body dict -- dict' )  prepend entry to lexi
++  dict-add
  |=  [name=cord body=prog d=lexi]
  ^-  lexi
  [[name body] d]
:: WORD - text-layer word parser; stub pending text input
++  word      !!
:: Tier 8: Compilation
:: Colon definitions are handled directly in eval via the %colon token
:: and the ';' %word token; no separate gate arms are needed.
:: IMMEDIATE and CREATE require dict entry flags; stubs pending.
++  immediate  !!
++  create     !!
:: Tier 9: Text Parser
:: STRIP-LINE-COMMENTS - remove '\' and everything after it to end of line
++  strip-line-comments
  |=  t=tape
  ^-  tape
  |-
  ?~  t  ~
  ?:  =('\\' i.t)
    =/  rest  t.t
    |-
    ?~  rest  ~
    ?:  =(10 i.rest)  ^$(t t.rest)
    $(rest t.rest)
  [i.t $(t t.t)]
:: SPLIT-WS - split tape on whitespace into list of non-empty tapes
++  split-ws
  |=  t=tape
  ^-  (list tape)
  =|  words=(list tape)
  =|  cur=tape
  |-
  ?~  t
    =/  w2  ?~  cur  words  [(flop cur) words]
    (flop w2)
  =/  c  i.t
  =/  ws  ?|(=(32 c) =(9 c) =(10 c) =(13 c))
  ?:  ws
    ?~  cur  $(t t.t)
    $(t t.t, words [(flop cur) words], cur ~)
  $(t t.t, cur [c cur])
:: PARSE-DEC - parse unsigned decimal tape; ~ if invalid or empty
::  Uses 'any' flag to distinguish "" (invalid) from "0" (valid)
++  parse-dec
  |=  t=tape
  ^-  (unit @ud)
  =|  n=@ud
  =/  any  ^-(? %.n)
  |-
  ?~  t  ?.  any  ~  `n
  =/  c  i.t
  ?.  ?&((gte:ua c 48) (lte:ua c 57))  ~
  $(t t.t, n (add:ua (mul:ua n 10) (sub:ua c 48)), any %.y)
:: PARSE-HEX - parse 0x.../0X... hex tape; ~ if invalid
++  parse-hex
  |=  t=tape
  ^-  (unit @ud)
  ?.  ?&  ?=(^ t)  ?=(^ t.t)
          =(48 i.t)
          ?|(=(120 i.t.t) =(88 i.t.t))
      ==  ~
  =/  rest  t.t.t
  =|  n=@ud
  =/  any  ^-(? %.n)
  |-
  ?~  rest  ?.  any  ~  `n
  =/  c  i.rest
  =/  d  ?:  ?&((gte:ua c 48) (lte:ua c 57))   (sub:ua c 48)
         ?:  ?&((gte:ua c 97) (lte:ua c 102))   (add:ua 10 (sub:ua c 97))
         ?:  ?&((gte:ua c 65) (lte:ua c 70))    (add:ua 10 (sub:ua c 65))
         16
  ?:  (gte:ua d 16)  ~
  $(rest t.rest, n (add:ua (mul:ua n 16) d), any %.y)
:: PARSE-BIN - parse 0b.../0B... binary tape; ~ if invalid
++  parse-bin
  |=  t=tape
  ^-  (unit @ud)
  ?.  ?&  ?=(^ t)  ?=(^ t.t)
          =(48 i.t)
          ?|(=(98 i.t.t) =(66 i.t.t))
      ==  ~
  =/  rest  t.t.t
  =|  n=@ud
  =/  any  ^-(? %.n)
  |-
  ?~  rest  ?.  any  ~  `n
  ?.  ?|(=(48 i.rest) =(49 i.rest))  ~
  $(rest t.rest, n (add:ua (mul:ua n 2) (sub:ua i.rest 48)), any %.y)
:: PARSE-NUM - try hex, then binary, then decimal; ~ if not a number
++  parse-num
  |=  t=tape
  ^-  (unit @ud)
  =/  h  (parse-hex t)
  ?^  h  h
  =/  b  (parse-bin t)
  ?^  b  b
  (parse-dec t)
:: PARSE - compile Forth source tape to prog
::  Handles: numbers (dec/hex/bin), words, : ; ' ( comments
::  Control flow: IF ELSE THEN, BEGIN AGAIN UNTIL, BEGIN WHILE REPEAT
::  All words are folded to uppercase at parse time.
++  parse
  |=  src=tape
  ^-  prog
  =/  words  (split-ws (strip-line-comments src))
  =|  out=prog
  =|  cs=(list [tag=@t ix=@])
  |-
  ^-  prog
  ?~  words  out
  =/  w=tape   i.words
  =/  rest     t.words
  =/  wu=cord  (crip (cuss w))
  ::  Paren comment: skip tokens until ')'
  ?:  =(wu '(')
    =/  ws  rest
    |-
    ?~  ws  ^$(words ~)
    ?:  =((crip (cuss i.ws)) ')')  ^$(words t.ws)
    $(ws t.ws)
  ::  Semicolon ends definition
  ?:  =(wu ';')
    $(words rest, out (weld out ~[[%word w=';']]))
  ::  Colon definition: next token is name
  ?:  =(wu ':')
    ?~  rest  out
    $(words t.rest, out (weld out ~[[%colon name=(crip (cuss i.rest))]]))
  ::  VARIABLE: next token is name
  ?:  =(wu 'VARIABLE')
    ?~  rest  out
    $(words t.rest, out (weld out ~[[%variable name=(crip (cuss i.rest))]]))
  ::  CONSTANT: next token is name
  ?:  =(wu 'CONSTANT')
    ?~  rest  out
    $(words t.rest, out (weld out ~[[%constant name=(crip (cuss i.rest))]]))
  ::  Tick: push xt without executing
  ?:  =(wu '\'')
    ?~  rest  out
    $(words t.rest, out (weld out ~[[%tick w=(crip (cuss i.rest))]]))
  ::  IF: compile 0BRANCH placeholder, push index onto cs
  ?:  =(wu 'IF')
    =/  ix  (lent out)
    $(words rest, out (weld out ~[[%zbranch offset=--0]]), cs [['IF' ix] cs])
  ::  ELSE: patch IF's zbranch, compile BRANCH placeholder
  ?:  =(wu 'ELSE')
    ?>  ?&(?=(^ cs) =('IF' tag.i.cs))
    =/  ix-if      ix.i.cs
    =/  ix-branch  (lent out)
    =/  out2  (patch-prog out ix-if [%zbranch offset=(sun:si (sub:ua ix-branch ix-if))])
    $(words rest, out (weld out2 ~[[%branch offset=--0]]), cs [['ELSE' ix-branch] t.cs])
  ::  THEN: patch IF (or ELSE) branch to current position
  ?:  =(wu 'THEN')
    ?>  ?=(^ cs)
    =/  ix-then  (lent out)
    ?:  =('ELSE' tag.i.cs)
      =/  ix-br  ix.i.cs
      $(words rest, out (patch-prog out ix-br [%branch offset=(sun:si (sub:ua ix-then (inc:ua ix-br)))]), cs t.cs)
    ?>  =('IF' tag.i.cs)
    =/  ix-if  ix.i.cs
    $(words rest, out (patch-prog out ix-if [%zbranch offset=(sun:si (sub:ua ix-then (inc:ua ix-if)))]), cs t.cs)
  ::  BEGIN: push loop-start index
  ?:  =(wu 'BEGIN')
    $(words rest, cs [['BEGIN' (lent out)] cs])
  ::  AGAIN: unconditional backward branch to BEGIN
  ?:  =(wu 'AGAIN')
    ?>  ?&(?=(^ cs) =('BEGIN' tag.i.cs))
    =/  ix-begin  ix.i.cs
    =/  ix-again  (lent out)
    =/  off=@s    (dif:si (sun:si ix-begin) (sun:si (inc:ua ix-again)))
    $(words rest, out (weld out ~[[%branch offset=off]]), cs t.cs)
  ::  UNTIL: 0BRANCH back to BEGIN (flag=0 → loop, flag≠0 → exit)
  ?:  =(wu 'UNTIL')
    ?>  ?&(?=(^ cs) =('BEGIN' tag.i.cs))
    =/  ix-begin  ix.i.cs
    =/  ix-until  (lent out)
    =/  off=@s    (dif:si (sun:si ix-begin) (sun:si (inc:ua ix-until)))
    $(words rest, out (weld out ~[[%zbranch offset=off]]), cs t.cs)
  ::  WHILE: 0BRANCH out of loop when flag=0
  ?:  =(wu 'WHILE')
    =/  ix  (lent out)
    $(words rest, out (weld out ~[[%zbranch offset=--0]]), cs [['WHILE' ix] cs])
  ::  REPEAT: backward branch to BEGIN, patch WHILE exit
  ?:  =(wu 'REPEAT')
    ?>  ?&(?=(^ cs) =('WHILE' tag.i.cs))
    =/  ix-while  ix.i.cs
    =/  cs2       t.cs
    ?>  ?&(?=(^ cs2) =('BEGIN' tag.i.cs2))
    =/  ix-begin  ix.i.cs2
    =/  ix-rep    (lent out)
    =/  off-back=@s  (dif:si (sun:si ix-begin) (sun:si (inc:ua ix-rep)))
    =/  out2  (weld out ~[[%branch offset=off-back]])
    =/  off-exit=@s  (sun:si (sub:ua (lent out2) (inc:ua ix-while)))
    $(words rest, out (patch-prog out2 ix-while [%zbranch offset=off-exit]), cs t.cs2)
  ::  DO: emit %do token, push ['DO' ix-do] onto compile stack
  ?:  =(wu 'DO')
    =/  ix  (lent out)
    $(words rest, out (weld out ~[[%do ~]]), cs [['DO' ix] cs])
  ::  LOOP: backpatch backward branch to first body token (ix-do+1)
  ?:  =(wu 'LOOP')
    ?>  ?&(?=(^ cs) =('DO' tag.i.cs))
    =/  ix-do    ix.i.cs
    =/  ix-loop  (lent out)
    =/  off=@s   (dif:si (sun:si (inc:ua ix-do)) (sun:si (inc:ua ix-loop)))
    $(words rest, out (weld out ~[[%loop offset=off]]), cs t.cs)
  ::  +LOOP: same as LOOP but %ploop token
  ?:  =(wu '+LOOP')
    ?>  ?&(?=(^ cs) =('DO' tag.i.cs))
    =/  ix-do    ix.i.cs
    =/  ix-loop  (lent out)
    =/  off=@s   (dif:si (sun:si (inc:ua ix-do)) (sun:si (inc:ua ix-loop)))
    $(words rest, out (weld out ~[[%ploop offset=off]]), cs t.cs)
  ::  LEAVE I J UNLOOP: emit as %word tokens (handled in run-word)
  ?:  =(wu 'LEAVE')   $(words rest, out (weld out ~[[%word w='LEAVE']]))
  ?:  =(wu 'I')       $(words rest, out (weld out ~[[%word w='I']]))
  ?:  =(wu 'J')       $(words rest, out (weld out ~[[%word w='J']]))
  ?:  =(wu 'UNLOOP')  $(words rest, out (weld out ~[[%word w='UNLOOP']]))
  ::  Try as number literal
  =/  mn  (parse-num w)
  ?^  mn  $(words rest, out (weld out ~[[%num n=u.mn]]))
  ::  Otherwise: word token (already uppercased)
  $(words rest, out (weld out ~[[%word w=wu]]))
--
