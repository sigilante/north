.PHONY: test test-long test-examples

# Fast unit tests: Nock primitives + noun literal syntax (~5 min total)
test:
	bash tests/test-nock.sh

# North Forth example program tests: fibonacci, ackermann, sieve, charclass, wordcount
test-examples:
	bash tests/test-examples.sh

# Long-running benchmark tests (urbit/benchmark reference cases).
# Each test spawns a full urbit eval + nock.fs load; expect O(minutes) per test.
test-long:
	bash tests/test-nock-long.sh
