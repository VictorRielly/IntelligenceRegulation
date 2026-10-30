# Public interval rowfold handoff — cycle 0152

Run `20261029T215649Z-4ef3ea52`. **Candidate for owner measurement only;
no native/GPU/complete-proof speedup measured or production patch made.**

The current `dev_fold_rows` supports max4 public opening vectors and calls
`k_fold_rows`, scanning every row per output column. The preceding research
candidate used sorted `u32(row<<4|membership)` indices. This experiment
merges consecutive equal-membership indices into 8-byte `(word,len)` runs,
with public list/dense fallback selected by source logical operands.

Patch locations in `experiments/public-interval-fold-20261029/`:

- `interval.rs`: tested Rust interval builder, canonical validator, hybrid
  selector, loop model and controls; `indexed.rs` retains the prior list path.
- `candidate-kernel.cuh`: uncompiled CUDA sketch using the existing native
  field helpers and unchanged rho/output layouts; no CUDA compilation run.
- `census-result.json`: independent set audit and per-order operand costs;
  `prior-native-pins.json` / `seam-pins.json`: exact source hashes.

Interface: `Run { word:u32, len:u32 }`, repr(C), exactly8 bytes; row=`word>>4`,
flags=`word&15`, exclusive end=row+len. Require row<2^28, positive bounded
length, valid membership, sorted disjoint maximal spans, correct group order
and all support/mask/proximity rows. Public numerical zeros can be omitted
only after native mask-site admission, with both limbs checked and caller
provenance reviewed. Plan lifetime extends through the synchronized output
copy. Keep every rho upload, output and CPU pad fold initially.

At frozen R13 8B/T128 A geometry, original-order noDD/DD metadata falls
38,616/37,312 B →584/648 B. Logical matrix+rho+metadata operands fall
4.468/4.340 GB→3.845/3.740 GB (13.95/13.84% below the previous indexed loop).
This is 92.37/92.72% below dense **source operand counts**, with no statement
about physical traffic or runtime. Compiler broadcast/cache may already
eliminate many logical reads. R14 split widths differ; re-pin separately.

Added costs: existing public list construction, conversion10.634/11.060us,
validation286.722/292.304us (sharedCPU n=1), allocation/upload, mode dispatch,
nested loop starts, and possible register/occupancy/code-cache cost. Rho
uploads remain2.710/2.780MB; actual GPU costs and exclusive phase fraction
are unknown. These microsecond values are diagnostics, not proof timing.

Negative finding: zeroing every third public coefficient fragments74/81
spans into3242/3134 and raises hybrid metadata to25,728/24,856B, although
the full logical operand count still falls22.60/22.71%. Do not optimize
metadata bytes or row visits alone. Structural envelopes and exact numeric
lists are algebraically valid with different costs; dispatch must remain
public. No private matrix sparsity may select a path.

Validation:184,770 exact schoolbook modular-reference comparisons,
14 native-helper fixtures plus45 support patterns,462 controls and102,314
independent Python assertions. Source-row/narrow8 comparisons27,360.
Imaginary rho, cancellation, empty/dense/alternating/random supports,
reversed/packed orders and synthetic pad columns pass. Missing, overlapping,
oversized, truncated, invalid-flag/order, omitted-batch and missing mask/
proximity controls are rejected. Reference code is independently authored
by this researcher, not external review. Native define, FS, actual PCS pad
generation, CUDA, receipts and privacy acceptance remain untested.

Before implementation, obtain actual current public descriptor/support
counters and exclusive rho H2D/allocation/kernel/D2H/pad/open/enclosing
clocks. `secs_fold` includes multiple operations. If material, the owner can
register the separate run kernel in `FUNCS`, construct a per-call plan
inside `dev_fold_rows`, and retain existing list/dense fallbacks. No trait
change is needed for the current-public-rho scan. Retain native refusal and
mask audits, fresh masks/pads/proximity, H sum/U, RNG/FS/PCS and exact output
order. No mask/opening reuse or privacy weakening is authorized.

Owner promotion requires current shared build/heavy locks, native golden/
refusal/RNG/FS/PCS/privacy gates, CUDA register/spill/cache profiling, then
independently verified enclosing and resident-workload A/B. A mismatch or
absence of verified enclosing benefit falsifies it. End-to-end ceiling is
`N/(T-C_removed_exclusive+A_added)`, with unknown exclusive f; even free
deletion is bounded by `1/(1-f)`. No numerical GPU8B forecast follows.

Next bounded local question, conditional on materiality: can same-flag
intervals be coalesced across verifier-public all-zero gaps at lower total
cost? Test against independent dense/list references with nonzero-gap,
imaginary-limb, mask/proximity and stale-plan controls, charging extra loads
and MACs. New owner bottleneck measurements take precedence.

New full-stack proofs/passes/positions0/0/0; actual context/device none,
modeled T128 on one Intel Core Ultra9 185H CPU worker. All proof clocks,
startup fraction and full-workload/steady rates are unmeasured. No prefill,
resident series or decode ran; >=50 private8B proved tokens/s is unachieved.
Main/Claude reviews and integrates; researcher does not merge.
