# Four-reduction canonical Fp2 multiplication and accumulation

Run `20261012T172555Z-e8207bdf`, cycle0036, 2026-10-12. This is a CPU synthetic
fixed-width arithmetic and source-derived clause experiment. No native Rust/CUDA
was compiled or run; no complete-model proof or proving speed was measured.

The baseline is canonical Goldilocks `p=2^64-2^32+1`, `u²=7`. Native
`Fp2::mul` uses five `reduce128` calls and two modular base additions; a
subsequent extension accumulation adds two more modular base additions. Cycle0035's
five-reduction fused MAC retained all five reductions. Its wide alternative
reduced fewer times but needed three u192 sums, carry chains and per-sample scratch.

The new candidate first reduces `bd` and `ad`, then reduces
`ac + 7·reduced(bd) + acc0` and `bc + reduced(ad) + acc1`.
It uses four reductions, four variable products, one constant product and four
u128 additions per MAC. A product without an accumulator needs two u128 additions.
Variable and constant multiplication counts remain; the removed item is a
reduction call. No wide persistent sums, flush schedule or new arrays are needed.

For canonical limbs, conservative real and imaginary MAC bounds are
`(p-1)² + 8(p-1)` and `(p-1)² + 2(p-1)`, both below `2^128`.
Exact decimal bounds/headroom are in result.json. Two maximal RAW products do
not fit u128. Full u64 noncanonical limbs can break the headroom proof.
The native field API has a public tuple representation but states a canonical
precondition; the sketch inherits that precondition. Python's precondition
refusals are controls, not new native refusal behavior or an admission audit.

Validation completed in **3.602309 s**, **17,736 KiB peak RSS** on one affinity0,
nice19 Intel Core Ultra9 185H thread, Python3.10.12. Wall/CPU caps59s, AS512MiB,
estimated memory64MiB. Initial Rust-model-only pass was3.007839s/17,540KiB;
its exact passing source/result/command is retained in initial-rust-model-only/.
The repeat was required by the new CUDA limb model and carry controls.

- 54,848 arbitrary-accumulator MAC fixtures and matching product fixtures:
  six-limb exhaustive extrema grid plus8,192 seeded random cases.
- The same54,848 MACs match an independent32-bit-schoolbook, two-u64 CUDA
  emulation;2,097 full-u64 multiplication and4 explicit carry checks pass.
- 2,060 reducer checks,2,048 extension-law fixtures and256 ragged part schedules
  (lengths0..1025, partitions1/3/7/1024, full/base/zero/max values).
- 64 source-derived complete SC_SZC clause fixtures,256 release/debug schedules,
  576 independent original-cube samples against2,304 candidate samples,
  6,912 direct-MLE finals;368 recoveries and208 zero-factor fallbacks.
  Four schedules cover weighted-only/global-product arithmetic with explicit
  debug sample1 and recovered release sample1. n0..3,ls2/3,both pads or neither,
  full/base/zero/Boolean values,odd/even helpers and short equality spans.
- 19 controls catch raw-product overflow, absent accumulator/cross product,
  wrong nonresidue,truncation,noncanonical limbs,lifecycle/shape violations,
  dropped row,negative/overflow reducer input,top carry,low carry and discarded
  high bits of the constant product.

The reference MAC uses unbounded integer polynomial convolution with a final
modulo per coefficient. The complete-clause oracle uses independent tuple-field
schoolbook arithmetic and direct evaluation on the original cube. Candidate
schedulers share the previous local port; the independent oracle qualifies that
sharing. Global-product checks temporarily replace the local field multiplication;
CUDA emulation is separately checked at the primitive seam, not inside a native
masked device proof. Seed2026101236. Commands, pins, hashes and limitations are
in command.json,result.json,native-pins.json,copy-provenance.json and patch-pins.json.

Literal accounting uses cycle0033 compiled denominators (cycle0034 BEFORE row
stepping), with unchanged tables, brackets, weight products and folds retained.
Illustrative n23/ls3/padded/release/nonzero-recovery:

| Scope | Counted reductions removed | Fraction of counted scan/fold reductions |
|---|---:|---:|
| Weighted MAC only |79,691,768|0.604134%|
| All full Fp2 products, with optional weighted MAC |2,478,833,399|18.791733%|

Baseline13,191,084,671 counted reductions. `mul_base` stays at two reductions.
Combined product+MAC removes5,117,050,334 modular base additions and adds the
same number of u128 additions. These calls have different instruction/carry
costs. Reduction by a constant7 may already be substantially simplified by
LLVM/NVRTC. Register pressure, dependency chains, occupancy and enclosing clocks
are unknown; zero extra persistent scratch does not mean zero register cost.
Do not add the weighted reduction saving to the global saving: weighted products
are already included in the latter. Setup,Eqs,inversions,interpolation/recovery,
mask extensions,transcript,witness,PCS,transfers,serialization and verification
are outside this census. These fractions are not time ceilings or speedups.

The full workload ceiling is `N/(T-Caffected+Cnew)`; even ideal removal is bounded
by `N/(T-Caffected)`. Neither accepted8B T nor isolated affected clocks exists.
No numerical end-to-end ceiling is justified. Falsify any canonical output,
sample/final/native masked/extension/RNG/transcript/receipt/refusal mismatch, a
failed native canonical-admission premise, a peak/occupancy failure, or no
enclosing improvement after compiler/carry costs. A steady recurring cost above
20ms/newly proved position rejects50/s for that schedule even with unlimited
startup amortization. Long-context attention still grows quadratically.

Review-only alternatives: product-only.unapplied.patch,weighted-only.unapplied.patch,
combined.unapplied.patch (Rust),cuda-arithmetic.unapplied.patch (two-u64 CUDA).
They are alternatives, not patches to stack blindly. Native seam is
`zkp-core/src/field.rs:158`, grouped weighted samples in
`zkp-core/src/sumcheck/grouped.rs:110`, and CUDA `f2_mul` at
`hashline/src/gpu/kernels.cu:63`. The CUDA added MAC has no new caller in this
sketch. Candidate copies are under candidate/; source pins bind the read-only
Sonnet hardening tree. Nothing was applied to production or merged.

LIVE search inspected Plonky2's MAC/representation,gnark-crypto's October2 release
and version commit,October6 zkLLMPoT,and newly assessed older2017 ZK sumcheck.
Qualified dates,commit scope,license and fetch failures are in source-records.json
and search*.json. No author performance or foreign code was reproduced/executed.
Six prior cycle0035 source assessments were recovered with their original access
date; they are not new LIVE accesses. No public/private commitment or mask reuse
is authorized by any source.

Accepted independently verified complete private8B proofs/passes0; countable
tokens0. Device CPU only; proof context null. Steady-state/total-workload rates,
startup duration/fraction,witness/proof/serialization/independent-verification,
latency/lag/drain clocks are unmeasured. No prefill,resident-model pass or decode
proof occurred. The>=50 proved-token/s target remains unachieved.

Next owner action: review canonical callers and optimized assembly, then native
field/legacy/frozen/masked/extension/refusal gates and guarded full-slot/block
A/B with independently verified complete receipts. Builds/device jobs need the
owner's shared heavy/build guard and admission; none is queued here. Next local
cycle: a padded causal-mask descriptor/fold study against explicit original-cube
MLE, charging the predicate evaluation and scratch costs without dropping
masked-future score constraints. Preserve all earlier negative findings.
