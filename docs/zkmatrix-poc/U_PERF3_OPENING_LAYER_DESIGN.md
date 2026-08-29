# U-PERF3 — batched opening layer over the committed digits (design memo, no code)

Status: DESIGN MEMO (2026-08-18, orchestrator/Claude, no code). The
first deliverable the decision memo asks of route (1): the descent
rounds/pairs counted before and after, the transcript change priced, and
the factor modelled with its assumptions. No engine file is touched; the
one new measurement is the spike in Section 5.3/6.1.

Scope: route 1 of the 2026-08-18 decision memo in `PROGRESS_UPERF2.md`
(the lattice-line protocol change after the kernel curve flattened at
21.0 s for the 12x512 slice). Every number below carries one of
[MEASURED] / [COUNTED] / [MODEL] / [ASSUMED]; every claim about the
built protocol cites the report/section it comes from.

## 0. Recommendation

Build a **batched digit-opening layer** that replaces the ten per-table
masked descents with (a) the range/narrowing facts proved as base-field
booleanity + recomposition zero-checks on the committed digits, folded
into the existing claim layer, and (b) the SiLU lookup proved as a
LogUp-as-one-sumcheck with a committed helper `h`, so the whole
range/lookup family reduces — like the eight arithmetic instances
already do — to MLE-evaluation claims served by the SAME two per-group
lattice eval proofs (one opening per group, E-O2-BB preserved). Two
levers compose on top: (T11 b) batch the aggregate's terminal claims to
ONE evaluation point per group so the planner's `r` cap can drop the
level-0 h-garbage rows, and (T11 a/a') feed the level-0 claim functional
from the rank-structured `Phi_0` (never materialized) and — the one
genuinely new piece — let the prover supply `Psi_0` with a small
checkable sumcheck so the verifier's level-0 work goes from
O(n_value_rings) to O(log n_0).

Expected factor, staged and labelled honestly. **Stage A** (range ->
booleanity, SiLU -> LogUp-sumcheck, keep the LaBRADOR opening): the
descents (6.5 s of the 21.0 s, and 71.8% of the 1.51 MB artifact) drop
to ~1.0-1.5 s and the artifact to ~0.5 MB; prover 15.5 s -> ~10.5 s,
wall 21.0 -> ~15.5 s = **~1.35x prover, measurable, low risk**
[MODEL, from the measured phase shares]. **Stage B** (the R-row +
rank-structured `Phi_0` + one-point batching cut the eval proof's
level-0 h-garbage, and the supplied-`Psi_0` sumcheck makes the verifier
sublinear): wall ~11-12 s, and the verifier reaches the <= 2 s / 1T
line — **~1.8-2.5x prover combined** [MODEL, unmeasured; the eval-proof
term dropping is the biggest assumption]. The decision memo's "3-10x on
the prover" is the optimistic top of this range and it requires the
eval-proof opening itself to move (toward the Greyhound-class O(sqrt N)
serving of family (c), AGGREGATION_LITERATURE.md Section 3) — a larger
re-architecture than Stage A/B and out of scope for the first tranche.
None of this reaches the contract's 25-100x on its own; combined with a
<= 450 W desktop board (4-6x [MODEL]) it lands the 8B FFN shape in the
~15-160 s class the decision memo names, not the 5-15 s headline. The
lattice commitment (MLWE/MSIS, post-quantum) and the exact-integer
soundness (range facts failing by design) are preserved throughout.

Biggest [ASSUMED] items, carried into Section 5: (1) the range facts'
K-field descent arithmetic collapses to a much cheaper base-field
booleanity zero-check (the spike measures the K-mult/base-field ratio);
(2) the eval-proof level-0 h-garbage actually drops under the R-row +
one-point batching (device-bound today, may not move); (3) the
supplied-`Psi_0` verifier sumcheck is sound and cheap (new crypto, owes
a proof); (4) the aggregate sumcheck's base-field soundness closes to
the R5 knowledge-error line with challenges in a small extension.

## 1. The built protocol's cost anatomy, counted

All timings [MEASURED, WSL-BOX 8T + RTX 4070 Laptop, QUIET] from the
21.0 s attribution `fp_12x512_PQ_gpu_r1.txt` (statement digest
2f8a92f8.., EVAL 4c259008.., 1,509,911 B). All structural counts
[COUNTED] from `table-descent expect 12 512` (re-run here) and the
source. The pass has three witness-scanning phases that each read the
committed data with their own machinery: the **claim layer** (arithmetic
relations), the **descents** (range + lookup facts), and the **eval
proof** (the lattice opening). The first two produce claims that fold
into the third's per-group batched opening.

### 1.1 The descents — the object this memo replaces

`table-descent expect 12 512` [COUNTED]:

| pair | member cols | real trees | l (pad) | wit depth | tab dt | derived B |
|---|---:|---:|---:|---:|---:|---:|
| silu-m3 | 10 | 5 | 8 (3) | 22 | 9 | 118,336 |
| silu-m4 | 2 | 1 | 1 (0) | 22 | 9 | 92,480 |
| nrw-88 | 24 | 12 | 16 (4) | 22 | 9 | 129,856 |
| nrw-z | 12 | 6 | 8 (2) | 21 | 9 | 111,360 |
| rem-w5 | 4 | 2 | 2 (0) | 22 | 6 | 91,776 |
| rem-w6 | 7 | 3 | 4 (1) | 22 | 7 | 102,336 |
| rem-w7 | 10 | 3 | 4 (1) | 22 | 8 | 105,472 |
| rem-w8 | 17 | 8 | 8 (0) | 22 | 9 | 118,336 |
| rem-w9 | 7 | 3 | 4 (1) | 22 | 10 | 112,512 |
| rem-w10 | 3 | 2 | 2 (0) | 21 | 11 | 100,992 |
| **TOTAL** | **96** | **45** | 57 (12) | | | **1,083,456** |

- **10 pairs, 20 masked descents** (a witness descent + a table descent
  each), **45 real witness trees** + 12 neutral pads, table sides at
  dt 6-11 (small). Why ten, not one: BG-F1 (UAGB1_PASS_AGG_REPORT.md
  Section 1) — the real 125M statement has 2 SiLU family members and 6
  distinct remainder widths, so the shared-table fold breaks; BK-F1
  (UAGB1_TABLE_DESCENT_REPORT.md Section 1) — the monolithic dw25/26 tree
  is forbidden by two frozen gates, the LKP-2 characteristic ceiling
  (`ceiling_gate_ok`, N_inst x 64 < q caps a q31 LogUp instance at
  depth <= 24) and the audited K9 packed-table cap 2^25. Both gates are
  **base-field q31 facts about the LogUp multiset argument** — the reason
  the descents cannot simply be widened, and the first thing this design
  escapes.
- **By fact class:** SiLU (arbitrary 256-row table) = 12 of 96 cols, 6
  of 45 trees; range + narrowing (membership in `[0, 2^w)` / `[0,256)`)
  = **84 of 96 cols, 39 of 45 trees** — the bulk. This split is the
  design's fulcrum: 87.5% of the descent columns are RANGE facts that do
  not need an arbitrary-table LogUp at all.
- **Rounds** [COUNTED, `a.round-g x2367`]: 2,367 round-poly kernel
  evaluations = 1,233 device rounds + 1,134 tiny CPU-tail rounds
  (U_PERF2_GPU4_REPORT.md Section 4.4). Structure (gkr_masked.rs
  `masked_rounds_scalar`): per tree layer j a sumcheck of `j + e_bits`
  b-variables + 1 w-round, degrees `[5 if child-masked else 3, 3.., 2]`
  (`sc_degrees`). A depth-22, l=16 witness descent is
  `sum_{j=1}^{21}(j + 4 + 1) = 231 + 105 = 336` rounds [COUNTED]; ten
  pairs at their depths sum to the 2,367.
- **K-mults** [derived from MEASURED]: `bk.descent-gkr 4.89 s`
  (`a.round-g 4.61` = 3.9 s of device kernels at 70-88% of the
  1.7 G kmul/s register ceiling, U_PERF2_GPU4_REPORT.md Section 4.5) =>
  **~5.5e9 K-mults** in the descents, every one a GF(q^16) multiply
  (~363 `mad.wide.u32`, kfield.rs header). This is the single largest
  arithmetic block in the prover and it is 100% in the big challenge
  field because LogUp needs it.
- **Trees** [MEASURED]: `bk.descent-trees 1.59 s` (`a.tree-step 0.83` +
  `a.tree-pack 0.75` host fill) — 45 real trees built at depth 21-22.
  The descent phase's memory peak was the pass peak until lane H
  (the nrw-88 pair, 1.75U = 5.6 GB, U_PERF2_DESCENT4_REPORT.md).
- **Per-leaf reconcile:** 45 real trees, 37 at depth 22 + 8 at depth 21
  = 172.0M real leaf elements (U_PERF2_DESCENT_REPORT.md Section 5);
  4.89 s / 172M ~ 28 ns per real leaf element on the GPU chain.

### 1.2 The claim layer

`bg.claim-layer 1.75 s` [MEASURED], `d.cl-rounds x138`
(U_PERF2_CLAIMCOMMIT_REPORT.md, U_PERF2_CLAIM2_REPORT.md):
**8 folded ixf instances** = 3 joint-matmul sumchecks (mm-gate/up/down,
FD (3,2) form) + **5 stacked zero-check instances** (Hadamard + 4
requant, degree 2-3). The 5 zero-checks build factor tables of **2^24
elements = 1 GB packed each, 4-5 tables per instance** at 12x512; lane O
now builds them on the device from 300 MB of compact operands. The
requant zero-checks already prove `Acc = 2^s * y + r` (the recomposition
half of every range fact); what the descents add on top is only the
`r in [0, 2^w)` membership.

### 1.3 The eval proof (the lattice opening) — the floor this design does NOT remove

Two commitment groups (weight T_W, act T_act), each bound by ONE outer
identity `u_0` and served by ONE batched LaBRADOR-form eval proof
(E-O2-BB: exactly one opening per group). Digit-ring counts [COUNTED,
`table-descent expect`]: **act n_0 = 7,854,476** (aux 31,116 = 0.40%,
schedule 9 levels, floor 915 rings e7), **weight n_0 = 3,538,944**
(8 levels, floor 939 e7; Tier-Z floor 1,368 e4). Prover phases
[MEASURED]: `bg.prove-group 7.10 s` = level-h 1.87 + kernel-rows 1.77
(q.rows-t 1.13 host T rings) + psi0-factored 1.57 + fold 0.85 + matvec
0.80; `ep.transport 1.36`; `ep.crs-expand 1.28`. The level-0 h
cross-garbage is **Theta(n_0 x r)** ring-mults with the planner's
byte-optimal `r` pinned at the 64 cap (BG-F3) — the dominant designed
term of both the prover and, before the BH split, the verifier.

- **Level-0 value rings and the verifier:** after T8b the verifier's
  level-0 work is `psi_level0_factored_multi` = O(n_value_rings x 16 x
  n_contrib) scalar MACs — **~8.6G at 125M** (~14 s [WSL 1T], ~7 s
  [MAC 1T]; T11 a'). n_value_rings is n_0 / (l0 limbs), ~0.8M (act) +
  ~0.3M (weight). At 8T on the rig this is inside the 1.7 s verify; at
  1 thread it is the reason verify is NOT <= 2 s (T11 a', the chunk-
  alignment idea WITHDRAWN — a verifier sublinear in n_value_rings needs
  a protocol change).

### 1.4 Commit and CRS

`bg.commit-phase 2.47 s` (d.precommit-u0 1.63, chain-derive 1.03,
digit-witness 0.44); `ep.crs-expand 1.28` (m.crs-blocks 0.51 SHA-NI +
~0.7 poly walk). These are the digit witness, the `u_0` matvecs, the
chain GEMM, and the seed-expanded commitment key — untouched by this
design (but the artifact-byte drop below eases the P2 Tier-Z pressure).

### 1.5 The transcript, composed (1,509,911 B) [COUNTED]

| block | B | share |
|---|---:|---:|
| statement + 8 folded instances + public claims | 63,367 | 4.2% |
| **descent pairs (10)** | **1,083,456** | **71.8%** |
| weight group (outer + rows + levels + floor) | 179,576 | 11.9% |
| act group (outer + rows + levels + floor) | 182,184 | 12.1% |

The descents are 71.8% of the artifact — the same object that is the
biggest single prover arithmetic block. Both facts point at the same
lever.

### 1.6 Scaling to 8B x 512 [MODEL]

Let (L, T, d, f) be (layers, tokens, model width, FFN hidden). The
125M rig is (12, 512, 768, 2048); the 7B FFN surrogate (32, 512, 4096,
11008); the 8B FFN target (32, 512, 4096, 14336). MACs scale as
`L x d x f` -> 2.9e10 (125M) to 2.9e12 (8B) = **~100x**.

| quantity | scales as | 125M -> 8B FFN |
|---|---|---|
| descent leaf elements / rounds | activations `L x T x f` | ~19x (FFN); ~66x with attention (ATTENTION_INTEGER_SPEC.md: +3.5x/layer, 32 vs 12 layers) |
| descent pairs (count) | table families x widths | ~same 10-12 (BG-F1 structure is per-model, not per-size) |
| claim-layer zero-check tables | activations, 2^24 -> 2^24 x (L x T x f ratio) | ~19x elements |
| eval-proof n_0 | weights `L x d x f` + activations | weight ~64x, act ~19x |
| level-0 verifier MACs | n_value_rings | ~19-64x -> the 1T verify gap widens with scale |

The descents grow with activations (~19x FFN, ~66x full transformer),
the eval proof with the witness (~20-64x). The design removes the
first as a separate O(N) K-field pass and shrinks the second's level-0
term — both matter more at 8B than at 125M.

## 2. The design

### 2.1 The objects committed

Unchanged commitment layer: the exact-digit witness per tensor (balanced
base-2^e0, l0 limbs; the v4 typing) under the two-group MLWE/MSIS lattice
commitment, one outer identity `u_0` per group (UAGB1_PASS_AGG_REPORT.md
Section 2.1). The exact-integer soundness is unchanged: values live at
q31, the range gadget at q46, tied by the U-L modulus link (chain-demo).

Two changes to what rides in the ACT group's aux tensors (replacing the
descents' `bk-m/bl/wm/tm` mask/multiplicity tensors):

1. **The SiLU LogUp helper `h`** — one committed column per SiLU witness
   column: `h_i = 1/(alpha - key_i)` in K, plus the table-side
   multiplicities `m_j` (256 rows). 12 SiLU columns -> 12 helper columns
   (vs today's 6 witness trees + 2 table trees). Blinded exactly as the
   descent masks are today (M1/M3 material committed inside `u_0(T_act)`,
   FP-L2 mask-then-fold by construction).
2. **The range/narrowing facts commit nothing new** — they are proved on
   the digits already committed. Where a width wants bit-granularity the
   remainder's dense bit planes at q46 are already the TARGET_CONTRACT
   construction (Section 2); where the committed digit is base-2^e0 the
   booleanity is the base-4 product form (below).

### 2.2 The batched sumcheck(s)

**One aggregate sumcheck per commitment group** over that group's
committed-digit hypercube (log2 n_0 variables: ~23 for act, ~22 for
weight). It replaces the 8 separate claim-layer ixf sumchecks AND the 20
masked descents with a single Fiat-Shamir random-linear-combination
(RLC) of all instances.

- **What is summed:** with betas drawn from the transcript after `u_0`
  (so mask-then-fold holds), the summand is
  `sum_k beta_k * F_k(x) * eq(rho_k, x)` over the hypercube `x`, where
  `F_k` ranges over: (i) the 3 matmul relations and the Hadamard /
  requant zero-checks (the current claim-layer summands, verbatim
  `IxfCombine::eval` closures — Prod3 / Had / Rq, fold.rs); (ii) the
  **range facts as booleanity + bound zero-checks** on the committed
  digits; (iii) the **SiLU LogUp well-formedness** `h_i(alpha - key_i) -
  1` batched over the 12 columns via the instance axis.
- **Over which hypercube:** the group's digit-ring index space, the same
  `x` the eval proof already opens; each `F_k` is supported on its
  tensors' sub-cube via `eq(rho_k, .)` row/col kernels (the additive
  `MultiClaimKernel` shape already built for the pass, eval_proof.rs
  [UAGB1-BJ]).
- **Degree per round:** matmul (3,2); requant/Hadamard 3; range
  booleanity 2 (bit planes) or 4 (base-4 digit product
  `d(d-1)(d-2)(d-3)`); LogUp well-formedness 3. RLC does not raise
  degree — **degree <= 4 per round**.
- **How many rounds:** ~23 (act) + ~22 (weight) WIDE rounds, plus the
  small SiLU table-side sum-equality (256 rows) and the sub-block tails
  — call it **~50 round-polynomials total** vs the descents' 2,367.
- **What the prover computes per round, and its cost model:** evaluate
  the summand at points 0..deg over the current hypercube = O(current
  size x deg) field MACs, then fold (halve). The **arithmetic + range**
  terms run in the BASE field q31 (the digits are base-field residues;
  challenges in a small extension GF(q^c), c>=4, for soundness — Section
  2.6) at ~1-2 `mad`/MAC, against the descents' ~363-op K-mults. Only
  the **SiLU LogUp** term carries K-fraction arithmetic, and only over
  the 12 SiLU columns (T x f-shaped), ~1/8 of the descent leaf volume.
  Total prover work = one O(n_0) base-field sumcheck pass + one small
  K-field LogUp — replacing the descents' O(172M) K-field tree pass.

### 2.3 How the range facts ride it

A requant remainder `r in [0, 2^w)` is, on the committed digits: (bound)
each bit plane `b_i in {0,1}` — the degree-2 zero-check `b_i(b_i - 1) =
0`, batched across all planes of all remainders by the RLC; (recompose)
`r = sum_i 2^i b_i` and `Acc = 2^s y + r` — already the requant
zero-check (rq-g/u/h/d) in the claim layer. The int8 narrowing
`[0, 256)` is the 8-plane instance of the same. No table, no LogUp, no
tree, no GF(q^16): **the 84 range/narrowing columns (39 trees, ~5 s of
K-field descent) become one batched base-field booleanity zero-check on
digits that are already committed.** The exact-integer, fail-by-design
property is preserved and sharpened: a value outside `[0, 2^w)` cannot
present boolean planes that recompose to it (a non-boolean plane fails
`b(b-1)=0`), which is the same "uncalibrated model cannot be proven"
guarantee, now a booleanity check instead of a LogUp root cross-check.

Two subtleties: (1) some committed digits are base-2^e0 (e0=2) not bits;
there the per-digit bound is the degree-4 product `prod_{v<4}(d-v)=0`, or
the remainder is committed at bit granularity at q46 (the existing
construction) and linked by U-L — the design uses whichever the tensor
already commits, priced in Section 3. (2) the "committable-but-off-table
gap" that BK's tamper leg exploits (`[2^sh_z, representable_max]`) closes
identically: booleanity of the top planes rejects any value above the
width.

### 2.4 How the lookup rides it (SiLU)

The SiLU (-3,-3)/(-4,-4) tables are arbitrary 256-row int8->int8 maps,
not ranges, so they keep a LogUp — but as **one sumcheck, not a tree
descent**. Commit `h_i = 1/(alpha - key_i)` (the helper) and the table
multiplicities `m_j`; prove two identities in K:

- **well-formedness** `h_i (alpha - key_i) - 1 = 0` for every witness i,
  a degree-3 zero-check batched over the 12 columns via the instance
  axis — folded into the aggregate sumcheck of 2.2;
- **sum equality** `sum_i h_i = sum_{j<256} m_j / (alpha - t_j)` — the
  witness side is a hypercube sum the aggregate already computes; the
  table side is 256 rows, a tiny separate sumcheck.

This is the Haböck LogUp-as-sumcheck (the sumcheck form of what the
descent computes as a GKR tree): ~log2(N) wide rounds instead of the
tree's ~336, the same O(N) K-mults but far fewer round-poly objects, and
`h` rides the ACT eval proof instead of a separate descent transcript.
alpha is drawn in K after `u_0` (as the descent alpha is today). If any
`key_i = alpha` (measure ~2^-490) the prover redraws.

### 2.5 The lattice opening at the end

**Still exactly one eval proof per group** (E-O2-BB preserved). The
aggregate sumcheck's final random point `x*` yields one MLE-evaluation
claim per committed tensor (the `F_k` evaluations at `x*`, opened via the
per-tensor `MultiClaimKernel` weights); the SiLU `h` and `m` claims fold
into the ACT b_rows exactly as the descent pins do today
(UAGB1_TABLE_DESCENT_REPORT.md Section 2.3). Three composition levers:

- **(T11 b) one-point batching / the R-row.** Today the 8 instances open
  at their own outer points, so the level-0 h cross-garbage is
  Theta(n_0 x r) with `r = 64`. If the aggregate reduces every claim to
  ONE point per group (RLC at a common `x*`), the opening serves one
  evaluation and the planner's `r` can drop (r=32 halves the level-h
  term, BG-F3 / T11 b), trading bytes for the h-garbage — and the
  artifact already sits at 0.48x its gate with room, and drops further
  here (Section 3), so the byte trade is affordable.
- **(T11 a) rank-structured `Phi_0`, prover side.** The level-0 claim
  functional is fed from `PHI_vr = sum_{c,d1} sr_c[row][d1] G_c[cb][d1]`
  (the T5/T8b factored form) per value ring, never materializing the
  ~11 GiB `Phi_0` — the T9(c) memory item, here made load-bearing for
  the one-point opening.
- **(T11 a') sublinear verifier.** Two options, Section 2.6/5: (Stage A)
  the verifier computes `Psi_0` factored, O(n_value_rings) — same as
  today, NOT <= 2 s at 1T; (Stage B, NEW) the prover supplies `Psi_0`
  with a small sumcheck proving `Psi_0[u] = sum_k c_k Phi_0[k*chunk+u]`
  against the committed digits, so the verifier checks O(log n_0) rounds
  + one opening instead of re-deriving `Phi_0`. This is the polylog-
  verifier opening layer T11 a' names and the only genuinely new crypto.

### 2.6 Soundness sketch (which lemma covers each step; what is NEW)

- **Arithmetic sumcheck + RLC batching:** standard sumcheck soundness
  (Q4 lemmas); the RLC of instances at a common point is standard
  multi-claim batching (Schwartz-Zippel over the betas). COVERED, re-use.
- **Range as booleanity:** degree-2 zero-check soundness (standard); the
  bit-plane <-> value link is the U-L cross-modulus link (built,
  chain-demo, integer-exact). NEW only as a claim-class swap: the
  RangeLookup soundness argument is replaced by a booleanity argument —
  same guarantee, different lemma; owes the O-3 (claim-class reduction)
  write-up.
- **LogUp-as-sumcheck:** Haböck's fractional-identity soundness with the
  committed helper, re-derived at K = GF(q^16) (the field is already the
  descent's; the construction swap is tree -> sumcheck). COVERED by the
  same characteristic bound that gates the descent; NEW as an engine
  object.
- **Base-field challenge soundness:** the aggregate runs ~50 rounds at
  degree <= 4; per-round Schwartz-Zippel error `deg/|field|`. At q31 the
  base field gives ~2^-25 per round — INSUFFICIENT alone. Challenges must
  be drawn in GF(q^c) (c >= 4 -> ~2^-120 per round; the slot field
  already provides K = GF(q^16)); the prover tables stay base-field, only
  the challenge/fold scalars lift. NEW: re-derive the aggregate knowledge
  error to the R5 line (2^-128 / the 2^-220 house target). This is O-7.
- **The supplied-`Psi_0` sumcheck (Stage B):** genuinely NEW. Needs a
  proof that the prover's `Psi_0` is bound to the committed digits (a
  sumcheck over the level-0 claim functional, extraction in the
  Q4_LEMMAS style + the recursive-FS composition PSS pattern). This is
  the O-5/O-7 obligation and the gating risk for the verifier factor.
- **ZK for the declared private set:** the aggregate sumcheck runs over
  MASKED MLEs — the existing `gkr_masked` machinery (g-mask + boundary
  masks, HVZK lemmas Q4.7-Q4.9) applies to a sumcheck as it does to the
  descent; the SiLU `h` is blinded as the descent witness is today; the
  range booleanity zero-checks are masked by the same g-mask. The
  eval-proof floor masking (Tier-Z, P2) is unchanged. The private-set
  modes (P1/P2/P3, ZK_GAP_OPTIONS.md Section 6) are unaffected — this is
  an act-side/relation change, and the P2 weight-floor path is
  untouched. NEW: the aggregated-transcript simulator (O-4, the WSMD
  Section 3 style) must cover the aggregate sumcheck instead of the
  descent — a re-derivation on built masked-sumcheck machinery, not a new
  primitive.

## 3. The counts AFTER, side by side with 1

### 3.1 Structural counts

| quantity | built (Section 1) | after (design) | note |
|---|---:|---:|---|
| descent pairs / masked descents | 10 / 20 | 0 | replaced |
| real witness trees built | 45 | 0 | no tree phase |
| round-polynomials (descents) | 2,367 | 0 | |
| aggregate sumcheck rounds | (in 8 ixf) | ~50 | ~23 act + ~22 weight + tails + SiLU table side |
| K-mults (range facts) | ~4.5e9 (GF(q^16)) | ~0 | -> base-field booleanity |
| K-mults (SiLU lookup) | ~1.0e9 (tree) | ~1.0e9 (sumcheck) | same total, ~log N round-polys |
| base-field MACs (aggregate) | (claim layer) | ~O(n_0 x deg) ~ few e9 | one wide pass, q31 |
| committed aux (act) | 40 tensors (masks/trees) | 12 h + 12 m-cols | fewer |
| eval proofs (openings) | 2 (one/group) | 2 | E-O2-BB preserved |
| level-0 h-garbage | Theta(n_0 x 64) | Theta(n_0 x 32) [T11 b] | one-point batching lets r drop |
| level-0 verifier | O(n_value_rings) | O(log n_0) [Stage B] | supplied-Psi_0 |
| transcript bytes | 1,509,911 | **~500,000** [MODEL] | descents 1.08 MB -> ~tens of KB |

Transcript-after composition [MODEL]: statement + 8 instances + public
claims 63,367; aggregate sumcheck round polys ~50 x (deg+1) x 64 B ~
16 KB; SiLU LogUp (h/m claims + table sumcheck) ~30-60 KB; range
booleanity folds into the instance kel (~few KB); weight + act groups
~180 KB each (unchanged, or smaller with r=32). Total ~**0.5 MB**, from
1.51 MB — a 3x artifact shrink that also relieves the P2 Tier-Z pressure
(the descents were ~1.08 MB of the ~2.0 MB P2 pass, over the 2 MiB band
edge; UAGB1_TABLE_DESCENT_REPORT.md Section 3.2).

### 3.2 Prover cost model, 12x512 [MODEL, from the measured per-phase shares]

| phase | built [MEASURED] | Stage A [MODEL] | Stage B [MODEL] |
|---|---:|---:|---:|
| descents | 6.5 | ~1.2 | ~1.2 |
| — range facts | ~5.2 (K-field) | ~0.4 (base-field booleanity, in aggregate) | ~0.4 |
| — SiLU lookup | ~1.3 (tree) | ~0.6 (LogUp-sumcheck) + h commit | ~0.6 |
| — trees | 1.6 | 0 (no trees) | 0 |
| claim layer + aggregate | 1.75 | ~2.0 (one wide pass/group) | ~2.0 |
| eval proof (prove-group) | 7.1 | 7.1 (unchanged) | ~4.0 (r=32 + one-point) |
| commit | 2.5 | 2.5 | 2.5 |
| CRS | 1.3 | 1.3 | 1.3 |
| transport | 1.4 | 1.4 | ~1.0 |
| **prove wall** | **15.5** | **~10.5 (1.5x)** | **~7.5-8 (2.0x)** |
| **pass wall** | **21.0** | **~15.5** | **~11-12** |

Stage A is dominated by the unchanged eval proof (7.1 s prove-group +
2.5 commit + 1.3 CRS + 1.4 transport = ~12.3 s floor); the descents'
~5 s is the whole realistic Stage-A saving, hence ~1.5x. Stage B's
further factor is entirely the eval-proof level-0 term dropping under the
R-row + one-point batching + rank-structured `Phi_0` — the biggest
[ASSUMED] (Section 5), because that term is device-bound today
(bg.level-h is ~10 ms/stage in the GEMM, U_PERF2_EVALPROOF3_REPORT.md
Section 5) and may not move with `r`.

### 3.3 Prover cost model, 8B x 512 on a desktop board [MODEL]

Chain the ratios: 12x512 built = 21.0 s -> 8B FFN ~100x MACs but the
eval-proof/commit scale ~20-64x and descents ~19x; the decision memo's
built projection is **2-8 min** on a <= 450 W desktop board (4-6x this
laptop part). Applying Stage A (~1.5x) -> **~1.3-5 min**; Stage B
(~2.0x) -> **~1-4 min**; with the full-transformer attention multiplier
(~3.5x/layer) these grow but the descents' share shrinks (attention adds
more matmul/zero-check than lookup). This lands in the **~15-160 s class
the decision memo names for route (1) + a desktop board**, NOT the
5-15 s headline; that needs the eval-proof opening itself to go
Greyhound-class (family (c), out of scope here) plus the desktop board.

### 3.4 Verifier cost model, single thread [MODEL]

- **Built:** ~1.7 s at 8T on the rig; at 1T ~10 s (12x512), dominated by
  the level-0 O(n_value_rings) `psi_level0_factored_multi` (~8.6G scalar
  MACs -> ~14 s [WSL 1T] at the 125M composed scope, T11 a'/T8b) plus
  transport + the descent verifies.
- **Stage A:** the descent verifies vanish (no descents; the range
  booleanity + SiLU sum-equality are O(rounds) checks the aggregate
  verifier already does) — the descent-verify term (~0.06 s pair loop
  today, but the aux tensors' level-0 rows were the real cost, E-F1)
  goes; but the eval-proof level-0 term stays O(n_value_rings), so 1T
  verify is ~8-10 s — **still not <= 2 s at 1T**. The honest interim is
  the `ZK_THREADS` route (the contract wording amendment "single machine,
  N threads stated") which meets <= 2 s at 8-22 threads today.
- **Stage B (supplied-`Psi_0`):** the level-0 work becomes O(log n_0)
  rounds + one opening; the verifier is then polylog + the eval-proof's
  own O(sqrt N)-class levels -> **~1-2 s at 1T reachable** [MODEL],
  the T11 a' protocol answer. This is the only path to <= 2 s at 1T
  without a contract amendment, and it needs the new soundness proof.

## 4. Transcript / freeze consequences

This is a **transcript-changing** design — the artifact bytes and the
EVAL-PROOF digest MOVE. Under the repo's rule (CONTINUATION.md Section 5,
"a speedup that moves a freeze digest is a bug") that means it is NOT a
kernel-round lane; it ships only on Victor's ruling with the freeze rows
re-pinned. What moves, what stays bit-identical, and what the migration
battery must show:

### 4.1 Freeze rows that move

- **Retired:** the descent freeze rows — UAGB1-BK-1 (the 125M remainder-
  width inventory), UAGB1-BK-2 (the 10 pair plans depth/dt/l/trees), and
  the relevance of UAGB1-BK-3 (the caps `ceiling_gate_ok(2^25)` /
  `K9_MAX_LEAVES`) to the range facts — the range facts no longer
  descend, so those gates no longer bound them. Keep BK-3 pinned for the
  SiLU LogUp (which still lives in K and still respects a characteristic
  bound), and record BK-1/BK-2 as HISTORICAL.
- **New, to pin:** the aggregate-sumcheck instance schedule (the
  ordered list of `F_k` and their `eq(rho_k, .)` kernels), the RLC
  challenge derivation and its FS order (a domain-separation string),
  the range-booleanity degrees per digit class (2 for bit planes, 4 for
  base-4), the SiLU LogUp helper layout (h/m columns), and — if adopted
  — the R-row `r` value and the supplied-`Psi_0` sumcheck shape.
- **Re-pinned unchanged in NUMBER, moved in derivation:** the two-group
  schedule (act 9 levels/915 floor, weight 8 levels/939 floor) if `r`
  stays 64; if `r` drops to 32 (T11 b) the level and floor rows move and
  must be re-derived by the public planner (freeze rows UAGB1-BG-1a/1b
  style, both directions).

### 4.2 What stays bit-identical (the migration battery's identity legs)

The eight arithmetic instances' summands (`IxfCombine::eval`), the
commit phase (digit witness, `u_0` matvecs, chain GEMM), the CRS bytes
(the SHA-NI core is the freeze), and the two-group eval-proof machinery
BELOW the level-0 claim assembly are unchanged in semantics. The battery
must show the arithmetic instances and the commit/CRS bytes bit-identical
to the pre-change capture at fixed seeds (the U-PERF differential
discipline: `*_ref` oracles behind a knob, digests compared).

### 4.3 The new differential gates (where semantics change)

- **Range -> booleanity:** an off-range value that today REJECTS at the
  RangeLookup root cross-check (BK Section 4's off-table leg, the
  `[2^sh_z, representable_max]` gap) must REJECT at the booleanity
  zero-check, with the first-fail string recorded. The tamper battery
  from UAGB1_TABLE_DESCENT_REPORT.md Section 4 (off-table, wrong-table,
  cross-table) is re-run against the new gates; each REJECT must land at
  a named, pre-registered gate.
- **SiLU tree -> LogUp-sumcheck:** an off-table value REJECTS at the `h`
  well-formedness or the sum-equality (not the descent root); a
  wrong-table-for-exponent REJECTS at the table-side fold. A
  differential leg proves the sumcheck-form claims equal the descent-form
  claims at fixed seeds on a synthetic column (the oracle = the current
  descent).
- **Aggregate RLC:** a tampered instance claim (self-consistent
  sumcheck, ct-forced b_rows — the BD WrongC pattern) must still REJECT
  at the eval-proof floor, as it does today (pass-agg battery leg).
- **The rigs:** the REAL 3x16 / 12x128 / 12x512 rigs must `accept` with
  the NEW digests recorded (the digests change by design); an A/B at
  8T and 1T; and the artifact-byte reduction (1.51 MB -> ~0.5 MB
  [MODEL]) measured, not projected.

### 4.4 Audit obligations (codex-audit-* conventions)

An auditor must be able to re-derive, from the statement and the public
planner alone: the aggregate-sumcheck instance list and its FS order;
the RLC beta derivation; the range-booleanity degrees per committed digit
class and their U-L link to the q31 values; the LogUp-h identity and the
256-row table digest binding; and (Stage B) the supplied-`Psi_0`
sumcheck's soundness reduction. These are exactly the U-AG2 obligations
O-3 (claim-class reduction: every ct-engine claim class re-expressed as
MLE-evaluation claims), O-5 (verifier model to R2), and O-7 (knowledge-
error and extraction, the recursive-FS PSS pattern) from
AGGREGATION_LITERATURE.md Section 8.1 — this design is the first concrete
consumer of that obligation sheet on the lattice line.

## 5. Honest risks and unknowns

### 5.1 What could make the factor smaller than modelled

- **The eval proof is the floor, and Stage A does not touch it.** ~12.3
  s of the 15.5 s prove is prove-group + commit + CRS + transport, all
  unchanged by Stage A. So Stage A is capped at ~1.5x no matter how well
  the descents collapse. Everything above ~1.5x rides Stage B's
  eval-proof restructuring, which is the riskiest part.
- **The level-0 h-garbage may not drop with `r`.** `bg.level-h` (1.87 s)
  is DEVICE-bound in K's GEMM (~10 ms/64x64x1024 stage,
  U_PERF2_EVALPROOF3_REPORT.md Section 5), not obviously Theta(r) once
  the GEMM tiles are fixed; halving `r` may cut fewer than half the
  stages, and it costs bytes. The one-point batching's real effect on
  the level-0 schedule is unmeasured.
- **The base-field win may be smaller than "K-mult vs base-mult".** The
  aggregate sumcheck does more MACs per element than the descent (degree-4
  evals over the full hypercube, eq folding), so the ~100-360x per-mult
  ratio is diluted; the honest lever is "range facts leave K entirely",
  not "every op gets 100x cheaper". The spike measures the true ratio.
- **The SiLU LogUp-sumcheck commits `h`** (12 columns, T x f each) into
  the ACT group — it grows n_0 and the eval proof slightly; if the
  committed-h cost exceeds the tree-descent saving on the SiLU columns
  the swap is a wash there (only the range facts are an unambiguous win).

### 5.2 What needs a proof (before it can ship)

- **The supplied-`Psi_0` sumcheck** (the verifier's <= 2 s / 1T route):
  genuinely new crypto — a sumcheck that binds the prover's `Psi_0` to
  the committed digits, with extraction and recursive-FS composition
  (O-7). Until proven, the verifier stays O(n_value_rings) and <= 2 s at
  1T needs the contract wording amendment, not the protocol.
- **The aggregate knowledge error** to the R5 line (2^-128 / 2^-220):
  ~50 rounds at degree 4 with challenges in GF(q^c); the c that closes
  the bound must be derived and the ZK simulator (O-4) re-done for the
  aggregate sumcheck.
- **The range-as-booleanity claim-class reduction** (O-3): the RangeLookup
  soundness argument is replaced by booleanity + U-L link — a lemma swap
  that the standing independent review (REMEDIATION_PLAN Phase 2.5) must
  sign off, because it is the soundness of "uncalibrated models cannot be
  proven".

### 5.3 What needs a measurement first — the spike

The biggest single [ASSUMED] is 5.1's "range facts collapse from ~5.2 s
of K-field descent to ~0.4 s of base-field booleanity". A 1-2 day spike,
no engine change, on synthetic shapes, de-risks it:

- **Spike S1 (range).** On a synthetic 2^20-element remainder column at a
  representative width (w=8): build (a) the current masked descent pair
  (the `uperf-a descent-bench` shape) and (b) a base-field booleanity
  zero-check over the same committed bit planes folded into a synthetic
  aggregate sumcheck; count K-mults vs base-field MACs, round-polys, and
  transcript bytes; measure the wall ratio at 1T/8T. Acceptance: the
  base-field path is >= 5x cheaper in K-mult-equivalents and the round
  count collapses ~10x. This measures the exponent lever directly.
- **Spike S2 (SiLU LogUp-sumcheck).** One SiLU column at 2^20: the
  descent-form claims vs the LogUp-as-sumcheck claims (committed h),
  byte-identical at fixed seeds (the descent as oracle); measure the
  round-poly count and the committed-h overhead. Acceptance: claims
  equal, rounds ~log N, h overhead < the tree saving.
- **Spike S3 (one-point / R-row, optional).** On the existing 3x16 rig,
  re-derive the level-0 schedule at r=32 with one-point batching and
  measure whether `bg.level-h` + `bg.kernel-rows` actually drop — this is
  the Stage-B gating measurement and can reuse the built eval proof.

S1 and S2 are the gate to the design freeze; S3 gates Stage B.

### 5.4 Unknowns carried explicitly

- Whether the full-transformer (attention) statement changes the balance
  — attention adds more matmul/zero-check than lookup, so the descents'
  share shrinks at 8B and this design's relative win shrinks with it
  (still positive, smaller).
- The desktop-board 4-6x [MODEL] multiplier is unmeasured (the Metal/M3
  or CUDA-desktop port, decision-memo route 3) — every 8B wall here
  carries it.
- Memory: the design REMOVES the descent phase's tree peak (5.6 GB pair,
  lane H) — a memory win for the 15 GB box — but the aggregate sumcheck
  holds the digit witness resident (already does); net peak should fall,
  unmeasured.

## 6. A staged plan

### 6.1 The spike (1-2 days, no engine change, no ruling needed)

Spikes S1 (range -> booleanity) and S2 (SiLU -> LogUp-sumcheck) from
Section 5.3, as `uperf-*`-style benches on synthetic 2^20 shapes with
the current descent as the differential oracle. Deliverable: the
measured K-mult / base-field-MAC / round-poly / byte counts before and
after, the wall ratios at 1T/8T, and a go/no-go on the ~5x range lever.
This is the "counted rounds/pairs before and after" the decision memo
asks for as route (1)'s first deliverable, now with a measurement behind
the [MODEL].

### 6.2 The design freeze — Victor's ruling items (explicit)

1. **Transcript change approved?** The EVAL-PROOF digest moves; freeze
   rows UAGB1-BK-1/2 retire and new aggregate-sumcheck rows are pinned.
   This is a deliberate freeze break (CONTINUATION.md Section 5), not a
   bug — it needs the ruling before any build lane opens.
2. **Range facts: table-membership LogUp -> bit-plane booleanity?** The
   soundness story stays "range facts fail by design / uncalibrated
   models cannot be proven", but via booleanity + U-L recomposition
   instead of a 2^w-row LogUp. This is a claim-class change (O-3) the
   independent review must accept.
3. **The verifier route (T11 a'):** the supplied-`Psi_0` polylog verifier
   (new crypto, R5 review, the only path to <= 2 s at 1T) vs the
   `ZK_THREADS` "single machine, N threads stated" contract wording
   amendment (no new crypto, meets <= 2 s at 8-22 threads today). Pick
   one; they are not exclusive but the build cost differs by a tranche.
4. **The R-row `r` value (T11 b):** r=64 (bytes-optimal, current) vs r=32
   (halves the h-garbage, grows the artifact) — priced by S3; the
   artifact already has headroom (0.48x its gate, and this design shrinks
   it 3x), so r=32 is affordable if S3 shows the level-0 term drops.

### 6.3 The build tranche (lanes, files, gates)

Sibling worktrees, strict file-lane ownership (the tranche protocol),
each lane keeping its `*_ref` oracle behind a knob and its differential
battery. Order: Stage A first (lanes 1-2, the measurable ~1.5x), then
Stage B (lanes 3-4) gated on S3 and ruling 3/4.

- **Lane 1 — the aggregate sumcheck + LogUp-sumcheck.** OWNS a new
  opening-driver module + `fold.rs` (the RLC aggregate over the two
  groups' hypercubes) and `gkr_masked.rs` (the masking of the aggregate
  and of `h`). Builds `h`/`m` commitment, the well-formedness + sum-
  equality identities, and the batched-instance summand. Oracle: the
  current claim-layer + descent path. Battery: S2's differential legs +
  the SiLU tamper legs; digests vs the descent oracle at fixed seeds.
- **Lane 2 — range as booleanity.** OWNS `bg_zc_prove` and the range
  instances in the bin's claim-layer region; folds the booleanity
  zero-checks into the aggregate. Oracle: the current RangeLookup
  descents. Battery: S1's differential legs + BK Section 4's off-table /
  wrong-table / cross-table tamper legs re-pointed at the booleanity
  gates, each REJECT at a named gate.
- **Lane 3 (Stage B) — the eval-proof one-point batching + R-row.** OWNS
  `eval_proof.rs` (the level-0 claim assembly, the `r` planner, the
  rank-structured `Phi_0` feed — the T9(c) / T11 a machinery). Oracle:
  the current per-instance opening. Battery: the pass-agg seam
  differential (Psi_0 == compute_psi(phi) bit for bit) at r=64 and r=32.
- **Lane 4 (Stage B) — the supplied-`Psi_0` verifier sumcheck.** OWNS the
  verifier's level-0 path + its soundness note (O-5/O-7). Battery: the
  new sumcheck's soundness legs (a forged `Psi_0` REJECTS) + the 1T
  verify measurement.

Gates for every lane (the repo's differential discipline): the `*_ref`
oracle behind `ZK_UPERF_ORACLE=1` / a per-item knob; the differential
battery bit-identical at ZK_THREADS 1/2/7 where semantics are unchanged;
the new differential gates (Section 4.3) where they change; `freeze-check`
re-pinned (the new rows derived both directions); the REAL 3x16 / 12x128
/ 12x512 rigs `accept` with the new digests recorded and an 8T/1T A/B;
`self-test` / `agg-matmul` / `bh-verifier` / `pass-agg` green. The
acceptance number for the tranche is the measured 12x512 wall (Stage A:
~15.5 s target; Stage B: ~11-12 s + the 1T verify), byte count, and
digests — measured on a quiesced box, not projected.

### 6.4 Sequencing against the roadmap

This sits at CONTINUATION.md's fallback juncture (Phases 0-3 measured,
the residual is protocol-shape not kernel). It is route (1) of the
decision memo; it runs BEFORE any move to the float/int-mix channel
(route 2) and composes with the desktop-board measurement (route 3). It
does not touch the attention/8B wiring (Phase 4-5) — those multiply the
statement and should land on the post-U-PERF3 base, not the current one.

---

*Author's note on labels: every seconds figure in Sections 1 and the
"built" columns is [MEASURED] from `fp_12x512_PQ_gpu_r1.txt`; every
structural count is [COUNTED] from `table-descent expect 12 512` or the
source; every "after" figure is [MODEL] from the measured per-phase
shares and the counted round/K-mult ratios, and the single biggest one
(the range base-field collapse) is gated by spike S1 before the design
freeze. No number here is a new measurement; the spike is where the
first new measurement is taken.*

## Appendix A (2026-08-29) — post-integration amendments (lane GG's measured findings; ruling inputs)

Stage A is now INTEGRATED and ACCEPTING on the real pass (round 5,
lane GG: range and full modes at 3x16; the 12x128 A/B; every claim
grounded bit-for-bit; O-4 masked at pass level). The integration
falsified two of this memo's claims and sharpened one open choice —
recorded here as amendments awaiting Victor's ruling, NOT silently
patched into the sections above.

### A.1 (= finding F1) The "commit nothing new" claim is WRONG — the commit-side bill

Section 2.1's implication that Stage A commits no new objects does
not survive contact: (a) the off-table gap needs the WIDTH PLANES
committed (committed limbs cannot close it) — +4.5M rings at
12x512; (b) h under the naive encoding at l0_q = 16 adds +25.2M
rings (the act group's n_0 goes 7.85M -> ~37.5M counted; measured
as the 12x128 full-mode OOM at 14.8 GiB on the 15 GB box). THE
RULING (round-6 opening decision 2): Stage-A round 1 = RANGE-ONLY
(84/96 columns; the silu descents stay), which retires the range
descents — including the 8B 120 GB pair — while dodging (b)
entirely; full mode returns only with a committed-h design that
beats the naive encoding. The 8B memory verdict under range-only:
~116 GB at 32x512 with lane HH's diet [COUNTED, subject to HH's
phi_1 correction], i.e. the 128 GB milestone stands on range-only.

### A.2 (= finding F2) The h ordering in sections 2.1/2.4 is circular as written

h depends on the fold challenge alpha, and u_0 is nonlinear — the
memo's ordering (h inside u_0(T_act)) cannot be transcribed. The
working amendment, IMPLEMENTED in lane GG's full mode: a THIRD
"act-h" group committed MID-TRANSCRIPT (after alpha is drawn), one
opening per group preserved. Adopting this ordering formally is
round-6 opening decision 3; it costs one extra commitment wave and
nothing else that the 3x16 measurements can see.

### A.3 (= OQ-2) The alphabet: what the sign-binary planes actually prove

The house sign-binary digit planes prove membership of
[-(2^w - 1), 2^w - 1], NOT [0, 2^w) — the descents' range tables
proved the one-sided fact. For the range families this is a
soundness-relevant widening (two-sided where one-sided was
declared): either (i) the statement rows are re-declared two-sided
where the chain analysis permits (the requant remainders are
nonneg by relation — the recomposition pins them, so the widening
may be harmless case by case), or (ii) the {0,1} booleanity
alphabet lands (1/3 cheaper rounds, needs the bit-granularity
commitment — the q46-remainder / U-L link of the spike report §5).
Round-6 opening decision 4; (i) needs a per-family analysis memo,
(ii) needs a commitment-design rung. Until ruled, range-only
Stage A declares the two-sided fact honestly in its statement rows
(what lane GG's R3 implements).
