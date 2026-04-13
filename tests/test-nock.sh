#!/usr/bin/env bash
# Nock interpreter tests — loads nock.fs into a north state, then runs tests
# Run from repo root: bash tests/test-nock.sh
#
# Noun literals use the [ ] syntax supported by north's parser.
# Option B future: define a Forth parsing word in nock.fs for noun literals.

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
echo "=== Noun literal syntax [ ] ==="

check "atom literal"      "[ 42 ] get-value"                   "~[42]"
check "cell literal"      "[ 42 99 ] is-cell?"                 "~[1]"
check "cell head"         "[ 42 99 ] get-head get-value"       "~[42]"
check "cell tail"         "[ 42 99 ] get-tail get-value"       "~[99]"
check "nested [ 1 [2 3]]" "[ 1 [ 2 3 ] ] get-tail is-cell?"   "~[1]"

echo ""
echo "=== Nock wut ? ==="

check "wut atom"  "[ 5 ] wut"                 "~[1]"
check "wut cell"  "[ 1 2 ] wut"               "~[0]"

echo ""
echo "=== Nock lus + ==="

check "lus 0"    "[ 0 ] lus get-value"   "~[1]"
check "lus 41"   "[ 41 ] lus get-value"  "~[42]"
check "lus 255"  "[ 255 ] lus get-value" "~[256]"

echo ""
echo "=== Nock tis = ==="

check "tis equal atoms"   "[ 42 ] [ 42 ] tis get-value"  "~[0]"
check "tis unequal atoms" "[ 1 ] [ 2 ] tis get-value"    "~[1]"

echo ""
echo "=== Nock slot / ==="

check "slot 1 is-cell"  "[ 1 ] [ 42 99 ] slot is-cell?"           "~[1]"
check "slot 2"          "[ 2 ] [ 42 99 ] slot get-value"           "~[42]"
check "slot 3"          "[ 3 ] [ 42 99 ] slot get-value"           "~[99]"
check "slot 4 deep"     "[ 4 ] [ [ 1 2 ] [ 3 4 ] ] slot get-value" "~[1]"
check "slot 5 deep"     "[ 5 ] [ [ 1 2 ] [ 3 4 ] ] slot get-value" "~[2]"

echo ""
echo "=== Nock tar * ==="

check "nock-1 constant"   "[ 42 [ 1 99 ] ] nock get-value"          "~[99]"
check "nock-0 slot1"      "[ 42 [ 0 1 ] ] nock get-value"           "~[42]"
check "nock-4 increment"  "[ 42 [ 4 [ 0 1 ] ] ] nock get-value"     "~[43]"
check "nock-3 wut atom"   "[ 42 [ 3 [ 0 1 ] ] ] nock get-value"     "~[1]"
check "nock-3 wut cell"   "[ [ 42 99 ] [ 3 [ 0 1 ] ] ] nock get-value" "~[0]"
check "nock-5 tis"        "[ 0 [ 5 [ [ 0 1 ] [ 1 0 ] ] ] ] nock get-value" "~[0]"

echo ""
echo "=== Nock eval (2) ==="

# *[42 [2 [0 1] [1 [4 [0 1]]]]] = *[42 [4 [0 1]]] = 43
check "nock-2 eval"  \
  "[ 42 [ 2 [ 0 1 ] [ 1 [ 4 [ 0 1 ] ] ] ] ] nock get-value"  \
  "~[43]"

echo ""
echo "=== Nock if-then-else (6) ==="

# *[42 [6 [1 0] [4 [0 1]] [1 99]]] = 43  (condition=0=yes → true branch: +42)
check "nock-6 true branch"  \
  "[ 42 [ 6 [ 1 0 ] [ 4 [ 0 1 ] ] [ 1 99 ] ] ] nock get-value"  \
  "~[43]"

# *[42 [6 [1 1] [4 [0 1]] [1 99]]] = 99  (condition=1=no → false branch)
check "nock-6 false branch"  \
  "[ 42 [ 6 [ 1 1 ] [ 4 [ 0 1 ] ] [ 1 99 ] ] ] nock get-value"  \
  "~[99]"

echo ""
echo "=== Nock compose (7) ==="

# *[42 [7 [4 [0 1]] [4 [0 1]]]] = 44
check "nock-7 compose"  \
  "[ 42 [ 7 [ 4 [ 0 1 ] ] [ 4 [ 0 1 ] ] ] ] nock get-value"  \
  "~[44]"

echo ""
echo "=== Nock push (8) ==="

# *[42 [8 [4 [0 1]] [0 2]]] = 43
check "nock-8 push"  \
  "[ 42 [ 8 [ 4 [ 0 1 ] ] [ 0 2 ] ] ] nock get-value"  \
  "~[43]"

echo ""
echo "=== Nock invoke (9) ==="

# *[0 [9 2 [1 [[4 [0 3]] 42]]]]  arm [4 [0 3]] increments slot-3 (42) → 43
check "nock-9 invoke"  \
  "[ 0 [ 9 2 [ 1 [ [ 4 [ 0 3 ] ] 42 ] ] ] ] nock get-value"  \
  "~[43]"

echo ""
echo "=== urbit/benchmark: decrement ==="
# Standard Nock decrement: *[n [8 [1 0] [8 [1 6 [5 [0 6] 4 0 6] [0 6] 9 2 [0 2] [4 0 6] 0 7] 9 2 0 1]]]
# Decrement 1 → 0
check "dec 1"   "[ 1 [ 8 [ 1 0 ] [ 8 [ 1 6 [ 5 [ 0 6 ] 4 0 6 ] [ 0 6 ] 9 2 [ 0 2 ] [ 4 0 6 ] 0 7 ] 9 2 0 1 ] ] ] nock get-value"  "~[0]"
# Decrement 42 → 41
check "dec 42"  "[ 42 [ 8 [ 1 0 ] [ 8 [ 1 6 [ 5 [ 0 6 ] 4 0 6 ] [ 0 6 ] 9 2 [ 0 2 ] [ 4 0 6 ] 0 7 ] 9 2 0 1 ] ] ] nock get-value" "~[41]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
