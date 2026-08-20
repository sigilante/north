( North core stdlib )
( Composite definitions layered on top of the interpreter primitives. )
( Load interactively with  INCLUDE /lib/core  or via the test harness. )
( Uses paren comments throughout so the file can be flattened to a single )
( line for tooling that does not preserve newlines. )

( ---- Comparison shorthands ---- )

: <=   ( a b -- f )   > NOT ;
: >=   ( a b -- f )   < NOT ;
: 0<>  ( n -- f )     0= NOT ;
: U<=  ( a b -- f )   U> NOT ;
: U>=  ( a b -- f )   U< NOT ;

( ---- Range test: true iff lo <= n < hi ---- )

: WITHIN  ( n lo hi -- f )   >R OVER <= SWAP R> < AND ;

( ---- Numeric convenience ---- )

: SQUARED  ( n -- n*n )    DUP * ;
: CUBED    ( n -- n*n*n )  DUP SQUARED * ;

( ---- Fetch and print: classic Forth debug helper ---- )

: ?  ( addr -- )   @ . ;
