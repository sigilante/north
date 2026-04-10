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
  (echo "=>"; cat "$LIB"; echo "$1") | ~/bin/urbit eval 2>&1 | tail -1
}

check() {
  local desc="$1"
  local expr="$2"
  local expected="$3"
  local result
  result=$(north-eval "$expr")
  # strip ANSI color codes and carriage returns
  result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r')
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
check "if-true"    "d-stack:(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=1] [%num n=99]] *north)" "~[99]"
# 3 5 > IF 99 THEN  →  false path: zbranch skips 1 token
check "if-false"   "d-stack:(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=1] [%num n=99]] *north)" "~"
# 5 3 > IF 1 ELSE 2 THEN  →  true path: push 1, branch over else
check "if-else-true"  "d-stack:(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=2] [%num n=1] [%branch offset=1] [%num n=2]] *north)" "~[1]"
# 3 5 > IF 1 ELSE 2 THEN  →  false path: zbranch skips to else, push 2
check "if-else-false" "d-stack:(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=2] [%num n=1] [%branch offset=1] [%num n=2]] *north)" "~[2]"

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
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
