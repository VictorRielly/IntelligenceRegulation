# U-PERF3 — batched opening layer over the committed digits (design memo, no code)

Status: SKELETON — sections are filled in commit by commit; a section
headed "(pending)" has not been written yet.

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

## 3. Counts after, side by side (pending)

## 4. Transcript / freeze consequences (pending)

## 5. Honest risks and unknowns (pending)

## 6. Staged plan (pending)
