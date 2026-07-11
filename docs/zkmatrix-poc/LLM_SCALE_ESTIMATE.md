# Estimate: Proving a Large-LLM Feedforward, and What "More Efficient Than the Feedforward" Can Mean

Reference workload throughout: one forward pass of a Llama-7B-class model
(L = 32, d = 4096, f = 11008, ~6.7B params) over T = 512 tokens
(~3.4e12 MACs). Baselines on that workload: **~0.05-0.1 s** on an A100
(bf16), **~7 s** quantized int8 on this 22-thread CPU. All prover numbers
extrapolate from throughputs *measured in this repo* (tier-0 optimized
lattice kernels: mod-q matmul 4.6e9 MACs/s, commit kernel 1.1e10 MACs/s).

## 1. First, the goal needs one clarification

"Prove the feedforward more efficiently than the feedforward itself" has
two readings with opposite answers:

- **Verification cheaper than re-running the feedforward: already
  achieved.** This is the deployable meaning of verifiable inference — a
  regulator/validator checks the proof instead of re-executing the model.
  Pairing-track verification is milliseconds regardless of model size;
  even the lattice verifier is far below inference cost. This property
  survives every design decision below.
- **Proving cheaper than the feedforward: impossible in the strict
  sense, approachable in the practical one.** The prover must *run* the
  feedforward to obtain its witness, so prover time >= inference time,
  always. The meaningful target is the **overhead factor** — prover cost
  as a multiple of inference on comparable hardware. Today that factor
  is ~10^3-10^5; the plan below brings it to **single digits vs
  quantized CPU inference** (~2x), with an honest floor of ~10^2 vs
  A100-class float inference for this cryptography family.

## 2. Where the cost lives at LLM scale

The cost structure inverts compared to single-matmul benchmarks. Per the
measured lattice cost model at 7B/512-token scale:

- **Commitments dominate.** Every activation tensor (and every range-
  proof bit tensor) must be committed: ~10 tensors/layer x 32 layers,
  ~2.5e13 commit MACs bare, ~1.5e14 including w=12-bit decompositions on
  ~40% of tensors -> **~3.6 h on today's CPU Route Z**. Weight
  commitments (~2.5e14 MACs) are comparable but one-time and amortize
  across every proof made against the same model.
- **Matmul claim proofs are side-linear, not area-linear** (the
  compression pays off): ~2,200 claims for the full pass at ~1-3 s each
  on Route Z — an hour-scale term that Route R's r -> 1 collapse turns
  into minutes.
- **Elementwise gadgets** (M2) add O(elements) work and, more
  importantly, the bit-tensor commitments already counted above.
- The pairing track at this scale is prover-bound at ~28 us per witness
  element (measured at n = 2048): ~60 CPU-hours per pass, ~2 GPU-hours
  with GPU MSM. It stays the verification/proof-size track, not the
  LLM-scale proving track.

## 3. The lever stack (lattice track, cumulative, measured anchors)

| Stage | 7B/512-token prover (est.) | x CPU-int8 inference | x A100 |
|---|---|---|---|
| Today: Route Z CPU + M0-M2 gadgets | ~3.6 h | ~1,900x | ~3x10^5 |
| + Tier-1 kernels (ternary add/sub commits, IFMA, deeper blocking; ~3x) | ~1.2 h | ~630x | ~10^5 |
| + Route R ring lift at k=2 (r: 64 -> 1 on proofs; ~2-3x on commit ops -- corrected from ~15x by ROUTE_R_DESIGN.md: q = 5 mod 8 caps CRT splitting at one level, no full NTT; proofs to ~50-175 KB) | ~2-4 min | ~20-35x | -- |
| + Route R Q2/Q3 (response decomposition to a 32-bit q; deeper k-split with real NTT) + GPU integer GEMM *(superseded by the measured row below)* | **~15 s** | **~2x** | ~300x |
| **MEASURED (Q2/Q3/A2 tranche, RING_MULT_BOTTLENECK.md Section 6): k = 8 split + Karatsuba at q31 -- commit kernel 8.1x, commit bill ~34x vs Route Z (~6.6 min CPU-22T, ~20 s with the GPU 20x row); total pass ~25-45 s with GPU** | ~25-45 s | ~4-6x | -- |
| **+ A1 aux-modulus NTT (INTEGRATED-MEASURED: 6.2-6.4x over k8+Kara head-to-head at FFN shape inside ring_lattice, ~99-111 ns/committed element; commit bill ~~~1.6-2.0 min CPU-22T~~ -> ~5-6 s GPU; proofs bit-identical)** | **~15-30 s** | **~2-4x** | ~300x |
| **M5-lite CORRECTION (MEASURED end-to-end, full 512x4096x11008 triple streamed under the chunked CRS, M5_LITE_REPORT.md): 117 ns/paid element 1T; 22T scaling 8.7-9.1x MEASURED (was ~15x assumed); element count now GENERATED from the statement DAG (1.389e10 paid — statement-inventory update below) -> commit bill 3.1 min 22T; pass ~3.5-3.7 min CPU; the ~15-40 s row survives ONLY via the [ASSUMED] 20x GPU factor** | ~3.5-3.7 min CPU / ~20-40 s [GPU ASSUMED] | ~30x CPU | -- |
| **+ M4 activations via LogUp-GKR (lookup CORE built, U-K1..K7 batteries green; the U-K8 integration exit is OPEN — audit 2026-07-10 H-01): commit +~0 dce/el (the M4 verdict's axis — held exactly in the U-K6 committed rig); prover core as-built 10.8-10.9 us/el 1T [MEASURED-AT-RATE, unmasked/uncommitted microbenchmark] = ~1.95 ks/pass 1T; the 22T (~222 s) and GPU rows are [ASSUMED] — the lookup code is single-threaded and the factor is imported from the M5 commit kernel. The [MODEL] ~0.5-1 us/el needs U-K9 (kernel-grade K-mults). Still dominates piecewise on both axes. **ZK UPDATE (2026-07-10): U-K5a..e LANDED — the lookup transcript is masked (HVZK at subprotocol level, E3Z battery green, engine-scale m-recovery closed); mask material 2311 K-elems/pass = ~37k committed coefficients [noise class], masked transcript 150 KB/pass [LKP-7], pass-level prover delta sub-percent (descent core x2.0 measured, O(N) vs the tensor weight-expansion)** | activations: ~1.95 ks 1T [MEASURED-AT-RATE core] / ~222 s 22T [ASSUMED] -> ~10-25 s after U-K9 [MODEL] | -- | -- |
| + bit-packing / lookup-based ranges (2-4x on gadget commitments; the SAME U-K engine — priced in M4_LOOKUP_LITERATURE Section 3) | ~5-10 s | ~1-1.5x | ~100-200x |

Reality checks on the endpoint:

- **~2x quantized CPU inference is a defensible target**, because the
  prover's kernels are the *same arithmetic class* as quantized
  inference (integer GEMMs), just over ~61-bit words with a ~(k+N)/cols
  commitment blow-up that Route R and packing mostly absorb.
- **The gap vs A100 float inference is an engineering question, not a
  hard floor.** The naive argument ("61-bit modular arithmetic has no
  tensor cores") caps this family at ~10^2 vs A100; but Route R drops q
  to one 32-bit-class limb, and RNS/limb decomposition can map modular
  GEMMs onto int8 tensor cores (~16 int8 GEMMs per 30-bit modular GEMM,
  as in tensor-core NTT work). Under that mapping the ops accounting of
  Section 3b applies on-GPU and low-single-digit factors become
  conceivable even against tensor-core inference. Unproven anywhere at
  this scale; tracked as research-engineering, not assumed in the table.
  Small-field hash-based systems (sumcheck/FRI/Binius lineage; zkLLM at
  ~15 min for 13B) remain the alternative frontier, without PQ hiding.

**Route R spike update (ROUTE_R_DESIGN.md):** the spike verified the
ring lift end-to-end (working r=1 prototype, quinary challenge set
after finding ternary-at-d=128 misses the FS budget by ~54 bits, a
ct-engine design for the scalar-claim soundness gap) and corrected two
assumptions: commit-op savings at the recommended k=2 split are ~2-3x,
not ~15x, and the elementwise gadget family lands at ~17 us/element
(meeting the M2 criterion by design, ~6000x below Route Z's measured
108 ms). Consequence: Route R at k=2 reaches ~20-35x CPU-int8
inference; the 2x endpoint is now gated on the spike's Q2 (response
decomposition -> 32-bit modulus) and Q3 (deeper CRT split -> real NTT),
both scoped in the design doc.

**Q2/Q3 tranche update (measured; RING_MULT_BOTTLENECK.md Section 6):**
Q2 and Q3 are implemented and verified jointly feasible at a 31-bit
single-limb modulus: (k = 8, q = 2^31 - 399, digit base 2^e, e in
{2, 3, 4}), with the k = 8 LS18 margin at 1.30x over quinary challenge
differences and the C2 floor (2^29.5) above the k = 8 LS18 minimum
(2^28.07) -- the coupling risk is retired. Measured on this machine:
commit-kernel 8.1x over the naive baseline (1.11 us/ring-MAC
single-thread, k = 8 + Karatsuba amortized-split GEMM), commit bill
~34x below Route Z (~6.6 min at 22T, ~20 s with the GPU 20x row).
Q2's price: +45% proof bytes at e = 4 (117 -> 170 KB at Pi2 n = 2048)
for a 46% smaller commitment stream (22.3 -> 12.1 KB/column). ~~The
~15 s / ~2x endpoint now rests on A1 (auxiliary-modulus NTT, parallel
tranche, results pending): without it the measured stack lands at
~25-45 s (~4-6x CPU-int8).~~

**A1 integration update (measured; RING_MULT_BOTTLENECK.md Section 6.5,
A1_AUX_NTT_REPORT.md Section 5 actuals):** the auxiliary-modulus NTT
kernels are integrated into the Route R prototype (commit path, mask
commitments, all three Sigma rounds, verifier; proofs bit-identical to
the split-kernel paths, capacity policy wired into the parameter chain
as the P0 line). Integrated commit kernel at the FFN shape:
0.161-0.195 us/ring-MAC (84-102 eff GMAC/s single-thread), 6.2-6.4x
over k8+Karatsuba head-to-head; at q31 the whole commit bill (bit AND
value tensors) rides the single-prime golden regime. Commit bill:
~~~1.6-2.0 min at 22T CPU~~ *(superseded by the M5-lite measurement
below)*, ~5-6 s under the assumed 20x GPU row; pass total
~~**~15-30 s (~2-4x CPU-int8) with GPU** — the arithmetic layer of
this ladder rung is now measurement, not projection.~~ Remaining
assumptions at that point: the 20x GPU factor and the ~15x multithread
scaling — the second of which the M5-lite measurement has now
FALSIFIED for this box.

**M5-lite update (MEASURED end-to-end at FFN matmul dims;
M5_LITE_REPORT.md, results/m5_bench_ffn_s{1,2,3}.txt):** wide-object
chunking (a layout-only change — the 17-124 GB monolithic wide CRS
becomes one 2.4 MB msg_r = 32-class CRS) made the first REAL
full-shape run possible on this machine: a complete 512x4096x11008
triple (22,528 column commitments, 5.27e7 ring-MACs) streamed at
**117 ns/paid element end-to-end single-thread** (the 99-111 ns
kernel anchor + streaming overhead, peak RSS 94 MB) and — the
correction — **8.7-9.1x measured 22-thread scaling, not the ~15x this
section assumed.** Pass total on CPU: commit + claim layer with R1
pads counted; activations per the M4 lookup design stay noise-class
[MODEL]. The "~1.6-2.0 min at 22T" row above therefore did NOT hold
on this hardware — its single-thread arithmetic was right, its
parallelism assumption was ~1.7x optimistic. The ~15-30 s pass rung
now rests entirely on the unimplemented GPU row (audit H-03).

**Statement-inventory update (GENERATED count, 2026-07-10,
statement-integrity tranche):** the per-pass committed-element count
that every commit-bill row above multiplies is no longer a two-model
band. The old 9.4e9 vs 1.33e10 disagreement (1.4x) traced to both
numbers being divisor round-trips of the SAME modeled 1.5e14-MAC
total (divided by ~16k and ~11.3k MACs/element respectively — neither
was an inventory). The single replacement number is generated from
the validated statement DAG: `ring_matmul statement-inventory` builds
the 32-layer FFN-surrogate statement frozen in TARGET_CONTRACT.md
(validated Statement v2: shapes, quantization, range/narrowing facts,
consumption all machine-checked) and counts **1.351e10 used /
1.389e10 paid committed elements per pass** (q31 values 2.0e9, q46
range bit planes 1.15e10; weights 4.33e9 one-time). At the measured
M5 rates the commit bill reads **1631 s 1T / 187 s = 3.1 min at 22T
[MEASURED-AT-RATE]**, ~9.3 s only under the still-[ASSUMED] 20x GPU
row; pass total on CPU ~3.5-3.7 min at 22T. The plane family
dominates the count — the lookup-based range row below (2-4x on
gadget commitments) is the standing reduction lever, unimplemented
for ranges today. Details and the wrong-number autopsy:
M5_LITE_REPORT.md Sections 4-5.

## 3b. The 2x-overhead decomposition (refined target)

The project target is prover <= 2x the feedforward it certifies, on
comparable hardware. Decompose prover overhead as
(extra ops) x (arithmetic throughput ratio):

- **Proof ops are side-linear, not area-linear** — measured: a Pi2 claim
  at n = 2048 proves in ~1.3x the mod-q matmul, and the *proof* portion
  shrinks relative to area as matrices grow; after Route R (r: 64 -> 1)
  it is a few percent of inference ops. The "proving each component is
  cheaper than computing it" intuition is correct for this portion.
- **Commitment ops per element** are the crux: ~16,000 MACs/element at
  Route Z (commit-dominance today) but **~320 MACs/element after Route R
  ring packing — i.e. 3-8% of the 4096-11008 MACs/element the
  feedforward itself spends at LLM widths.** At LLM dimensions the
  commitment bill is intrinsically a small fraction of compute; this is
  what makes the 2x target principled rather than hopeful.
  *(Measured update, Q2/Q3 tranche: k = 8 + Karatsuba at q31 lands at
  ~950-1,070 mults/element (0.63 us/element single-thread);
  RING_MULT_BOTTLENECK.md Section 6.4.)* *(A1 integration update: the
  amortized aux-NTT commit kernel, now integrated into the Route R
  rounds, measures ~99-111 ns/element = ~119 helper-prime
  multiplications per committed element at the FFN parameter point —
  the few-hundred-MACs/element condition is MET, measured in-protocol;
  RING_MULT_BOTTLENECK.md Section 6.5.)*
- **Throughput ratio**: witness computation can run in native int8 (the
  prover runs ordinary quantized inference and encodes mod q only inside
  crypto kernels); commit/proof kernels at 32-bit-class modular
  arithmetic run at ~1/2-1/4 of int8 SIMD throughput. Net commit cost:
  ~16-31% of inference time.
- **The condition that decides it: range-proof machinery.**
  *(M2 measurement update: on Route Z the binding constraint is the
  gadget proofs themselves, not the commitment bill — measured ~108
  ms per range-proved element, see M2_REPORT.md Section 4. The 2x
  budget for elementwise work is reachable only after Route R; the
  packed/LNP22 commitment argument below then applies on top.)** With naive
  per-bit decomposition (w = 12 on ~40% of tensors) the commit bill
  grows ~5.8x and the total lands at ~3-4x inference. With packed bits
  or LNP22-style range proofs (no full decomposition), the 1.5-2.5x
  target holds. Range-proof design is therefore a first-class
  performance requirement, not a detail.
- **Parallelism and pipelining**: proving parallelizes as well as
  inference (GEMM-shaped throughout), so it changes wall-clock, not the
  overhead factor — with one exception in our favor: with per-layer
  transcript segmentation (each claim's challenges bind the commitments
  it references and everything earlier, instead of the current
  all-commitments-first rule), layer-l proving pipelines behind
  layer-(l+1) inference. With ~2x hardware, added *latency* approaches
  zero even while total work is ~2x. This segmentation is sound if the
  binding order is enforced per claim; adopt it in M5's DAG design.
- **Memory is the other wall**: ~5 GB of activations plus w-times that
  in bit tensors per pass. Streaming/wave-scheduled commitment (the M5
  item; the machinery exists since tier-0) is mandatory, not optional.

## 4. Sequencing and time estimates

Working-time magnitudes at the pace this project has actually sustained
(autonomous agent runs + review):

| Phase | Contents | Estimate |
|---|---|---|
| M2 (in flight) | elementwise gadget family, both tracks | days |
| M3 | ReLU + FFN block end-to-end (composition of M0-M2 pieces) | ~1 week |
| M4 | exp/softmax primitive decision + attention block | 2-4 weeks (the main research risk) |
| M5 | multi-layer DAG, streaming witnesses, first full small-transformer proof | 2-4 weeks |
| Route R | ring lift of the lattice track (the 15-50x lever) | 4-8 weeks (one real design point: general A-maps over the ring) |
| GPU kernels | integer GEMM commit/prove backends | 2-4 weeks, parallelizable with Route R |

Cumulative: **first end-to-end small-transformer proof in ~1-2 months;
7B-forward proofs in minutes on one workstation in ~4-6 months;
the ~2x-of-CPU-inference endpoint in ~6-12 months.** Main uncertainties,
in order: the exp/lookup primitive (M4), Route R's A-map design, GPU
modular-kernel engineering, and the risk that range-proof coverage in a
real quantized spec exceeds the 40%-of-tensors assumption (each +10%
coverage adds ~10% to the commit bill at w = 12).

## 5. What to claim along the way

At every stage the honest public claim is: *verification is cheaper than
re-running the model* (true today) and *proving costs Nx the quantized
inference it certifies* (N falling from ~2,000 to ~2 across the lever
stack). Never claim proving beats inference outright — it can't — and
always name the baseline hardware and the quantized-spec caveat from
TRANSFORMER_PROOF_PLAN.md Section 1.
