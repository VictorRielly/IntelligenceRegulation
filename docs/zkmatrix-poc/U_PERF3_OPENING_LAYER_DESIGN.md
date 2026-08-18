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

## 2. The design (pending)

## 3. Counts after, side by side (pending)

## 4. Transcript / freeze consequences (pending)

## 5. Honest risks and unknowns (pending)

## 6. Staged plan (pending)
