# Native Fp2 U8 reader and tiled arithmetic reference

Cycle0108 / `20261020T161854Z-f0b8edce`. **No proving speed improvement; no production patch.**

The [experiment](../experiments/native-fp2-u8-consumer-20261020/README.md)
ports the prior tiled consumer to native Goldilocks Fp2 and validates against
a compiled source-pinned Rust arithmetic/helper reference and independent
original Boolean-basis MLEs. Main 10386 checks /100 consumers /
3168 helper entries; audit 1766 checks /28 more consumers /
164 wrapping reader values /256 zero sites /6pins. Sixteen main controls plus
four overflow controls pass. Probe0.313s and audit2.925s are CPU correctness
clocks; zero full-stack receipts, no GPU measurement.

Interface and patch location: research-only `fp2.py::Attempt/OrderedLookup`
implements fresh challenge-local denominator/reciprocal caching and immutable
wrapping-i64 Lk reads; `read(index)->(N,D)`. `tiled_fp2.py::consumer` yields
the full four-sample cubic row before receiving the actual challenge, then
hands off four original folded MLEs. `oracle.rs` is a reference harness using
the copied native field and two exact pure helper bodies, NOT a native prover.

Native seams: frozen R9 protocol::lookup_values_at/u8_denominator_inverses/
helper_one/write_h; layout::Lk/lookups_at; argument::helper_sum/SC_TAB and
zkp-core::field. Original source paths/hashes in source-pins.json.

The native256-entry inverse cache already exists; no new inversion saving.
A denominator table adds4096B payload per attempt if retained beside it.
Zero table denominators refuse even for absent values and multiplicity0.
Keep all table rows and original refusal/RNG/draw/absorb order; no retries,
cross-attempt caching or private mask/opening reuse authorized. Out-of-range
i64 fallback tests are dishonest-input arithmetic, never profile admission.

Unresolved: original-A leaf binding and MSB mapping (consumer explicitly LSB),
all83/85 lookup sites and paired helper grouping, one global histogram and
pad constraints, versioned private GKR/CFS/PCS, mask/claim/opening site counts,
soundness/privacy/fidelity reviews, native masked transcripts/refusals/receipts,
actual peak capacity and complete workload time. Wrong-site swaps preserve
the fraction root; an ordered terminal link is mandatory. Unmasked rows/roots
cannot be published as a private proof.

Free-deletion ceiling<=1/(1-f) for unknown exclusive affected fraction f,
before added scans and private proof work. Prior selected-array memory is
not a net native saving. Reject any binding/exactness/refusal/draw mismatch,
stale source/cache, missing private cost or enclosing slowdown.

Build a source-pinned claim/mask/PCS site ledger for a prospective private
fraction-tree replacement: both child branches per layer, all83/85 ordered
original U8 links and one global table. Make the LSB consumer to native MSB
point mapping explicit. Reject count-preserving wrong-site merges; keep
unknown private costs unknown before making a net-memory or time claim.

Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.

Main/Claude reviews and integrates if appropriate; do not merge this lane.
All production/reviewer/instruction/Git/runtime files remain read-only.
