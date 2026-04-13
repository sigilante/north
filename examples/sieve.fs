\ Sieve of Eratosthenes in North Forth
\ After sieve-run: sieve-arr+n holds 1 if n is prime, 0 otherwise.
\ Usage:
\   sieve-run              ( -- )       run the sieve
\   n is-prime?            ( n -- flag ) test primality (after sieve-run)

100 CONSTANT SIEVE-LIMIT

HERE SIEVE-LIMIT ALLOT CONSTANT sieve-arr

\ Set all slots to 1; mark 0 and 1 as non-prime.
: sieve-init  ( -- )
    SIEVE-LIMIT 0 DO  1 sieve-arr I + !  LOOP
    0 sieve-arr !
    0 sieve-arr 1 + ! ;

\ Mark every multiple of p starting at p^2 as composite.
: sieve-mark  ( p -- )
    DUP >R                           \ save p on r-stack
    DUP *                            \ start at p^2
    BEGIN DUP SIEVE-LIMIT < WHILE
        0 OVER sieve-arr + !         \ mark slot as composite
        R@ +                         \ advance by p
    REPEAT
    DROP R> DROP ;

\ Run the full sieve up to SIEVE-LIMIT.
: sieve-run  ( -- )
    sieve-init
    2 BEGIN DUP DUP * SIEVE-LIMIT < WHILE
        DUP sieve-arr + @ IF         \ if p is still marked prime
            DUP sieve-mark           \ mark its multiples
        THEN
        1+
    REPEAT DROP ;

\ Primality test (requires sieve-run to have been called).
: is-prime?  ( n -- flag )  sieve-arr + @ ;
