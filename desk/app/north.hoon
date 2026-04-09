::  North - Nock Forth interpreter (stub agent)
/+  default-agent, dbug
|%
+$  versioned-state  $%([%0 state-0])
+$  state-0  ~
--
=|  state-0
=*  state  -
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
++  on-init   `this^~
++  on-save   !>(state)
++  on-load   |=(vase `this^state)
++  on-poke   on-poke:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
