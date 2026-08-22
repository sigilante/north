::  North - interactive Forth REPL via %shoe
::
/+  default-agent, shoe, dbug
/+  vm=north
::
|%
::  each state mold carries its own head tag, so the union is over them
::  directly -- +on-save writes the bare state, not a wrapped one
+$  versioned-state  $%(state-0 state-1)
+$  state-0
  $:  %0
      forth=north:vm    ::  live interpreter state; persists across commands
      show-stack=?      ::  SON/SOFF flag; %.n = off by default
  ==
::  $session: one client's interpreter.
::
::    state-0 kept a single global interpreter, so every %sole session on the
::    agent shared one stack and one dictionary.  Two terminals -- or two
::    notebooks in a client like /app/caderno, which opens a session per
::    notebook -- would silently scribble on each other.  Key it by sole-id
::    instead, created on first command and dropped in +on-disconnect.
+$  session
  $:  forth=north:vm
      show-stack=?
  ==
+$  state-1
  $:  %1
      sessions=(map sole-id:shoe session)
  ==
+$  command  tape   ::  raw Forth input line; North's parse gate handles tokenisation
::  step-budget: interpreter steps one command may take before it is stopped.
::
::    Arvo is non-preemptive, so a slow command blocks the entire ship -- other
::    agents, other %sole sessions, networking -- not just this session, and
::    there is no way to cancel a move once it is running.  See #37.
::
::    This bounds steps, not wall-clock, and the two are only related if steps
::    cost roughly the same.  Measured: ~280k steps/sec with jetted arithmetic
::    (#38), so this is about three or four seconds.  Without #38 a single
::    step can be a whole unary +add, and the same budget is minutes.
::
::    So this is a real bound but a soft one, and it is much sharper once #38
::    lands.  It is still worth having: it converts "blocks the ship until
::    someone intervenes" into "blocks the ship for a bounded time, then
::    reports".  Turn it up if legitimate work is being cut off.
++  step-budget  1.000.000
+$  card  card:shoe
--
::
=|  state-1
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
  =/  try  (mule |.(!<(versioned-state old)))
  ?.  ?=(%& -.try)  `this
  ?-  -.p.try
      %1  `this(state p.try)
      %0
    ::  the state-0 interpreter belonged to no session in particular, so
    ::  there is nobody to hand it to; everyone starts fresh
    `this(state [%1 ~])
  ==
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
  ::  the client left; drop its interpreter so that re-subscribing under the
  ::  same session name starts clean.  This only fires if /lib/shoe calls it
  ::  from +on-leave (urbit/urbit#7416); without that the session leaks and
  ::  a client cannot reset its kernel.
  `this(sessions (~(del by sessions) sole-id))
::
++  on-command
  |=  [=sole-id:shoe cmd=command]
  ^-  (quip card _this)
  ::  this client's interpreter; created on first command
  =/  ses  (~(gut by sessions) sole-id *session)
  ::  meta-commands: toggle stack display (agent-level, not Forth words)
  =/  wu  (crip (cuss cmd))
  ?:  =(wu 'SON')
    :_  this(sessions (~(put by sessions) sole-id ses(show-stack %.y)))
    ~[[%shoe ~[sole-id] %sole [%txt "stack display on"]]]
  ?:  =(wu 'SOFF')
    :_  this(sessions (~(put by sessions) sole-id ses(show-stack %.n)))
    ~[[%shoe ~[sole-id] %sole [%txt "stack display off"]]]
  ::  INCLUDE <path> is parsing sugar for S" <path>" INCLUDED
  =/  cmd
    ?.  =((cuss (scag 8 cmd)) "INCLUDE ")
      cmd
    :(weld "S\" " (slag 8 cmd) "\" INCLUDED")
  ::  run Forth input through the interpreter
  ::  inject now, our, and desk from the bowl so NOW/OUR/INCLUDE work correctly
  =/  forth1
    %=  forth.ses
      settings
        %=  settings.forth.ses
          now   now.bowl
          our   our.bowl
          desk  q.byk.bowl
          fuel  `step-budget
        ==
    ==
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
  ::  Budget exhausted: the command was stopped part-way, so discard it and
  ::  keep the pre-command interpreter, exactly as the crash path above does.
  ?:  ?&(?=(^ fuel.settings.new) =(0 u.fuel.settings.new))
    :_  this
    :~  :*  %shoe  ~[sole-id]  %sole
            :-  %txt
            "! step budget exhausted; command stopped and discarded"
    ==  ==
  =/  out    output.buffers.new
  =/  ds     d-stack.new
  ::  Surface compile mode.  An unterminated `: FOO ...` leaves the
  ::  interpreter compiling, and because forth.ses persists across commands
  ::  every later cell is silently absorbed into that definition.  Showing it
  ::  is how a user finds out; ABORT is how they get out.  See #37.
  =/  mode=tape  ?:(state.settings.new "  ok" "  compiling")
  =/  ok=tape
    ?:  show-stack.ses
      :(weld mode "  " <ds>)
    mode
  :_  %=  this
        sessions
          %+  ~(put by sessions)  sole-id
          ses(forth new(buffers buffers.new(output ""), settings settings.new(fuel ~)))
      ==
  %-  zing
  :~  ?.  =(~ out)
        ~[[%shoe ~[sole-id] %sole [%txt out]]]
      ~
      ~[[%shoe ~[sole-id] %sole [%txt ok]]]
  ==
--
