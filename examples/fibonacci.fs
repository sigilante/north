\ Fibonacci sequence in North Forth
\ fib(n) -- nth Fibonacci number, 0-indexed
\ fib(0)=0, fib(1)=1, fib(2)=1, fib(3)=2, fib(5)=5, fib(10)=55
\ Uses two variables and BEGIN/WHILE/REPEAT to avoid DO LOOP's
\ "always-at-least-once" behaviour when the trip count is zero (n=2).

VARIABLE fib-a
VARIABLE fib-b

: fib  ( n -- fib(n) )
    DUP 2 < IF EXIT THEN      \ fib(0)=0, fib(1)=1 returned directly
    1 fib-a !                  \ fib(1) = 1
    1 fib-b !                  \ fib(2) = 1
    2 -                        \ remaining iterations (0 for n=2)
    BEGIN DUP 0 > WHILE        \ while counter > 0
        fib-a @ fib-b @ +      \ next = a + b
        fib-b @ fib-a !        \ a = old b
        fib-b !                \ b = next
        1-                     \ decrement counter
    REPEAT
    DROP
    fib-b @ ;
