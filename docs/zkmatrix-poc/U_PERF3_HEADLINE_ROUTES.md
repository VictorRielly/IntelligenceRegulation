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

(pending)

### 2.2 (ii) Folding across the 32 identical layers

(pending)

### 2.3 (iii) Batching level-0 claims beyond the R-row

(pending)

### 2.4 (iv) GPU-native restructuring: serial vs parallel, desktop board, N boards, the field

(pending)

### 2.5 (v) 2025-26 literature that fits

(pending)

### 2.6 (vi)+ own candidates

(pending)

## 3. Compositions and the honest reach

(pending)

## 4. Recommendation for a second design freeze + THE ONE spike

(pending)

## 5. References (with labels)

(pending)
