\ Word count in North Forth
\ count-words ( addr len -- n )
\ Counts space-separated words in a memory buffer.
\ A "word" is a maximal run of characters with ASCII code >= 33.
\ Demo strings are pre-stored using [CHAR]/comma to avoid S" quoting issues.

VARIABLE wc-base
VARIABLE wc-len
VARIABLE wc-words
VARIABLE wc-in

: count-words  ( addr len -- n )
    wc-len !  wc-base !
    0 wc-words !
    0 wc-in !
    wc-len @ 0 DO
        wc-base @ I + @              \ fetch char at offset I
        33 < IF
            0 wc-in !                \ space/ctrl: leave word
        ELSE
            wc-in @ 0= IF
                wc-words @ 1+ wc-words !  \ entering new word
            THEN
            1 wc-in !                \ mark in-word
        THEN
    LOOP
    wc-words @ ;

\ Pre-stored demo string: "hello world" (11 chars, 2 words)
HERE CONSTANT wc-demo-addr
[CHAR] h , [CHAR] e , [CHAR] l , [CHAR] l , [CHAR] o ,
32 ,
[CHAR] w , [CHAR] o , [CHAR] r , [CHAR] l , [CHAR] d ,
11 CONSTANT wc-demo-len

\ Pre-stored demo string: "  foo   bar  baz  " (18 chars, 3 words)
HERE CONSTANT wc-demo2-addr
32 , 32 ,
[CHAR] f , [CHAR] o , [CHAR] o ,
32 , 32 , 32 ,
[CHAR] b , [CHAR] a , [CHAR] r ,
32 , 32 ,
[CHAR] b , [CHAR] a , [CHAR] z ,
32 , 32 ,
18 CONSTANT wc-demo2-len
