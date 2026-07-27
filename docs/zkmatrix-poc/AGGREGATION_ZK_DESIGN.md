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
   round masks, one per instance, ~600-1,000 K-elements total —
   inside the T_blind [MODEL] budget with >5x headroom (Section 2).
   Two precisely-identified extensions are NOT covered by the built
   lemmas and are stated and spike-checked here: the joint counting
   for instances SHARING round challenges (AZ-L1b), and the
   composition of round masks with a blinded (nonzero, private)
   initial claim for the matmul instances (Section 2.4).
2. **Surface 2 (terminal evaluation values) CLOSES.** The U-K5c
   aggregate-only-pin discipline generalizes as BLIND-EXTENSION rows:
   every proven tensor is extended by one index bit whose extension
   block is fresh committed blind material constrained to satisfy the
   instance relation; every terminal and claimed value the verifier
   sees is then uniform on the batch-consistency coset (AZ-L2, the
   Q4.8b rank pattern one level up), and the true per-tensor values
   never appear on the wire. Compatible with DA's batch shape (one
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
   deterministic image of the private tensors, it accumulates as
   clean LINEAR equations across proofs of the same witness
   (recomposition linearity, Section 4.4 — spike-demonstrated), and
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
| W11 | eval proof: final bare witness z_L (~500-624 rings = 64,000-79,872 base coords; PARAMS 3.2/5.2) | the full fold-and-decompose chain applied to ALL columns: z-descended coords = PURE digit folds of T_data/T_blind (hiding tails occupy SEPARATE coordinates and do not pad them — Section 4.4); g/h-descended coords = witness inner products; t-descended coords = commitment digits (tail-protected) | **LEAK: the residual R** — z- and g/h-descended coordinates are challenge-keyed deterministic witness images; linear accumulation across proofs by recomposition linearity (4.4, SPKZ-6) | NOT COVERED — the AZ-T1 obstruction (Section 4.4); confinement verified by the battery (Section 6) |
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
  floor shapes [MODEL]) are witness images. **NOT closed.** Naive
  linear-algebra recovery of the full digit witness needs ~10^3-10^5
  proofs of the same witness depending on shape and encoding
  (Section 7.3's table) — and by the WSMD 1.1 honesty rule this
  number is an UPPER bound on adversary cost (integer/digit
  structure undercuts it) and confers NO safety margin: by the R1
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
