# Public padding and native MSB sumcheck rounds

Cycle 0069, `20261017T222105Z-d6d7aa4d`, 2026-10-17 UTC.
No proving speedup established. Synthetic arithmetic and exact geometry only.

The question tested is whether public padding can be omitted from a new batched
lookup round evaluator without changing its dense reference polynomial. Native
`sumcheck::prove` and `SumcheckRounds` fix the most significant bit first. This
experiment keeps that convention. It evaluates the expressly chosen cubic
`E~(x) S~(x) V~(x)`, with three separately multilinear tables. `E` contains
independent initial row-point weights for every real column, `S` is fixed public
shape support, and `V` is synthetic private-scratch data. This cubic is a
round-arithmetic probe, not a complete lookup/GKR construction or a requirement
that an eventual lookup protocol use exactly these three factors.

`ragged.rs` keeps the union of structurally occupied factor nodes, pairs on the
current MSB, substitutes zero for absent nodes and retains every projected node
after folding, even if its values become numerically zero. It never tests private
values to select work. Shape descriptors are synthetic public data; hidden prompt
lengths, selectors and real private data are outside this interface.

Two layouts are compared separately: column bits before row bits, and row bits
before column bits. Both reproduce their own dense round sequence exactly.
Matched real values and permuted terminal points reproduce the same initial sum
and all three final factors across the layouts; this is polynomial permutation
evidence, not native transcript/PCS equivalence. For a chosen layout, all four
round samples, all final factors and the captured native mask polynomial agree.
Native mask coefficients are supplied deterministic PUBLIC fixtures: no claim
about actual entropy, zero knowledge or security follows. Whole-cube masking
continues independently of the sparse base arithmetic.

Commands, from the research root:

```text
python3 experiments/ragged-logup-rounds-20261017/record.py run.py
python3 experiments/ragged-logup-rounds-20261017/record.py audit.py
python3 experiments/ragged-logup-rounds-20261017/record.py account.py
```

`run.py` compiles only the captured local field, the local mask implementation
(unused RNG constructor omitted, independently checked), and research code with
existing `rustc`. No Cargo, dependencies, installations, foreign scripts or GPU.
Every experiment has one CPU, CPU/wall alarm <60 seconds and a 512 MiB address
space cap; seed 2026101769, CPU0, Core Ultra 9 185H, final nice19. The scripts
are separate bounded processes. Peak rustc RSS is 134,544 KiB; main 22,404 KiB.
The 2.038-second main clock includes compilation and fixture/oracle work. It is
not a comparable Rust kernel measurement. Audit: 0.552 s, 17,724 KiB.

Final results: 94 fixtures; 1,424 round values; 282 final factors; 480 additional
brute-force round values; 1,600 mask values; 356 masked chain checks; 23 controls.
Independent audit: 5,185 checks using polynomial convolution, direct tensor MLE,
monomial mask integration, point-weight provenance and public support projection.
The first passing version and weaker controls are retained under `first-pass/`.
Final artifact checks preserve an initial comment-normalization assertion
failure: the field module changes `//!` to `//` when embedded. The corrected
audit verifies exact source equality after that documented conversion; no
arithmetic test changed. Native code pins stayed fixed, while the owner's
active progress ledger changed after capture; both hashes are recorded.

At the prior counted 8B T32 four-group sizes (not executed here), MSB
column-first visits all 17,842,172 pairs. Row-first needs 11,714,587, avoiding
6,127,585 (34.3433%). The pair-count ratio 1.523073 is only an arithmetic ratio.
For N rows, C real columns and W=next_power_of_two(C), counts are `N W - 1`
and `C (N - 1) + W - 1`. Sixty small rectangle layouts validate the formulas.
Arrays/indices, allocations, support planning, reductions, masks, extensions,
PCS and transfers are absent from those counts.

The naive payload summed over four groups is 656,015,360 B for indices plus
three factors, before BTreeMap scratch or allocation overhead; three factors
alone are 562,298,880 B. These are aggregate materialization counts, **not**
measured peak memory; sequential groups have a smaller initial maximum. The
full public weight array alone is 187,432,960 B. Public factors should be
factorized before considering a capacity or performance handoff.

The original ordered A/index links, wrapping-i64 semantics, table denominator
refusals, new GKR layers, private terminal masking, extension/opening schedules,
soundness and trained-shape joint-view privacy remain unimplemented. The native
query arrays were already uncommitted, so extra query commitment saving is zero.
See [handoff](../../handoffs/20261017-ragged-logup-rounds.md) and the
[dated report](../../progress/20261017T222105Z-d6d7aa4d.md).
