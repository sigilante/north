The North noun has a standard structure:

```hoon
[[word-list settings-and-buffers] [return-stack data-stack]]
```

That is:
4. Word list/dictionary at +4
  * Structurally, as (list [term *])
  * This permits rightwards-branching redefinitions of words without changing references.  For example, if ADD refers to DEC in its definition, the reference is search upwards/backwards in the tree.  Since term axes are always located at (4, 12, 28, …, n^2-4) within the +4 tree, they can be efficiently searched.
 * `[[DEC dec2*] [ADD add*] [DEC dec*] ~]`
 * Word code looks something like a gate:  `[1 8 [1 0] [1 …] [0 1]]`
 * How do words call other words?  If the stack branches immutably rightwards, then axes are persistent.
5. ANSI Standard FORTH settings and buffers at +5
 * Standard settings +10 (ad hoc or map) (maybe move to buffer section)
 * Scratch pad +22
 * Addressing done via stack operations on a list (like Hoon +tape)
 * 84+-char scratch pad (largely unused in unorthodox FORTH), PAD
 * Other buffers under +23 (+46, etc.)
6. Return stack at +6 (stack list, could be rightwards but to be determined)
7. Data stack at +7 (rightwards stack list, snoc to tail)

Stacks:  `~[new-value old-stack]` vs. `[~ old-stack new-value]`