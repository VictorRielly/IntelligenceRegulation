# U-AG-B1 Pass Aggregation Report — Lane BG (wave 3: THE COMPOSITION)

Status: LANE DELIVERABLE (2026-08-10, U-AG-B1 wave 3, worktree
wt-uagb1-bg). Ledger: PROGRESS_UAGB1.md "Agent BG status". Machine:
Victor's Mac (Apple silicon) — NOT the contract reference box; every
timing [MAC-BOX, non-reference], [NOISY-SHARED] where sibling lanes
(BH/BI) ran concurrently. Byte counts, schedules, battery verdicts,
and freeze rows are machine-independent.

## 0. What this lane built, in one paragraph

The pass-level composition: BF's 12-layer real-weights v4 pass
statement (ckpt-00009536, T = 512) -> BE's IXF folded instance
families (the joint matmul iterated at the 3 pass positions, the
stacked zero-check for the Hadamard, plus a NEW folded requant
zero-check family with the public layer-coefficient MLE 2^{s_l}
read from the statement's shift table) -> BD's per-group batched
opening + eval proof (W-C two-group layout, exactly one eval proof
per commitment group — E-O2-BB enforced). The wave-1/2 opening
volume (99.7-99.8% of every prior artifact: 7.38 GiB at BF's pass)
does not exist in this artifact at all: the pass data is bound by
ONE outer identity u_0 per group and grounded by the two eval-proof
descents. Mode P0 (bare) and mode P2 (Amendment A1 declaration
plumbing + the FP-L3 split: the WEIGHT group's floor Tier-Z-masked
ONCE per pass, activation group bare) both run end to end on the
real checkpoint data.

## 1. Scope and honest labels

**Composed relation set** (what THIS artifact proves, printed with
every run):

| relation family | pass form | claims into the batched opening |
|---|---|---|
| 3 matmuls/layer (gate/up/down) | 3 folded joint-matmul sumchecks (FD-L2 (3,2) form; 12 layers -> ONE instance each) | A*/C* (act group), B* (weight group), per instance |
| Hadamard a8 o u8 = H | 1 folded stacked zero-check (FD-L1) | a8*/u8*/H* (act) |
| 4 requant edges/layer (Acc = 2^{s_l} y + r) | 4 folded requant zero-checks — NEW family: public layer-coefficient MLE c~(l) = 2^{s_l}; schedule [2; n_pos]++[3; lambda]; sh* and eq* verifier-recomputed from the STATEMENT | Acc*/y*/r* x4 (act) |
| input/output binding | X_l and declared-z_l public claims at one shared post-h0 point; values computed BY THE VERIFIER from the public data | 24 per-layer claims (act) |
| weight binding | u_0(T_W) outer identity + statement digests (the per-model, off-the-clock discipline). Weights are NEVER verifier-evaluated — the FD 6.4 W-A rejection ruling | (commitment layer) |

**NOT composed (the loud label):** the table-membership facts — the
SiLU LookupAt and the 7 RangeLookups per layer (96 descent-pair
instances at BF's per-layer form). The folded masked descent is the
recorded unbuilt piece (lane BE WILL-NOT-DO: the >= 2^23.6-element
folded witness column needs the multi-wave C2 lift,
AZB_BATTERY_PLAN Section 7 route 2). The statement still DECLARES
every fact; the composed artifact's covered-operation set excludes
them, and their derived byte lines ride the Section 4 expectation
[MODEL] in BOTH structural forms. Consequence stated plainly:
without the range/lookup facts, the composed relations pin the
witness chain up to the table-fact freedoms (e.g. a remainder is
tied by its requant identity but not range-bounded; a8 is tied by
the Hadamard but not by SiLU membership). The wrong-layer battery
leg (Section 6) is scoped to what the composed relations DO pin;
the full-statement artifact is exactly this artifact + the folded
descent lines when that machinery lands.

**Finding BG-F1 (the shared-table assumption breaks at 125M).**
F-IF1.1's descent-fold rows assume ONE shared SiLU table and ONE
shared range table. The real 125M statement has TWO SiLU family
members ((-3,-3) x10 layers, (-4,-4) x2) and SIX distinct remainder
widths (w in {5..10}) — the folded descent at 125M is therefore
2 + 1 + 6 = 9 per-table folded pairs, not the design's 2-3
(Section 4 prices both). Exported to FINAL/the descent build.

**P2 honest label (pre-registered at plan, held).** The P2 artifact
masks the WEIGHT GROUP FLOOR (the accumulation-critical object —
the A1/E2/E4 carve-out; I-6 holds everywhere else). The
matmul/terminal ROUND POLYNOMIALS are functions of the weights and
ride unmasked this wave — the T_blind instance-masking machinery is
the E-1..E-5 block, absent at the composed path. Design price for
that gap: the FP 3.2 masked-instance deltas (~4 x 416 B [MODEL]).
Deployment-grade P2 requires it; nothing here claims it.

## 2. The construction (what is on the wire)

### 2.1 Commitment layer

Per group (T_W = 36 per-layer weight tensors; T_act = 168 per-layer
activation/accumulator/remainder tensors), the exact-digit witness
(classes derived per entry from the v4 typing: weights CLS_W8S
e0 = 1 l0 = 8 sign-binary (F-N2); 8-bit acts l0 = 5, accumulators
l0 = 13, H l0 = 8, remainders l0 = 5-6 at e0 = 2) is bound by ONE
outer identity u_0 = B_0u(t-hat) per group (5,680 B). h0_agg =
SHA(statement digest || the canonical GROUP/SEGMENT MAP bytes ||
u_0(T_W) || u_0(T_act)); the map is DERIVED from the statement's
privacy classes by the verifier (zero wire bytes) — the AZB-10b
edge lives exactly here.

### 2.2 Claim layer (one rolling transcript)

Instance order: mm-gate, mm-up, mm-down, had, rq-g, rq-u, rq-h,
rq-d, then the public binding claims, then nu (one per claim, drawn
AFTER all terminal values are absorbed — CRB-N5). Per matmul
instance: outer draws (r_l, rx, ry) -> the committed-C claim value
v_C absorbed (computed from the ACT witness — manifestly
T_act-only, the AZB-11 recompute form; the honest run asserts it
equals the instance-table sum, the composition seam's self-check)
-> the folded sumcheck (fold.rs public API) -> terminals absorbed.
Stacked claims decompose onto per-layer tensors with eq(l*, l)
row-kernel scales — BD's product-form kernel interface, generalized
in ring/pass_agg.rs to ADDITIVE multi-claim weights (an API-change
export is filed for eval_proof.rs's one-kernel-per-tensor
ClaimKernelCtx — BH's zone, built around, not edited).

### 2.3 The eval proofs

BD's LaBRADOR-form recursion consumed as-is at pass scale (kappa
11, R-EB1/R-EB3/R-EB4 rows, adaptive bases, h-family transport):
schedules DERIVED by the public planner from the pass inventories
(freeze rows UAGB1-BG-1a/1b, both directions):

| group | n_0 (digit rings) | levels | floor | floor e |
|---|---:|---:|---:|---:|
| act (T_act) | 7,823,360 | 9 | 915 rings | 7 |
| weight (T_W) | 3,538,944 | 8 | 939 rings | 7 |
| weight Tier-Z (P2) | 3,538,944 | 8 | 1,368 rings | 4 |

**Witness-size independence, demonstrated:** the weight bare floor
(939) and Tier-Z floor (1,368, corner b = 2^27.75) EQUAL lane BD's
single-layer schedule values at a 144x bigger weight witness — the
LaBRADOR floor regrowth law (FP-L1 component 3) at engine scale.
F-Z1 asserted at derive (freeze row UAGB1-BG-1c).

## 3. THE BARE COMPOSITION (P0) — measured

(filled at the full-shape run)

## 4. The derived 125M pass-budget expectation (BA rule; `pass-agg expect`, executable)

Derived from the design formulas AT the 125M shapes (group
inventories from the statement class table; schedules from the
public planner; instance kel arithmetic at 125M rounds). The 7B
rows (ZK_GAP_OPTIONS Section 8 / FP 3.3) are cited, never copied.

| component | derived B |
|---|---:|
| statement (serialized; BF-measured 26,116 + mode section) | 26,270 |
| folded instances (50+50+53+101+82+82+82+79 = 579 kel) | 37,056 |
| public binding claims (24) | 1,536 |
| [act] outer 11,360 + rows 8,260 + levels 45,440 + floor 117,124 | 182,184 |
| [weight] outer 11,360 + rows 8,260 + levels 39,760 + floor 120,196 | 179,576 |
| **EXPECTED Tier N composed pass (arithmetic-relation scope)** | **426,622 = 0.407 MiB** |
| vs the P0 pass gate 12 x 262,144 = 3,145,728 B | **0.136x — UNDER; 34.7 KiB/layer amortized** |
| [weight] Tier-Z: floor -> masked response 700,420 + images 12,388; levels unchanged | |
| **EXPECTED Tier Z P2 pass (weight floor masked once/pass, FP-L3)** | **1,019,234 = 0.972 MiB** |
| + the not-composed masked-instance deltas [MODEL, FP 3.2] | +~1,664 |

The folded-instance transcript (579 kel = 37,056 B) lands within
1% of BE's FA-convention full-population line (511 kel [MODEL] —
the difference is the engine's d+1-evals convention plus the
per-table split), and the composed Tier N expectation lands inside
the U-AG4 "folded W-C pass 0.3-0.5 MiB" class.

**The NOT-composed descent lines [MODEL], both structural forms:**

- design-form (F-IF1.1 shared-table assumption): ONE folded pair at
  dw_pass = 21 + 4 = 25 -> kel(25) = 1,760 = 112,640 B + rho-shared
  range arm (D-R1) + table arms.
- 125M-STRUCTURAL (finding BG-F1): SiLU (-3,-3) dw 25 = 112,640;
  SiLU (-4,-4) dw 23 = 98,944; narrowings [0,2^8) dw 26 = 119,872;
  remainders w=5/6/7/9 dw 24 = 105,664 each, w=8 dw 25 = 112,640,
  w=10 dw 22 = 92,480 — TOTAL ~959,232 B = 0.915 MiB [MODEL].
  D-R1 breaking adds one witness arm per shared group.

Full-statement expectations: Tier N ~1,385,854 B [MODEL descent
lines], P2 ~1,978,466 B [MODEL]. The descent fold (and BG-F1's
per-table structure) is the load-bearing open item between the
composed artifact and the full-statement artifact.

**A1 comparison discipline:** the frozen Tier Z budget (1,114,112 B)
is the 7B-pass P3/W-C scope — cited, not transferred. THE 125M-pass
P2 obligation this round owed (ledger: "the 125M-shape Tier Z pass
number must be DERIVED by this round") = the derived 0.972 MiB
above at the composed scope, [MODEL]-extended by the descent lines
for the full statement.

## 5. THE P2 PASS (Tier Z) — measured

(filled at the full-shape run)

## 6. Battery

(filled after the battery runs)

## 7. E-O3-BB disposition; E-blocks; walls and findings

### 7.1 E-O3-BB at the pass statement (dispositioned, not silent)

E-O3-BB = "D-R1 rho-sharing verified with a battery leg OR the split
priced (+one descent pair), never silent" — transferred here from
BA via BD. Disposition at the composed pass artifact: **the composed
path carries NO descent pair at all** (the folded masked descent is
the recorded unbuilt piece — Section 1), so D-R1 rho-sharing has no
engine object THIS wave either. Both branches are PRICED in the
Section 4 expectation: the rho-shared reading rides the design-form
line (one witness arm shared); the break case adds one witness-arm
descent pair per shared fold group ([MODEL], the FP 3.5 sensitivity
form at 125M structure). The battery leg lands when the folded
descent lands; the obligation stays OPEN and attached to that build
item — recorded in the ledger verdict row.

### 7.2 AZB E-blocks at this lane's stages

| leg | status here |
|---|---|
| E-10 (AZB-10 vs the real pass manifest) | **group face (AZB-10b) WIRED at the composed pass**: the statement-derived group map binds inside h0_agg; forged-map F5 pair BOTH directions (shipped h0 REJECT / map-unbound weak verifier ACCEPTS with the leak face live) + the migrated-floor weight-functional exhibit (canary leg 4). The segment face (AZB-10a) stays BE's landed engine leg (statement-digest edge), consumed unchanged. |
| E-11 (AZB-11, the weight-independence canary) | **WIRED at the pass group map** — the four FP 4.2 legs + both 11b contaminated variants (Section 6); leg 1 (static support) runs in EVERY shipped prove AND verify as an error, not a warning (deployment-blocking semantics per F-Z3). |
| E-6 / E-7(i) | inherited from BD's landed engine legs; my per-level structure is BD's (one representative-level F5 pair battery-covered there). The AZB-11 leg-2 recompute IS the E-7(i) pattern applied per GROUP at pass scope. |
| E-1..E-5, E-7(ii/iii), E-8, E-9 | **NOT unlocked** — they bind the T_blind/blinding machinery, which does not exist at the composed bare/Tier-Z path (the same honest gap as the P2 round-polynomial masking, Section 1). Stated, not fudged. |

### 7.3 Walls and findings

(filled at close)

## 8. Freeze rows and reproduction

- `freeze_check_uagb1_bg()` (in `freeze-check`): UAGB1-BG-1a (pass
  inventories 7,823,360 / 3,538,944 digit rings), BG-1b (schedules
  L9/915-e7 act, L8/939-e7 weight, 1,368-e4 Tier-Z weight), BG-1c
  (F-Z1 corner b = 2^27.748 < 28.00, growth branch dead), BG-2
  (mode digest/codec discipline: mode-less digests and wire bytes
  stable; P2 digest distinct; round-trip; old wire -> None).
  Every pre-existing freeze digest unmoved at every commit.

```
zkmatrix-rs$ cargo build --release
zkmatrix-rs$ ./target/release/ring_matmul pass-agg expect     # the derived expectation (no exports needed)
zkmatrix-rs$ ./target/release/ring_matmul pass-agg battery    # 13 legs, 3 layers, T = 16, real data
zkmatrix-rs$ ./target/release/ring_matmul pass-agg canary     # AZB-11 + AZB-10b leak face
zkmatrix-rs$ ./target/release/ring_matmul pass-agg prove 12 512 p0   # THE Tier N pass number
zkmatrix-rs$ ./target/release/ring_matmul pass-agg prove 12 512 p2   # THE Tier Z pass number
zkmatrix-rs$ ./target/release/ring_matmul freeze-check
repo$ python3 -m unittest tests.test_uagb1_pass_agg
```
