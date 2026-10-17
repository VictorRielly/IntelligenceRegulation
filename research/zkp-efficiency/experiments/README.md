# Equality-factor sumcheck experiment

Command, from the repository root:

```sh
python3 research/zkp-efficiency/experiments/eq_factor_rounds.py
```

Standard Python only; deterministic synthetic inputs; no source downloads,
secrets, GPU, build, external service or project code mutation. The first run
completed in 0.237 seconds. The result file records the script SHA-256.

## What is tested

For `s(t) = prefix * eq(w_j,t) * h(t)`, the inner `h` has degree one less
than the full round polynomial. Compute `h(0)..h(d)`; obtain `h(d+1)` from
the vanishing next forward difference and reconstruct every original `s(t)`.
After the first round, when `e1 = prefix * eq(w_j,1)` is nonzero,
`h(1) = (actual_unmasked_claim - e0*h(0))/e1`. If `e1=0`, compute `h(1)`
normally. No challenge is discarded/resampled. Splitting the remaining
equality point into two parts lets the nested sum use two small tables.

The reference materializes the full equality table and folds it with the
other tables, using R1d-style recover-one after round one. Both evaluators use
MSB-first variable order and the same exact Goldilocks/Fp2 arithmetic. A toy
deterministic message wrapper checks challenge drift; **it is not CFS and
proves no privacy property**.

Evidence in `eq_factor_rounds.result.json`:

- 62 differential cases across 1, 2, 3, 5 and 7 variables, inner degrees 1–3,
  base, extension, signed-int16 and zero data; full arrays, challenge streams,
  final table values and transcript digests agree.
- 288 round evaluations recomputed by a direct original-cube MLE oracle,
  independent of either evaluator's folding procedure.
- Five fallback rounds from zero `e(1)` and an accumulated zero prefix; two
  malformed-shape refusals.
- A negative control demonstrates that `E*A + B` cannot be rewritten as
  `E*(A+B)`: the structure requirement is essential.
- Two reference and two candidate observations per degree at 1,024 rows.
  Degree-two product count: 3,581 → 2,558; degree-three: 4,604 → 3,581.
  Retained equality entries: 1,024 → 48. These are logical retained eq
  entries, not total memory or allocator peak.

The Python timing order is reference/candidate/candidate/reference. Results
are 15.0–16.2 ms versus 11.1–11.5 ms for inner degree two, and 21.4–22.8 ms
versus 17.2–17.4 ms for degree three. These are small shared-CPU diagnostics;
do not promote their ratios to the native prover or GPU.

## Concrete integration seam

The inspected R1d source adds `SumcheckRounds::{round,fold,finals}` in
`zkp-core/src/sumcheck/rounds.rs`. The driver requires unmasked evaluations
at the unchanged `0..=degree`, folds at its own challenge, and preserves
final table order. The candidate fits that contract for a validated factorable
group. `hashline/src/private_block/argument.rs::Tab::Eq` already carries
the equality point and starting coordinate. The stage-34 test-only
`slot_ir.rs` records terms/table provenance and can guide an eligibility check.

Required next gates:

1. Extend the experiment to multiple equality groups and partial-coordinate
   factors matching the actual `SC_SZC` expression, including padded gates.
   The host has three distinct equality factors. An asserted combined claim
   cannot be used as a subgroup claim.
2. Preserve first-round behavior for inconsistent Host/Standalone witnesses:
   no claim-based shortcut until the arithmetic actually establishes that sum.
3. Preserve all finals in the original order, including public equality tables
   needed by subsequent extension rounds. Do not change public degree or
   transcript labels, masker calls, RNG draws, challenge law or refusal rules.
4. Compare actual native masked rounds, full receipts and old/new verifiers on
   dense and adversarial fixtures. Do not edit the frozen R1d/R2a candidates
   in place while another validation owns them.
5. Benchmark the actual affected slot and then a complete block; report witness,
   proving and verification separately. GPU work needs device evidence.

The immediate PoC only covers `eq * product`, full-coordinate equality, and
synthetic tables. The formulas generalize algebraically, but the code has not
proved eligibility or benefit for all 23 native slots.

## Local reference pins (read only, 2026-09-22)

| File | SHA-256 |
|---|---|
| `/tmp/zk60-rounds-20260922/zkp-core/src/sumcheck/rounds.rs` | `c60520596e6d855687e0a225850850c12bd15b8741522de69a624f0db8a003df` |
| `/tmp/zk60-rounds-20260922/hashline/src/private_block/argument.rs` | `f71be0d3d6a78814c25c85a89c2fdcd9a538b49891af974853149e53d6f3506c` |
| `/tmp/zk60-rounds-20260922/hashline/src/private_block/slot_ir.rs` | `734cd0e0e03b5ea61da6e50aff98f53d35ec686b47bd317dcade29ee85adee9e` |
| `zkp-core/src/field.rs` | `df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13` |

The `/tmp` paths may disappear across restarts. The repository's retained
R1d source/archive and hash manifests are under
`results/zk60_sumcheck_rounds_20260922/`; revalidate before porting.

Primary ideas: [equality-factor optimization](https://eprint.iacr.org/2024/1210),
[extended sumcheck paper](https://eprint.iacr.org/2026/587).
This experiment was written locally, not copied from a downloaded implementation.
