# Fresh lookup-row tiling — review candidate, no measured proving gain

Cycle0127, run `20261026T192925Z-2a61ec3c`, 2026-10-26 UTC.

The research-only [patch](../experiments/lookup-row-tiling-20261026/row-tiling.patch)
changes `table_values_exp_at` and `table_values_act_at` in canonical
`ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs` (snapshot
lines1132/1143). It is unapplied and uncompiled. Main/Claude reviews and
integrates; this lane does not merge.

Interface stays `len + current public table + beta + family gamma -> Vec<Fp2>`.
A private helper encodes indices0..min(len,256) directly into the preallocated
output, then `extend_from_within` repeats the initialized prefix with a
bounded last copy. `eq_cube` already uses this API in the same native file.
No separate4KiB table scratch, explicit zero fill, cached challenges or new
public/private state. Zero length reads no table; short lengths stay lazy.

At R12 T128, L16384, the exp/act pair's source Fp2 products fall32768→512,
additions and signed conversions65536→1024. Same524288B output payload;
516096B added logical copy reads minus161280B removed raw public table loads
=354816B **more logical reads**. No peak memory or DRAM/clock claim. The
compiler can already simplify a product by a base-field operand. Prefix-copy
capacity checks, dispatch, cache and codegen costs need native measurement.

Incidence: one pair per SC_TAB definition per block/argument invocation.
For32blocks,1032192 source products removed;16515072B copy reads added.
Prove, its verification and each fresh verify are separate invocations, not
an additive wall-clock formula. H helper wrappers construct256rows, so no
work disappears there. Their full-table inversions/refusals remain unchanged.
The existing public-vector move already avoids a downstream clone.
R12T32/T64 useL8192; T128L16384. Do not extrapolate to an admitted T512 or
selected R13LOW+h24/per-group tables. Earlier GPU constructor bodies match,
but there is no device validation or inherited FZC incidence.

Validation in [experiment](../experiments/lookup-row-tiling-20261026/README.md):
3353 synthetic checks,204cases,2264184 compared output entries,17lengths,
1025copy schedules,48malformed adapters,256zero-alpha cases,30original-cube
MLE checks at base-field points and13controls. Separate integer-coordinate/
direct-cube oracle; both implementations researcher-authored. Model9.169534s/
56076KiBRSS, source audit158checks/0.010463s/16976KiBRSS, one nice19 CoreUltra9
185H worker,30sCPU/alarm/35sparent/256MiBAS,96MiBestimate. Diagnostic clocks.
Nine source pins and an exact candidate/patch reconstruction are retained.
No native transcript, mask, PCS, receipt, proof, privacy or GPU gate ran.

Owner gates, only if exclusive constructor/SC_TAB timing shows materiality:

1. Review the pinned patch, current R12/R13 divergence, compiler output and
   exact field/byte behavior; compile under current shared build/heavy locks.
2. Differentially check all256rows, arbitrary partial/full lengths, fresh
   beta/gamma including0, signed extremes and full Fp2 evaluation points.
   Retain all shape/support/P3-lift/pad-zero/whole-table denominator refusals.
3. Compare every masked round, terminal, next challenge, draw order, complete
   receipt byte, failure path and fresh-process verifier result; run current
   profile-specific soundness/privacy gates. No blinding/opening reuse.
4. Measure exclusive constructor, SC_TAB and enclosing independently verified
   workloads, actual capacity/traffic and serialization. Reject if added
   copies dominate or the constructor is negligible. Then measure verified
   fixed-context resident1/2/4/8 workloads, with startup and drain charged.

End-to-end ceiling is unknown. With affected critical-path fractionf,
even deleting it for free gives at most1/(1−f), before copies. No50-token/s
projection follows. This candidate is lower priority than whole-prover GPU,
DD-context/fidelity scaling and complete phase/capacity measurements.

Source negative retained: [Celer's Dory prototype](https://github.com/quwenjie/Celer/blob/main/dory_pcs.hpp)
uses BN254/mcl and explicitly drops blinding. Its reported lookup gains do
not establish a private native optimization. Code license/commit/update date
could not be resolved; no code executed or imported.

Next local question: adapt prior public descriptor work to actual periodic
SC_TAB public factors, preserving full cube, bit order, public extensions,
terminals and pad-zero refusals. This may remove materialization/copies rather
than exchange arithmetic for extra reads; native affected share is still unknown.

New independently verified full-stack proofs/passes/positions0/0/0; context
and accelerator none. Witness/proof/serialization/verification/startup/prefill,
startup fraction and steady/total-workload rates unmeasured. Private8B/high-end
GPU >=50 proved tokens/s remains unachieved. Saved handoff is not delivery.
