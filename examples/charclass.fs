\ Character classification words for North Forth
\ All predicates: ( c -- flag )   flag is forth-true or 0
\ All converters:  ( c -- c' )
\ ASCII ranges:  digits 48..57  upper 65..90  lower 97..122

: isdigit  ( c -- flag )  DUP 48 < 0= SWAP 57  > 0= AND ;
: isupper  ( c -- flag )  DUP 65 < 0= SWAP 90  > 0= AND ;
: islower  ( c -- flag )  DUP 97 < 0= SWAP 122 > 0= AND ;

: isalpha  ( c -- flag )  DUP isupper SWAP islower OR ;
: isalnum  ( c -- flag )  DUP isalpha SWAP isdigit OR ;

: isspace  ( c -- flag )
    DUP 32 = SWAP
    DUP  9 = SWAP
    DUP 10 = SWAP
    13 = OR OR OR ;

: toupper  ( c -- c' )  DUP islower IF 32 - THEN ;
: tolower  ( c -- c' )  DUP isupper IF 32 + THEN ;
