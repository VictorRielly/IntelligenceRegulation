# Aggregation ZK Design (O-4): The Three Exposure Surfaces of the Reduced Protocol

Status: DESIGN ROUND (U-AG3, Agent EC lane, 2026-07-27) — paper +
Python spike, no Rust engine changes. Spec: PROGRESS_UAG3.md EC lane;
discharges obligation **O-4** (AGGREGATION_LITERATURE.md 8.1; the
AGGREGATION_CLAIM_REDUCTION.md Section 11 handoff list is the input
inventory; the AGGREGATION_PARAMS_DESIGN.md Section 2.4/2.5 layout and
interface **I-6** are hard constraints). Companions:
WAVE_SHARE_MASKING_DESIGN.md (WSMD — the simulator style Section 5
copies and the 7.1 standing constraint Section 5.6 discharges),
M4_LOOKUP_ZK_DESIGN.md + Q4_LEMMAS.md Q4.7-Q4.9 (the built
masked-sumcheck machinery Sections 2-3 extend), SOUNDNESS_REFERENCE.md
Section 7 (the hash-edge table format; the Z1 rows whose function
Section 5.5 inherits). Machine checks:
`scripts/aggregation_zk_spike.py` (certificates SPKZ-1..7, named per
claim below; output recorded in Section 8). This document does not
modify WSMD, Q4_LEMMAS.md, or SOUNDNESS_REFERENCE.md — transcription
of its lemmas into those files is build-round scope.

Grading (SOUNDNESS_REFERENCE.md Section 0 + the CR 0.2 spike-round
convention): **[PROVEN]** imported machine-checked machinery;
**[PROVEN*]** complete elementary argument here + a named SPKZ spike
certificate (engine-scale certification owed to the build round);
**[MODEL]** quantitative model, constants cited; **[OBLIGATION]**
believed and designed, write-up or build-time verification owed;
**LEAK** — a transcript value that is a deterministic function of
(witness, public challenges) with no masking argument, per the house
R1 principle (a deterministic witness image is a leak unless proven
otherwise).

## Executive verdict

**O-4 lands as a PRECISE GAP, not a full closure — and the gap is a
genuine finding, not a failure of design effort.** Two of the three
exposure surfaces close completely, with exact simulators in the WSMD
Section 3 style:

1. **Surface 1 (masked sumcheck rounds) CLOSES.** The Q4.7 counting
   discipline extends mechanically to every new instance of the
   reduced protocol (3 matmuls, Hadamard, binariness/requant
   zero-checks, the packing-image check if EA keeps slot encoding,
   the CR-L4 batch and multi-point merge sumchecks): Libra-shape
   round masks, one per instance, ~360-660 K-elements of new mask
   material — T_blind carries everything (masks + pads + claim
   blinds, ~460-560 rings) with ~2x headroom at the low end of its
   [MODEL] window (Section 2).
   Two precisely-identified extensions are NOT covered by the built
   lemmas and are stated and spike-checked here: the joint counting
   for instances SHARING round challenges (AZ-L1b), and the
   composition of round masks with a blinded (nonzero, private)
   initial claim for the matmul instances (Section 2.4).
2. **Surface 2 (terminal evaluation values) CLOSES.** The U-K5c
   aggregate-only-pin discipline generalizes as SELECTOR-EXTENSION
   pads: every proven tensor is extended by one index bit whose
   extension block is FREE fresh committed blind material, with a
   public selector in the instance kernel keeping the proven
   relation exactly the original one; every terminal and claimed
   value the verifier sees is then uniform on the check coset
   (AZ-L2, the Q4.8b rank pattern one level up), and the true
   per-tensor values never appear on the wire. Compatible with DA's batch shape (one
   common point I-1, quinary ring weights I-4, slot-complete checks
   I-3) — with one new binding design rule: blinding must be
   slot-complete (AZ-R1). (Section 3.)
3. **Surface 3 (evaluation-proof internals) SPLITS.** The committed
   internals (outer commitments u_i, the committed Greyhound w
   message, the g/h garbage inside u2) hide under MLWE with the
   PARAMS 2.5 tails — closed. The JL norm-check projections are
   cleartext witness images under the JL configurations; the
   **exact-digit configuration eliminates them entirely** — a new,
   independent argument for exact-digit on top of its FS-soundness
   advantage (PARAMS 3.5), adopted here as the ZK-mandated
   configuration. **What does NOT close: the final bare witness of
   the LaBRADOR recursion floor** (~6.4-8.0 x 10^4 base-field
   coordinates at the derived schedules) is a challenge-keyed
   deterministic image of the private tensors — linear in the
   final-level witness, hence cleanly linearly accumulating across
   proofs in the unrecursed Greyhound sub-case (spike-demonstrated
   exact recovery), and accumulating as ~79k explicit constraint
   values per proof with digit-range structure in the recursed case
   (Section 4.4) — and
   at q31 under I-6 and the 262,144 B budget NO known technique
   masks it: Gaussian, uniform-flooding, and uniform-rejection
   masking all violate either the q/8 norm line or the byte budget
   (the masked floor response alone costs ~317 KB — Section 4.5's
   arithmetic, spike-anchored); the toolkit-2026/1289 composition
   does not port (the LNP22 front-end needs either the same evicted
   masking arithmetic in-ring or a tensor-scale cross-modulus escape
   that CR 12.2 rule 2 forbids); and every witness-sanitization
   route (uniformized openings, homomorphic blinding, never-open
   binding) is blocked by the DIGIT WALL — balanced digit
   decomposition, forced by q31's norm budget, destroys the module
   homomorphism every known lattice ZK-opening technique rides
   (Section 4.4, the AZ-T1 obstruction). This is the first worked ZK
   analysis of Greyhound/LaBRADOR composition under an external
   masking discipline (the AGGREGATION_LITERATURE Section 9 gap),
   and its honest answer is: **the composed evaluation proof is a
   proof of knowledge, not zero-knowledge, and at this ring it
   cannot be made zero-knowledge inside the current constraint
   set.** Five escapes are priced (Section 4.5); until one opens,
   the aggregate layer ships under the M4-precedent **non-ZK
   deployment label** with the leak exactly confined: everything
   except the floor image R is simulatable (the Section 5 simulator
   is complete-minus-R), R's dimension and accumulation law are
   stated exactly, and the R3-analogue battery (Section 6) verifies
   the confinement, not a vacuous "no leak" claim.

One consequence the orchestrator must weigh for U-AG4: the floor
leak's RELATIVE weight grows if EA's dense re-encoding lands (a ~13x
smaller witness against the same ~79k-coordinate floor image —
Section 7.3 exports the arithmetic), so the D-1 encoding decision now
has a privacy axis, not just a byte axis.

## PROGRESS

- [x] Section 0: scope, symbols, standing constraints, what "ZK"
      means here
- [x] Section 1: the leakage inventory (every wire object x what it
      is a function of; JL and exact-digit variants; encoding-
      parametric rows)
- [x] Section 2: Surface 1 — mask-budget extension (AZ-L1a/b), the
      per-instance table, T_blind sizing, uncovered instances named
- [x] Section 3: Surface 2 — terminal blinding (AZ-L2), the
      blind-extension construction, DA-interface interaction
- [x] Section 4: Surface 3 — the route decision (toolkit vs house),
      the AZ-T1 obstruction, the five escapes priced, costs to O-2
- [x] Section 5: the simulator (WSMD Section 3 style), component
      grades, the hybrid chain, the residual R, the fold-round
      FS-ordering lemma AZ-L4 + hash-edge table
- [x] Section 6: the R3 battery analogue SPEC (AZB-1..9)
- [x] Section 7: verdict, honest scope, exports/imports (EA/EB/O-2)
- [x] Section 8: spike output (recorded verbatim)

## 0. Scope, symbols, and the standing constraints

### 0.1 What is being analyzed

The REDUCED protocol adopted by U-AG2 (AGGREGATION_CLAIM_REDUCTION.md
= "CR" below; AGGREGATION_PARAMS_DESIGN.md = "PARAMS"): per layer
statement, two global super-commitments T_data + T_blind (PARAMS
2.1), ~8-10 masked sumcheck instances (CR 10.1), ~110-170 terminal
MLE-evaluation claims collapsing by mu-batch + nu-RLC to ONE batched
claim per commitment group (CR 10.2), served by 1-3 Greyhound
evaluation proofs with 7-9 adaptive-base LaBRADOR levels beneath
(PARAMS 3.2). There are NO waves: the entire Z1 wave complex is
dissolved (CR Section 9.1), and the protocol has exactly THREE
exposure surfaces (CR Section 11): (i) masked sumcheck round
transcripts, (ii) terminal/claimed evaluation values, (iii)
evaluation-proof internals. This document is the O-4 treatment of all
three.

ZK scope, stated as in WSMD 0.1 and M4_LOOKUP_ZK_DESIGN Section 7
item 6: **honest-verifier ZK, proof-of-protocol** — the simulator
target is the complete per-layer aggregate transcript against the
statement (commitments, shapes, public plan). Chain-wide composition
(manifest, cross-layer folding O-8) and timing/memory side channels
are out of scope repo-wide.

### 0.2 Symbols

Everything from CR 0.2 (q31, R_q, D = 128, k = 8 slots, K = GF(q^16)
~ 2^496, MLE, eval claim) and PARAMS Section 2 (m1 x m2 column
layout, digit base e0, l0 limbs, kappa = 10, gamma_z, gamma_max,
levels i = 0..L, floor witness z_L). New here:

- **Instance** — one masked sumcheck of the reduced protocol (CR
  10.1's table); its round-degree pattern (d_1, .., d_ell) and
  round count ell are per-instance.
- **n_g** — the free-coefficient count of a Libra Construction 1
  round mask, n_g = 1 + sum_t d_t (Q4.7's counting).
- **Blind-extension row** — Section 3's construction: tensor T
  extended by one high index bit to T-hat with T-hat(0, b) = T(b)
  and T-hat(1, b) = the committed blind block of T.
- **R** — the residual unsimulatable transcript object (Section
  4.4/5.4): the floor bare witness z_L (plus JL projections p under
  a JL configuration).
- **Exposure / pad** — as in Q4.7's shared setting: an exposure is a
  transcript value the verifier sees; a pad is a committed uniform
  mask degree of freedom; hiding claims are rank statements.
- Eval-proof wire objects (verified this session against the
  zksecurity expositions, Section 4.1): **w** = a^T G S (Greyhound's
  evaluation-row message, committed as v = D w-hat in the LaBRADOR
  handoff), **z** = S c (the level-0 fold), **u_i** (level-i outer
  commitment), **p = Pi s** (the modular-JL projection, 256 or 512
  base-field coordinates), **g_ij = <s_i, s_j>**, **h_ij** (garbage
  terms, committed in u2), **z_L** (the final bare witness).

### 0.3 Standing constraints (inherited, not relitigated)

1. **I-6 is HARD** (PARAMS 2.4 item 1 / Section 7; PROGRESS_UAG3
   standing constraints): no rejection-sampled masked opening
   anywhere in the aggregate opening layer at q31 — sigma would need
   2^25.3, bounds 2^37 against q/8 = 2^28. ZK rides the T_blind
   commitment segment + masked sumcheck only. Section 4 derives the
   consequences honestly, including where the same arithmetic lands
   at floor scale — recorded as information for the orchestrator,
   not as a relitigation.
2. **Z1 discipline**: nothing the old waves masked may re-appear on
   the wire. The reduced protocol has no per-wave objects (CR 9.1);
   Section 5.6 restates the WSMD 7.1 discharge and its one caveat.
3. U-AG2 verdicts stand; the BaseFold fallback boundary is PARAMS
   6.3 and nothing here touches it. This lane's verdict gates the
   ZK DEPLOYMENT LABEL, not the architecture's byte/soundness
   closure.
4. Numbers only from repo-recorded sources or references verified
   in-session, cited inline; [MODEL] on unmeasured constants.

### 0.4 Sources verified this session

- Greyhound protocol structure: zksecurity "Proofs On A Leash"
  (blog.zksecurity.xyz/posts/greyhound/, read in full this session):
  prover messages t_j = A G^-1(s_j), u = B t-hat, w = a^T G S (after
  the evaluation point), z = S c (after the challenge); verifier
  checks <w, b> = y, <c, w> = <a, z>, sum_i c_i t_i = A z; the
  LaBRADOR handoff relation with v = D w-hat committing the
  decomposed w. **No masking or hiding measure appears anywhere in
  the published protocol.**
- LaBRADOR level structure: zksecurity "Playing with LaBRADOR"
  (blog.zksecurity.xyz/posts/labrador/, read in full this session):
  per level u1 = B t-hat, u2 = C g-hat + D h-hat with g_ij =
  <s_i, s_j>, h_ij = (1/2)(<phi_i, s_j> + <phi_j, s_i>); JL
  projections p_i = Pi s_i in CLEARTEXT (256 rows, entries in
  {0, ±1} at (1/2, 1/4, 1/4)), sqrt(30)/sqrt(337) window, slack
  sqrt(128/30) ~ 2.07; folded z = sum c_i s_i decomposed into the
  next level's witness; the final level's witness sent BARE. **No
  ZK measure in the published protocol.**
- ePrint 2024/1293 (Greyhound) and 2026/1289 (ZK toolkit) abstracts
  confirmed; both PDFs behind the bot-check this session (as in
  DA's session) — LNP22 front-end internals are carried at
  [S10]/[MODEL] grade from AGGREGATION_LITERATURE 1.3 (the toolkit
  integrates the linear-size LNP22 ZK proof in front of LaBRADOR;
  LaBRADOR compresses the verification of the LNP22 proof; <100 KB
  outputs).
- ePrint 2022/1341 (LaBRADOR) abstract previously verified (PARAMS
  Section 0); structural facts cited to the exposition above.

## 1. The leakage inventory (deliverable a)

Every wire object of the reduced protocol, what it is a function of,
its class under the M4_LOOKUP_ZK_DESIGN Section 1 taxonomy
(recoverable-witness-image / aggregate-statistic / not-a-leak), and
which mechanism of this design covers it. The table is the WSMD 1.3
table for the aggregate transcript; rows marked (EA) are parametric
in the D-1 encoding decision and stated for both cases.

### 1.1 The wire, in transcript order

| # | wire object | function of | class (unmasked) | covered by |
|---|---|---|---|---|
| W1 | statement: T_data outer identity u, T_blind outer identity u | Ajtai images of digit columns + 16-ring ternary hiding tails (PARAMS 2.2/2.5) | not a leak — MLWE hiding, 193.3-bit row [PROVEN-class import, ESTIMATOR_NOTE] | commitment hiding (tails) |
| W2 | per-instance masked sumcheck round polynomials (~130-160 new rounds + the descent pairs' 1,651 K-el; CR 10.1) | degree-<=3 evaluations of instance summands + nu_j x round masks | without masks: aggregate-statistic (challenge-keyed digests, the M4 Section 1 g_{k,t} class) | Surface 1: AZ-L1 masks (Section 2); descents already Q4.7-9 [PROVEN] |
| W3 | per-instance G_j mask-sum pins + mask openings g^(j)(r, c) | committed mask coefficients (public-weight functionals) | forced/pinned values | E4-pin class, unchanged (Q4.7 setting) |
| W4 | instance initial claims: matmul MLE(C-hat)(rx, ry); zero-check claims (public 0) | matmul: one MLE value of a private tensor; zero-checks: nothing | matmul: aggregate-statistic with LINEAR ACCUMULATION (16 base-field equations per proof per claim — the M4 v^X class) | Surface 2: blind-extension (Section 3); zero-checks need nothing |
| W5 | terminal evaluation values per instance (the ~110-170 batch entries of CR 10.2) | MLE(T-hat_j)(r*-class points) — public-weight linear functionals of private tensors | **the C-02 shape one level up**: 9(W-1) per-wave equations became ~110-170 per-layer equations; same accumulation law (WSMD 1.1) | Surface 2: AZ-L2 blind-extension — the values sent are uniform on the check coset |
| W6 | batched claim values v_{i,s} (B x 8 slots, PARAMS Section 4/5.1) | mu/nu/gamma-weighted combinations of W5 values + the unit-weight T_blind segment | blinded aggregates | Surface 2 (the PARAMS 2.5 claim-blinding line, made concrete in Section 3.2) |
| W7 | eval proof: level-0 v commitment (committed w-hat) | w = a^T G S — one evaluation-row image of ALL witness columns, committed | not a leak GIVEN hiding tails on the v commitment [MODEL — tail budget line, Section 4.3] | commitment hiding |
| W8 | eval proof: level-i outer commitments u_i (incl. u2 with g/h garbage) | Ajtai images of level witnesses (folds, t-digits, g_ij = <s_i,s_j>, h_ij) + tails | not a leak GIVEN per-level tails [MODEL, Section 4.3] | commitment hiding |
| W9 | eval proof: JL projections p (JL configs only; 256/512 base-field coords x (L-1) levels) | p = Pi s — DIRECT public-matrix linear images of the level witness, norm-checked in cleartext | **LEAK: recoverable-witness-image class** — 1,536-4,096 cleartext linear equations per proof on level witnesses, hence (by recomposition linearity, 4.4) on the original digits | ELIMINATED by the exact-digit configuration (Section 4.3) — the ZK-mandated config |
| W10 | eval proof: level aggregation scalars | functions of committed g/h material + public challenges, pinned by level check equations | forced-class [OBLIGATION AZ-O4: per-message enumeration against the LaBRADOR spec at build time] | check-equation forcing |
| W11 | eval proof: final bare witness z_L (~500-624 rings = 64,000-79,872 base coords; PARAMS 3.2/5.2) | the full fold-and-decompose chain applied to ALL columns: z-descended coords = PURE digit folds of T_data/T_blind (hiding tails occupy SEPARATE coordinates and do not pad them — Section 4.4); g/h-descended coords = witness inner products; t-descended coords = commitment digits (tail-protected) | **LEAK: the residual R** — z- and g/h-descended coordinates are challenge-keyed deterministic witness images, linear in the level-L witness; clean linear accumulation in the unrecursed sub-case (4.4, SPKZ-6), explicit constraint accumulation with digit-range structure in the recursed case | NOT COVERED — the AZ-T1 obstruction (Section 4.4); confinement verified by the battery (Section 6) |
| W12 | norm checks: ||z_L|| bound; JL window checks | properties of R (and p) | rides W9/W11 | — |

### 1.2 What accumulates, quantified

The three accumulating rows before this design's mechanisms:

- W5 (terminals): ~110-170 K-values = ~1,760-2,720 base-field
  equations per proof against the ~2.8 x 10^8-coordinate (FFN,
  slot-encoded) tensor family. CLOSED by Section 3 (zero fresh
  equations; the coset argument is exact).
- W9 (JL): 1,536-4,096 base-field equations per proof on level
  witnesses. CLOSED by the exact-digit mandate (deleted wire).
- W11 (floor): 64,000-79,872 base-field values per proof, of which
  the z- and g/h-descended blocks (the majority at the derived
  floor shapes [MODEL]) are witness images. **NOT closed.** In the
  unrecursed Greyhound sub-case the equations are linear on the
  FIXED column matrix and m2 transcripts recover it EXACTLY
  (SPKZ-6); in the recursed case each proof contributes ~79k
  explicit deterministic constraint values whose unknowns are
  digit-range-structured (integer-programming-shaped, not
  linear-algebra-shaped — Section 7.3's threshold table is
  [MODEL] and one-directional) — and by the WSMD 1.1 honesty rule
  NO safety margin is read into the nonlinearity: by the R1
  principle the construction is non-ZK at ONE proof.

### 1.3 Encoding-parametric rows (EA reconciliation)

Two D-1 cases (PROGRESS_UAG2 R-2):

- **Slot form retained for Y/UP/Z** (DA's as-drawn layout): the
  packing-image zero-check (CR 6.3) is a live instance — one more
  Surface-1 mask family (Section 2.2's table row I-7) and its two
  terminals join the Surface-2 batch. The committed junk coordinates
  are policed by that check and carry no reveal wire — no new
  leakage class.
- **Dense re-encoding** (EA's counter-lever): the packing-image
  instance disappears; committed rings drop ~13x (R-2: 2,157,768 ->
  ~170k at FFN); all Surface-1/2 rows carry over with smaller n.
  **New privacy consequence (this lane's export)**: the W11 floor
  image dimension is set by the LaBRADOR regrowth floor
  (r kappa l_t + r^2 l_gh — PARAMS 3.2), NOT by n, so a ~13x
  smaller witness faces the SAME ~79k-coordinate leak per proof:
  the naive recovery threshold drops ~13x (Section 7.3). Dense
  encoding is better on bytes and WORSE on the residual leak — the
  D-1 decision now has a privacy axis.

Both cases' Surface-1 mask counts are given parametrically in
Section 2.2 (masks scale with round counts, i.e. with log of the
committed volume — the delta between encodings is <= 2 rounds per
instance ~ +/-8 K-elements, noise).

## 2. Surface 1 — the mask-budget extension (deliverable b)

### 2.1 What carries over verbatim, and why the new instances are easier

The built machinery (Q4.7-Q4.9, PROVEN at engine scale) masks the
LAYERED LogUp-GKR descents: round masks (M1/Q4.7), boundary masks
with the w-dummy-variable correction (M2/Q4.8a), and blinder leaves
for tops and leaf boundaries (M3/Q4.8b/Q4.9). The descent pairs are
kept verbatim by the reduction (CR-10), so their masking carries over
unchanged — including the h0-binding and freshness rules.

The NEW instances (matmul x3, Hadamard, binariness/requant
zero-checks, packing-image if slot-encoded, the CR-L4 batch sumcheck,
the multi-point merge) are SINGLE sumchecks with no layer structure:
no fold boundary exists, so **no M2/Q4.8a analogue is needed** (there
is no interior boundary value to pad and no w-variable correction —
the 6/4/3 degree pattern of the descents does NOT propagate; round
degrees stay the instance degrees), and **no Q4.9 analogue is
needed** (no root cross-check exists). What each instance needs is
exactly one M1-class round mask (2.2) plus Surface 2's treatment of
its initial and terminal values (Section 3). The masking problem for
the new instances is strictly SMALLER than the one already solved.

### 2.2 The per-instance mask table (AZ-L1a)

Round-mask shapes per instance, Libra Construction 1 with degrees
matching the instance's round degrees; n_g = 1 + sum_t d_t (Q4.7's
counting, degree-agnostic). Round counts from CR 10.1 [MODEL where
estimated]; the extension bits of Section 3 add +1-2 rounds per
instance (included):

| instance | degree | rounds ell | n_g (K-el) | count |
|---|---|---|---:|---:|
| matmul gate/up/down (CR-1) | 2 | ~13-16 | 27-33 | 3 |
| Hadamard zero-check (CR-3) | 3 | ~24-25 | 73-76 | 1 |
| binariness / requant zero-checks (CR-4a/CR-7) | <= 3 | ~24-25 | <= 76 | 1-2 |
| packing-image (CR-8; SLOT ENCODING ONLY — EA) | 2 | ~24-25 | 49-51 | 0-3 |
| multi-point merge (PARAMS 4.3; only if k > 1 point families) | 3 | ~21-24 | 64-73 | 0-3 |
| CR-L4 terminal batch sumcheck | 3 | ~24-25 | 73-76 | 1 |
| descent pairs (silu + range arms) | Q4.7-9 as built | 253 + 28-class | 2,315 K-el total incl. M2/M3 | 2 |

New mask material (excluding the descents' built 2,315):
**~360-660 K-elements** [MODEL, summed from the table across the
encoding/point-family cases]. Every mask is committed in T_blind
(PARAMS 2.5's segment — "refreshable per proof" is exactly the
freshness rule), bound by the statement hash BEFORE any challenge,
fresh per proof (reuse subtracts — battery AZB-5, the E3Z-N3/Z1-h
class). Wire delta from masking itself: one G_j value + one opening
per instance ~ 2 x 64 B x ~10 instances ~ **1.3 KiB** [MODEL] (the
round transcript delta of the instances themselves is CR 10.1's
+27-40 KiB and is already on O-2's ledger; masking does not change
round counts or degrees).

**Lemma AZ-L1a (per-instance counting).** For each instance above,
with the n_g mask coefficients uniform, fresh, committed before the
instance's challenges, and nu != 0: the mask-bearing exposures (the
d_t + 1 evaluations per round, G, the end opening) net of the ell + 1
forced check relations number exactly n_g, the coefficient-to-
exposure map has full rank n_g, and the exposures are uniform on the
check variety independent of the witness. *Proof:* Q4.7's argument
verbatim — the counting never used the descent's specific degree
pattern, only that round t exposes d_t + 1 values with one forced
relation per round plus the end check. Status: **[PROVEN*]** —
certificate SPKZ-3a (rank n_g with exactly ell + 1 forced relations
at a degree-3 zero-check toy shape and a degree-2 matmul toy shape).

### 2.3 T_blind budget arithmetic [MODEL]

| T_blind content | K-elements |
|---|---:|
| descent masks + blinders (M4 3.1, moves into T_blind under the reroute) | 2,315 |
| new instance round masks (2.2) | 360-660 |
| Surface-2 extension pads (Section 3.3: ~110-170 pads at ring granularity, 8 K-el each) | 880-1,360 |
| claim-blind segment (B x 8 slots; PARAMS 5.1's claim-value line) | ~128 |
| **total** | **~3,700-4,500 K-el = 460-560 rings** |

Against the PARAMS 2.1 T_blind window of 2^10-2^12 rings [MODEL]:
fits at the LOW end with ~1.8-2.2x headroom. dce cost: ~59-72k
committed coefficients ~ +3e-5/el at FFN — noise. Committed-material
conclusion: **Surface 1 (and Surface 2's pads) fit T_blind as
modeled; no budget pressure.**

### 2.4 What the existing lemmas do NOT cover — named precisely

1. **Shared round challenges across parallel instances (AZ-L1b).**
   CR-L4b runs the per-tensor batch sumchecks IN PARALLEL with
   SHARED round challenges (that is what lands every terminal at one
   point). Q4.7 is a per-sumcheck statement. Joint statement needed:
   with each parallel instance carrying its OWN mask g^(i) and own
   nu_i, the joint coefficient-to-exposure map is block-diagonal in
   the masks and the forced relations do not couple instances (each
   has its own running claim), so the joint rank is the sum of the
   per-instance ranks and joint uniformity holds. Status:
   **[PROVEN*]** — certificate SPKZ-3c (two toy instances sharing
   challenges: joint rank = n_g1 + n_g2, forced relations exactly
   (ell + 1) per instance). Engine-scale canary owed (AZB-2).
2. **Blinded nonzero initial claims (the matmul composition).** The
   zero-checks start from the public claim 0; Q4.7's setting derives
   its initial claim from masked tops (Q4.9). The matmul instances
   start from MLE(C-hat)(rx, ry) — a PRIVATE value, sent in blinded
   form (Section 3). The composition "initial claim uniform on its
   coset (AZ-L2), then rounds uniform on the check variety given
   that claim (AZ-L1)" is new relative to the built lemmas; it is
   the H1/H2 hybrid step of Section 5.3. Status: **[PROVEN*]** —
   SPKZ-2 runs the full composition at toy shape (blinded initial
   claim + masked rounds + blinded terminals, honest accept, masks
   live, tamper reject).
3. **Mask coefficients enter the eval-proof witness.** The G_j pins
   land as batch entries against T_blind (CR-5 class), so T_blind's
   columns are part of the batched opening's witness — and Surface
   3's residual floor image (Section 4.4) therefore touches MASK
   material, not just data. The (H1) secrecy hypothesis of
   Q4.7/AZ-L1 is thereby weakened from "masks secret" to "masks
   secret up to the floor image's projection onto mask coordinates."
   This surface COMPOSITION is not covered by any built lemma; it is
   obligation **AZ-O2** (joint-rank certificate: floor image +
   sumcheck exposures vs mask dimensions — battery AZB-8) and is
   priced into the verdict (Section 7). Under the deployment
   mitigation of Section 4.6 (one proof per witness) the projection
   is a single ~79k-dim system against ~5 x 10^5 fresh mask/pad
   coordinates per proof — rank-deficient by counting [MODEL], but
   counting is not a proof; the certificate is owed.

### 2.5 Ordering edges (forward reference)

All Surface-1 edges land in the Section 5.5 hash-edge table: the
statement hash binds T_blind (all masks, pads, extensions) before ANY
challenge; nu_i follows the instance claim and G_i; round challenges
follow their round polynomials (the classic order). Each row carries
its attack and its battery leg, F5-pair style.

## 3. Surface 2 — terminal blinding (deliverable c)

### 3.1 The problem, sharpened (the C-02 shape one level up)

Unblinded, the reduced protocol sends ~110-170 terminal evaluation
values per layer proof (W5): each is MLE(T)(z) at a
challenge-determined point — a public-coefficient linear functional
of a private tensor, exactly equation (1) of WSMD 1.1 with "wave"
replaced by "instance". Counts: ~1,760-2,720 base-field equations
per proof, accumulating across proofs of the same witness under
fresh challenges, plus the M4 Section 1 v^X/v^Y accumulation rows
reborn at layer scale. By the R1 principle and the R1 history
(WSMD 1.1's "bounded but growing" kill), this is non-ZK at one
proof. The design target, as in WSMD 1.3: make the sent values carry
ZERO information beyond what the check equations force.

### 3.2 The construction: selector-extension pads (aggregate-only, generalized)

The U-K5c discipline ("no functional of the private object alone is
ever sent; only blinded aggregates are claimed") generalizes as
follows. For every instance and every private tensor T whose
evaluation the instance exposes (initial claims and terminals):

1. **Extend the summed index space by one bit** (two for matmul —
   one per exposed side). The extended tensor T-hat has the real
   data on the 0-block and a FREE committed blind block beta_T
   (fresh per proof, uniform K-values at ring granularity, living in
   T_blind's segment space, bit-block aligned) on a small aligned
   sub-block of the 1-block, zero elsewhere.
2. **Kill the extension's effect on the relation with a public
   selector**, not with constrained blinds: the instance kernel
   gains the factor (1 - b_ext) (zero-checks: the relation is
   enforced only on real positions), and the matmul's two extension
   blocks are arranged so every cross product has a structurally
   ZERO side (A's pad block pairs with B's zero block and vice
   versa) — the proven statement is EXACTLY the original relation on
   the real block. Degree: +1 in the extension round only; +1-2
   rounds per instance (priced in 2.2/2.3).
3. **Every exposed evaluation is then padded**: the instance's
   terminal MLE(T-hat)(r-hat) = (real part) + w_ext x
   MLE(beta_T)(r-low), with w_ext the public nonzero eq-weight of
   the extension coordinate (guard: extension challenge outside
   {0, 1} — the Q4.8 guard class, restart on the ~2^-495 event).
   The verifier's end checks run on the extended relation, so
   completeness is exact — the pads are committed tensor content,
   not post-hoc additions (the M3 blinder-leaf pattern one level
   up).

**Rejected alternative, recorded with its failure**: in-relation
blind rows (extension rows constrained to satisfy the relation, e.g.
beta_Z := beta_G o beta_U) fail for CONSTRAINED-VALUE tensors — a
binariness extension row must be binary, and a K-combination of
~dce binary blind bits is nowhere near uniform on K (~2^128-support
vs 2^496): the coset argument collapses from exact to
entropy-heuristic. The selector variant keeps every pad free and
K-uniform for every instance type, and needs no solved pads (no
contents-correlation caveat).

**Lemma AZ-L2a (terminal one-time-padding).** Under the construction
above with all blind blocks uniform, fresh, committed before all
challenges: the joint exposure vector of an instance (round
polynomial evaluations, initial claim where private, terminal
values) is uniform on the instance's check variety, independent of
the witness; in particular the terminal sub-vector is a full-rank
affine image of the dedicated pad dimensions (one fresh pad
dimension per exposure, none spent twice — the Q4.8b ledger
pattern). *Proof:* the pad enters each exposure through its own
block's eq-weight (nonzero by guard), giving a diagonal sub-block in
the exposure/pad map (Q4.8b's argument); joint uniformity with the
round masks is the block-diagonal composition of AZ-L1a/b. Status:
**[PROVEN*]** — certificates SPKZ-3b (rank = #exposures over the pad
dimensions) and SPKZ-2 (completeness + tamper reject under full
blinding).

**Lemma AZ-L2b (batch level).** The batched claim values (W6) are
public gamma/mu/nu-weighted combinations of AZ-L2a-uniform values
plus the unit-weight T_blind claim-segment values (fresh committed
uniform); an affine map of uniform inputs with public coefficients —
simulatable outright. The unit-weight segment additionally decouples
the eval-proof's opened value from the tensor MLEs even under
adversarial weight degeneracies. Status: **[PROVEN*]** (SPKZ-1's
masked leg exercises the full pipeline).

### 3.3 What the verifier sees vs what stays blinded

| verifier sees | status |
|---|---|
| blinded terminals and initial claims (extension-padded) | uniform on the check coset (AZ-L2a) |
| G_j mask pins, mask openings | forced values (E4-pin class) |
| batched claim values v*_{group, s}, all 8 slots | uniform (AZ-L2b) |
| end-check arithmetic | forced (check equations) |
| NEVER: any raw MLE(T)(z) of a private tensor; any per-tensor batch subtotal; any unblinded slot value | — the aggregate-only discipline, generalized |

### 3.4 Interaction with DA's batch-opening shape

- **I-1 (one common point):** the extension bits ride the SAME point
  family (the common point gains coordinates); no new merge blocks;
  the >~4-point-family byte erosion is not touched.
- **I-3 (slot-complete checks) + I-4 (quinary ring weights):** the
  batch weights gamma_i act per slot via res_s(gamma_i) (injective
  by L2/LS18). **Design rule AZ-R1 (binding):** blind material must
  be drawn at RING granularity so all 8 slot images of every pad are
  independently uniform — a slot-shared or slot-sampled blind
  re-opens a per-slot leak channel exactly where Reference 6's
  soundness failure lived on the soundness side. With AZ-R1, an
  affine ring-weighted combination of slot-uniform values is
  slot-uniform: I-3/I-4 compatible [PROVEN* arithmetic, SPKZ-1].
- **IA-O1-5 (weights):** if the weight tensors W are public, their
  terminals need no blinding (verifier-evaluated); if committed per
  model, they take extensions like any private tensor — both cases
  wired in 3.2's matmul pattern.

### 3.5 Costs

Pads ~110-170 rings-worth (2.3's table), +1-2 rounds per instance
(~+1-2 KiB transcript [MODEL] — to O-2), no new challenge draws, no
restart surfaces beyond the ~2^-495 guard class. Per-instance wiring
tables (which index bit, which sub-block, per tensor) are build-round
detail [OBLIGATION], with the Hadamard and matmul wirings of 3.2 as
the two normative exemplars.

## 4. Surface 3 — the eval-proof ZK layer under I-6 (deliverable d)

### 4.1 What the composed proof exposes, at our layout

Mapping the verified protocol structure (Section 0.4) onto the PARAMS
5.1 byte lines:

| byte-model line | object | exposure class |
|---|---|---|
| outer identities u (2x) | Ajtai + tails | committed (hiding) |
| level-0 v commitment | the Greyhound w = a^T G S message, decomposed and COMMITTED (the LaBRADOR handoff commits it; w never rides bare) | committed (hiding, given a tail on the v commitment [MODEL]) |
| level messages: u_i | level outer commitments (incl. u2 carrying g_ij = <s_i, s_j>, h_ij) | committed (hiding, given PER-LEVEL tails — 4.3) |
| level messages: JL | p = Pi s in CLEARTEXT, 256/512 base coords x level | **cleartext witness image** (W9) — JL configs only |
| level messages: agg scalars | challenge-weighted claim constants pinned by level check equations against committed material | forced-class [AZ-O4] |
| final bare witness | z_L, 64,000-79,872 base coords | **cleartext witness image** (W11) — the residual R |
| batched claim values | Surface 2 objects | blinded (AZ-L2b) |

The published protocols carry NO masking of any of these (Section
0.4 — confirmed against both expositions); every ZK property must be
supplied by our side. Two further structural facts, both load-bearing
below: (i) the hiding tails occupy SEPARATE coordinates of each
column, so the fold z = sum c_j s_j has a data-block that is a PURE
digit fold — tails hide commitments, they do NOT pad fold images;
(ii) g_ij = <s_i, s_j> includes data-data inner products — the
garbage terms are witness images too (committed at levels < L, bare
in the floor).

### 4.2 The toolkit route (ePrint 2026/1289) — priced and REJECTED at tensor scale

The toolkit's architecture (AGGREGATION_LITERATURE 1.3 [S10];
abstract confirmed this session): the LNP22 linear-size ZK proof
proves the witness-bearing statement; LaBRADOR compresses the
VERIFICATION of the LNP22 proof. The load-bearing principle: **the
compressed witness is the LNP22 transcript, which is a ZK artifact —
simulatable — so LaBRADOR's cleartext tail (JL, bare floor) leaks
nothing sensitive.** Sanitize the witness, then compress in the
clear.

Why it does not port to our layer, four reasons with arithmetic:

1. **In-ring (LNP22 at q31): the I-6 eviction applies to LNP22's own
   masking.** LNP22's ZK is Fiat-Shamir-with-aborts: Gaussian
   rejection-sampled masked responses over the witness [S10
   structure]. For the tensor-scale witness the masking arithmetic
   is EXACTLY PARAMS 2.4 item 1: sigma ~ 12 x gamma_z ~ 2^25.3,
   response bound ~2^37 against q/8 = 2^28 — impossible. The
   toolkit cannot run its front-end in our ring at our scale. [The
   same spike leg SPKZ-7 that anchors I-6 anchors this.]
2. **Out-of-ring (LNP22 at a larger q'): the tensor-scale
   cross-modulus wall.** Proving "com_q31(x) opens to x AND the
   batched claim holds" inside a mod-q' system requires carrying
   the q31 residue relation at tensor scale across moduli — CR 12.2
   rule 2's recorded open problem (the U-L link's per-row counting
   argument does not survive tensor-structuring; CR 7.3). The
   alternative — moving the whole commitment layout to q46+ — is
   PARAMS 5.2's q46 row: 354,104 B = 1.35x, OVER. Blocked both
   ways.
3. **Engine reuse ~zero, review burden maximal.** LNP22/LaZer
   publish and implement at degree-64 rings with their own
   challenge sets and samplers; a D = 128 / q31 port of the full
   LNP22 apparatus (ABDLOP, Gaussian samplers, abort loops) is the
   M4-flagged "first of its shape" composition — against the house
   route's reuse of machinery that is already PROVEN at engine
   scale (Q4.7-9) and already reviewed in-house.
4. **Prover cost.** Gaussian sampling + rejection restarts over
   tensor-scale mask vectors multiply the commit-class pass [MODEL];
   the house route's masks are committed data — no per-round
   sampling surface at all (the M4 Section 5.5 argument).

The toolkit's one genuine advantage — published, third-party-
implemented maturity — is real but attaches to foreign parameters.
**DECISION: house route.** The toolkit PRINCIPLE (only simulatable
witnesses reach the compressor's cleartext tail) is retained as the
correct lens — and Section 4.4 shows precisely why its q31-native
instantiation fails, which is the finding.

### 4.3 The house route (adopted): what T_blind + masked sumcheck + tails DO close

1. **Committed internals.** Every commitment in the eval-proof
   transcript carries a hiding tail: the top-level inner columns and
   outer witness are already tailed in PARAMS 2.5 (MLWE at the
   measured 193.3-bit row); the level-0 v commitment and every
   level-i inner/outer commitment need the SAME 16-ring ternary
   tails — a layout amendment this document adds [MODEL: ~(r_i + 2)
   x 16 rings committed per level, zero wire; flagged to O-2 and to
   the build round]. With tails, W1/W7/W8 are MLWE-hiding — closed.
2. **The exact-digit mandate (the ZK-side selection of PARAMS
   3.5's sound config).** The JL configurations put 256/512
   cleartext base-field projections of the level witness on the
   wire per level (W9) — a direct witness-image class that no house
   mechanism can mask (the projections are norm-checked; masking
   them is 4.4's dead end). The exact-digit variant DELETES the
   class: range facts become committed digit columns proven by
   relations inside the recursion (PARAMS 6.4 obligation 4's
   plumbing), i.e. committed material under (1). ZK therefore
   MANDATES exact-digit — stacking with its FS advantage (2^-217,
   no JL statistical term, no unconfirmed paper constant). Byte
   cost of the mandate at FFN: +10,112 B vs per-level+512-JL
   (289,080 vs 278,968 — PARAMS 5.2) — the ZK-mandated config is
   the more expensive sound config; O-2 line item.
3. **Pad-polynomial reach.** T_blind's pads close Surfaces 1-2
   (Sections 2-3) including every claimed VALUE the eval proof
   serves. What pads cannot reach: the cleartext norm-checked tail
   — next.

### 4.4 The obstruction AZ-T1: the cleartext floor cannot be masked or sanitized at q31

**The residual object.** After 4.3, exactly one wire object class
remains unsimulatable: R := the final bare witness z_L (the JL rows
being deleted by the mandate). Its z-descended data-block coordinates
are pure challenge-fold images of T_data/T_blind digit columns
(Section 4.1 fact (i)); its g/h-descended coordinates are witness
inner products; its t-descended coordinates are tail-protected
commitment digits (the one sub-block with a hiding argument — graded
[OBLIGATION AZ-O5]: the leakage-resilient-MLWE reading under the
concurrent tail-fold exposure). Dimension: 64,000-79,872 base
coordinates at the PARAMS 3.2 schedules.

**Lemma AZ-L3 (what R is, exactly).** (a) Each coordinate of z_L is
a public-coefficient LINEAR functional of the level-L witness
s^(L) (z_L = sum c_j s_j^(L), challenges public). (b) In the
unrecursed Greyhound sub-case (L = 0: z = S c bare), the functionals
act on the FIXED original column matrix S, and m2 transcripts with
fresh challenges recover S EXACTLY by linear algebra — the C-02
recovery shape at the aggregate layer. (c) In the recursed case,
s^(L) is an explicit, publicly-computable but NONLINEAR
(digit-extraction) function of the original witness; each proof
contributes dim(z_L) explicit constraint values on the fixed
original witness with digit-range side structure. Status: (a), (b)
**[PROVEN*]** — certificate SPKZ-6 (exact recovery, rank m2/m2, plus
the recomputation check that every floor coordinate is an explicit
deterministic witness image at L = 1); (c) accumulation-complexity
deliberately UNGRADED in the adversary's favor (WSMD 1.1's honesty
rule: digit-structured integer systems are what lattice decoders
eat; no margin is read into the nonlinearity).

**Why no masking closes it** (the I-6 arithmetic, extended to all
three masking families and to floor scale — certificate SPKZ-7):

| masking route | norm side (vs q/8 = 2^28.00) | byte side | verdict |
|---|---|---|---|
| Gaussian, global fold (I-6's own row) | bound ~2^37 | — | dead (PARAMS 2.4 item 1, reproduced) |
| Gaussian, floor scale, byte-optimal schedule (e_L = 9-10) | bound ~2^32.5 | — | dead on norms |
| Gaussian, floor scale, forced e_L <= 4 | bound 2^27.3-2^27.9 — AT the line | masked response ~4 B/coord x 79-175k coords = 317-700 KB vs 79,872 B bare: +190-240 KB minimum | **dead on bytes** (1.8-2.7x budget) |
| uniform flooding (statistical distance 2^-lambda) | needs ~lambda + log(dim) extra bits — 2^37+ class | same width problem | dead |
| uniform rejection (Lyubashevsky-09 style) | A ~ dim x T for constant acceptance: 2^28+ at floor dims | same width problem | dead |

The unifying fact, stated once: **a norm-checked cleartext object
cannot be information-theoretically masked** (a mask wide enough to
hide breaks the norm check; a mask narrow enough to pass leaks by
range bias), and at q31 the computational escapes (rejection
sampling) cost response width ~4 B/coordinate — 3-4x the bare
witness's 1 B/coordinate digits — which alone exceeds the entire
262,144 B budget. ZK and byte-optimality of the floor are in direct
conflict at this modulus.

**Why no sanitization closes it** (the digit wall — the failure of
the toolkit principle's q31-native instantiation). Every route to
"open only non-sensitive material" was worked and each is killed:

1. *Uniformized opening* (open v = x + b, v uniform mod q): Ajtai
   commits DIGITS and the digit map is nonlinear, so com(v) is not
   derivable from com(x), com(b); committing v fresh requires
   BINDING v = x + b, and every binding proof terminates in
   evaluation claims against com(x) — the opening being avoided.
   Circular.
2. *Digit-level homomorphic blinding* (open d_x + d_b, the map IS
   linear): bounded-integer sums have data-dependent range bias (no
   one-time pad on bounded supports); wrapping mod 2^e0 restores
   uniformity but breaks recomposition by a carry vector whose
   value, given the wrapped digits, DETERMINES the data digit — the
   carry cannot be committed-and-proven without re-importing the
   leak. Killed both branches.
3. *Pad columns in the fold*: pad influence on z_L passes through
   the digit-extraction maps between levels — non-affine, no rank
   argument survives; final-level pads enter affinely but must be
   small-norm (they are folded and norm-checked), hence not uniform
   — no OTP; and sizing them to dominate is the byte death again.
4. *Never-open binding* (b bound by hash/XOF): requires hash
   arithmetization in-house — family-(e) machinery, priced out at
   GiB-witness scale (AGGREGATION_LITERATURE 5.2). Structured b
   (low-rank/tensor): not tensor-hiding (v - x low-rank determines
   x up to small dof).
5. *MLWE-structured b* (b = A_pub f + e, open short (f, e) claims):
   the terminal weight A_pub^T eq(z) costs the verifier O(N) at
   tensor scale unless A_pub is tensor-structured — CR 12.2 rule
   1's recorded near-wall — and tensor-structuring A_pub leaves
   MLWE-hardness unsupported [nonstandard assumption; not
   adoptable].

**AZ-T1 (the obstruction, stated).** At q31, the norm budget forces
balanced digit decomposition before commitment (e0 in {1..4} —
PARAMS 2.2); digit decomposition destroys the module homomorphism
that every known lattice ZK-opening technique rides (masked
responses act on the module; sanitization needs commitment
linearity in the VALUE, not the digits); and undecomposed openings
have no masking room under q/8. Hence the composed evaluation proof
at this ring is a proof of knowledge and NOT zero-knowledge, and no
combination of T_blind material, masked sumcheck, or commitment
hiding changes that for the floor object R. Grade: each kill above
[PROVEN*] or [MODEL] as marked; the universal quantifier ("no known
technique") is a SURVEY claim, not a theorem — it is exactly the
question Section 7.2 poses for external review, and
AGGREGATION_LITERATURE Section 9 already records that no published
work addresses it.

### 4.5 The five escapes, priced

| escape | mechanism | price | status |
|---|---|---|---|
| E1: modulus escape | opening layer at q46+ (masking room exists there) | 354,104 B = 1.35x OVER (PARAMS 5.2) + tensor-scale cross-modulus link (CR 12.2 rule 2, open problem) | blocked at current budget |
| E2: floor-scale masked response (an I-6 carve-out at e_L <= 4) | Gaussian mask of the ~79k-coord floor opening only | norm AT the line (2^27.3-27.9 vs 2^28); +190-240 KB response width | blocked on bytes; recorded as information, NOT a relitigation of I-6 |
| E3: LNP22 at the floor (toolkit principle, floor scale) | sanitize only the floor statement | same response-width class as E2 + LNP22 port + its own overhead | dominated by E2; blocked |
| E4: budget relief | at ~2x layer budget (~500 KiB), E2 opens: exact-digit + masked floor = full ZK | +~240 KB/layer; a policy decision (PROOF_BYTE_LEDGER 3.1's "the TOTAL may not move" would have to move) | the ONLY currently-actionable full-ZK path; orchestrator/R1 territory |
| E5: a new primitive | a ZK opening for balanced-digit Ajtai commitments at q ~ 2^31 with response + proof <= ~100 KB | unknown | the external-review question; O-9 watch item (2026/1289 lineage at small moduli) |

### 4.6 Deployment posture and the costs fed to O-2

**Posture** (the M4 precedent — M4_LOOKUP_DESIGN 3.5/8's non-ZK
label, applied one layer up): the aggregate layer ships with a
**non-ZK deployment label** — "the evaluation-proof floor exposes
~6.4-8.0 x 10^4 challenge-keyed deterministic witness functionals
per proof; all other transcript components are simulatable (Section
5)" — until an escape opens. Operational mitigation, recorded as a
deployment rule: **at most one aggregate proof per witness** (fresh
proofs of the same witness accumulate fresh floor images; a re-proof
demand is served by caching, not re-proving) — this stalls
accumulation operationally and is verifiable at the deployment
layer; it does NOT change the single-proof label.

**Costs to O-2** (consolidated):

| item | delta | note |
|---|---|---|
| exact-digit config mandated | +10,112 B at FFN vs JL-512 | the ZK-side selection among PARAMS' two sound configs |
| G_j values + mask openings (2.2) | +~1.3 KiB | wire |
| extension rounds (3.5) | +~1-2 KiB | wire |
| T_blind at ~460-560 rings | ~+3e-5 dce/el | committed only |
| per-level hiding tails (4.3) | ~(r_i + 2) x 16 rings/level committed, zero wire | [MODEL]; build-round layout amendment |
| E2 if ever adopted | +190-240 KB | the dead option's price, for the record |

Prover-side: mask generation and extension blocks are committed data
(no sampling loops, no restarts beyond ~2^-495 guards); the marginal
rides the existing commit-pass model (PARAMS 5.4) at +0.1%-class
[MODEL].
