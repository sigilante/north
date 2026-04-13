#!/usr/bin/env bash
# Long-running Nock benchmark tests (urbit/benchmark reference cases).
# Each test spawns a full urbit eval + nock.fs load, so runtime is O(minutes).
# Run via:  make test-long    (not included in default CI)
# Run from repo root: bash tests/test-nock-long.sh

LIB="desk/lib/north.hoon"
NOCK="tests/nock.fs"
PASS=0
FAIL=0

NOCK_SRC=$(sed 's/[[:space:]]*\\[[:space:]].*$//; s/^[[:space:]]*\\[[:space:]].*$//' "$NOCK" \
           | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//; s/ *$//')

nock-eval() {
  local test_expr="$1"
  local raw
  raw=$( (printf '=>\n'; cat "$LIB"; printf 'd-stack:(eval (parse "%s %s") *north)\n' "$NOCK_SRC" "$test_expr") \
         | ~/bin/urbit eval 2>&1 )
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
  result=$(nock-eval "$expr")
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

# DEC_FORMULA: standard Nock decrement.
# Subject slots after two nock-8 pushes: slot2=battery, slot6=counter, slot7=n.
# Condition [5 [0 7] [4 [0 6]]]: terminate when n == counter+1, return counter = n-1.
DEC='[ 8 [ 1 0 ] [ 8 [ 1 [ 6 [ 5 [ 0 7 ] [ 4 [ 0 6 ] ] ] [ 0 6 ] [ 9 2 [ 0 2 ] [ 4 [ 0 6 ] ] 0 7 ] ] ] [ 9 2 0 1 ] ] ]'

echo "=== urbit/benchmark: decrement ==="
check "dec 1"   "[ 1 $DEC ] nock get-value"   "~[0]"
check "dec 2"   "[ 2 $DEC ] nock get-value"   "~[1]"
check "dec 10"  "[ 10 $DEC ] nock get-value"  "~[9]"
check "dec 42"  "[ 42 $DEC ] nock get-value"  "~[41]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
