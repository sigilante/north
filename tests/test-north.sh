#!/usr/bin/env bash
# North unit tests — shell-based, uses urbit eval
# Run from repo root: bash tests/test-north.sh
# Later: convert to in-Urbit threads

LIB="desk/lib/north.hoon"
PASS=0
FAIL=0

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

check "dup"        "(eval ~[[%num n=5] [%word w='dup']] ~)"            "~[5 5]"
check "drop"       "(eval ~[[%num n=5] [%num n=3] [%word w='drop']] ~)" "~[5]"
check "swap"       "(eval ~[[%num n=1] [%num n=2] [%word w='swap']] ~)" "~[2 1]"
check "over"       "(eval ~[[%num n=1] [%num n=2] [%word w='over']] ~)" "~[1 2 1]"
check "depth-0"    "(eval ~[[%word w='depth']] ~)"                     "~[0]"
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

check "= true"     "(eval ~[[%num n=3] [%num n=3] [%word w='=']] ~)"   "~[0]"
check "= false"    "(eval ~[[%num n=3] [%num n=4] [%word w='=']] ~)"   "~[1]"
check "< true"     "(eval ~[[%num n=2] [%num n=5] [%word w='<']] ~)"   "~[0]"
check "< false"    "(eval ~[[%num n=5] [%num n=2] [%word w='<']] ~)"   "~[1]"
check "> true"     "(eval ~[[%num n=5] [%num n=2] [%word w='>']] ~)"   "~[0]"
check "> false"    "(eval ~[[%num n=2] [%num n=5] [%word w='>']] ~)"   "~[1]"
check "0= zero"    "(eval ~[[%num n=0] [%word w='0=']] ~)"              "~[0]"
check "0= nonzero" "(eval ~[[%num n=1] [%word w='0=']] ~)"              "~[1]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
