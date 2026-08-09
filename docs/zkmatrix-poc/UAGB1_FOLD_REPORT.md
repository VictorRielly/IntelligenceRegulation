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

### 3.1 Legs

(see the battery output table — recorded on lane close)

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

### 5.1 Norm (measured at the engine ring)

(filled from `ixf-fold norm` on lane close)

### 5.2 Byte model

(filled from `ixf-fold bytes` + measured runs on lane close)

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

(filled on lane close)
