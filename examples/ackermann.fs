\ Ackermann-Péter function in North Forth
\ ( m n -- ack(m,n) )
\ Definition:
\   ack(0, n) = n + 1
\   ack(m, 0) = ack(m-1, 1)
\   ack(m, n) = ack(m-1, ack(m, n-1))
\ Grows extremely fast; keep m <= 3, n <= 4 for reasonable runtimes.
\ ack(0,0)=1  ack(1,1)=3  ack(2,2)=7  ack(3,2)=29  ack(3,3)=61

: ack  ( m n -- result )
    OVER 0 = IF
        NIP 1+                       \ ack(0,n) = n+1
    ELSE
        DUP 0 = IF
            DROP 1- 1 RECURSE        \ ack(m,0) = ack(m-1,1)
        ELSE
            OVER SWAP 1- RECURSE     \ compute ack(m, n-1) ...
            SWAP 1- SWAP RECURSE     \ ... then ack(m-1, that)
        THEN
    THEN ;
