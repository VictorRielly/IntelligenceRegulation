# U-AG-B1 Fold Report — Lane BE (wave 2): IXF at the 12-layer 125M pass shape

Status: LANE DELIVERABLE (2026-08-08, U-AG-B1 wave 2, worktree
wt-uagb1-be). Ledger: PROGRESS_UAGB1.md "Agent BE status". Machine:
Victor's Mac (Apple silicon) — NOT the contract reference box; every
timing here is [MAC-BOX, non-reference], plus [NOISY-SHARED] where
sibling lanes (BD/BF) ran concurrently. Byte counts, freeze rows and
battery verdicts are machine-independent.

Companion code: `src/ring/fold.rs` (the IXF machinery), the
`[UAGB1-BE]` section of `src/bin/ring_matmul.rs` (`ixf-fold`
subcommand: battery / norm / bytes / measured runs), freeze rows
`UAGB1-BE1a..1e` in `ring_matmul freeze-check`,
`tests/test_uagb1_fold.py`.

## 0. Scope and honest labels

- This lane folds the per-layer SUMCHECK INSTANCE families — the
  stacked zero-check (FD-L1) and the joint matmul terminal form
  (FD-L2), per the frozen F-IF1 interface — into ONE folded instance
  family per relation class at the 12-layer 125M pass shape, with
  full commitment grounding (multi-wave C2 + U-Z1 masked splitter +
  per-wave masked ct-rounds — the D2 pipeline, layer-extended).
- NOT in this lane (honest): the eval-proof/batched-opening layer
  (lane BD's, running in parallel — the seam is F-IF1.4/AFS-L8: the
  folded families and their per-tensor pins are the INPUT one eval
  proof per commitment group consumes); the folded LOOKUP DESCENT
  (FD-L3 — the dw+4 ruling is settled on paper in Section 1; the rig
  needs the multi-wave C2 lift, AZB_BATTERY_PLAN Section 7 route 2);
  the 3-position gate/up/down instance iteration and the real-weight
  integration (lane BF's 12-layer pass);
  wire format (BB item 6). The counted bytes below therefore still
  carry the pre-aggregation OPENING volume, reported not hidden —
  the fold shrinks the CLAIM layer (Section 5), BD's stack replaces
  the opening layer.

## 1. THE 12->16 RULING (deliverable 1 — settled, pinned)

F-IF1 froze IXF at flat-32: 5 index variables, one-time sqrt(32)
absorbed at e0 (F-IF1.0/F-IF1.5). The 125M pass has 12 layers. Every
delta from the frozen interface, DERIVED (never extrapolated — the BA
rule), each with its freeze row:

### 1.1 lambda = 4 over 16 slots with 4 vacuous slots (row UAGB1-BE1a)

lambda(k) = ceil(log2 k); lambda(12) = 4, index space 16, pads 4.
This does NOT move a frozen constant: F-IF1's "5" is the 32-layer 7B
instantiation of a layer-count-generic interface — FD-L1's proof is
explicitly "variable-count-generic", and FD Section 10.3 commissions
the 125M rows at "12 layers, index pad to 16". The freeze row pins
the boundary behavior both directions (11 -> 4, 16 -> 4, 17 -> 5)
and reproduces the frozen 7B point lambda(32) = 5 / 0 pads unchanged.

### 1.2 Padded-slot semantics: zero-extension, I-3 kept (rows UAGB1-BE1a/1e; battery PadSmuggle legs)

The 4 vacuous slots follow the engine's EXISTING zero-extension
discipline — the D-1/D2 precedent for the inner dimension (768 ->
1024): the prover's sumcheck tables extend the layer axis with
zeros; commitments carry ONLY the 12 real layers; every verifier-side
functional (the stacked pins) is position-determined over committed
indices, so the pad region contributes zero to every functional BY
CONSTRUCTION. No new commitment class, no new wire object, no new
challenge class => no new soundness surface in the F-IF1.6 draw
table. I-3 slot-completeness (R-FC4) is KEPT: the folded sumcheck
runs over the full 16-slot space — nothing is sampled or skipped;
the pads are inside the enumeration and provably vacuous through the
pin grounding.

The FENCE is adversarial, not definitional: the pad slots are the
one place a prover has post-challenge freedom in its own tables. The
battery's PadSmuggle legs construct the full adversary — a COMMITTED
defect in a real layer covered by pad-slot table content solved
AFTER the draws — and show it passes its own sumcheck (and, on the
matmul family, even the C pin) and is caught exactly by the
committed pin functionals (A*/B* pins). REJECT, both families
(Section 3).

### 1.3 The norm law at 12/16: one-time log2 sqrt(12) = 1.79 b (rows UAGB1-BE1b/1c)

F-IF1.5's law is gamma_z(pass) = OP_CONC * 2^(e0-1) *
sqrt(N_limb(pass) * D), N_limb counted over COMMITTED limb-rings.
Pads are uncommitted (1.2), so N_limb(125M pass) = 12 x
N_limb(layer) and the one-time cost on the real inventory is log2
sqrt(12) = 1.792 b; the conservative index-space figure log2
sqrt(16) = 2.000 b bounds it; both sit strictly under the FROZEN 7B
row FC2-law (log2 sqrt(32) = 2.5 b — unmoved, still enforced by
scripts/aggregation_freeze_rows.py). The chain identity
gamma(12x)/gamma(1x) = sqrt(12) is asserted exactly (1e-9) in row
UAGB1-BE1b.

The e0 absorption re-derived at the REAL 125M matmul-family
inventory (12 x 512x768x2048; rings = elements/128; gate =
gamma_max(exact-digit) = 2^22.12, the UAGB1-1b / freeze-script
H-gate-ed row):

| group (12 layers) | classes | e0 | N_limb | gamma_z | headroom | row |
|---|---|---:|---:|---|---:|---|
| weight (A x12) | 36,864 rings @ 8b | 1 (sign-binary, the F-N2 base) | 294,912 | 2^16.963 | **+5.159 b** | UAGB1-BE1c |
| activation (B x12 + C x12) | 147,456 @ 8b + 98,304 @ 25b | **2 (ADOPTED)** | 1,867,776 | 2^19.294 | **+2.828 b** | UAGB1-BE1c |
| activation, layer-base check | same | 5 | 786,432 | 2^21.670 | **+0.452 b — FITS** | UAGB1-BE1c (finding) |

**HONEST FINDING (BE-F1).** At the 125M matmul-family inventory the
7B negative row FC2-act5 (layer e0 = 5 fails at x32) does NOT
transfer — the inventory is ~46x smaller in limb-rings, and even
e0 = 5 fits with +0.45 b. The pass e0 re-derivation is therefore
mandatory at the 7B scale but NOT gate-forced at the 125M rung;
e0 = 2 stays ADOPTED as the DECLARED class base (the D1 class table
the statement binds — consistency, not necessity). Recorded as a
positive-headroom row, not silently inherited from the 7B table.

### 1.4 Descent dimension: dw_pass = dw + 4 = 25 (row UAGB1-BE1d; NOT built)

FD-L3/F-IF1.8 at lambda = 4: the 125M lookup witness is 2048x512 =
2^20 per layer (the RECORDED dw-21 rig point), so dw_pass = 21 + 4 =
25 and kel(25) = 1,760 = 112,640 B [MODEL — the F-IF1.8 fit, ONE
step past the recorded dw-24 point]. This confirms BC's F-O2 row
("if BB lands lambda = 4 the row stands") — F-O2 stays
7B-freeze-blocking, not PoC-blocking. The folded descent is NOT
built this lane (the >= 2^24-element witness column needs the
multi-wave C2 lift — AZB_BATTERY_PLAN Section 7 route 2); the
ruling is paper + freeze row.

### 1.5 What does NOT change (verified against F-IF1/AFS-L8)

- Zero fold messages (F-IF1.0): the folds add ONLY the lambda index
  coordinates in the outer draw (CRB-N1 class) and lambda extra
  in-round challenges (CRB-N2 class). No accumulator, no
  cross-terms, no witness-multiplying challenge at the claim layer
  (AFS V1/V2 hold verbatim at lambda = 4).
- The FS table (F-IF1.6/AZ-L4(a)) keeps its shape; Section 4 lists
  the as-built hash edges.
- AFS-L8 (two commitment groups) is untouched: the folded families
  keep per-tensor pins (A pins reference weight-class segments only;
  B/C pins activation-class only) — the group separation "by
  construction" that AFS-L8 hypothesis (iv) needs. Seam exported to
  BD.
- No R-rows: no delta moves a frozen constant or contradicts
  F-IF1/AFS-L8. The 125M rows land as NEW dated rows exactly as FD
  10.3 commissioned.

## 2. The implementation (deliverable 2)

- `src/ring/fold.rs`: `ixf_layout` (the lambda/slots/pads ruling);
  `ixf_sumcheck_prove/verify` — the degree-SCHEDULED sumcheck
  (FD-L2's (3,2) form: public per-round degree schedule, house
  transcript discipline: absorb round poly, then draw); the norm-law
  chain (`n_limb_rings`, `gamma_z_log2`, `headroom_bits`,
  `law_delta_bits`, `one_time_law_bits` — one copy of the law,
  shared with ring::digits); `kel_fit_dw` (the F-IF1.8 [MODEL] fit).
- `[UAGB1-BE]` rigs in ring_matmul.rs, both with full commitment
  grounding (multi-wave C2 plan, statement v3 with the per-layer
  segment map bound through the model digest, one folded sumcheck,
  stacked pins -> psi -> U-Z1 masked splitter -> per-wave masked
  ct-rounds + closing round):
  * `uagb1_ixf_matmul_run` — FD-L2: tables eq(r_l,l) (expanded),
    A~(l,rx,k), B~(l,k,ry) over (inner-low, layer-high); schedule
    [2;lk]++[3;lambda]; claim C~(r_l,rx,ry); terminals -> pin_C (at
    eq_rl x eq_rx x eq_ry), pin_A*, pin_B* (at eq_l* x eq_rx x
    eq_k* / eq_l* x eq_k* x eq_ry). The eq factor is verifier-
    recomputed at the final point (never trusted from final_evals).
  * `uagb1_ixf_zerocheck_run` — FD-L1: tables eq(r,(b,l)), Y, U, Z
    over (pos-low, layer-high); schedule [3; n+lambda]; claim 0;
    terminals -> pin_Y*, pin_U*, pin_Z* at the split final point.
- Statement binding (the AZB-10a edge): the model digest carries
  layers, lambda, the exact-digit class declarations (D1 table:
  weight w8s e0=1, activation a8s e0=2, accumulator/z derived), the
  PER-LAYER SEGMENT ROWS (group_list_digest of each layer's
  commitment digests), and every data commitment digest — all
  inside h0 before any draw. NO manifest.rs codec change (a typed
  field would either move existing statement digests or preempt
  BB's recorded one-versioned-codec-change disposition for
  E-O1-BB); the registration check (declared rows vs the registered
  per-model map) is the verifier-side gate the relabel legs
  exercise.

## 3. Battery (deliverable 3)

Filled from `ixf-fold battery` + the self-test smoke; every leg
listed with its verdict in Section 3.1. F5 pairs run BOTH directions
(attack accepts under the weakened verifier, shipped rejects the
same crafting).

### 3.1 Legs (`ixf-fold battery` — 20/20 green, 53.2 s [MAC-BOX]; also carried by tests/test_uagb1_fold.py)

| leg | verdict |
|---|---|
| zc fold honest ACCEPT at 12x(128x64) — lambda 4, 4 vacuous slots (288 data cms, 3 waves; commit 0.03 s / prove 5.51 s / verify 0.41 s) | green |
| zc cross-layer Z swap (self-consistent statement): index-extended eq binds each layer's Z to the SAME layer's Y,U | REJECT |
| zc early-draw F5 ATTACK: 17-position crafted defect (16 solved + 1 free — see BE-F2) ACCEPTS under the weakened (leaked-r) verifier | accepts (attack lands) |
| zc early-draw F5 DEFENSE: same crafting under the shipped order (r from h0 binding every commitment) | REJECT |
| zc PADDED-SLOT tamper (6 layers, 2 vacuous slots): committed layer-0 defect + covering pad-slot table content solved post-draw — sumcheck GREEN, caught by the committed pin functionals | REJECT (waves) |
| AZB-10a (zc) completeness: honest pass under its own registered segment map | ACCEPT |
| AZB-10a (zc) DEFENSE: full-layer relabel (2<->7, self-consistent) vs the registered map bound in h0 | REJECT (statement gate) |
| AZB-10a (zc) ATTACK: same relabel under the map-unbound weakened verifier — slots 2/7 carry unregistered content, untouched slots unmoved | accepts (edge exhibited) |
| mm fold honest ACCEPT at 12x(64x96x128) — lambda 4, 4 vacuous slots (312 data cms, 3 waves; commit 0.03 s / prove 9.94 s / verify 0.52 s) | green |
| mm stale-order F5 ATTACK: forged stacked C (16 solved entries in layer 0, NOT A*B) under draws-before-C ordering | accepts (attack lands) |
| mm stale-order F5 DEFENSE: same forged C under the shipped verifier (r_l, rx, ry from the full h0) | REJECT |
| mm PADDED-SLOT tamper (6 layers): committed C defect + covering pad-slot A/B content — sumcheck green AND the C pin consistent BY CONSTRUCTION (the claim is defined as the committed-C functional), caught by the A*/B* pin grounding | REJECT (waves) |
| AZB-10a (mm) completeness / DEFENSE / ATTACK (as zc) | ACCEPT / REJECT / accepts+exhibit |
| FD-L2 naive fold INCOMPLETE on honest data (cross terms) | exhibited |
| FD-L2 naive fold UNSOUND under early draws (forged C' accepts the naive check) | exhibited |
| the JOINT in-sumcheck fold rejects the same forged claim | exhibited |
| (self-test smoke) zc + mm honest ACCEPT at 4 toy layers + zc TamperZ REJECT + mm cross-layer C swap REJECT (sumcheck green, C pin fails) | green |

### 3.2 An engine-scale crafting finding (BE-F2)

The AZ-L4 A1/A2 early-draw crafting against the stacked zero-check
CANNOT use the design spike's two-position defect at the engine: one
K = GF(q^16) equation is 16 base-field equations, so a defect with
eq_r-weighted sum zero needs 17 committed positions (16 solved by
Gaussian elimination + 1 free). The battery leg constructs exactly
that. This is R-EB3's full-entropy point made concrete: the K-draw
structurally kills low-weight crafted defects; the attack class
survives only at 17+ positions AND only under a broken hash order.

### 3.3 AZB-10 status

- AZB-10a (segment-map edge): LANDED at engine scale, F5 pair both
  directions on BOTH families — a fully self-consistent full-layer
  relabel is REJECTED at the shipped statement gate (declared
  per-layer rows vs the registered map, inside h0 before every
  draw) and ACCEPTS under the weakened (map-unbound) verifier with
  the wrong-slice binding exhibited on the segment rows.
- AZB-10b (group-map edge): NOT unlockable this lane — the leak
  face (a weight functional migrating into the bare activation
  floor) needs lane BD's eval-proof/floor layer. The E-10 spec
  stands; my statement's class declarations + per-tensor pin
  separation are the hooks it will consume.

## 4. FS hash edges as built (AZ-L4(a) rows)

| challenge | drawn from | follows (absorbed state) | battery leg |
|---|---|---|---|
| h0 | — | statement digest (INCLUDING layers, lambda, class decls, per-layer segment rows, every data commitment digest) + all t1/t2 tags via ct_h0 | segment-relabel pair (AZB-10a); stale-order pairs |
| rx, ry, r_l (matmul) / r (zero-check) | FS on h0 | h0 (hence every commitment + the segment map) | EarlyDraw pairs BOTH families |
| round challenge t | in-round | the round-t polynomial (house sumcheck discipline) | inherited (E3-N4 class) |
| psi (pin batch) | FS state | claim + all round polys + final evals + all pin values (E4-N1) | inherited from D2 pattern |
| wave binding | — | transcript state + wave index (h0_w per wave) | inherited (D2 WaveOrderSwap class) |

## 5. Norm measurements and byte model (deliverables 4-5)

### 5.1 Norm (measured at the engine ring — `ixf-fold norm`)

Real quinary negacyclic folds at D = 128 over e0 = 2 digit columns
(the adopted activation base), 8 trials per point, exact integer
norms ([MAC-BOX] applies to wall-clock only):

| m columns | 4 | 8 | 16 | 32 | 64 | 128 | 256 |
|---|---:|---:|---:|---:|---:|---:|---:|
| avg fold inf-norm | 99 | 152 | 231 | 328 | 430 | 563 | 854 |

- log-log slope **0.52** (band [0.35, 0.65]) — the sqrt(m) stacked
  law at engine ring dimensions; the design spike measured 0.49 at
  its D = 32 toy. MEASURED, engine scale.
- 12x columns cost **3.9x** measured (sqrt(12) = 3.46 class, band
  [2.0, 6.0]).
- The certified law rows: 1.792 b (12x, real committed inventory) /
  2.000 b (16-slot conservative bound) / 2.500 b (the frozen 7B 32x
  row FC2-law — unmoved). Chain identity gamma(12x)/gamma(1x) =
  log2 sqrt(12) asserted exact (1e-9) — row UAGB1-BE1b.
- The e0 absorption at the act group re-derived and pinned: Section
  1.3's table (rows UAGB1-BE1c), including the BE-F1 honest finding.

### 5.2 Byte model (`ixf-fold bytes` — derived; counted-not-serialized, 64 B/K-el)

Folded vs unfolded INSTANCE-TRANSCRIPT accounting at the 12-layer
125M pass shape (matmul family at 512x768x2048/layer; zero-check
family at 2048x512 positions/layer). Engine-actual counts d+1 evals
per degree-d round; the FA convention counts d kel/round + 4
boundary:

| family | folded (engine-actual) | unfolded (engine-actual) | folded (FA-conv) | unfolded (FA-conv) |
|---|---:|---:|---:|---:|
| joint matmul (10 deg-2 + 4 deg-3 rounds vs 12 x 10 deg-2) | 3,200 B (50 kel) | 25,344 B (396 kel) | 2,304 B | 18,432 B |
| stacked zero-check (24 vs 12 x 20 deg-3 rounds) | 6,464 B (101 kel) | 65,280 B (1,020 kel) | 4,864 B | 49,152 B |
| pins | 3 x 64 B | 36 x 64 B | — | — |
| **claim-layer total** | **9,856 B** | **92,928 B** | — | — |

**The fold shrinks the claim layer 9.4x with ZERO fold messages** —
the only growth is +4 index rounds per instance and the lambda
coordinates inside the existing outer draw. Count-invariance holds:
3 stacked pins per folded family vs 3 per layer unfolded (36).

Descent row (ruling only, NOT built): dw_pass = 25 -> kel(25) =
1,760 = 112,640 B [MODEL — F-IF1.8 fit one step past the recorded
dw-24 point].

**The FA-table "folded instance transcript" line at the FULL
F-IF1.1 population, 125M shape, lambda = 4 (DERIVED, FA convention:
d kel per degree-d round + 4 boundary/instance) [MODEL where
flagged]:**

| instance (per pass) | rounds | kel |
|---|---|---:|
| matmul gate (inner 768 -> lk 10) | 4x3 + 10x2 | 32 |
| matmul up (lk 10) | 4x3 + 10x2 | 32 |
| matmul down (inner 2048 -> lk 11) | 4x3 + 11x2 | 34 |
| Hadamard zero-check (2^20 pos + 4) | 24x3 | 72 |
| requant zero-checks x2 | 24x3 each | 144 |
| range-table descent (shared table, unchanged) | 28x3 | 84 |
| terminal batch [MODEL — rounds = ceil(log2 pass coeffs) ~ 27; exact count awaits the integration statement inventory (lane BF)] | 27x3 | 81 |
| boundary (8 instances x 4) | — | 32 |
| **folded pass instance transcript** | | **511 kel = 32,704 B** |
| unfolded 12x per-layer equivalent | | ~5,160 kel = ~330,240 B |

The 7B FA table's counterpart line is 37,056 B over 8 instances at
lambda = 5 (FD 6.1) — the 125M line lands in the same class, smaller
with the smaller index space and shapes, ~10x under its unfolded
form. DERIVED from the ruling's lambda = 4 and the 125M shapes; the
terminal-batch row is the one [MODEL] slot.

The OPENING layer at the 12-layer full shape, derived from the
layout arithmetic (35,328 data cms, 270 waves at cap 131): ct-z
962,138,112 B + w1 148,021,248 B + tags ~293,871,616 B — UNCHANGED
by IXF (the D2 wave-1 finding at 12x: the opening volume is 99.8%+
of the artifact and is exactly what lane BD's eval-proof stack
replaces; reference: 12 x the measured D2 single-layer artifact ~
1.409 GB of opening volume vs the folded claim layer's 9,856 B).

### 5.3 Measured folded runs [MAC-BOX, NOISY-SHARED]

| run | data cms | waves | commit | prove | verify | counted total |
|---|---:|---:|---:|---:|---:|---:|
| zc fold 12 x (128x64) (battery leg) | 288 | 3 | 0.03 s | 5.51 s | 0.41 s | (battery leg) |
| mm fold 12 x (64x96x128) (battery leg) | 312 | 3 | 0.03 s | 9.94 s | 0.52 s | (battery leg) |
| zc fold 12 x (512x256) (mid shape; 2^17 positions/layer, 21-round fold, RSS 2.97 GiB) | 4,608 | 36 | 0.48 s | 51.5 s | 6.75 s | 183,686,051 B |
| **mm fold 12 x (512x768x2048) — the FULL 125M-shape 12-layer fold, honest ACCEPT** | **35,328** | **270** | **4.07 s** | **431.5 s** | **59.3 s** | **1,406,719,131 B** |

### 5.4 The full-shape capstone row, decomposed [MAC-BOX, NOISY-SHARED (lane BD's self-test ran concurrently); single run — magnitudes, not p50/p95]

The 12-layer fold AT THE FULL 125M LAYER SHAPE (512x768x2048 per
layer = 12 x the D2-proven statement shape) proves and verifies as
ONE folded instance: total wall 499.4 s (492.6 s user — effectively
single-threaded), peak RSS 13.57 GiB (/usr/bin/time -l;
14,571,339,776 B — the pin weight vectors dominate the transient).

| component | bytes | share |
|---|---:|---:|
| statement (serialized, real; 36 entries + 12 Matmul ops + segment map in the model digest) | 4,659 | ~0% |
| commitment tags t1+t2 | 293,871,616 | 20.9% |
| folded sumcheck (claim + 14 rounds + finals) | 3,200 | ~0% |
| masked share reveals (9 x 270 x 12) | 29,160 | ~0% |
| ct-round z responses | 962,271,232 | 68.4% |
| ct-round w1 images | 148,041,728 | 10.5% |
| ct-round h + w_claim | 2,497,536 | 0.2% |
| **TOTAL** | **1,406,719,131** | |

- The folded sumcheck measured EXACTLY the derived 50 kel = 3,200 B
  (Section 5.2's model row — derived and measured agree); the wave
  plan measured exactly the derived 270 waves at cap 131.
- What the fold compressed (vs 12 unfolded D2 statements): 12
  sumchecks -> 1 (25,344 -> 3,200 B), 12 statements -> 1, 36 pins ->
  3. What it does NOT touch: the wave-bound material — reveals and
  h/w_claim scale with WAVES (270 vs 12 x 23 = 276, ~unchanged) and
  the opening volume (z + w1 + tags = 99.8%) is byte-for-byte the
  D2 finding at 12x — 1.404 GB vs 12 x 117.4 MB = 1.409 GB. THE
  FOLDED FAMILY IS NOW A CLEAN SINGLE-INSTANCE INPUT to lane BD's
  per-group batched opening; the opening volume is exactly what BD
  replaces (F-IF1's design: one eval proof per commitment group).
- Prover scaling: 12x the D2 single-layer data at 431.5 s vs D2's
  45.2 s — 9.5x wall for 12x commitments (sublinear: the single
  folded sumcheck + 3 pins amortize).

## 6. Exports

- To BD: the folded families + per-tensor stacked pins are the input
  to the per-group batched opening (F-IF1.4/AFS-L8); the pin
  separation by tensor class is the group map's substrate; nothing
  in this lane touches eval/opening code.
- To BF/orchestrator: the 3-position (gate/up/down) iteration of the
  matmul fold and the integration statement's segment map (typed
  E-O1-BB form) remain pass-statement work; BE-F1 (the 125M-scale
  e0 finding) belongs in the freeze table as a dated 125M row set.
- To BC: the dw_pass = 25 ruling confirms the kel(25) measurement
  point; F-O2 disposition unchanged.

## 7. Verdict row

**IXF LANDS AT 12 LAYERS, FULL 125M SHAPE, per the frozen F-IF1
interface — the 12->16 ruling settled with zero frozen-constant
moves and zero R-rows.**

| item | status |
|---|---|
| 12->16 ruling | SETTLED + PINNED (rows UAGB1-BE1a..1e, both directions, all green; every pre-existing freeze digest unmoved). lambda 4 / 16 slots / 4 pads; pads = zero-extension, I-3 kept; law 1.792 b (real) / 2.000 b (bound) < frozen 2.5; dw_pass 25. No R-rows. |
| fold implementation | LANDED: fold.rs + two engine-scale rigs (FD-L1 stacked zero-check, FD-L2 joint matmul) with full commitment grounding; zero fold messages; AZ-L4(a) hash edges as Section 4. |
| battery | 20/20 legs green (53.2 s): honest ACCEPT at 4 AND 12 layers both families; cross-layer swap REJECT; early-draw F5 pairs BOTH directions (incl. BE-F2's 17-position K-draw crafting); padded-slot tampers REJECT both families; AZB-10a segment-map completeness/DEFENSE/ATTACK both families; FD-L2 naive-fold negative all three directions. AZB-10b honestly blocked on BD (E-10 spec stands). |
| capstone | the 12-layer FULL-125M-shape joint matmul fold: honest ACCEPT — 35,328 data cms, 270 waves, prove 431.5 s / verify 59.3 s / RSS 13.57 GiB [MAC-BOX, NOISY-SHARED], folded sumcheck measured = derived 3,200 B. |
| norm | measured at engine ring: slope 0.52 (sqrt law), 12x ratio 3.9x vs sqrt(12) = 3.46; law identity exact; 125M e0 rows derived + pinned incl. finding BE-F1. |
| bytes | claim-layer fold 9.4x (derived, both conventions); full-population FA-table line 511 kel = 32,704 B [MODEL on terminal-batch rounds]; opening layer honestly reported unchanged (BD's target). |
| suite | full python suite green in-lane (53 tests) + freeze-check green at every commit. |

Findings: **BE-F1** (the 7B e0=5 negative does not transfer to the
125M matmul-family inventory — pinned as a positive-headroom row,
e0=2 stays the declared class base); **BE-F2** (the K-draw forces
17-position early-draw crafting where the base-field toy needed 2 —
R-EB3's full-entropy margin made concrete at the engine).
