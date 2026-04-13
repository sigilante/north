#!/usr/bin/env bash
# North Forth example program tests
# Tests fibonacci, ackermann, sieve, charclass, and wordcount.
# Run from repo root: bash tests/test-examples.sh
#
# Each test loads the relevant .fs source into a fresh north state,
# evaluates a test expression, and checks the resulting d-stack.
#
# Boolean results are normalised with "1 AND" so tests expect ~[1] or ~[0]
# rather than the internal forth-true value (0x7fff_ffff_ffff_ffff).

LIB="desk/lib/north.hoon"
PASS=0
FAIL=0

# Strip Forth \ comments and collapse whitespace to a single line.
# Handles both "\ comment" and bare "\" (blank comment lines).
load-fs() {
  sed 's/[[:space:]]*\\[[:space:]].*$//; s/^[[:space:]]*\\[[:space:]].*$//; s/^[[:space:]]*\\$//' "$1" \
      | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//; s/ *$//'
}

north-eval() {
  local src="$1" expr="$2"
  local raw
  raw=$( (printf '=>\n'; cat "$LIB"; \
          printf 'd-stack:(eval (parse "%s %s") *north)\n' "$src" "$expr") \
         | ~/bin/urbit eval 2>&1 )
  echo "$raw" \
    | grep -v '^lite:\|^loom:\|^eval (run):\|^eval:' \
    | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' \
    | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//; s/ *$//'
}

check() {
  local desc="$1" src="$2" expr="$3" expected="$4"
  local result
  result=$(north-eval "$src" "$expr")
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

FIB=$(load-fs "examples/fibonacci.fs")
ACK=$(load-fs "examples/ackermann.fs")
SIV=$(load-fs "examples/sieve.fs")
CLS=$(load-fs "examples/charclass.fs")
WC=$(load-fs  "examples/wordcount.fs")

# ── Fibonacci ──────────────────────────────────────────────────────────────
echo "=== Fibonacci ==="
check "fib(0)"  "$FIB" "0 fib"  "~[0]"
check "fib(1)"  "$FIB" "1 fib"  "~[1]"
check "fib(2)"  "$FIB" "2 fib"  "~[1]"
check "fib(5)"  "$FIB" "5 fib"  "~[5]"
check "fib(10)" "$FIB" "10 fib" "~[55]"

# ── Ackermann ──────────────────────────────────────────────────────────────
echo ""
echo "=== Ackermann ==="
check "ack(0,0)" "$ACK" "0 0 ack" "~[1]"
check "ack(0,5)" "$ACK" "0 5 ack" "~[6]"
check "ack(1,0)" "$ACK" "1 0 ack" "~[2]"
check "ack(1,1)" "$ACK" "1 1 ack" "~[3]"
check "ack(2,0)" "$ACK" "2 0 ack" "~[3]"
check "ack(2,2)" "$ACK" "2 2 ack" "~[7]"
check "ack(3,2)" "$ACK" "3 2 ack" "~[29]"

# ── Sieve of Eratosthenes ──────────────────────────────────────────────────
echo ""
echo "=== Sieve of Eratosthenes ==="
check "sieve: 0 not prime"   "$SIV" "sieve-run 0 is-prime? 1 AND" "~[0]"
check "sieve: 1 not prime"   "$SIV" "sieve-run 1 is-prime? 1 AND" "~[0]"
check "sieve: 2 is prime"    "$SIV" "sieve-run 2 is-prime? 1 AND" "~[1]"
check "sieve: 3 is prime"    "$SIV" "sieve-run 3 is-prime? 1 AND" "~[1]"
check "sieve: 4 composite"   "$SIV" "sieve-run 4 is-prime? 1 AND" "~[0]"
check "sieve: 97 is prime"   "$SIV" "sieve-run 97 is-prime? 1 AND" "~[1]"
check "sieve: 99 composite"  "$SIV" "sieve-run 99 is-prime? 1 AND" "~[0]"

# ── Character Classification ───────────────────────────────────────────────
echo ""
echo "=== Character Classification ==="
check "isdigit '5' (53)"  "$CLS" "53 isdigit  1 AND" "~[1]"
check "isdigit 'a' (97)"  "$CLS" "97 isdigit  1 AND" "~[0]"
check "isdigit ' ' (32)"  "$CLS" "32 isdigit  1 AND" "~[0]"
check "isupper 'A' (65)"  "$CLS" "65 isupper  1 AND" "~[1]"
check "isupper 'a' (97)"  "$CLS" "97 isupper  1 AND" "~[0]"
check "islower 'a' (97)"  "$CLS" "97 islower  1 AND" "~[1]"
check "islower 'Z' (90)"  "$CLS" "90 islower  1 AND" "~[0]"
check "isalpha 'a' (97)"  "$CLS" "97 isalpha  1 AND" "~[1]"
check "isalpha 'Z' (90)"  "$CLS" "90 isalpha  1 AND" "~[1]"
check "isalpha '5' (53)"  "$CLS" "53 isalpha  1 AND" "~[0]"
check "isalnum '5' (53)"  "$CLS" "53 isalnum  1 AND" "~[1]"
check "isalnum 'a' (97)"  "$CLS" "97 isalnum  1 AND" "~[1]"
check "isalnum ' ' (32)"  "$CLS" "32 isalnum  1 AND" "~[0]"
check "toupper 'a'->65"   "$CLS" "97 toupper"         "~[65]"
check "toupper 'A'->65"   "$CLS" "65 toupper"         "~[65]"
check "tolower 'A'->97"   "$CLS" "65 tolower"         "~[97]"
check "tolower 'a'->97"   "$CLS" "97 tolower"         "~[97]"

# ── Word Count ─────────────────────────────────────────────────────────────
echo ""
echo "=== Word Count ==="
check "wc: empty string"     "$WC" "0 0 count-words"                          "~[0]"
check "wc: 'hello world'"    "$WC" "wc-demo-addr  wc-demo-len  count-words"   "~[2]"
check "wc: '  foo   bar  baz  '" "$WC" "wc-demo2-addr wc-demo2-len count-words" "~[3]"

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
