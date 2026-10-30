# Dedicated five-vector tail — research candidate for owner review

Cycle0155, run `20261030T005649Z-506c4db2`.
**Exact synthetic algebra passed. No native/CUDA proving gain or privacy acceptance.**

Interface: ordered public rhos including the freshly drawn final proximity
vector; systematic rows×n base-field matrix; return the same k vectors of
n full Fp2 values. If k>=5 and k mod4=1, process the final five together.
All earlier chunks remain4 and all other counts keep their original plan.
No coefficient,claim,output or transcript permutation; no private-value
scheduling and no mask/opening/randomness reuse.

Research patch location:
[candidate_kernel.cu](../experiments/five-rho-tail-20261030/candidate_kernel.cu)
is the exact extracted current loop body with a new`k_fold_rows_tail5`
symbol and max5. The original max4 body remains separate.
[harness.rs](../experiments/five-rho-tail-20261030/harness.rs) contains the
public tail planner and serial differential. No production patch applied.

Actual seam: `zkp-core/src/pcs.rs::fold_rows_multi_zk` chunks4 before
`EncodedStore::fold_rows`, then `hashline/src/gpu/cuda.rs::dev_fold_rows`
asserts max4, then `k_fold_rows`. Changing only the PCS chunk size breaks
the adapter contract. An optional whole-opening batch method with a default
chunks4 implementation and a CUDA-specific override can preserve all other
stores/fallbacks; this interface is proposed, not implemented or accepted.
Do not raise the old global kernel maximum and risk all ordinary batches.

Evidence:612Rust fixtures/228780 scalar limbs including synthetic pad
columns;375extracted-kernel CPU-shim fixtures/30750limbs;1050Python bigint
limbs and1817Python assertions.141Rust controls=130planner+3shape+8fault
checks. Both limbs,output order,missing proximity,protected-row changes,
new-call state,overlaunch and output bounds are covered at their stated
synthetic scope. Independent references were authored by this researcher;
not external review.30native/document/owner pins retained.

Conditional f_e9 standalone generic-core source reads:

| Layout | Scan saved | Combined matrix source-read reduction |
|---|---:|---:|
| T128,noDD,A3517 |460980224B|5.61525%|
| T128,DD,H3116 |408420352B|4.91088%|
| T256,noDD,A4065 |1065615360B|5.57071%|
| T256,DD,H3454 |905445376B|5.04506%|

These are Shieldstral3B layouts with historical generic groups, not current
native groups, multi-block costs or8B geometry. Four historical producer
files differ from held R14 source. Two external endpoints are included;
current internal grouping is unknown. T128 A460980224 corrects prior shorthand
461373440, which used3520rows instead of3517. Prior files are preserved.

Added cost: fifth Fp2 accumulator source payload+16B/thread; compiled
registers/spills/occupancy unknown. Largest affected rho/output scratch+25%
(T128 A1,273,664->1,592,080B; DD H1,248,000->1,560,000B).
All rho upload/output download bytes and MACs stay unchanged. Pad folds,
fresh masks/proximity,encoding/commitments and verification remain.
`secs_fold` includes flatten,H2D,alloc,launch,D2H and conversion; it is
not kernel time and omits rho upload from its local H2D byte counter.

Owner gate before promotion: current native public group/rho count and
actual-device dispatch census; source/binary/shape pins; separate compiled
register/spill/occupancy and peak-memory data; exact native both-limb/order/
mask/pad/refusal/RNG/FS/PCS/receipt parity, retained independent verification
and current privacy/soundness gates. Use current shared build/heavy locks;
do not duplicate the held recovery/build. Compare enclosing complete work,
including preparation,all transfers,serialization and drain. Reject on any
parity/refusal/privacy defect, no applicable tail, capacity failure or
enclosing regression. No numerical8BGPU rate follows from these counts.

Next local experiment: source-derived lifetime/offset differential for
one-opening public-rho/output staging versus per-chunk allocations. Count
full/ring scratch peaks and partial-failure cleanup; no GPU or heavy build.
Main/Claude decides integration. No code is merged or external message sent.
