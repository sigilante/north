\ Fibonacci sequence in North Forth
\ fib(n) -- nth Fibonacci number, 0-indexed
\ fib(0)=0, fib(1)=1, fib(2)=1, fib(3)=2, fib(5)=5, fib(10)=55
\ Uses two variables for iterative O(n) computation.

VARIABLE fib-a
VARIABLE fib-b

: fib  ( n -- fib(n) )
    DUP 2 < IF EXIT THEN      \ fib(0)=0, fib(1)=1 returned directly
    1 fib-a !                  \ fib(1) = 1
    1 fib-b !                  \ fib(2) = 1
    2 - 0 DO                   \ iterate n-2 times
        fib-a @ fib-b @ +      \ next = a + b
        fib-b @ fib-a !        \ a = old b
        fib-b !                \ b = next
    LOOP
    fib-b @ ;
