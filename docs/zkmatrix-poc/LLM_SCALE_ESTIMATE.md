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
| + Route R ring lift (~15x fewer commit ops via ring packing; r: 64 -> 1 on proofs; proofs to ~50-150 KB) | ~5 min | ~40x | ~6,000x |
| + GPU integer GEMM for commit/prove kernels (~20x) | **~15 s** | **~2x** | ~300x |
| + bit-packing / lookup-based ranges (2-4x on gadget commitments) | ~5-10 s | ~1-1.5x | ~100-200x |

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
