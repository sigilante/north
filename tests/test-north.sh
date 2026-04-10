#!/usr/bin/env bash
# North unit tests — shell-based, uses urbit eval
# Run from repo root: bash tests/test-north.sh
# Later: convert to in-Urbit threads

LIB="desk/lib/north.hoon"
PASS=0
FAIL=0
# Forth TRUE = max direct atom in Vere64 (2^63-1 = 0x7fff.ffff.ffff.ffff)
# Hoon requires dots in large decimal literals and prints them the same way
T="9.223.372.036.854.775.807"
F=0

north-eval() {
  local raw
  raw=$( (echo "=>"; cat "$LIB"; echo "$1") | ~/bin/urbit eval 2>&1 )
  # Strip ANSI, CR, eval header lines; collapse multi-line output to one line
  echo "$raw" \
    | grep -v '^lite:\|^loom:\|^eval (run):\|^eval:' \
    | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' \
    | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//; s/ *$//'
}

check() {
  local desc="$1"
  local expr="$2"
  local expected="$3"
  local result
  result=$(north-eval "$expr")
  if [ "$result" = "$expected" ]; then
    echo "PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $desc"
    echo "      expected: $expected"
    echo "      got:      $result"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Tier 0: Stack Ops ==="

check "dup"        "d-stack:(eval ~[[%num n=5] [%word w='dup']] *north)"              "~[5 5]"
check "drop"       "d-stack:(eval ~[[%num n=5] [%num n=3] [%word w='drop']] *north)" "~[5]"
check "swap"       "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='swap']] *north)" "~[2 1]"
check "over"       "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='over']] *north)" "~[1 2 1]"
check "rot"        "d-stack:(eval ~[[%num n=1] [%num n=2] [%num n=3] [%word w='rot']] *north)" "~[2 3 1]"
check "depth-0"    "d-stack:(eval ~[[%word w='depth']] *north)"                      "~[0]"
check "depth-2"    "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='depth']] *north)" "~[1 2 2]"

echo ""
echo "=== Tier 1: Unsigned Arithmetic ==="

check "add"        "d-stack:(eval ~[[%num n=3] [%num n=4] [%word w='+']] *north)"   "~[7]"
check "sub"        "d-stack:(eval ~[[%num n=10] [%num n=3] [%word w='-']] *north)"  "~[7]"
check "mul"        "d-stack:(eval ~[[%num n=25] [%num n=10] [%word w='*']] *north)" "~[250]"
check "div"        "d-stack:(eval ~[[%num n=10] [%num n=2] [%word w='/']] *north)"  "~[5]"
check "mod"        "d-stack:(eval ~[[%num n=10] [%num n=3] [%word w='mod']] *north)" "~[1]"
check "/mod"       "d-stack:(eval ~[[%num n=10] [%num n=3] [%word w='/mod']] *north)" "~[1 3]"
check "1+"         "d-stack:(eval ~[[%num n=4] [%word w='1+']] *north)"             "~[5]"
check "1-"         "d-stack:(eval ~[[%num n=4] [%word w='1-']] *north)"             "~[3]"
check "compound"   "d-stack:(eval ~[[%num n=25] [%num n=10] [%word w='*'] [%num n=50] [%word w='+']] *north)" "~[300]"
check "dup-mul"    "d-stack:(eval ~[[%num n=3] [%word w='dup'] [%word w='*']] *north)" "~[9]"

echo ""
echo "=== Tier 1: Comparisons ==="

check "= true"     "d-stack:(eval ~[[%num n=3] [%num n=3] [%word w='=']] *north)"   "~[$T]"
check "= false"    "d-stack:(eval ~[[%num n=3] [%num n=4] [%word w='=']] *north)"   "~[$F]"
check "< true"     "d-stack:(eval ~[[%num n=2] [%num n=5] [%word w='<']] *north)"   "~[$T]"
check "< false"    "d-stack:(eval ~[[%num n=5] [%num n=2] [%word w='<']] *north)"   "~[$F]"
check "> true"     "d-stack:(eval ~[[%num n=5] [%num n=2] [%word w='>']] *north)"   "~[$T]"
check "> false"    "d-stack:(eval ~[[%num n=2] [%num n=5] [%word w='>']] *north)"   "~[$F]"
check "0= zero"    "d-stack:(eval ~[[%num n=0] [%word w='0=']] *north)"              "~[$T]"
check "0= nonzero" "d-stack:(eval ~[[%num n=1] [%word w='0=']] *north)"              "~[$F]"

echo ""
echo "=== Tier 3: Bitwise ==="

check "and"        "d-stack:(eval ~[[%num n=12] [%num n=10] [%word w='and']] *north)"    "~[8]"
check "or"         "d-stack:(eval ~[[%num n=12] [%num n=10] [%word w='or']] *north)"     "~[14]"
check "xor"        "d-stack:(eval ~[[%num n=15] [%num n=10] [%word w='xor']] *north)"    "~[5]"
check "invert-0"   "d-stack:(eval ~[[%num n=0] [%word w='invert']] *north)"              "~[$T]"
check "invert-T"   "d-stack:(eval ~[[%num n=$T] [%word w='invert']] *north)"             "~[$F]"

echo ""
echo "=== Branching (IF/ELSE/THEN) ==="

# 5 3 > IF 99 THEN  →  true path: zbranch skips 0, pushes 99
# offset=--1: ip-advance(ip, --1) = ip+1+1 = ip+2, skipping %num n=99
check "if-true"    "d-stack:(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=--1] [%num n=99]] *north)" "~[99]"
# 3 5 > IF 99 THEN  →  false path: zbranch jumps to ip+2, skipping %num n=99
check "if-false"   "d-stack:(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=--1] [%num n=99]] *north)" "~"
# 5 3 > IF 1 ELSE 2 THEN  →  true path: push 1, branch over else
# zbranch offset=--2: ip+1+2=ip+3, skipping %num n=1 and %branch
# branch offset=--1: ip+1+1=ip+2, skipping %num n=2
check "if-else-true"  "d-stack:(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=--2] [%num n=1] [%branch offset=--1] [%num n=2]] *north)" "~[1]"
# 3 5 > IF 1 ELSE 2 THEN  →  false path: zbranch skips to else, push 2
check "if-else-false" "d-stack:(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=--2] [%num n=1] [%branch offset=--1] [%num n=2]] *north)" "~[2]"

echo ""
echo "=== Tier 4: Return Stack ==="

# >R moves TOS from data stack to return stack
check ">r d-stack"  "d-stack:(eval ~[[%num n=42] [%word w='>r']] *north)"   "~"
check ">r r-stack"  "r-stack:(eval ~[[%num n=42] [%word w='>r']] *north)"   "~[42]"
# R> moves TOS from return stack to data stack
check "r> d-stack"  "d-stack:(eval ~[[%num n=42] [%word w='>r'] [%word w='r>']] *north)"  "~[42]"
check "r> r-stack"  "r-stack:(eval ~[[%num n=42] [%word w='>r'] [%word w='r>']] *north)"  "~"
# R@ copies return stack TOS to data stack without removing it
check "r@ d-stack"  "d-stack:(eval ~[[%num n=7] [%word w='>r'] [%word w='r@']] *north)"   "~[7]"
check "r@ r-stack"  "r-stack:(eval ~[[%num n=7] [%word w='>r'] [%word w='r@']] *north)"   "~[7]"
# stacking: push two values, retrieve in LIFO order
# LIFO: 1 pushed first, 2 on top; >R >R reverses onto r-stack; R> R> restores original order
check ">r/>r/r>/r>" "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='>r'] [%word w='>r'] [%word w='r>'] [%word w='r>']] *north)" "~[1 2]"

echo ""
echo "=== Tier 5: Memory ==="

# Pre-populated memory state: mem=~[10 20 30] (indices 0,1,2)
# Pattern: =+(st=*north EXPR st(mem ~[10 20 30])))
#   - =+(  opens 1 paren
#   - (eval opens 1 paren (via d-stack: or mem:)
#   - st(  opens 1 paren
#   - )))  closes all three
M="=+(st=*north"
ME='st(mem ~[10 20 30])))'

# @ fetch: addr 0 -> 10
check "@ addr-0"     "$M d-stack:(eval ~[[%num n=0] [%word w='@']] $ME"              "~[10]"
# @ fetch: addr 1 -> 20
check "@ addr-1"     "$M d-stack:(eval ~[[%num n=1] [%word w='@']] $ME"              "~[20]"
# @ fetch: addr 2 -> 30
check "@ addr-2"     "$M d-stack:(eval ~[[%num n=2] [%word w='@']] $ME"              "~[30]"
# ! store: 99 to addr 1, then fetch back
check "! store"      "$M d-stack:(eval ~[[%num n=99] [%num n=1] [%word w='!'] [%num n=1] [%word w='@']] $ME" "~[99]"
# ! store leaves data stack clean (no value residue)
check "! d-stack"    "$M d-stack:(eval ~[[%num n=99] [%num n=0] [%word w='!']] $ME"  "~"
# ! store updates mem
check "! mem"        "$M mem:(eval ~[[%num n=99] [%num n=0] [%word w='!']] $ME"      "~[99 20 30]"
# +! add to cell: addr 0 (10), add 5 -> 15
check "+! add"       "$M d-stack:(eval ~[[%num n=5] [%num n=0] [%word w='+!'] [%num n=0] [%word w='@']] $ME" "~[15]"
# +! updates mem
check "+! mem"       "$M mem:(eval ~[[%num n=5] [%num n=0] [%word w='+!']] $ME"      "~[15 20 30]"

echo ""
echo "=== Tier 6: Dictionary Basics ==="

# HERE on fresh state -> 0
check "here-0"       "d-stack:(eval ~[[%word w='here']] *north)"                                                                      "~[0]"
# ALLOT extends mem and advances HERE
check "allot-mem"    "mem:(eval ~[[%num n=5] [%word w='allot']] *north)"                                                               "~[0 0 0 0 0]"
check "allot-here"   "d-stack:(eval ~[[%num n=5] [%word w='allot'] [%word w='here']] *north)"                                          "~[5]"
# , (comma) stores at HERE, advances HERE
check ",-store"      "d-stack:(eval ~[[%num n=42] [%word w=','] [%num n=0] [%word w='@']] *north)"                                     "~[42]"
check ",-here"       "d-stack:(eval ~[[%num n=42] [%word w=','] [%word w='here']] *north)"                                             "~[1]"
check ",-mem"        "mem:(eval ~[[%num n=10] [%word w=','] [%num n=20] [%word w=','] [%num n=30] [%word w=',']] *north)"              "~[10 20 30]"
# CELLS is identity (cell size = 1)
check "cells"        "d-stack:(eval ~[[%num n=5] [%word w='cells']] *north)"                                                           "~[5]"
# CELL+ increments address by 1
check "cell+"        "d-stack:(eval ~[[%num n=3] [%word w='cell+']] *north)"                                                           "~[4]"
# ALLOT then comma overwrites allocated cells
check "allot-then-," "mem:(eval ~[[%num n=3] [%word w='allot'] [%num n=99] [%num n=1] [%word w='!']] *north)"                         "~[0 99 0]"

echo ""
echo "=== Tier 7: Interpreter Core ==="

# State with 'sq' defined as DUP *
SQ_D="~[['sq' ~[[%word w='dup'] [%word w='*']]]]"
SQ_S="=+(st=*north =+(st=st(dict $SQ_D)"
SQ_E="))"

# %tick pushes xt (cord) without executing; then EXECUTE runs it
check "tick+execute prim"  "d-stack:(eval ~[[%num n=5] [%tick w='dup'] [%word w='execute']] *north)"             "~[5 5]"
check "tick+execute arith" "d-stack:(eval ~[[%num n=6] [%num n=7] [%tick w='+'] [%word w='execute']] *north)"   "~[13]"

# User-defined word dispatched via dict lookup in run-word
check "user word call"     "$SQ_S d-stack:(eval ~[[%num n=4] [%word w='sq']] st)$SQ_E"                          "~[16]"
# User word composed with itself
check "user word compose"  "$SQ_S d-stack:(eval ~[[%num n=3] [%word w='sq'] [%word w='sq']] st)$SQ_E"          "~[81]"
# tick + execute on user word
check "tick+execute user"  "$SQ_S d-stack:(eval ~[[%num n=5] [%tick w='sq'] [%word w='execute']] st)$SQ_E"     "~[25]"

# FIND: flag is TOS; forth-true if in dict, 0 if not
# Use (rear ...) to extract just the flag
check "find known"    "$SQ_S (rear d-stack:(eval ~[[%num n='sq'] [%word w='find']] st))$SQ_E"   "$T"
check "find unknown"  "(rear d-stack:(eval ~[[%num n='unk'] [%word w='find']] *north))"          "$F"

echo ""
echo "=== Tier 8: Compilation ==="

# Basic colon definition and call: : sq  dup * ;
check ": sq -- 4 sq"    "d-stack:(eval ~[[%colon name='sq'] [%word w='dup'] [%word w='*'] [%word w=';'] [%num n=4] [%word w='sq']] *north)"  "~[16]"
# Composed calls
check ": sq -- 3 sq sq" "d-stack:(eval ~[[%colon name='sq'] [%word w='dup'] [%word w='*'] [%word w=';'] [%num n=3] [%word w='sq'] [%word w='sq']] *north)"  "~[81]"
# Definition stored in dict
check ": sq -- dict"    "=(~ dict:(eval ~[[%colon name='sq'] [%word w='dup'] [%word w='*'] [%word w=';']] *north))"  "%.n"

# Word with literal: : double  2 * ;
check ": double -- 7"   "d-stack:(eval ~[[%colon name='double'] [%num n=2] [%word w='*'] [%word w=';'] [%num n=7] [%word w='double']] *north)"  "~[14]"

# Word calling another word: : quad  sq sq ;
check ": quad -- 3"     "d-stack:(eval ~[[%colon name='sq'] [%word w='dup'] [%word w='*'] [%word w=';'] [%colon name='quad'] [%word w='sq'] [%word w='sq'] [%word w=';'] [%num n=3] [%word w='quad']] *north)"  "~[81]"

# STATE word: 0 in interpret, forth-true in compile
check "state interpret" "d-stack:(eval ~[[%word w='state']] *north)"  "~[$F]"

# Word with comparison: : pos?  0 > ;
check ": pos? -- 5"     "d-stack:(eval ~[[%colon name='pos?'] [%num n=0] [%word w='>'] [%word w=';'] [%num n=5] [%word w='pos?']] *north)"  "~[$T]"
check ": pos? -- 0"     "d-stack:(eval ~[[%colon name='pos?'] [%num n=0] [%word w='>'] [%word w=';'] [%num n=0] [%word w='pos?']] *north)"  "~[$F]"

echo ""
echo "=== Tier 9: Parser ==="

# parse-dec (unit @ud prints as [~ val] when non-null)
check "dec 0"      "(parse-dec \"0\")"            "[~ 0]"
check "dec 42"     "(parse-dec \"42\")"           "[~ 42]"
check "dec 255"    "(parse-dec \"255\")"          "[~ 255]"
check "dec empty"  "(parse-dec \"\")"             "~"
check "dec abc"    "(parse-dec \"abc\")"          "~"
check "dec 12a"    "(parse-dec \"12a\")"          "~"

# parse-hex
check "hex 0xff"   "(parse-hex \"0xff\")"         "[~ 255]"
check "hex 0xFF"   "(parse-hex \"0xFF\")"         "[~ 255]"
check "hex 0x10"   "(parse-hex \"0x10\")"         "[~ 16]"
check "hex empty"  "(parse-hex \"0x\")"           "~"
check "hex bad"    "(parse-hex \"abc\")"          "~"

# parse-bin
check "bin 0b1"    "(parse-bin \"0b1\")"          "[~ 1]"
check "bin 0b1010" "(parse-bin \"0b1010\")"       "[~ 10]"
check "bin 0b0"    "(parse-bin \"0b0\")"          "[~ 0]"
check "bin empty"  "(parse-bin \"0b\")"           "~"
check "bin bad"    "(parse-bin \"abc\")"          "~"

# parse-num (tries hex, bin, dec in order)
check "num dec"    "(parse-num \"99\")"           "[~ 99]"
check "num hex"    "(parse-num \"0x1F\")"         "[~ 31]"
check "num bin"    "(parse-num \"0b111\")"        "[~ 7]"
check "num bad"    "(parse-num \"xyz\")"          "~"

# strip-line-comments
check "slc none"   "(strip-line-comments \"hello world\")"       "\"hello world\""
check "slc full"   "(strip-line-comments \"\\\\ comment\")"      "\"\""
check "slc mid"    "(strip-line-comments \"hello \\\\ rest\")"   "\"hello \""

# split-ws ((list tape) prints as <<...>>)
check "split basic" "(split-ws \"a b c\")"       "<<\"a\" \"b\" \"c\">>"
check "split multi" "(split-ws \"  a  b  \")"    "<<\"a\" \"b\">>"
check "split empty" "(split-ws \"\")"            "<<>>"

# parse: text -> prog (check key structural properties)
# Simple number
check "parse num"    "(parse \"42\")"              "~[[%num n=42]]"
# Simple word (uppercased)
check "parse word"   "(parse \"dup\")"             "~[[%word w='DUP']]"
# Colon definition tokens
check "parse colon"  "(parse \": sq\")"            "~[[%colon name='SQ']]"
# Tick
check "parse tick"   "(parse \"' dup\")"           "~[[%tick w='DUP']]"
# Hex literal
check "parse hex"    "(parse \"0xff\")"            "~[[%num n=255]]"
# Binary literal
check "parse bin"    "(parse \"0b1010\")"          "~[[%num n=10]]"
# Paren comment ignored
check "parse paren"  "(parse \"( comment ) 5\")"  "~[[%num n=5]]"
# IF/THEN: zbranch offset=--1
check "parse if-then" "(parse \"5 3 > IF 99 THEN\")" \
  "~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=--1] [%num n=99]]"
# IF/ELSE/THEN: zbranch offset=--2, branch offset=--1
check "parse if-else-then" "(parse \"5 3 > IF 1 ELSE 2 THEN\")" \
  "~[ [%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=--2] [%num n=1] [%branch offset=--1] [%num n=2] ]"

# Full round-trip: parse then eval
check "parse+eval arith"  "d-stack:(eval (parse \"3 4 +\") *north)"         "~[7]"
check "parse+eval dup"    "d-stack:(eval (parse \"5 dup\") *north)"          "~[5 5]"
check "parse+eval def"    "d-stack:(eval (parse \": sq dup * ; 4 sq\") *north)"  "~[16]"
check "parse+eval if-t"   "d-stack:(eval (parse \"5 3 > IF 99 THEN\") *north)"   "~[99]"
check "parse+eval if-f"   "d-stack:(eval (parse \"3 5 > IF 99 THEN\") *north)"   "~"
check "parse+eval ifelse" "d-stack:(eval (parse \"5 3 > IF 1 ELSE 2 THEN\") *north)" "~[1]"
check "parse+eval case"   "d-stack:(eval (parse \"DUP 5\") *north)"          "~[5]"

echo ""
echo "=== Tier 10: Extended Stack ==="

check "2dup"       "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='2dup']] *north)"            "~[1 2 1 2]"
check "2drop"      "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='2drop']] *north)"           "~"
check "2swap"      "d-stack:(eval ~[[%num n=1] [%num n=2] [%num n=3] [%num n=4] [%word w='2swap']] *north)" "~[3 4 1 2]"
check "2over"      "d-stack:(eval ~[[%num n=1] [%num n=2] [%num n=3] [%num n=4] [%word w='2over']] *north)" "~[1 2 3 4 1 2]"
check "nip"        "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='nip']] *north)"             "~[2]"
check "tuck"       "d-stack:(eval ~[[%num n=1] [%num n=2] [%word w='tuck']] *north)"            "~[2 1 2]"
check "?dup 0"     "d-stack:(eval ~[[%num n=0] [%word w='?dup']] *north)"                       "~[0]"
check "?dup nonz"  "d-stack:(eval ~[[%num n=5] [%word w='?dup']] *north)"                       "~[5 5]"
check "pick 0"     "d-stack:(eval ~[[%num n=10] [%num n=20] [%num n=30] [%num n=0] [%word w='pick']] *north)" "~[10 20 30 30]"
check "pick 2"     "d-stack:(eval ~[[%num n=10] [%num n=20] [%num n=30] [%num n=2] [%word w='pick']] *north)" "~[10 20 30 10]"
check "roll 0"     "d-stack:(eval ~[[%num n=1] [%num n=2] [%num n=3] [%num n=0] [%word w='roll']] *north)" "~[1 2 3]"
check "roll 2"     "d-stack:(eval ~[[%num n=1] [%num n=2] [%num n=3] [%num n=2] [%word w='roll']] *north)" "~[2 3 1]"

echo ""
echo "=== Tier 10: Arithmetic ==="

check "negate"     "d-stack:(eval ~[[%num n=4] [%word w='negate']] *north)"                     "~[3]"
check "negate neg" "d-stack:(eval ~[[%num n=3] [%word w='negate']] *north)"                     "~[4]"
check "neg+neg"    "d-stack:(eval ~[[%num n=7] [%word w='negate'] [%word w='negate']] *north)"  "~[7]"
check "abs pos"    "d-stack:(eval ~[[%num n=4] [%word w='abs']] *north)"                        "~[4]"
check "abs neg"    "d-stack:(eval ~[[%num n=3] [%word w='abs']] *north)"                        "~[4]"
check "abs zero"   "d-stack:(eval ~[[%num n=0] [%word w='abs']] *north)"                        "~[0]"
check "min"        "d-stack:(eval ~[[%num n=3] [%num n=7] [%word w='min']] *north)"             "~[3]"
check "max"        "d-stack:(eval ~[[%num n=3] [%num n=7] [%word w='max']] *north)"             "~[7]"
check "2*"         "d-stack:(eval ~[[%num n=5] [%word w='2*']] *north)"                         "~[10]"
check "2/"         "d-stack:(eval ~[[%num n=10] [%word w='2/']] *north)"                        "~[5]"
check "lshift"     "d-stack:(eval ~[[%num n=1] [%num n=3] [%word w='lshift']] *north)"          "~[8]"
check "rshift"     "d-stack:(eval ~[[%num n=8] [%num n=3] [%word w='rshift']] *north)"          "~[1]"

echo ""
echo "=== Tier 10: Comparison and Logical ==="

# 0< tests: odd atoms are ZigZag-negative
check "0< neg"     "d-stack:(eval ~[[%num n=3] [%word w='0<']] *north)"                         "~[$T]"
check "0< pos"     "d-stack:(eval ~[[%num n=4] [%word w='0<']] *north)"                         "~[$F]"
check "0< zero"    "d-stack:(eval ~[[%num n=0] [%word w='0<']] *north)"                         "~[$F]"
# 0> tests: even nonzero atoms are ZigZag-positive
check "0> pos"     "d-stack:(eval ~[[%num n=4] [%word w='0>']] *north)"                         "~[$T]"
check "0> neg"     "d-stack:(eval ~[[%num n=3] [%word w='0>']] *north)"                         "~[$F]"
check "0> zero"    "d-stack:(eval ~[[%num n=0] [%word w='0>']] *north)"                         "~[$F]"
check "<> true"    "d-stack:(eval ~[[%num n=3] [%num n=5] [%word w='<>']] *north)"              "~[$T]"
check "<> false"   "d-stack:(eval ~[[%num n=5] [%num n=5] [%word w='<>']] *north)"              "~[$F]"
check "not true"   "d-stack:(eval ~[[%num n=0] [%word w='not']] *north)"                        "~[$T]"
check "not false"  "d-stack:(eval ~[[%num n=1] [%word w='not']] *north)"                        "~[$F]"
check "true"       "d-stack:(eval ~[[%word w='true']] *north)"                                  "~[$T]"
check "false"      "d-stack:(eval ~[[%word w='false']] *north)"                                 "~[$F]"
check "u< true"    "d-stack:(eval ~[[%num n=3] [%num n=7] [%word w='u<']] *north)"              "~[$T]"
check "u< false"   "d-stack:(eval ~[[%num n=7] [%num n=3] [%word w='u<']] *north)"              "~[$F]"
check "u> true"    "d-stack:(eval ~[[%num n=7] [%num n=3] [%word w='u>']] *north)"              "~[$T]"
check "u> false"   "d-stack:(eval ~[[%num n=3] [%num n=7] [%word w='u>']] *north)"              "~[$F]"

echo ""
echo "=== Tier 10: Output Buffer ==="

check "emit char"  "output.buffers:(eval ~[[%num n=65] [%word w='emit']] *north)"               "\"A\""
check "space buf"  "output.buffers:(eval ~[[%word w='space']] *north)"                          "\" \""
check "spaces buf" "(lent output.buffers:(eval ~[[%num n=3] [%word w='spaces']] *north))"          "3"
check "emit+space" "output.buffers:(eval ~[[%num n=65] [%word w='emit'] [%word w='space'] [%num n=66] [%word w='emit']] *north)" "\"A B\""

echo ""
echo "=== Tier 10: Parse Round-trips ==="

check "parse 2dup"      "d-stack:(eval (parse \"5 6 2dup\") *north)"                            "~[5 6 5 6]"
check "parse negate"    "d-stack:(eval (parse \"4 negate negate\") *north)"                     "~[4]"
check "parse min/max"   "d-stack:(eval (parse \"3 7 min 3 7 max\") *north)"                     "~[3 7]"
check "parse lshift"    "d-stack:(eval (parse \"1 4 lshift\") *north)"                          "~[16]"
check "parse true/false" "d-stack:(eval (parse \"true false\") *north)"                         "~[$T $F]"

echo ""
echo "=== Tier 9: Loop Tokenization ==="

# BEGIN/AGAIN: unconditional backward branch
# ix-begin=0, ix-again=1; off=dif:si(sun:si 0)(sun:si 2)=0-2=-2 → atom 3
check "parse begin/again tok" "(parse \"BEGIN 1 AGAIN\")" \
  "~[[%num n=1] [%branch offset=-2]]"

# BEGIN/UNTIL: conditional backward branch (exit when flag≠0)
# Same offsets as AGAIN; zbranch instead of branch
check "parse begin/until tok" "(parse \"BEGIN 1 UNTIL\")" \
  "~[[%num n=1] [%zbranch offset=-2]]"

# BEGIN/WHILE/REPEAT: exit zbranch + backward branch
# ix-begin=0, ix-while=1, ix-rep=3
# off-back = dif:si(sun:si 0)(sun:si 4) = 0-4 = -4 → atom 7
# off-exit = sun:si(sub(lent out2=4, inc ix-while=2)) = sun:si(2) = 4 → --2
check "parse begin/while/repeat tok" "(parse \"BEGIN 1 WHILE 2 REPEAT\")" \
  "~[[%num n=1] [%zbranch offset=--2] [%num n=2] [%branch offset=-4]]"

# Countdown: 3 BEGIN 1- DUP 0= UNTIL
# ix-begin=1, ix-until=4; off=dif:si(sun:si 1)(sun:si 5)=+1-+5=-4 → atom 7
check "parse countdown/until tok" "(parse \"3 BEGIN 1- DUP 0= UNTIL\")" \
  "~[[%num n=3] [%word w='1-'] [%word w='DUP'] [%word w='0='] [%zbranch offset=-4]]"

# Countdown: 3 BEGIN DUP WHILE 1- REPEAT
# ix-begin=1, ix-while=2, ix-rep=4
# off-back = dif:si(sun:si 1)(sun:si 5) = -4 → atom 7
# off-exit = sun:si(sub(5,3)) = sun:si(2) = 4 → --2
check "parse countdown/while tok" "(parse \"3 BEGIN DUP WHILE 1- REPEAT\")" \
  "~[ [%num n=3] [%word w='DUP'] [%zbranch offset=--2] [%word w='1-'] [%branch offset=-4] ]"

echo ""
echo "=== Tier 9: Loop Round-trips ==="

# BEGIN/UNTIL: UNTIL pops the flag; 5 BEGIN DUP UNTIL → DUP gives flag=5 (nonzero),
# UNTIL exits, leaving ~[5] (the original 5 under the popped DUP copy)
check "parse+eval begin/until exit" \
  "d-stack:(eval (parse \"5 BEGIN DUP UNTIL\") *north)" \
  "~[5]"

# Countdown via UNTIL: 3 → 2 → 1 → 0; DUP 0= consumed by UNTIL each iter
# Final stack: ~[0]
check "parse+eval countdown/until" \
  "d-stack:(eval (parse \"3 BEGIN 1- DUP 0= UNTIL\") *north)" \
  "~[0]"

# Countdown via WHILE/REPEAT: DUP provides flag, WHILE pops it, 1- decrements
# Final stack: ~[0]
check "parse+eval countdown/while" \
  "d-stack:(eval (parse \"3 BEGIN DUP WHILE 1- REPEAT\") *north)" \
  "~[0]"

echo ""
echo "=== Tier 9: Additional Coverage ==="

# Multiple definitions in one source string
check "parse+eval multi-def" \
  "d-stack:(eval (parse \": sq dup * ; : double 2 * ; 3 sq double\") *north)" \
  "~[18]"

# Nested word definitions (word calling word)
check "parse+eval nested-def" \
  "d-stack:(eval (parse \": sq dup * ; : quad sq sq ; 3 quad\") *north)" \
  "~[81]"

# Case-folding: mixed-case control words
check "parse+eval case-fold-ctrl" \
  "d-stack:(eval (parse \"5 3 > iF 99 tHen\") *north)" \
  "~[99]"

# Return stack via text
check "parse+eval >r r-stack" \
  "r-stack:(eval (parse \"42 >r\") *north)" \
  "~[42]"
check "parse+eval >r r>" \
  "d-stack:(eval (parse \"42 >r r>\") *north)" \
  "~[42]"
check "parse+eval r@" \
  "d-stack:(eval (parse \"7 >r r@\") *north)" \
  "~[7]"

# Memory ops via text
check "parse+eval allot+store+fetch" \
  "d-stack:(eval (parse \"3 allot 99 1 ! 1 @\") *north)" \
  "~[99]"

# Tick and EXECUTE via text
check "parse+eval tick execute" \
  "d-stack:(eval (parse \"5 ' dup execute\") *north)" \
  "~[5 5]"

# Hex and binary through full eval
check "parse+eval hex+bin eval" \
  "d-stack:(eval (parse \"0xff 0b1010 +\") *north)" \
  "~[265]"

# Paren comment through full eval
check "parse+eval paren-comment eval" \
  "d-stack:(eval (parse \"( setup ) 3 4 +\") *north)" \
  "~[7]"

# Line comment through eval (backslash: Hoon tape uses \\ for literal \)
check "parse+eval line-comment eval" \
  "d-stack:(eval (parse \"5 \\\\ ignore this\") *north)" \
  "~[5]"

echo ""
echo "=== Tier 11: DO/LOOP Tokenization ==="

# 5 0 DO I LOOP → [num 5][num 0][do][word I][loop offset=-2]
# ix-do=2, ix-loop=4; off=dif:si(sun:si 3)(sun:si 5)=dif:si 6 10=-2 → atom 3
check "parse do/loop tok" "(parse \"5 0 DO I LOOP\")" \
  "~[[%num n=5] [%num n=0] [%do ~] [%word w='I'] [%loop offset=-2]]"

# 5 0 DO I 2 +LOOP → [num 5][num 0][do][word I][num 2][ploop offset=-3]
# ix-do=2, ix-loop=5; off=dif:si(sun:si 3)(sun:si 6)=dif:si 6 12=-3 → atom 5
check "parse do/+loop tok" "(parse \"5 0 DO I 2 +LOOP\")" \
  "~[[%num n=5] [%num n=0] [%do ~] [%word w='I'] [%num n=2] [%ploop offset=-3]]"

echo ""
echo "=== Tier 11: DO/LOOP Round-trips ==="

# Basic DO/LOOP: 5 0 DO I LOOP → pushes 0..4
check "do/loop 0-4"     "d-stack:(eval (parse \"5 0 DO I LOOP\") *north)"          "~[0 1 2 3 4]"

# +LOOP stepping by 2: 10 0 DO I 2 +LOOP → pushes 0,2,4,6,8
check "do/+loop step2"  "d-stack:(eval (parse \"10 0 DO I 2 +LOOP\") *north)"      "~[0 2 4 6 8]"

# DO/LOOP with word definition: : sum5  0 5 0 DO + LOOP ;  5 dup dup dup dup sum5
check "do/loop in word"   "d-stack:(eval (parse \": count5  5 0 DO I LOOP ; count5\") *north)" "~[0 1 2 3 4]"

# Nested DO loops: I = inner index, J = outer index
# 2 0 DO 2 0 DO I J + LOOP LOOP → [0+0 1+0 0+1 1+1] = [0 1 1 2]
check "nested do I J"   "d-stack:(eval (parse \"2 0 DO 2 0 DO I J + LOOP LOOP\") *north)"  "~[0 1 1 2]"

# LEAVE: exit loop early when I=2
# 5 0 DO I DUP 2 = IF LEAVE THEN LOOP → pushes 0,1,2
check "leave"           "d-stack:(eval (parse \"5 0 DO I DUP 2 = IF LEAVE THEN LOOP\") *north)" "~[0 1 2]"

# DO/LOOP with accumulation: sum 1..5 using loop and +
# 0 6 1 DO I + LOOP → 0+1+2+3+4+5 = 15
check "do/loop sum"     "d-stack:(eval (parse \"0 6 1 DO I + LOOP\") *north)"       "~[15]"

# DO/LOOP body that uses data stack (push limit-I each iter)
# 4 0 DO 4 I - LOOP → 4-0=4, 4-1=3, 4-2=2, 4-3=1
check "do/loop 4-I"     "d-stack:(eval (parse \"4 0 DO 4 I - LOOP\") *north)"       "~[4 3 2 1]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
