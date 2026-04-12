#!/usr/bin/env bash
# Nock interpreter tests — loads nock.fs into a north state, then runs tests
# Run from repo root: bash tests/test-nock.sh

LIB="desk/lib/north.hoon"
NOCK="tests/nock.fs"
PASS=0
FAIL=0

# Strip \ line-comments from nock.fs and join to a single space-separated line.
# Forth \ comments run from "\ " to end of line.
# We must remove them before embedding in a Hoon tape literal (which treats \ as escape).
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

echo "=== Nock noun construction ==="

check "make-atom 42"   "42 make-atom get-value"                          "~[42]"
check "make-atom 0"    "0 make-atom get-value"                           "~[0]"
check "is-cell? atom"  "5 make-atom is-cell?"                            "~[0]"
check "make-cell"      "1 make-atom 2 make-atom make-cell is-cell?"      "~[1]"
check "get-head"       "1 make-atom 2 make-atom make-cell get-head get-value"  "~[1]"
check "get-tail"       "1 make-atom 2 make-atom make-cell get-tail get-value"  "~[2]"

echo ""
echo "=== Nock wut ? ==="

check "wut atom"  "5 make-atom wut"                                       "~[1]"
check "wut cell"  "1 make-atom 2 make-atom make-cell wut"                 "~[0]"

echo ""
echo "=== Nock lus + ==="

check "lus 0"    "0 make-atom lus get-value"                              "~[1]"
check "lus 41"   "41 make-atom lus get-value"                             "~[42]"
check "lus 255"  "255 make-atom lus get-value"                            "~[256]"

echo ""
echo "=== Nock tis = ==="

check "tis equal atoms"   "42 make-atom 42 make-atom tis get-value"        "~[0]"
check "tis unequal atoms" "1 make-atom 2 make-atom tis get-value"          "~[1]"

echo ""
echo "=== Nock slot / ==="

# /[1 [42 99]] = whole noun (a cell)
check "slot 1 is-cell"  \
  "1 make-atom  42 make-atom 99 make-atom make-cell  slot  is-cell?"  "~[1]"
# /[2 [42 99]] = 42
check "slot 2"  \
  "2 make-atom  42 make-atom 99 make-atom make-cell  slot  get-value"  "~[42]"
# /[3 [42 99]] = 99
check "slot 3"  \
  "3 make-atom  42 make-atom 99 make-atom make-cell  slot  get-value"  "~[99]"
# /[4 [[1 2] [3 4]]] = 1
check "slot 4 deep"  \
  "4 make-atom  1 make-atom 2 make-atom make-cell  3 make-atom 4 make-atom make-cell  make-cell  slot  get-value"  "~[1]"
# /[5 [[1 2] [3 4]]] = 2
check "slot 5 deep"  \
  "5 make-atom  1 make-atom 2 make-atom make-cell  3 make-atom 4 make-atom make-cell  make-cell  slot  get-value"  "~[2]"

echo ""
echo "=== Nock tar * ==="

# *[42 [1 99]] = 99  (nock-1: constant)
check "nock-1 constant"  \
  "42 make-atom  1 make-atom 99 make-atom make-cell  make-cell  nock  get-value"  \
  "~[99]"

# *[42 [0 1]] = 42  (nock-0: slot 1 = whole subject)
check "nock-0 slot1"  \
  "42 make-atom  0 make-atom 1 make-atom make-cell  make-cell  nock  get-value"  \
  "~[42]"

# *[42 [4 [0 1]]] = 43  (nock-4: increment *[a [0 1]])
check "nock-4 increment"  \
  "42 make-atom  4 make-atom  0 make-atom 1 make-atom make-cell  make-cell  make-cell  nock  get-value"  \
  "~[43]"

# *[42 [3 [0 1]]] = 1  (nock-3: wut of atom = 1)
check "nock-3 wut atom"  \
  "42 make-atom  3 make-atom  0 make-atom 1 make-atom make-cell  make-cell  make-cell  nock  get-value"  \
  "~[1]"

# *[[42 99] [3 [0 1]]] = 0  (nock-3: wut of cell = 0)
check "nock-3 wut cell"  \
  "42 make-atom 99 make-atom make-cell  3 make-atom  0 make-atom 1 make-atom make-cell  make-cell  make-cell  nock  get-value"  \
  "~[0]"

# *[0 [5 [[0 1] [1 0]]]]  (nock-5: equality test 0 = 0 -> 0 = equal)
check "nock-5 tis"  \
  "0 make-atom  5 make-atom  0 make-atom 1 make-atom make-cell  1 make-atom 0 make-atom make-cell  make-cell  make-cell  make-cell  nock  get-value"  \
  "~[0]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
