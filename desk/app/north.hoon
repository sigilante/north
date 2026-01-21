::
::  The North (Nock Forth) Interpreter
::
::  Like Arvo itself, North is an executable noun with a well-definted
::  lifecycle.  It is a stack-based virtual machine that executes Forth
::  code read from its TIB (Terminal Input Buffer).
::
::  The primary loop is the QUIT loop, which is a simple REFILL-BEGIN-AGAIN
::  loop that reads a line from the TIB, parses it, and executes it.
::
::  The parser is a simple state machine that reads a line from the TIB,
::  parses it, and executes it.
::
/+  *north
=>
|%
++  nord  %544  :: the melting point of bismuth
--
|_  state=*
++  quit  !!
--

: QUIT ( -- )
  BEGIN
    REFILL           \ Get new line into TIB
    BEGIN
      BL WORD        \ Parse next word (delimiter = space)
      DUP C@         \ Get length of parsed word
    WHILE            \ While there are words...
      FIND           \ Look up in dictionary
      ?DUP IF        \ If found (xt on stack)
        STATE @ IF   \ Are we compiling?
          IMMEDIATE? IF  \ Is word immediate?
            EXECUTE      \ Yes: execute even in compile mode
          ELSE
            ,            \ No: append xt to definition
          THEN
        ELSE         \ Interpreting mode
          EXECUTE    \ Just execute it
        THEN
      ELSE           \ Not found in dictionary
        NUMBER       \ Try to parse as number
        ?DUP IF      \ Parsed successfully?
          STATE @ IF   \ Compiling?
            LIT ,      \ Yes: compile as literal
            ,
          THEN       \ (If interpreting, already on stack)
        ELSE
          ." Unknown word" CR
          ABORT
        THEN
      THEN
    REPEAT
    ." ok" CR
  AGAIN ;