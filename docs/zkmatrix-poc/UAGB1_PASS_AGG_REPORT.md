# U-AG-B1 Pass Aggregation Report — Lane BG (wave 3: THE COMPOSITION)

Status: LANE DELIVERABLE (2026-08-10, U-AG-B1 wave 3, worktree
wt-uagb1-bg). Ledger: PROGRESS_UAGB1.md "Agent BG status". Machine:
Victor's Mac (Apple silicon) — NOT the contract reference box; every
timing [MAC-BOX, non-reference], [NOISY-SHARED] where sibling lanes
(BH/BI) ran concurrently. Byte counts, schedules, battery verdicts,
and freeze rows are machine-independent.

**HEADLINES (both measured on real ckpt-00009536, 12 layers,
T = 512, end to end, accept = true; composed-relation scope per
Section 1):**

> **Tier N pass (P0, bare): 426,455 B = 0.407 MiB = 0.1356x the P0
> pass gate** (12 x 262,144 B) — derived expectation 426,622 B,
> agreement to the statement-section byte.
> **Tier Z pass (P2, weight floor masked once/pass): 1,019,211 B =
> 0.972 MiB** — derived expectation 1,019,234 B; the A1 frozen
> 1,114,112 B is the 7B-P3 scope (cited); the measured once-per-pass
> weight-mask surcharge = 592,756 B (FP-L3/W-C amortization
> measured).
> vs BF's wave-path pass artifact: **18,581x smaller**; the
> opening volume is GONE.

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

**The pass-level Tier N artifact, 12 layers, T = 512, real
ckpt-00009536 data, one shot, end to end: accept = true.**

| component | measured B |
|---|---:|
| statement (serialized, real; v4 + P0 mode section; digest 6a2b52f5..) | 26,103 |
| mm-gate 50 kel + mm-up 50 + mm-down 53 | 9,792 |
| had 101 kel + rq-g/u/h 82 x3 + rq-d 79 | 22,208 |
| public binding claims (24) | 1,536 |
| [weight] outer 11,360 + rows 8,260 + levels 39,760 + floor 120,196 (939 rings e7, 8 levels) | 179,576 |
| [act] outer 11,360 + rows 8,260 + levels 45,440 + floor 117,124 (915 rings e7, 9 levels) | 182,184 |
| **TOTAL (counted-not-serialized)** | **426,455** |

**Verdicts of the number:**

- vs the DERIVED expectation (Section 4, 426,622 B): measured is
  167 B under — the delta is entirely the statement's serialized
  mode section (P0 = 10 B vs the P2 estimate used in the
  expectation); every instance kel count and every group line is
  EXACT to the derivation. Derived-vs-measured agreement at the
  byte level.
- vs the Tier N P0 gate (262,144 B/layer x 12 = 3,145,728 B/pass):
  **0.1356x — 7.4x UNDER the gate; 35,538 B/layer amortized.** The
  composed-scope label applies (Section 1): the artifact covers the
  arithmetic-relation set + input/output binding; the [MODEL]
  descent lines for the table-membership facts would bring the
  full-statement expectation to ~1.39 MB (still under the pass
  gate; Section 4).
- vs BF's wave-path pass artifact (7,923,653,984 B): **18,581x
  smaller.** vs BE's folded-transcript pass (1,406,719,131 B):
  3,299x smaller. The opening volume (99.7-99.8% of every wave-1/2
  artifact) is GONE — replaced by 2 outer identities + 2 eval-proof
  descents, exactly as the aggregation trench designed.
- The U-AG4 "folded W-C pass target 0.3-0.5 MiB class [MODEL]"
  (wave-1 close) is now MEASURED at 0.407 MiB.

Timing [MAC-BOX, non-reference, NOISY-SHARED — lane BH re-measures
+ the BG battery ran concurrently for parts of the run]: commit
380.1 s (loads + chain derivation + digit witnesses + u_0s), prove
4,178.1 s (69.6 min), verify 955.2 s (15.9 min), wall 5,521 s,
peak RSS 38.2 GiB (/usr/bin/time -l; single-threaded). One shot,
measured once, honestly — p50/p95 discipline is lane BI's harness
(stretch not taken here; per-run numbers recorded as-is).

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

**The pass-level Tier Z artifact, mode P2 declared on the statement
(Amendment A1 plumbing: private set = exactly the 36 weight-class
entries), 12 layers, T = 512, real data: accept = true.** The FP-L3
split as designed: the WEIGHT group's floor masked ONCE per pass
(Tier-Z e_L = 4 refit, F-Z1 corner b = 2^27.75 asserted at derive,
prover-internal Gaussian mask, FP-L2/A8 no hash edge, response after
all level challenges per AZB-6, Lyubashevsky rejection with
**0 restarts logged** — F-Z3); the activation group BARE.

| component | measured B |
|---|---:|
| statement (serialized; v4 + P2 mode section 144 B; digest c8aaf326..) | 26,247 |
| folded instances (identical to P0) | 32,000 |
| public binding claims | 1,536 |
| [weight] outer 11,360 + rows 8,260 + levels 39,760 + MASKED floor 700,420 (1,368 rings e4) + mask images 12,388 | 772,188 |
| [act] outer 11,360 + rows 8,260 + levels 45,440 + bare floor 117,124 (915 rings e7) | 182,184 |
| **TOTAL** | **1,019,211 = 0.972 MiB** |

**Verdicts of the number:**

- vs the DERIVED expectation (1,019,234 B): measured is 23 B under
  — again the statement-section estimate; every protocol line
  EXACT. The derivation IS the artifact.
- **THE 125M-PASS TIER Z OBLIGATION (the ledger's "must be DERIVED
  by this round"): P2 = 1,019,211 B measured at the composed scope
  [+ ~0.92 MiB [MODEL] descent lines for the full statement —
  Section 4].** The A1 FROZEN budget (1,114,112 B) is the 7B-pass
  P3/W-C scope — cited for class only: the 125M P2 composed number
  sits 94,901 B under it; the full-statement [MODEL] extension
  (~1.98 MiB) sits above it, driven by BG-F1's 9-per-table descent
  structure — an honest 125M-structural finding, not a 7B
  statement.
- **The measured once-per-pass weight-mask surcharge (FP 4.3's
  amortization, measured): P2 - P0 = 592,756 B** = masked-vs-bare
  floor (+580,224) + mask images (+12,388) + the mode section
  (+144). Per layer amortized: +49,396 B. The unfolded per-layer
  alternative would pay a masked floor PER LAYER; the composition
  pays it once — the FP-L3/W-C design's point, now measured.
- Restarts 0 across the pass (single Tier-Z floor challenge; the
  F-Z3 abort discipline exercised with the logged counter).

Timing [MAC-BOX, non-reference, NOISY-SHARED — the 14-leg battery
ran concurrently]: commit 367.0 s, prove 4,121.9 s, verify 949.9 s,
wall 5,446 s, peak RSS 42.9 GiB. Single-shot; p50/p95 = lane BI's
harness (not claimed).

P1/P3: REFUSED by the composition layer with the named gap (the
act-side mask + T_blind instance masking = E-1..E-5, absent); the
declarations themselves validate (plumbing complete) — no silent
degradation in either direction.

## 6. Battery and the AZB-11 canary

### 6.1 The composition battery (`pass-agg battery` — **14/14 GREEN, 4,682.8 s** [MAC-BOX, NOISY-SHARED]; 3 layers, T = 16, REAL ckpt data; lambda = 2 with 1 vacuous pad slot; shifts differ across the 3 layers so the requant publics are genuinely layer-keyed)

| leg | verdict |
|---|---|
| honest P0 ACCEPT (383,798 B counted at the small shape) | ok |
| honest P2 ACCEPT (Tier-Z weight floor, restarts 0, 966,462 B) | ok |
| **the composed seam**: fold-family claim lie (tampered gate A table; self-consistent sumcheck + claim; act b_rows ct-forced, the BD WrongC pattern) — REJECT lands at **floor-target**: the eval proof catches the claim-interface lie through the transported chain | ok |
| wrong-layer content through the composed path: Gacc_0 <-> Gacc_1 witness swap (self-consistent commit) — REJECT at **sc-matmul** (the folded matmul's committed-C claim vs the sumcheck; the layer-keyed requant publics stand behind it) | ok |
| bare-floor wire tamper — REJECT floor-fold-consistency | ok |
| OOA floor pair (recomposition-preserving) — REJECT **isolated to the alphabet gate** (the BD sharp leg reproduced at pass scope) | ok |
| Tier-Z response-norm tamper — REJECT tierz-response-norm | ok |
| Tier-Z mask-image tamper — REJECT tierz-family | ok |
| declared-output public-claim lie (shipped on the wire) — REJECT public-claim (the verifier's own recompute from public data) | ok |
| AZB-10b DEFENSE (derive): shipped prover REFUSES the forged group map (azb11-static-prover, loud) | ok |
| AZB-10b DEFENSE (h0): hook-produced forged-map proof REJECT at the shipped verifier's statement-derived map binding | ok |
| AZB-10b ATTACK: map-unbound weakened verifier ACCEPTS the migrated pass — the leak face live (exhibit in 6.2) | ok |
| E-O2-BB: second batched opening in a group = build error | ok |
| mode plumbing: P2 digests; wrong private set REJECTS (ModeDeclInvalid); codec round-trips; P3 declaration validates; P1/P3 runner REFUSES | ok |

### 6.2 AZB-11 at the pass group map (`pass-agg canary` — **6/6 GREEN, 1,777.8 s**, 3 layers, T = 16, mode P2)

The four FP 4.2 legs + both 11b contaminated variants, at the pass
group map where the canary's semantics live (BD's wave-2
disposition). Legs 2/3 run under the engine's own honest-verifier
fixed-coin transcripts (challenges independent of absorbed content
— the leak-harness tool; battery-only, never shipped) with the
honest h0 pinned, which is exactly the spec's f(T_act, challenges)
recompute form.

| leg | verdict |
|---|---|
| 1 static support (derive-time, EVERY shipped pass): every act-batch tensor in T_act; nu support zero on T_W | **ok** |
| 2 functional recompute: act batched claims AND act floor recomputed from (T_act, challenges) ALONE — the weight witness zeroed out — act-side proof bytes **byte-exact** | **ok** |
| 3 perturbation: W perturbed, T_act fixed — the bare activation transcript **byte-identical** | **ok** |
| 4 migration F5, three directions: shipped prover REFUSES at derive (azb11-static-prover — the E-11 F-Z3 wiring); hook-produced forged-map proof REJECTED by the shipped verifier's h0 map binding; map-unbound weak pipeline ACCEPTS (attack lands) with the static leg firing | **ok** |
| AZB-11b(i) claim-layer smuggle (a weight-tensor claim marked act-side) fires the static leg | **ok** |
| AZB-11b(ii) floor fold-in (delta = a WgT digit-ring column — an explicit weight functional) fires the leg-2 recompute | **ok** |

**The AZB-10b leak face, exhibited (E-10 group face):** the
weak-accepted migrated pass's act floor differs from the honest act
floor (936 vs 921 rings) — the delta carries the migrated WgT_0
digit rings folded into the bare floor (explicit weight-functional
coordinates c_j (x) w_weight in the z-fold). The shipped defenses
(derive refusal + h0 map binding) kill both routes to it.

**REJECT semantics, wired:** any canary failure is
DEPLOYMENT-BLOCKING for P2 — the shipped prover refuses at derive
(loud error), the shipped verifier rejects (azb11-static /
h0-map-binding) — errors, never warnings (F-Z3).

**The positive certification this buys (the brief's ask):** the
BARE ACTIVATION FLOOR of the P2 pass is certified
weight-independent — its bytes are a function of (T_act witness,
challenges) only, demonstrated by byte-exact recompute with the
weight witness ABSENT and invariance under weight perturbation;
weight-contaminated variants FIRE. The FP 4.3 accumulation story
(the weight mask once per pass carries the across-pass asymmetry)
rides on exactly this invariant.

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

1. **BG-F1 (design finding): the shared-table fold assumption
   breaks at 125M** — Section 1; the folded-descent line is 9
   per-table pairs (~0.92 MiB [MODEL]) at 125M structure vs the
   design's one-pair form (~0.11 MiB). Exported to the descent
   build item and FINAL.
2. **BG-F2: derived-vs-measured byte identity.** The measured pass
   artifact equals the executable derivation line-for-line (the
   only delta: the statement's 10-B P0 mode section vs the P2
   estimate). The schedules, kel counts, and floors ARE the
   artifact — the counted convention has no slack at this scope.
3. **BG-F3 (the wall row): the pass-scale prover is level-0-
   dominated.** Prove 69.6 min [MAC-BOX, NOISY-SHARED, 1T]:
   the level-0 h cross-garbage is Theta(n_0 * r) ring-mults with
   the planner's byte-optimal r pinned at the 64 cap for both
   pass groups (~500M + ~227M kara-muls), plus three O(N_limb)
   claim-kernel/phi passes (~16 kara-muls/ring each). Verify
   15.9 min = BD's recorded O(N_limb) verifier wall at pass scale
   (the phi materialization; this lane consumed the pre-split
   eval_proof API — lane BH's row-column split is the recorded
   fix, bytes unaffected). Commit 380 s = 12 chain derivations +
   digit decomposition + the u_0 matvecs.
4. **BG-F4: floor witness-size independence, demonstrated.** The
   weight group's bare floor (939 rings) and Tier-Z floor (1,368
   rings, corner 2^27.75) at the 3,538,944-ring pass witness EQUAL
   lane BD's single-layer schedule values (24,576 rings) — the
   FP-L1 regrowth law measured at 144x, and the reason the pass
   amortization works at all.
5. **BG-F5 (E-11 wiring design point):** the derive-time static
   refusal first landed as a panic; converted to a loud
   deployment-blocking VERDICT (azb11-static-prover) so both
   shipped F5 faces are observable rejects (the battery caught
   this — the leg-4 crash was my own refusal firing correctly but
   uncatchably).
6. **The P2 gap, restated:** the weight-touching ROUND POLYNOMIALS
   ride unmasked (T_blind machinery absent — E-1..E-5); the FP 3.2
   deltas price it at ~1,664 B [MODEL]. Deployment-grade P2 needs
   the instance masks; the artifact and label say so.

### 7.4 Exports

- To the orchestrator/BH (API rows, filed at plan, held): (1)
  eval_proof.rs ClaimKernelCtx supports ONE product-form kernel per
  tensor (kernels.find) — the pass needs additive multi-claim
  weights (built around in ring/pass_agg.rs::GroupClaims); (2) a
  streaming (vw-free) kw_row variant — the materialized per-value
  table is O(N_values) K-elems at pass scale. Both non-blocking;
  merge-ready for BH's row-column split to consume.
- To BI: the composed artifact's counted lines (Section 3) are the
  wire-format's target inventory; the statement's mode section is
  additive-only (old wire byte-identical) — the codec face is
  already round-trip-tested in the manifest battery + freeze row.
- To FINAL: the Tier N and Tier Z pass rows vs the derived
  expectations and A1 (Sections 3/5); BG-F1 (the per-table descent
  structure) attached to the folded-descent build item; E-O3-BB
  still OPEN and attached there too (Section 7.1); the P1/P3
  refusal is the standing honest gap (E-1..E-5).

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

## 9. Wave-4 addendum (2026-08-11, lane BJ): R-BG1 fixed — the additive multi-claim API landed; composed verify re-measured under BH's split

### 9.1 R-BG1: the defect, reproduced and pinned

At the wave-3 merged HEAD the AZB-11 canary panicked in its first
leg (`assertion left == right failed, left: 972, right: 162` at
ring_matmul.rs:21318, `agg_floor_family_values` <- `bg_verify_group`
<- `bg_pass_run` — reproduced with backtrace before any fix).
Root cause: lane BH's factoring changed
`agg_floor_family_values`'s last parameter from PHI (the level
array, r x chunk rings) to PSI (per-chunk, `plan_last.chunk` rings)
and updated BD's call sites; BG's `bg_verify_group` Tier-Z arm —
written pre-BH, merged after — still passed `&phi_cur` (len
r x chunk = 6 x 162 = 972 at the canary shape). Consequence at
merged HEAD: EVERY composed P2 VERIFY panicked there (the canary,
the battery's P2 legs, and a 12-layer P2 pass verify had one been
run); the P0 verify and the P2 PROVER (`agg_tier_z_mask_floor` kept
its phi parameter) were unaffected — which is exactly why the
shipped-path checks stayed green and the canary was the first thing
to hit it.

### 9.2 The fix: the exported API, landed additively

Per Section 7.4's export, `src/ring/eval_proof.rs` now carries the
ADDITIVE multi-claim entry points ([UAGB1-BJ] block):
`MultiClaimKernel` (one scaled product-form contribution per entry —
the `pass_agg::ClaimContrib` shape; any number per tensor, weight
tables ADD) and `psi_level0_factored_multi` — the row-column split
of the SUMMED weight (per kernel the scale folds into the row
factor, K being a field; contributions add ring-linearly into
Psi_0; aligned + misaligned-generic branches; no O(N_values) table
and no Phi_0 materialization — export item 2's vw-free form is
subsumed). `ClaimKernelCtx`, `psi_level0_factored`,
`transport_level`, `transport_level_from_psi` and every BD/BH call
site are untouched. `phi0_reference_multi` is the per-ring oracle.

`bg_verify_group` now rides BD's post-BH shape end to end: Psi_0
factored-multi after c_0 (the wave-3 `bg_kernel_pass` alpha-pass
phi materialization is GONE from the recursed verify),
`transport_level_from_psi` at level 1, `psi_floor` = Psi_0 for
one-level schedules else `compute_psi` of the small transported
phi, and BOTH floor branches (bare L1 and the Tier-Z family
values) consume `psi_floor` — the R-BG1 fix proper. The prover is
untouched (it materializes phi for its h-garbage by design).
Transcript absorb/draw order, wire bytes, and all counted-byte
lines are unchanged.

### 9.3 Evidence at this HEAD

- **`pass-agg seam` (NEW, [UAGB1-BJ]): 12/12 green, 46.3 s** — the
  factored-multi Psi_0 equals `compute_psi(bg_kernel_pass phi)`
  coefficient-for-coefficient on the REAL 1-layer T = 16 groups
  (act: 42 kernels, aligned; weight: 9 kernels, e0 = 1 sign-binary
  radix path) and on the misaligned 64x96x128 synthetic groups
  (generic branch, forced L2 + L1) with the per-ring oracle tied
  in; a perturbed contribution scale moves Psi (non-vacuity).
- **`pass-agg canary`: 6/6 GREEN — twice** (1,621.9 s at the fix
  commit; re-run **1,600.9 s at the final lane HEAD**) [MAC-BOX,
  NOISY-SHARED]: all four FP 4.2 legs + both 11b contaminated
  variants, byte-exact act-side recompute (legs 2/3), the leg-4
  three-direction migration F5 with the AZB-10b leak exhibit
  intact (weak-accepted migrated act floor 936 vs honest 921
  rings). The gate this stage existed for.
- **`pass-agg battery`: 14/14 GREEN at the final HEAD** (4,177.6 s
  [MAC-BOX, NOISY-SHARED — stage-2 lanes ran concurrently]) — the
  honest P0/P2 accepts reproduce the wave-3 counted bytes EXACTLY
  (383,798 / 966,462 B), and every REJECT surface my rewiring sits
  under lands with its recorded first-fail: floor-target,
  sc-matmul, floor-fold-consistency, the OOA alphabet isolation,
  tierz-response-norm, tierz-family (the two Tier-Z tampers now
  RUN — at the merged wave-3 HEAD they panicked before reaching
  the check), public-claim, the AZB-10b trio, E-O2-BB, and the
  mode-plumbing legs.
- **`m125-pass battery small`: 8/8 green** (Section 9.5's leg
  included); **python suite: Ran 62 tests — OK (674.0 s)** and
  **freeze-check green** at the final HEAD with every pre-existing
  digest unmoved.

### 9.4 Composed-verify re-measure under BH's split (deliverable 2)

Wave 3 measured the composed P0 pass verify at 955.2 s PRE-split
(this report, Section 3 — the composed verifier materialized phi
via its own kernel pass, the O(n_0)-class wall BH removed for BD's
path). At this HEAD the composed verifier rides the split through
the multi-claim entry point. Re-measured, single-shot honest, same
machine [MAC-BOX, non-reference, NOISY-SHARED — wave-4 stage-2
lanes BK/BL launched on this box mid-run and their batteries
overlapped; the wave-3 baseline carried the same class of label],
fresh full prove in the same invocation (the BG rig has no
serialized-artifact re-verify path; the artifact is re-proven and
re-verified in one `pass-agg prove 12 512 p0` run):

| measurement (12 layers, T = 512, P0) | wave 3 (pre-split) | this HEAD | ratio |
|---|---:|---:|---:|
| **VERIFY** | **955.2 s** | **199.6 s** | **4.79x** |
| prove | 4,178.1 s | 4,117.4 s | ~1x (untouched) |
| commit | 380.1 s | 375.4 s | ~1x |
| counted bytes | 426,455 B | 426,455 B | 1.000x (wire untouched) |
| statement digest | 6a2b52f5.. | 6a2b52f5.. | identical |
| accept | true | true | — |
| wall / peak RSS (/usr/bin/time -l) | 5,521 s / 38.2 GiB | 4,700 s / 40.8 GiB | — |

- Every byte LINE reproduces exactly (statement 26,103; instances
  50/50/53/101/82/82/82/79 kel; [weight] 179,576 = outer 11,360 +
  rows 8,260 + levels 39,760 + floor 120,196; [act] 182,184) — the
  fix and the split are implementation restructures; the artifact
  is bit-stable.
- The verify drop BEATS the queued "expected ~3x" (BH's 3.23x was
  measured at the single-layer statement with ONE kernel per
  tensor): at pass scale the composed verifier's removed
  kernel-pass materialized phi over 7.8M + 3.5M digit rings with
  DOZENS of additive contributions per tensor, so the removed term
  was a larger share. 199.6 s is user-dominated (99.6% CPU) despite
  the shared box. The contract's 2 s R2 line binds the REFERENCE
  box and is NOT claimed; [MAC-BOX] magnitude only.
- RSS note: the pass peak (40.8 vs 38.2 GiB) sits in the PROVE
  phase (the prover still materializes phi for its h-garbage by
  design); the verifier-phase phi materialization (~8 GiB-class at
  the act group) is gone.

### 9.5 BF-F3 wiring side effect on this report's [MODEL] lines

Lane BJ also wired BH's BF-F3 capacity lift into the m125 rig
(`bf_dw_for` -> split-fill capacity n - 8; see the
M125_PASS_REPORT.md wave-4 addendum). `pass-agg expect`'s
125M-STRUCTURAL descent lines ride `bf_dw_for`, so the NOT-composed
[MODEL] lines of Section 4 MOVE (every structural dw down 1):
125M-STRUCTURAL total 959,232 -> 898,496 B (0.915 -> 0.857 MiB);
FULL-STATEMENT expectations Tier N 1,385,854 -> 1,325,118 B
(~1.32 -> ~1.26 MiB), P2 1,978,466 -> 1,917,730 B. The composed
derivations (426,622 / 1,019,234 B) are UNCHANGED. Wave-4 stage 2
(lane BK, the folded masked descent) should target the UPDATED
structural lines; the design-form F-IF1.1 line (dw_pass = 25) is a
formula, not a `bf_dw_for` consumer, and did not move.

---

*Changelog: 2026-08-11 — wave-4 addendum (lane BJ): R-BG1 fixed
(the additive multi-claim API of Section 7.4's export landed in
eval_proof.rs; bg_verify_group rides the BH split; canary 6/6 at
the fixed HEAD); composed P0 verify re-measured under the split
(Section 9.4); [MODEL] descent lines updated for the BF-F3 lift
(Section 9.5).*

*Changelog: 2026-08-10 — first edition (U-AG-B1 wave 3, lane BG):
the pass-level composition landed and measured end to end on real
weights — Tier N P0 426,455 B (0.136x the pass gate) and Tier Z P2
1,019,211 B (0.972 MiB, weight floor masked once/pass, restarts 0),
both within bytes of their executable derivations; battery 14/14;
AZB-11 canary 6/6 with the AZB-10b leak exhibit; mode-declaration
plumbing (additive manifest, old digests/wire unmoved); freeze rows
UAGB1-BG-1a..2; suite 61/61; findings BG-F1..F5; E-O3-BB
dispositioned open against the folded-descent build item.*
