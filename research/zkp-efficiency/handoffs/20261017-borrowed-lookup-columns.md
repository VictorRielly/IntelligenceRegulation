# Borrow identity lookup slices — review-only capacity candidate

Cycle 0062, run `20261017T122624Z-c30acfa0`, 2026-10-17 UTC.

The proposal avoids storing lookup columns that exactly equal an existing
padded witness plane. TinyLlama T128 source counts put that payload at
167.5 MiB per block (75.706% of looked-column storage). Actual peak RSS,
allocator traffic and native runtime savings remain unmeasured.

The owner source seam is
`ops/zkp-mvp/trained-1b/hashline/src/private_block/protocol.rs`:
`lookup_values_at`, `byte_histogram_at`, and the `looked` construction before
the A commitment. Source hashes are in
[native-pins.json](../experiments/lookup-borrow-catalog-20261017/native-pins.json).
This is the trained lane, not the older root implementation. Recompare source
pins before review/build and rebase only in the owner's isolated lane.

The [unapplied patch](../experiments/lookup-borrow-catalog-20261017/protocol-candidate.patch)
adds `lookup_columns_at<'a>(..., &'a Witness, ...) -> Vec<Cow<'a, [i64]>>`.
A public expression with zero constant and precisely one coefficient-1 term
borrows `&wit.planes[p][..len]`. Other expressions retain the old wrapping-i64
map into owned storage. Histogram input becomes generic over `AsRef<[i64]>`;
the old `Vec<Vec<i64>>` test callers remain supported in the proposal.
Existing helper functions take slices unchanged. Indexed order, public
thresholds and the `drop(looked); drop(wit);` boundary are retained.

The current source constructor has only single-plane expressions. Trained
shifts equal to the full byte width yield additional identity expressions;
the classification checks the expression rather than naming a fixed catalog.
It retains padded values, oversized-prefix semantics, bucket-0 invalid fallback,
whole-table zero-denominator refusals, every H term and every commitment.
No cross-proof state or randomness reuse is involved.

[Synthetic experiment](../experiments/lookup-borrow-catalog-20261017/README.md):
48 fixtures, 288 domains, 4,176 columns, 23,834 integer comparisons and
12,328 Fp2 helper values pass. Eleven negative controls and five generic
fallback cases cover affine/multiterm expressions, signed wrapping, padding,
out-of-range values, zero denominators and helper ordering. Separate audit:
235 checks, including all 22 public manifests and 12 closed-form census rows.
One CPU0 thread, nice19, seed2026101762, 59-second/512-MiB caps; final test
1.050006 seconds, 17,464 KiB RSS. No native build/Rayon/proof/GPU gate ran.

The direct speed ceiling is small in the new owner CPU diagnostic: lookup
construction plus histogram is 0.517 seconds of a 175.259-second T128 stack
process. Deleting the entire mark gives at most 1.002959× directly, with other
work fixed. H helper arithmetic remains. The later completed GPU-assisted
diagnostic assigns 0.748 s of 161.857 s to that mark, a conditional direct
deletion ceiling of 1.004643×. Its D/F zero-checks cost 25.353/19.484 s,
versus softmax 11.834 s. Both are T128, 22-block trained 1.1B cold passes,
16 threads, n=1; the GPU is RTX 4070 Laptop. No fresh-verifier evidence was
inspected for these samples, so they contribute zero credited positions.
Peak/caching effects require measurement. D/F work is the speed priority.

Owner acceptance, only if capacity justifies this lane:

1. Compile under shared build/heavy admission. Compare new borrowed/owned
   output against the old native function for every real layout and both
   serial/parallel threshold branches, including 1/2/8-thread pools.
2. Exercise padding, oversized/truncated planes, extrema, malformed lookup
   values and original refusal behavior. The generic histogram must preserve
   forced serial/chunk paths and all existing tests.
3. Compare helper/A/H words, RNG draw order, transcript, frozen proof bytes,
   and independently verify complete receipts with corruption controls.
4. Measure actual simultaneous allocation, HWM, lookup/helper/commit phases
   and enclosing workload cost with fresh masks. Include descriptor/dispatch,
   allocation/task-balance and compiler effects. No speed from byte ratios.

Reject any word, refusal, RNG or proof-byte mismatch. Unchanged measured peak
rejects a capacity gain; unchanged or worse enclosing time rejects a speed
gain. This is not an accepted privacy profile or a result for the private
8B / 50-token/s target. Main agent/Claude owns review and integration; no merge
or heavy job is queued by the researcher.
