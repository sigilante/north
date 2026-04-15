::  North - interactive Forth REPL via %shoe
::
/+  default-agent, shoe, dbug
/+  vm=north
::
|%
+$  versioned-state  $%  [%0 state-0]  ==
+$  state-0
  $:  %0
      forth=north:vm    ::  live interpreter state; persists across commands
      show-stack=?      ::  SON/SOFF flag; %.n = off by default
  ==
+$  command  tape   ::  raw Forth input line; North's parse gate handles tokenisation
+$  card  card:shoe
--
::
=|  state-0
=*  state  -
::
%-  agent:dbug
^-  agent:gall
%-  (agent:shoe command)
^-  (shoe:shoe command)
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
    des   ~(. (default:shoe this command) bowl)
::
++  on-init
  ^-  (quip card _this)
  `this
::
++  on-save   !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  `this
::
++  on-poke    on-poke:def
++  on-watch   on-watch:def
++  on-leave   on-leave:def
++  on-peek    on-peek:def
++  on-agent   on-agent:def
++  on-arvo    on-arvo:def
++  on-fail    on-fail:def
::
++  command-parser
  |=  =sole-id:shoe
  ^+  |~(nail *(like [? command]))
  (stag | (star prn))
::
++  tab-list  tab-list:des
::
++  can-connect
  |=  =sole-id:shoe
  ^-  ?
  =(our src):bowl
::
++  on-connect
  |=  =sole-id:shoe
  ^-  (quip card _this)
  ::  shoe's on-watch already emits the initial %pro; don't double it
  `this
::
++  on-disconnect
  |=  =sole-id:shoe
  ^-  (quip card _this)
  `this
::
++  on-command
  |=  [=sole-id:shoe cmd=command]
  ^-  (quip card _this)
  ::  meta-commands: toggle stack display (agent-level, not Forth words)
  =/  wu  (crip (cuss cmd))
  ?:  =(wu 'SON')
    :_  this(show-stack %.y)
    ~[[%shoe ~[sole-id] %sole [%txt "stack display on"]]]
  ?:  =(wu 'SOFF')
    :_  this(show-stack %.n)
    ~[[%shoe ~[sole-id] %sole [%txt "stack display off"]]]
  ::  INCLUDE <path> is parsing sugar for S" <path>" INCLUDED
  =/  cmd
    ?.  =((cuss (scag 8 cmd)) "INCLUDE ")
      cmd
    :(weld "S\" " (slag 8 cmd) "\" INCLUDED")
  ::  run Forth input through the interpreter
  ::  inject now, our, and desk from the bowl so NOW/OUR/INCLUDE work correctly
  =/  forth1  forth(settings settings.forth(now now.bowl, our our.bowl, desk q.byk.bowl))
  =/  result  (mule |.((eval:vm (parse:vm cmd) forth1)))
  ?:  ?=([%| *] result)
    =/  tanks=(list tank)  (flop p.result)
    =/  lines=(list tape)
      ?~  tanks  ~["error"]
      (turn tanks |=(t=tank ~(ram re t)))
    :_  this
    %+  turn  lines
    |=(l=tape [%shoe ~[sole-id] %sole [%txt (weld "! " l)]])
  =/  new    p.result
  =/  out    output.buffers.new
  =/  ds     d-stack.new
  =/  ok=tape
    ?:  show-stack
      :(weld "  ok  " <ds>)
    "  ok"
  :_  this(forth new(buffers buffers.new(output "")))
  %-  zing
  :~  ?.  =(~ out)
        ~[[%shoe ~[sole-id] %sole [%txt out]]]
      ~
      ~[[%shoe ~[sole-id] %sole [%txt ok]]]
  ==
--
