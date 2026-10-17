# Current F-slot grouped equality candidate

Cycle0064, 2026-10-17, `20261017T142624Z-6b84b6ef`. Research-only, unapplied.

The captured trained-lane F zero-check at
`ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs:1602` already
has three equality factors. Add `SlotDef.groups` using existing
`GroupedEqRounds`; polynomial = Eq(tau)*B0 + Eq(p_g)*B1 + Eq(p_u)*B2.
B0 is degree3 with or without padding. B1/B2 are degree1 without a support
table and degree2 with it. The conservative `pad_on` descriptor is safe when
the global pad rule is on but F itself needs no support table (not separately
covered by this harness). Slot degree4, table order and all equality tables
remain. Do not seed subgroup recovery from asserted hosted sums.

[Patch](../experiments/fzc-grouped-equality-20261017/argument-candidate.patch)
and [source pins](../experiments/fzc-grouped-equality-20261017/native-pins.json).
The proposed whole-source file is not compiled as a native crate. Its bracket,
the original full closure, field/helpers/pad code and two real evaluators were
compiled in a standalone std-only harness. Rayon calls are replaced by serial
iteration; no native dispatch, shape door or private proof was executed.
The candidate reconstructs the same full polynomial for extensions/verifier;
it has not proved masked transcript or receipt identity.

72 synthetic fixtures:1,600 evaluator round-value comparisons,960 independent
original-cube values including extension-field off-grid samples,1,512 terminal
words,512 bracket/full values,128 extension-like perturbations. Twelve
controls pass;190 actual subgroup recoveries and98 zero-factor fallbacks,
without resampling. Independent290-check source/work/degree audit passes.
One run7.060s/74,824KiB parent,149,768KiB compiler; audit0.0052s/16,112KiB.
Intel Core Ultra9 185H, CPU0, one thread, nice19,59s/512MiB caps, seed2026101764.
Three corrected harness/audit failures are preserved. No production/native/GPU/receipt gate.

For N=2^n, H=N/2 and nonzero factors, the present host-slot R1d baseline
evaluates its full polynomial9H-4 times. Grouped B0 runs7H-3 times;
each host runs3H-1 unpadded or5H-2 padded times. Independent executed counts
match. Added: three subgroup claims/prefixes, split Eq tables per round,
up to3(n-1) inversions, interpolation and group dispatch/accumulators. All
original table reads/folds stay. No per-proof mask reuse or private cache.

Small N=16 is a negative: grouped time is1.58x unpadded/1.37x padded baseline.
Larger N256/4096/8192 baseline/grouped ratios range1.03-1.42 in a short
shared-host test. N4096 stays in the serial-small arm; N8192 crosses the
common chunk cutoff (the captured parallel arm was serialized). This is
not a stable factor, a p95, a Rayon result or a token/context benchmark.
Timing includes evaluator initialization/rounds/folds/finals; factories,
input copies, serialization and the complete private proof are excluded.

End-to-end ceiling: retained TinyLlamaT128 GPU-assisted diagnostic total
161.857226s, F slot19.484s and masked portion16.457s. Removing the ENTIRE
masked F cost caps direct improvement at1.1132x; removing all F gives1.1369x.
This candidate removes only some of the arithmetic. No corresponding8B F
subclock or5090 measurement exists; no8B ceiling or rate is inferred.

Owner gates: rebase against active F-device lane first; no concurrent edits.
Compile actual crate, run bounded shape/pad/refusal/terminal oracles, compare
masked messages/challenges/finals/RNG continuation and frozen bytes, PCS/M
and shape-privacy obligations, saved receipt and fresh verifier controls.
Then alternate grouped/current F/full-workload timings under shared locks,
including extra table/setup costs and memory. Reject correctness on any
polynomial/degree/refusal/byte difference. Demote for speed if enclosing F or
whole-workload time does not improve. Keep ordinary path available for small
tables if an owner-measured crossover supports it. Do not combine this
synthetic factor with the prior base-constant rewrite or GPU forecasts.
