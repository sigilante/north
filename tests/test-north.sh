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

check "dup"        "(eval ~[[%num n=5] [%word w='dup']] ~)"              "~[5 5]"
check "drop"       "(eval ~[[%num n=5] [%num n=3] [%word w='drop']] ~)" "~[5]"
check "swap"       "(eval ~[[%num n=1] [%num n=2] [%word w='swap']] ~)" "~[2 1]"
check "over"       "(eval ~[[%num n=1] [%num n=2] [%word w='over']] ~)" "~[1 2 1]"
check "rot"        "(eval ~[[%num n=1] [%num n=2] [%num n=3] [%word w='rot']] ~)" "~[2 3 1]"
check "depth-0"    "(eval ~[[%word w='depth']] ~)"                      "~[0]"
check "depth-2"    "(eval ~[[%num n=1] [%num n=2] [%word w='depth']] ~)" "~[1 2 2]"

echo ""
echo "=== Tier 1: Unsigned Arithmetic ==="

check "add"        "(eval ~[[%num n=3] [%num n=4] [%word w='+']] ~)"   "~[7]"
check "sub"        "(eval ~[[%num n=10] [%num n=3] [%word w='-']] ~)"  "~[7]"
check "mul"        "(eval ~[[%num n=25] [%num n=10] [%word w='*']] ~)" "~[250]"
check "div"        "(eval ~[[%num n=10] [%num n=2] [%word w='/']] ~)"  "~[5]"
check "mod"        "(eval ~[[%num n=10] [%num n=3] [%word w='mod']] ~)" "~[1]"
check "/mod"       "(eval ~[[%num n=10] [%num n=3] [%word w='/mod']] ~)" "~[1 3]"
check "1+"         "(eval ~[[%num n=4] [%word w='1+']] ~)"             "~[5]"
check "1-"         "(eval ~[[%num n=4] [%word w='1-']] ~)"             "~[3]"
check "compound"   "(eval ~[[%num n=25] [%num n=10] [%word w='*'] [%num n=50] [%word w='+']] ~)" "~[300]"
check "dup-mul"    "(eval ~[[%num n=3] [%word w='dup'] [%word w='*']] ~)" "~[9]"

echo ""
echo "=== Tier 1: Comparisons ==="

check "= true"     "(eval ~[[%num n=3] [%num n=3] [%word w='=']] ~)"   "~[$T]"
check "= false"    "(eval ~[[%num n=3] [%num n=4] [%word w='=']] ~)"   "~[$F]"
check "< true"     "(eval ~[[%num n=2] [%num n=5] [%word w='<']] ~)"   "~[$T]"
check "< false"    "(eval ~[[%num n=5] [%num n=2] [%word w='<']] ~)"   "~[$F]"
check "> true"     "(eval ~[[%num n=5] [%num n=2] [%word w='>']] ~)"   "~[$T]"
check "> false"    "(eval ~[[%num n=2] [%num n=5] [%word w='>']] ~)"   "~[$F]"
check "0= zero"    "(eval ~[[%num n=0] [%word w='0=']] ~)"              "~[$T]"
check "0= nonzero" "(eval ~[[%num n=1] [%word w='0=']] ~)"              "~[$F]"

echo ""
echo "=== Tier 3: Bitwise ==="

check "and"        "(eval ~[[%num n=12] [%num n=10] [%word w='and']] ~)"    "~[8]"
check "or"         "(eval ~[[%num n=12] [%num n=10] [%word w='or']] ~)"     "~[14]"
check "xor"        "(eval ~[[%num n=15] [%num n=10] [%word w='xor']] ~)"    "~[5]"
check "invert-0"   "(eval ~[[%num n=0] [%word w='invert']] ~)"              "~[$T]"
check "invert-T"   "(eval ~[[%num n=$T] [%word w='invert']] ~)"             "~[$F]"

echo ""
echo "=== Branching (IF/ELSE/THEN) ==="

# 5 3 > IF 99 THEN  →  true path: zbranch skips 0, pushes 99
check "if-true"    "(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=1] [%num n=99]] ~)" "~[99]"
# 3 5 > IF 99 THEN  →  false path: zbranch skips 1 token
check "if-false"   "(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=1] [%num n=99]] ~)" "~"
# 5 3 > IF 1 ELSE 2 THEN  →  true path: push 1, branch over else
check "if-else-true"  "(eval ~[[%num n=5] [%num n=3] [%word w='>'] [%zbranch offset=2] [%num n=1] [%branch offset=1] [%num n=2]] ~)" "~[1]"
# 3 5 > IF 1 ELSE 2 THEN  →  false path: zbranch skips to else, push 2
check "if-else-false" "(eval ~[[%num n=3] [%num n=5] [%word w='>'] [%zbranch offset=2] [%num n=1] [%branch offset=1] [%num n=2]] ~)" "~[2]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
