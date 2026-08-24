# U-PERF3 — the headline within the lattice line: what 5-15 s at 8B would take (design/literature memo, no code)

Status: SKELETON (2026-08-18, U-PERF3 round 1, lane T, worktree
wt-uperf3-t). Sections are filled and committed one at a time; the
"Agent T status" block in PROGRESS_UPERF3.md says which are done.

Scope: Victor's ruling of 2026-08-18 ("be more creative and find a
solution anyway") applied to the lattice line (Route R: MLWE/MSIS
commitments, exact-integer range facts, masked lookup, HVZK for the
declared private set). Question: the line measures 21.0 s for the
12x512 slice (1.4e9 proven int8 MAC/s, laptop GPU + 8 threads); the
contract needs 1.9-5.8e11 MAC/s (5-15 s at 8B x 512); the counted
route-1 change (U_PERF3_OPENING_LAYER_DESIGN.md Stage A/B) buys
<= ~2.5x; the eval proof (the lattice opening) is the floor and scales
~x100. What moves the exponent while keeping the assumption class?

Labels: [MEASURED] / [COUNTED] / [MODEL] / [ASSUMED] / [EXTERNAL]
(external numbers are unverified unless from a paper with code).

## 0. Recommendation (one paragraph)

(to be written last)

## 1. The built pass located in the family map, and what scales x100

### 1.1 Which family the built pass IS (precisely, with the build reports)

AGGREGATION_LITERATURE.md named five families and recommended the
combination "(c) PCS reroute + (b) cross-layer folding + (a) as the
compression layer". What U-AG-B1 actually built, report by report:

- **The commitment layer and the claim collapse are family (c), built.**
  Two global commitment groups per pass (T_W, T_act), each bound by ONE
  outer identity `u_0`, exactly one batched opening per group (E-O2-BB;
  UAGB1_PASS_AGG_REPORT.md Sections 2.1-2.3). Every claim class —
  the 3 matmuls, Hadamard, 4 requants (8 folded IXF instances), the
  X/z public binding, and since wave 4 the table-membership facts
  (the 10 descent pairs' end pins, UAGB1_TABLE_DESCENT_REPORT.md
  Section 2.3) — reduces to MLE-evaluation claims folded into the
  group b_rows. Obligation O-3 (claim-class reduction) is DISCHARGED
  in code for the full statement; the wave architecture the old byte
  wall lived in is gone (openings 7.9 GB -> 0.36 MB of group blocks).
- **The opening is family (a) machinery WITHOUT family (c)'s sqrt
  serving.** Each group's eval proof is the LaBRADOR-form recursion
  (adaptive bases, 8-10 levels, masked floor) applied to the FULL
  group: its level 0 walks all n_0 digit rings with the Theta(n_0 x r)
  h cross-garbage at the byte-optimal r = 64 (finding BG-F3), and the
  verifier's level-0 term is O(n_value_rings) scalar MACs (T8b
  factored form). Greyhound's defining move — serve the evaluation
  from a two-tier structure so the expensive argument only ever sees
  an O(sqrt N)-sized relation — was never built. This is the single
  structural difference between the built pass and the family-(c)
  architecture the literature review recommended, and Section 1.3
  shows it is exactly the part that scales worst to 8B.
- **The lookups are the M4 LogUp-GKR engine over K = GF(q^16)**: 10
  per-table folded masked descent pairs, 45 real witness trees, 2,367
  round polynomials at 12x512 (UAGB1_TABLE_DESCENT_REPORT.md Section
  1.1) — the object the U-PERF3 opening-layer design memo (Stage A)
  replaces with base-field booleanity + LogUp-as-one-sumcheck.
- **Family (b) folding is ABSENT.** The 32-layer axis is handled by
  IXF instance-folding — a sumcheck claim-batching move in which every
  layer's witness is committed, summed over, and OPENED simultaneously
  in the same two groups. Nothing is accumulated; no witness ever
  leaves scope. The recommended-verdict slot "(b) as the cross-layer
  accumulator" is empty in the build, and with it the property that
  the expensive opening could be paid on a one-layer-sized object.

So the built pass = family (c)'s commitment/claim architecture +
family (a)'s compressor used as a full-witness opening + the M4
lookup engine, with no (b). The two design consequences: the prover
floor inherits Theta(n_0 x r) K-class work and the verifier inherits
O(n_value_rings) — both linear in the TOTAL witness of all 32 layers.

### 1.2 What scales how, 12x512 -> 8B x 512 [COUNTED, lane R]

From U_PERF3_MVP8B_SCALING.md Sections 1-2 (the m8b scaling model,
`--check`-verified against `table-descent expect 12 512`), for the
MVP-1 shape 32 x 512 x d4096 x f14336 = 2.89e12 int8 MACs (x99.6):

| quantity | 12x512 | 32x512 8B | factor |
|---|---:|---:|---:|
| weight group n_0 (digit rings) | 3,538,944 | 352,321,536 | x99.6 |
| act group n_0 | 7,854,476 | 145,475,764 | x18.5 |
| level-0 h cross-garbage Theta(n_0 x r) (ring-mults) | 0.73e9 | 30.7e9 | **x42** |
| level-0 verifier MACs (n_value_rings x 16 x n_contrib) | ~8.6e9 | ~3.5e11 | **x41** |
| CRS expansion words | ~2.1e6 rings | ~9.0e7 | x43 |
| descent leaf elements (K-work driver) | 172.0M | 3.42G | x19.9 |
| descent K-mults | ~5.5e9 | ~1.1e11 | x20 |
| zero-check tables (nf) | 2^24 (1.07 GB) | 2^28 (17.2 GB, over the K9 2^25 cap: W-1) | x16 |
| peak descent pair (1.75U) | 5.6 GB | 120 GB | x21 |
| w0 store / A_0 CRS / BfLayer | 1.5 / 2.1 / 8 GB class | 63.7 / 94.8 / 66 GB | x40-45 |
| artifact (P0) | 1,509,911 B | 1,937,432 B | x1.28 |

Two scaling laws and one gate: the weight side x100, the act side
x19, the OPENING-LAYER terms x41-43 (they blend the two through n_0
and n_value_rings). The act group FAILS the level-0 exact-digit gate
unsplit at 32x512 (-0.31 bits, W-3) and must split 2-4 ways as built.

### 1.3 The 8B wall, phase by phase [MODEL from the measured 12x512 attribution x the counted factors]

12x512 measured (WSL-BOX 8T + RTX 4070 Laptop, QUIET): wall 21.0 s =
commit 2.5 / prove-group 7.1 / descents 6.5 / claim 1.75 / transport
1.4 / CRS 1.3 / verify 1.7 [MEASURED].

| phase | 12x512 [MEASURED] | scale driver [COUNTED] | 8B laptop [MODEL] |
|---|---:|---|---:|
| commit (u_0, chain GEMM, digit witness) | 2.5 | n_0 x44 blended; chain GEMM weight-side | ~110-160 s |
| prove-group (level-h 1.87 / kernel-rows 1.77 / psi0 1.57 / fold 0.85 / matvec 0.80) | 7.1 | x41-42 (h-garbage, value rings) | ~290 s |
| descents | 6.5 | leaves x19.9; ~78 s IF device-resident — the 120 GB peak pair does NOT fit 8 GB VRAM | ~80-300 s |
| claim layer | 1.75 | tables x16 + W-1 window splits | ~30-40 s |
| transport | 1.4 | x~40 | ~55 s |
| CRS expand | 1.3 | x43 | ~55 s |
| verify (8T) | 1.7 | x41 | ~70 s (1T: ~10 min) |
| **wall** | **21.0** | | **~690-980 s = 11-16 min** |

On a <= 450 W desktop board (4-6x this laptop part [MODEL], decision
memo route 3): **~2-4 min** — consistent with the decision memo's
2-8 min band. Rate: 2.9e12 MACs / 120-240 s = **1.2-2.4e10 proven
MAC/s**; the contract's 5-15 s needs 1.9-5.8e11 — a **~10-50x gap on
the desktop board** [MODEL]. Stage A/B of the opening-layer design
buys <= ~2.5x of it; the residual 4-25x lives almost entirely in the
x41-43 rows above: prove-group + transport + CRS + the u_0/chain part
of commit — i.e. **the full-witness opening layer** — plus the
descents' K-field pass (which Stage A already removes). That is the
exponent this memo's candidates must move.

## 2. Candidates, with counts

### 2.1 (i) The full family-(c) O(sqrt N) reroute of the eval proof

**What changes.** The commitment layer, u_0, h0_agg, the claim layer,
and the descent replacement (Stage A) all stay. Per group, the opening
is re-architected in the Greyhound shape (AGGREGATION_LITERATURE.md
Section 3.1): view the group's digit rings as an ~sqrt(n_0) x
sqrt(n_0) matrix (weight 8B: 18,770^2; act: 12,061^2, or ~6,030^2
per split subgroup); commit each column under an inner Ajtai
commitment (the CRS is two seed-expanded matrices of sqrt-class
width, not today's kappa x chunk level-0 monster); to open the batched
MLE claim at the aggregate's point x*, the prover sends the
challenge-folded row `w = sum_i c_i row_i` — ONE weighted pass over
the n_0 rings — and the verifier checks the outer relation on
sqrt-sized objects; the norm/well-formedness of `w` and the inner
commitments is then proven by the EXISTING LaBRADOR-form recursion,
whose input is now an ~sqrt(n_0)-ring relation (~19K rings) instead
of 352M. The recursion we already built and audited becomes the
compressor family (c) always intended it to be.

**Counted/modelled cost at 8B.**

- Prover: the fold pass is ~5.0e8 ring-scalar mults over both groups
  = ~6.4e10 base-mults [COUNTED from n_0 x D]; at the A1 kernel
  constant (~0.16-0.20 us/ring-MAC class) ~90 s 1T, ~12-15 s 8T,
  seconds-class on the GPU GEMM path [MODEL]. The recursion on ~19K
  rings is floor-class immediately (~1 s). Replaces the ~290 s
  prove-group + most of the ~55 s transport [MODEL]. Commit is
  UNCHANGED (the inner commitments are the same Ajtai matvec volume
  as today's u_0/precommit class).
- CRS: the 64.4 + 30.4 GB level-0 matrices and the ~55 s `crs-expand`
  shrink to sqrt-class objects (MB, sub-second) [COUNTED from the
  two-tier shape].
- Verifier: O(sqrt n_0) ring ops + polylog rounds — ~2-4e4 ring-mults
  class, MILLISECONDS at 1T [MODEL] — against the built ~3.5e11 MACs
  (~10 min 1T) at 8B. This is the only candidate that makes the 8B
  verifier <= 2 s at 1T with room, closing T11 a' without the
  supplied-Psi_0 novelty (the Stage-B new-crypto item can be retired
  in favor of a published construction class).
- Bytes: the two ~185 KB group blocks become Greyhound-class
  evaluation proofs (53 KB at 2^30 published [EXTERNAL]; call it
  55-200 KB total for both groups incl. the norm layer) [MODEL].
- The W-3 repair, free: the exact-digit gate is gamma_z ~ 2^(e0-1)
  sqrt(n D) over the OPENED object; two-tier objects are sqrt-sized,
  so the act group's 8B failure (-0.31 bits flat) turns into ~11-12
  bits of headroom per tier [MODEL from the sqrt-n law of
  U_PERF3_MVP8B_SCALING.md Section 1.2] — no act split, no r-search
  panic class (W-2/W-3 dissolve structurally at any future shape).

**Soundness obligations.** O-1: parameter re-derivation at D = 128 /
q31 (Greyhound publishes at degree-64 rings; challenge operator norms
and two-tier binding at our 8-slot CRT are the "review burden, not
new math" friction already priced in AGGREGATION_LITERATURE Section
3.2, now on the critical path). O-7: knowledge error of fold +
recursion (the PSS pattern covers the recursion half — built and
audited already). O-4: ZK — no published ZK for Greyhound-class
evals (AGGREGATION_LITERATURE Section 9); the house answer is the
Tier-Z-style masked response ALREADY built for the floor (the P2
weight-floor machinery masks exactly this kind of object), extended
to the folded row `w`; a re-derivation on built machinery, not a new
primitive. Exact-integer soundness: untouched (the digits, ranges,
and U-L link live above the opening).

**Build size.** 3-5 tranche-weeks [ASSUMED]: a new opening driver in
eval_proof.rs behind a statement-version selector, the migration
battery of U_PERF3_OPENING_LAYER_DESIGN.md Section 4, planner freeze
rows re-derived. The biggest single re-architecture on the lattice
line, and the one the design memo declared out of scope for Stage A/B.

**Honest expected factor.** Prover ~2-3.5x over the built 8B pass
(with Stage A composed: ~3-5x); verifier 1T >100x (minutes ->
sub-second); artifact ~2-3x smaller; memory: removes the A_0
matrices (-95 GB) and the level-1 witnesses (-46 GB) from the peak.
NOT 5-15 s alone: lands the 8B pass at ~40-90 s on one desktop board
[MODEL].

### 2.2 (ii) Folding across the 32 identical layers

**What changes.** The per-layer FFN relation (3 matmuls + Hadamard +
4 requants + ranges/lookup, one layer's weights and acts) becomes THE
instance; a LatticeFold-class scheme (LatticeFold ePrint 2024/257;
LatticeFold+ 2025/247; Neo 2025/294; Cyclo 2026/359 [EXTERNAL])
accumulates the 32 instances into one running instance; ONE decider
proof — the current machinery at one-layer size — closes the pass.
Per fold: commit the incoming layer's witness (Ajtai, paid once per
layer regardless), one fold sumcheck over the layer hypercube
(~2^22-2^23), a range check on the INCOMING witness only (Cyclo's
design: no accumulator norm checks, additive norm growth per fold
[EXTERNAL, abstract]). One 8B layer [COUNTED, lane R's 1x16 rung
scaled to T = 512]: weight 11.0M digit rings, act ~4.5M, zero-check
tables 2^23 (under every cap).

**Counted/modelled cost at 8B.**

- Prover: total commit work UNCHANGED (~110-160 s laptop class —
  every witness element is committed exactly once, fold or no fold);
  32 fold sumchecks ~1e10 base-field MACs total ~10-30 s [MODEL];
  the decider = today's opening at ~15.5M rings: prove-group ~290/32
  ~ 10 s, transport/CRS /32. Net prover ~1.5-2.5x over built+Stage A
  — the win OVERLAPS candidate (i)'s (both shrink what the expensive
  opening sees).
- Memory — the real prize: the peak becomes one layer + accumulator +
  tables ~4-8 GB [MODEL] instead of lane R's 63.7 GB w0 + 94.8 GB A_0
  + 120 GB descent pair. **The 8B pass would FIT the WSL box and any
  32 GB desktop**, and MVP-1's Mac-only constraint disappears. No
  other candidate does this.
- Verifier: 32 fold-verifies (~ms each) + the decider verify at layer
  size ~1.1e10 MACs ~20-30 s 1T [MODEL] — still needs (i) on the
  decider for the <= 2 s line.
- Artifact: 32 fold messages (~4-8 KB each) + one layer-sized decider
  ~0.5-0.7 MB [MODEL].

**Norm growth vs q31/q46 — the load-bearing question.** Folding
multiplies witnesses by small-norm challenges and adds: naive growth
is multiplicative per fold and would blow the exact-digit gate.
LatticeFold re-decomposes each fold (extra O(N) work); LatticeFold+
avoids it via a monomial-embedding algebraic range proof — which is
EXACT set membership, i.e. the same fail-by-design guarantee class as
our range facts; Cyclo keeps growth ADDITIVE per fold within a
bounded fold count [EXTERNAL, abstracts]. Our budget [COUNTED-class]:
one-layer groups sit ~2.5-3 bits under gamma_max by the sqrt-n law —
a ~6-8x total growth allowance over 32 folds. Cyclo's regime claims
exactly this; at our parameters it is UNVERIFIED and would be this
candidate's spike question.

**Soundness obligations.** A reduction-of-knowledge lemma chain —
genuinely new for the house (no in-repo precedent; the O-7 class but
for folding); the exact-integer facts must survive the fold (LF+'s
range proof is exact — good fit — but re-derivation at q31/q46 with
the U-L link is owed); ZK: NO published ZK lattice folding
(LatticeBlindFold is blog-stage [EXTERNAL]) — the masked-sumcheck
machinery covers the fold sumchecks, the fold messages need a
simulator (O-4 class). FS ordering of fold challenges after pad
commitments (the WSMD 3.4 extension flagged in
AGGREGATION_LITERATURE Section 2.3).

**Build size.** 5-8 tranche-weeks [ASSUMED]. Maturity: paper-only
lineage BUT a Rust PoC now exists (NethermindEth/latticefold, LF +
LF+ [EXTERNAL]) — AGGREGATION_LITERATURE Section 9's "no
implementation or library for lattice folding" is STALE as of 2026.

**Honest expected factor.** Prover ~1.5-2.5x (overlapping (i));
memory peak ~20-30x smaller; artifact ~3x; verifier neutral without
(i). Its unique value is the MEMORY architecture and the streaming
story (prove layer k while layer k+1 computes), not the raw clock.

### 2.3 (iii) Batching the level-0 claims beyond the R-row

**What changes.** Inside the BUILT opening: (T11 b) reduce every
claim to ONE point per group so the planner's r can fall below the
64 cap (r = 32 halves the h cross-garbage; r = 16 quarters it), plus
one point shared ACROSS the two groups where the claim structure
allows; (T11 a) feed level-0 from the rank-structured Phi_0. At 8B
[COUNTED]: h-garbage 30.7e9 -> 15.3e9 (r 32) -> 7.7e9 (r 16)
ring-mults, i.e. the ~79 s level-h class term -> ~40 -> ~20 s laptop
[MODEL]; bytes grow at the floor (spike S3 of the design memo prices
it; the artifact has 2-4x headroom under its gate). Verifier: one
point per group collapses n_contrib in the O(n_value_rings x 16 x
n_contrib) formula -> ~1-3e10 MACs, ~10-30x — but still LINEAR in
n_value_rings: ~30-60 s at 1T at 8B [MODEL], not <= 2 s.

**Soundness obligations.** None new beyond Stage B's already-listed
items (the RLC-to-one-point batching is standard; the r re-derive is
planner work with freeze rows both directions).

**Build size.** 1-2 tranche-weeks (design memo Section 6.3 lane 3).

**Honest expected factor.** <= 1.3-1.5x prover at 8B, ~10-30x
verifier-but-still-linear. VERDICT: not a standalone route — it is
the FRONT HALF of candidate (i) (the sqrt reroute requires exactly
this one-point reduction to serve all claims from one fold), and it
should be built as such, not as a destination.

### 2.4 (iv) GPU-native restructuring: serial vs parallel, desktop board, N boards, the field

**What is inherently serial.** Only the Fiat-Shamir spine: each
sumcheck/descent round's challenge depends on the previous round's
absorbed polys. At 8B that is ~4,659 descent rounds + ~200 claim
rounds + 10-20 eval-proof levels (or ~50 aggregate rounds + the fold
under Stage A + (i)) [COUNTED, lane R Section 1.4]. At ~10-100 us of
launch/absorb latency per round the serial spine is **< 1 s total**
— at 12x512 the CPU-tail rounds were a real cost (1,134 tiny rounds),
but at 8B every round body is e8-e9-class work. The pass at 8B is
compute-bound, not latency-bound: Amdahl's serial fraction is < 1%.

**What is embarrassingly parallel** [COUNTED structure]: the 10
descent pairs are mutually independent (and vanish under Stage A);
the 2-5 commitment groups are independent; within a round the
hypercube body (3.42G leaves; 2^28 zero-check tables) is data-
parallel; the level-0 h-garbage and the (i)-fold are GEMM/AXPY
shapes; commit matvecs and chain GEMMs are GEMM; CRS blocks are
seed-expanded independently (lane R's W-8(b) block form is exactly
the streaming-friendly shape). Multi-board split: by layer (32 ways)
for commit/descents/zero-checks, by tile for the GEMMs, by group for
the openings; the only cross-board traffic is the per-round
round-poly reduction (KB per round, ~MB per pass) and the transcript.

**What a desktop board buys [MODEL].** The measured 12x512 chain
runs the K-field kernels at 70-88% of the 4070 Laptop's ~1.7 G
kmul/s register ceiling (U_PERF2_GPU4_REPORT.md) — a <= 450 W
desktop part (4090/5090 class) is **4-6x** on this mix (cores 3-4x,
bandwidth ~10x for the link-bound half; decision-memo route 3,
unmeasured). Four boards on one machine: ~3-3.5x more (near-linear
on a > 99% parallel pass), i.e. **~12-20x over the laptop part
combined** [MODEL]. VRAM (16-32 GB/board) binds only through the
descent trees (gone under Stage A) and A_0 (gone under (i); streamed
blocks under W-8(b) otherwise). Note the field interaction: Stage A
moves the bulk arithmetic from 363-op GF(q^16) mults to int32
base-field MACs — the GPU-native lever and the Stage-A lever
MULTIPLY (cheaper ops AND better-shaped kernels). Precedent that
transformer-proof workloads parallelize on GPUs at scale: zkLLM's
CUDA sumchecks and Attestable's claimed single-H100 full-model rate
[EXTERNAL, Section 2.5/refs].

**Soundness obligations.** NONE — hardware and scheduling only.
**Build size.** The route-3 port + harness: 1-2 tranche-weeks for
the desktop CUDA port (the kernels exist), more for Metal;
measurement gated on quiesced hardware we own (the desktop board is
a purchase decision for Victor). **Honest factor: 4-6x one board,
12-20x four boards [MODEL, unmeasured]** — multiplies every other
candidate; moves no exponent (the verifier and memory walls are
untouched).

### 2.5 (v) The 2025-26 lattice literature that fits (all [EXTERNAL]; abstracts read 2026-08-23, none verified at our parameters)

Searched 2026-08-23 (WebSearch; IACR ePrint). What is NEW since
AGGREGATION_LITERATURE.md closed (2026-07-27), and what it changes:

1. **RoKoko** (ePrint 2026/575, Mar 2026): lattice succinct argument
   with a LINEAR prover and POLYLOG communication and verifier;
   ~200 KB proofs; claims **100x faster verification than Greyhound
   at similar prover time**; refines RoK-and-Roll (ASIACRYPT 2025)
   by committing to cross-terms instead of sending them ("committed
   refinement"), generalizes LaBRADOR's double-commitment into
   recursive commitments, and **natively supports tensor-structured
   relations — polynomial evaluation and SUMCHECK relations**. If it
   re-derives at D = 128 / q31, this is candidate (i)'s serving
   layer with a polylog (not sqrt) verifier and a published
   construction to cite. The strongest single fit found.
2. **Hachi** (ePrint 2026/156, Feb 2026): lattice multilinear PCS,
   Module-SIS, sqrt-class verifier, ~55 KB proofs, claims 12.5x
   faster verification than Greyhound via sumcheck + ring-switching;
   AND a generic reduction converting evaluation claims over
   EXTENSION FIELDS F_{q^k} into cyclotomic-ring statements — our
   batched claims live in K = GF(q^16), so this reduction is
   directly the shape of our claim seam. Candidate (i) at its most
   conservative (MSIS, sqrt) would follow Greyhound-with-Hachi's-
   improvements.
3. **Grand Danois** (ePrint 2026/1196, Jun 2026): polylog
   verification AND proof size — but under the vanishing-SIS (vSIS)
   assumption with STRUCTURED public parameters, plus JL-projection
   norm proofs. An assumption-class change from our MLWE/MSIS
   mandate: RECORDED, not recommended, pending independent review of
   vSIS (the GATE_ALTERNATIVES posture: mandates first).
4. **Cyclo** (ePrint 2026/359, Eurocrypt 2026): lattice folding
   improving LatticeFold+ — NO norm checks on the accumulator
   (amortized norm-refreshing, additive growth per fold within a
   bounded fold count), pay-per-bit commitments from Neo, no witness
   decomposition when folding F_q constraints; ~30 KB class proofs,
   claimed order-of-magnitude better than LF+ and faster in
   practice. Directly upgrades candidate (ii)'s cost model and
   answers its norm-growth worry in print. Related: "Improving
   LatticeFold+ with l2-norm checks" (ePrint 2026/721);
   "Verifiable Bootstrapping from Lattice-based Folding" (2026/1127).
5. **Delegated CRS folding** (ePrint 2026/551): makes the VERIFIER's
   CRS-side folding work succinct by delegating the fold of a
   seed-generated CRS to the prover with a correctness proof —
   aimed at exactly the class of cost our `ep.crs-expand` (~55 s at
   8B, paid by prover AND verifier) represents. A component idea for
   (i)'s CRS story, not a system.
6. **Implementations**: NethermindEth/latticefold — a Rust PoC of
   LatticeFold and LF+ (their benches: LF+ prover ~5x faster than
   LF). AGGREGATION_LITERATURE Section 9's rows "no confirmed
   lattice PCS beats a sqrt verifier" and "no implementation for
   lattice folding" are BOTH STALE: RoKoko/Grand-Danois claim
   polylog verifiers (unreviewed), and a folding PoC exists.
7. **The other channel, for calibration only**: zkLLM (CUDA
   sumcheck + tlookup, ~50x GPU speedups), Lagrange DeepProve-1
   (full-LLM, DAG-parallel proving), zkGPT (USENIX Sec'25),
   Attestable's vendor-claimed 53 tok/s Gemma-31B on one H100
   (~1.6e12 MAC/s class) — all hash/FRI-family, none lattice; they
   bound what hardware + sumcheck engineering achieves when the
   opening is hash-cheap, which is the calibration point for
   Section 3's honest-reach numbers.

None of 1-5 is third-party-reviewed at our ring/modulus; every
number above is [EXTERNAL, abstract-verified only].

### 2.6 (vi) Own candidates

**(vi-a) Weight-group preprocessing (per-model, off the proving
clock).** The weight group is 352M of the 498M digit rings (71%) and
the x99.6 scaling driver — yet it is a PER-MODEL CONSTANT: the same
committed weights serve every pass, and the pass already treats
weight binding as "per-model, off-the-clock discipline"
(UAGB1_PASS_AGG_REPORT.md Section 1). Candidate: compute the weight
group's commitment, inner (two-tier) commitments, and CRS blocks
ONCE per model at export/calibration time (minutes, next to the int8
calibration, Grok-runnable); per pass, pay only the (i)-fold over
the weights (~3.5e8 rings, ~seconds GPU [MODEL]) + the sqrt-sized
opening. Removes the weight share of commit (~2/3 of ~110-160 s)
and of the CRS from every pass. Soundness: a commitment is binding
whenever it was computed; the statement already pins the model by
digest chain (M125_PASS_REPORT Section 3.3 discipline; lane R W-10).
Obligations: (1) the contract wording must say what the clock
includes (it should — inference-time proving is the product story;
the calibration was never on the clock); (2) P2/Tier-Z mask
freshness: the weight-floor mask is drawn per pass TODAY and must
stay per-pass — preprocess the commitment, never the masked
response. Build: ~1 tranche-week ON TOP of (i) (it is (i)'s
serving applied with a cache). Factor: ~1.3-1.6x prover at 8B
[MODEL] and a large wall-clock UX win (the pass starts at the acts).

**(vi-b) Token-axis streaming (defer).** T = 512 is one prefill
slab; act-side folding/streaming over token blocks (the (ii)
machinery pointed at the T axis) would cap act memory at a block and
serve the decode regime. Not priced here — lane R owns the memory
architecture; noted so the (ii) design, if built, is shaped to fold
EITHER axis.

## 3. Compositions and the honest reach

(pending)

## 4. Recommendation for a second design freeze + THE ONE spike

(pending)

## 5. References (with labels)

(pending)
