# O-7: Extraction-Slack Composition Across the Greyhound + LaBRADOR Chain at the House Ring

Status: DESIGN COMPLETE (U-AG3 tranche, Agent EB lane, 2026-07-27;
paper + Python spike only — no engine changes). Discharges obligation
**O-7** — the kill switch recorded by AGGREGATION_PARAMS_DESIGN.md
Sections 3.4/6.3/6.4 and restated by AGGREGATION_CLAIM_REDUCTION.md
Sections 1.5 (CR-L4b) and 10.4/12.3. Verdict (Section 5, one line):
**the PER-LEVEL reading holds — proved for our chain by transcription
and house re-instantiation of the published extraction machinery
(LaBRADOR Thm 5.1 + Remark 5.2 + Lemma 3.7; PSS Thm 4.1/4.2 + Eq. 18)
under four named conditions, all satisfiable at DA's recommended
parameter family; the COMPOUNDED reading is refuted for our chain (it
describes protocols without per-level norm re-grounding, which ours is
not); the BaseFold fallback boundary of AGGREGATION_PARAMS_DESIGN 6.3
is NOT engaged** — with four honest corrections to DA's constants
(Sections 2.4, 3.2: the extraction operator-norm cap, the deep-level
base cap R-EB4, kappa 10 -> 11, and a missing FS aggregation term)
whose net cost is +3-9% bytes depending on branch — the 2^20 layer
keeps its PASS on the exact-digit branch (0.991x, spike) — not the
architecture.

Spike: `scripts/slack_composition_spike.py` (stdlib + numpy, seconds,
tiny memory; checks the ARITHMETIC of this document — norm chains,
budgets, knowledge-error sums, the Monte-Carlo challenge-operator-norm
table — NOT the proofs). Companion docs: AGGREGATION_PARAMS_DESIGN.md
(DA; the parameter chain this lemma grounds), AGGREGATION_CLAIM_
REDUCTION.md (DB; the claim-side lemmas composed in Section 4),
SOUNDNESS_REFERENCE.md (grading conventions, ring facts, the L1/L2
challenge engines), Q4_LEMMAS.md (the transcription style followed
here; this document is self-contained and does NOT modify it).

Grading legend (SOUNDNESS_REFERENCE.md Section 0): **[PROVEN]** —
complete argument here or verified published fact with the exact
statement transcribed; **[CITED]** — published result adopted with
its statement quoted and its hypotheses checked at our parameters,
proof not re-derived; **[MODEL]** — quantitative engineering model,
parameters stated; **[OBLIGATION]** — believed and designed, write-up
or build work owed (collected in Section 5.3).

Lane discipline: this document derives at DA's PUBLISHED parameters
(AGGREGATION_PARAMS_DESIGN Sections 2-3). EA's dense re-encoding
lane (D-1) may shrink the committed-ring counts ~13x; the DIRECTION
of its effect on every statement here is recorded in Section 5.4 and
nowhere else. EC's ZK lane is not touched.

## 0. Scope, sources, and what O-7 asks

### 0.1 The question, restated precisely

The aggregate proof is a chain: a Greyhound-style two-tier commitment
opening (level 0) followed by L LaBRADOR-style recursion levels
(levels 1..L), the last level's witness sent bare. Extraction at any
level produces witnesses that are RELAXED: they satisfy the level's
verification algebra only after multiplication by an invertible
challenge difference, and their norms are bounded only up to
multiplicative factors (fork, norm-check slack, challenge operator
norms). AGGREGATION_PARAMS_DESIGN 3.4 carried three readings of how
these factors compose across levels:

- **per-level**: each level's binding is a fresh MSIS instance at a
  per-level-constant bound; total slack does not grow with depth L.
  Everything in DA's Section 5/6 tables holds.
- **exact-digit**: as per-level, with the JL projection replaced by
  deterministic digit range claims (slightly worse bytes, no JL
  statistical term).
- **compounded**: slack multiplies through levels
  (121.7 · 4.13^(L-1)); at q31 the gamma budget for L = 2 (2^19.02)
  is below the minimum feasible fold norm (2^20.88), so exactly ONE
  fold level fits, the artifact floor is 41.6 MB = 158.67x budget,
  and the architecture is dead at this ring.

O-7 must decide which reading is PROVABLE for our chain, by
derivation. This document is that derivation. The three sub-questions
(PARAMS 6.4 items 1-3, DB 12.3):

1. the composition lemma itself (Section 2),
2. the recursive Fiat-Shamir knowledge error (Section 3),
3. the RLC-batching knowledge error over the partially split ring,
   composed through the evaluation proof (Section 4) — the piece both
   U-AG2 lanes restated and neither absorbed; AGGREGATION_LITERATURE
   Section 9 records that no treatment of it exists in print. Section
   4 is, to our knowledge, the first written one.

### 0.2 Sources and verification routes

House sources, verified this session against the working tree:

- `zkmatrix-rs/src/ring/params.rs`: TAIL = 1.3, E_C2 = 2.0,
  `op_norm(conc)` = 1.3·sqrt(2D) = 20.79, `op_norm(worst)` = 2D =
  256; **no operator-norm cap is enforced on the quinary challenge
  set** (load-bearing for Section 1.4); `assert_ls18` (C0', margin
  1.30x at k = 8, q31). `ring/mod.rs`: Q8 = 2,147,483,249, ETA8,
  k = 8 split.
- SOUNDNESS_REFERENCE.md 1.3: the L1 (LS18 difference invertibility)
  and L2 (per-slot point mass 2^-297.2) engines; 2.2 relaxed binding.
- AGGREGATION_PARAMS_DESIGN.md Sections 2-3 (DA's layout, schedules,
  and the three-readings table); its Section 1 constants table was
  independently spot-checked above.
- AGGREGATION_CLAIM_REDUCTION.md Sections 1, 10 (CR-L1..L6, the
  batching structure and FS-ordering table).

External sources, READ IN FULL THIS SESSION (the ePrint PDFs are
behind a bot check; all three were retrieved as archived copies of
the ePrint PDFs via the Internet Archive Wayback Machine —
`web.archive.org/web/2024id_/https://eprint.iacr.org/<id>.pdf` — and
the quoted statements below are transcribed from those PDFs; page
identity with the live ePrint versions is [MODEL] to the extent the
archive snapshot lags the latest revision):

- **[LaB]** Beullens, Seiler. "LaBRADOR: Compact Proofs for R1CS from
  Module-SIS." CRYPTO 2023, ePrint 2022/1341. Used: Lemma 3.7
  (composition preserves knowledge soundness, errors ADD), Section 4
  (modular Johnson-Lindenstrauss: Lemma 4.1 = [GHL21] Cor 3.2, Lemma
  4.2 with the b <= q/125 window), Section 5.2-5.4 (protocol,
  recursion, decomposition, norm bounds), Theorem 5.1 + Remark 5.2
  (THE per-iteration extraction theorem and the one-factor recursion
  inflation), Appendix B (the extraction proof — the mechanism
  transcribed in Section 1.3), Section 5.6 (last-iteration
  optimization — the hazard flagged in Section 2.2).
- **[PSS]** Aardal, Aranha, Boudgoust, Kolby, Takahashi.
  "Aggregating Falcon Signatures with LaBRADOR." CRYPTO 2024, ePrint
  2024/311. Used: Definition 3.1 (B-well-spread challenge sets),
  Lemma 2.2 (modular JL constants: lambda = 128 -> C1 = 120,
  C2 = 30; lambda = 256 -> C1 = 168, C2 = 60), Theorem 4.1 (FS
  knowledge error of predicate-special-sound protocols, linear in
  Q), Theorem 4.2/Theorem I.1 (base LaBRADOR, FS'd, parametric in
  ring degree d, splitting factor l, well-spreadness B, challenge
  operator cap T_op), Appendix I.5 Eq. (18) (t-fold recursion:
  ADDITIVE error accumulation, per-level slack into MSIS norms),
  Appendix I.6 (the (T_op)^r hazard of the [NS22]-style garbage
  optimization under FS).
- **[Grey]** Nguyen, Seiler. "Greyhound: Fast Polynomial Commitments
  from Lattices." CRYPTO 2024, ePrint 2024/1293. Used: Lemma 3.2
  (CWSS extraction of the three-round opening proof: weak openings,
  binding at max-bounds), Theorem 4.1 (the evaluation-proof
  knowledge-soundness statement: extraction probability
  eps - eps_1 - r/|C|, weak binding at max(4*kbar*betabar, 2*gammabar),
  composition via [LaB] Lemma 3.7).

Everything quoted from these three is grade **[CITED]** unless a
house re-derivation is given, in which case the re-derivation is
graded on its own.

### 0.3 What "slack" means — the three faces

Extraction slack is not one number. It is three different objects
that the compounded reading conflates:

- **(algebraic) relaxation factors.** An extracted opening satisfies
  cbar·(verification equation) rather than the equation itself,
  cbar = c - c' a challenge difference. Over OUR ring cbar is
  invertible (L1/LS18, C0' freeze-checked), so the mod-q ALGEBRA is
  exact after one inversion per level: relaxation factors never
  accumulate as algebra. They survive only inside norm bounds, where
  division is not norm-preserving. (Section 1.2, SC-L0.)
- **(analytic) norm growth.** The extracted witness's norm bound at
  a level is set by that level's OWN norm check (modular-JL
  projection, or exact digit claims), NOT by transporting the
  previous level's extracted bound through the fold. This is the
  re-grounding mechanism — the heart of the per-level lemma.
  (Sections 1.3-1.5, 2.)
- **(statistical) knowledge-error terms.** Per-level extraction
  failure probabilities. These compose ADDITIVELY ([LaB] Lemma 3.7
  interactively; [PSS] Thm 4.1/Eq. 18 under Fiat-Shamir, linear in
  Q) — never multiplicatively into norms. (Section 3.)

## 1. (a) The composition model: per-level extraction statements

### 1.1 The chain and its objects (house instantiation)

Fixed by DA (AGGREGATION_PARAMS_DESIGN 2.2, 3.2); repeated here only
to name the objects the lemmas below quantify over.

- **Level 0 (Greyhound).** Committed vector: n rings arranged
  m1 x m2; column j digit-decomposed at base b_0 = 2^{e0} into
  s_j (m1·l0 + 16 rings, |entries|_inf <= 2^{e0-1}); inner Ajtai
  commitments t_j = A s_j (kappa rings); outer commitment
  u = B that over the base-2^{e_t} digits that of all t_j. Wire: u.
  Fold: quinary c_1..c_m2, z = sum_j c_j s_j, plus the w-message;
  (z, that, w) is NOT sent — it is the level-1 witness.
- **Levels i = 1..L (LaBRADOR).** Witness s^{(i)} (n_i rings, all
  entries digits bounded 2^{e_i - 1}), multiplicity r_i chunks,
  stated norm bound beta_i (the consolidated bound of [LaB] Section
  5.3: beta_i^2 = (2/b_{i-1}^2)·gamma_{i-1}^2 + gamma_{1,i-1}^2 +
  gamma_{2,i-1}^2 — the previous level's z-decomposition parts plus
  commitment/garbage digit material). Per level: inner commitments
  of chunks, outer commitment(s), norm statement (JL projection over
  256 or 512 rows, or the exact-digit variant), constraint
  aggregation, quinary fold, digit decomposition of the fold at the
  next base b_i = 2^{e_i} (DA's ADAPTIVE bases).
- **Level L (bare).** The final witness (~500-620 rings) is sent in
  the clear; the verifier checks its norm and the level-L
  verification equations DIRECTLY. Extraction at level L is reading
  the wire: slack exactly 1, error 0.

Throughout: K = GF(q^16) (slot field, 2^496); quinary set C with
|C| = 5^128 = 2^297.2, per-slot point mass 2^-297 (L2 [PROVEN,
SOUNDNESS_REFERENCE 1.3]); challenge differences LS18-invertible at
margin 1.30x (C0' [PROVEN, freeze-checked]).

### 1.2 SC-L0 — relaxation factors clear algebraically (no cross-level algebra slack)

**Statement.** Let level i+1's extractor return openings of level
i's outer commitment(s) and (weak) openings of level i's inner
commitments such that every level-i verification equation holds
after multiplication by a product P of challenge differences
cbar_1..cbar_k from C - C. Then every level-i verification equation
holds EXACTLY in R_q for the extracted values, and no relaxation
factor is passed to level i-1.

*Proof.* Each cbar_t is invertible in R_q by L1/LS18 (C0'; margin
1.30x at (k = 8, q31), asserted at derive time). A finite product of
units is a unit. P·v = 0 in R_q with P a unit forces v = 0. The
level-i verification equations are R_q-identities in the committed
values (dot-product constraints, [LaB] Section 5.1 form; DB's CR-L2c
slot form for the house claim classes), so clearing P leaves the
identities exact. Norms are NOT preserved by this clearing — the
inverse of a challenge difference is not short — which is exactly
why SC-L0 says nothing about norms: those are handled by SC-L2/SC-L3
per level, never by dividing. **[PROVEN]** (elementary given L1;
this is the house relaxed-binding shape, SOUNDNESS_REFERENCE 2.2,
promoted from one commitment to the level chain).

*Where used:* Section 2 (SC-L4 step 2); it is the reason the
compounded reading's "relaxation factors multiply into the MSIS
bound" mechanism has no purchase on the algebra.

### 1.3 SC-L1 — one level's extraction, house constants (the [LaB] Appendix B shape at our ring)

**Setting.** Level i as in 1.1. Write beta'_i for the next level's
stated (consolidated) bound, b = b_i = 2^{e_i} for the level's
z-decomposition base, T for the maximum operator norm of a SINGLE
challenge in the fold-challenge set actually used (see the CAP
condition below), and sigma_{i+1} for the norm-grounding slack that
level i+1's extraction guarantees on the level-i last-message
vectors (sigma = sqrt(2·lambda_rows/C2)-class for JL grounding =
2.07; sigma = 1 for exact-digit grounding; sigma = 1 at the bare
level).

**Statement (transcription of [LaB] Appendix B / Theorem 5.1 with
house constants).** From an accepting prover with success
probability above the level's knowledge error (Section 3), an
expected-poly extractor obtains:

1. **Outer binding.** The openings of the outer commitment(s)
   (that, g-digits, h-digits) are the SAME across all accepting
   transcripts, provided MSIS(kappa_1) is hard at norm bound
   2·sigma_{i+1}·beta'_i. (Two distinct openings of norm
   sigma_{i+1}·beta'_i each subtract to an MSIS solution.)
2. **Weak inner openings.** For each chunk j, two transcripts
   differing only in c_j yield sbar*_j with
   ||cbar_j · s*_j|| <= 2·(1 + b)·sigma_{i+1}·beta'_i
   (the recomposed fold z = z^(0) + b·z^(1) is bounded by
   (1 + b)·sigma_{i+1}·beta'_i per transcript; two transcripts give
   the factor 2). [NS22]-style amortized extraction, coordinate-wise.
3. **Inner binding.** Two distinct weak openings for the same t_j
   yield an MSIS(kappa) solution of norm <=
   8·T·(1 + b)·sigma_{i+1}·beta'_i (cross-clearing the two
   challenge differences costs one single-challenge operator norm
   per term; [LaB] Thm 5.1's first max-argument).
4. **Norm re-grounding.** The extracted s*_j THEMSELVES (not the
   cbar-products) satisfy sum_j ||s*_j||^2 <= sigma_i^2 · beta_i^2,
   by the level's own norm check applied to the extracted values —
   SC-L2 (JL) or SC-L3 (exact-digit). This is where the a-priori
   unbounded quotient norms are replaced by a per-level constant.
5. **Constraint transport.** The level-i dot-product constraints
   hold exactly for the s*_j (quadratic challenge-identity
   arguments; per-event probability 2·(per-slot point mass) =
   2^-296-class at our C, vs 2·2^-128 at [LaB]'s set — the house L2
   engine strictly improves these terms), and SC-L0 clears the
   relaxation.

**Grade.** [CITED] for the extraction strategy ([LaB] App. B,
verbatim structure); [PROVEN] for the house constant substitutions
(each is an operator-norm or point-mass fact checked against
params.rs / SOUNDNESS_REFERENCE 1.3); CONDITIONAL on the cap:

**The operator-norm cap condition (C-cap).** Steps 3 and 5 use T =
max operator norm over the challenge SET (adversarial transcripts —
the house restart discipline is prover-side and does NOT apply;
Q4.1c(i) covers verifier gates, not extraction constants). [LaB]
obtains a worst-case T by CONSTRUCTION: their challenge set is
rejection-sampled to operator norm <= 15 at d = 64. The house
quinary set carries NO such cap (params.rs verified this session):
worst case op = 2D = 256, and DA's slack table used the
concentration value 29.4 in its place. The spike's Monte-Carlo
section (20k draws; singular values via evaluation at the odd 256th
roots of unity) shows the true operator-norm distribution of quinary
challenges at D = 128 is p50 = 34.2, p99 = 46.8 (RMS scale 16) —
i.e. **the house `op_norm(conc)` = 20.8 is a per-use concentration
bound for c·u with u FIXED (valid for honest sizing under the Q4.1
restart discipline) and sits BELOW the median of the actual operator
norm; neither 20.8 nor 29.4 can serve as an extraction-side
challenge bound.** **Design rule R-EB1 (exported): the aggregate
layer's fold-challenge sampling (and batching-challenge sampling,
Section 4) MUST enforce an operator-norm cap T_cap by resampling
(deterministic FS counter loop, the house salt pattern; [LaB] does
exactly this with T = 15 at d = 64), with T_cap and its honest
resampling rate frozen as derive-time constants.** Measured
candidates [MODEL — MC]: T_cap = 33 accepts 38% (~3 attempts per
challenge); 36 accepts 67%; 42 accepts 94%. The working point used
in every Section 2.4 number is **T_cap = 33**. Without R-EB1 the
honest worst-case T = 256 costs ~2.9 bits over T_cap = 33 in
beta_top — R-EB4's base caps would tighten by the same bits and the
architecture would still stand (shallower bases, more bytes), so
R-EB1 is an efficiency rule, not a viability condition.

*Where used:* SC-L4 (the induction step); Section 2.4 (the corrected
per-level constant).

### 1.4 SC-L2 — modular-JL norm grounding at our ring [CITED + house arithmetic]

**Statement ([LaB] Lemma 4.1 = [GHL21] Cor. 3.2; Lemma 4.2;
constants re-derived by [PSS] Lemma 2.2 / their jl.py).** Let Pi
have iid entries 0 with probability 1/2 and +-1 with probability 1/4
each.

- (rows = 256, lambda = 128): for every w in Z^d:
  Pr[||Pi w|| < sqrt(30)·||w||] <~ 2^-128, and per row
  Pr[|<pi, w>| > 9.5·||w||] <~ 2^-141.
- (modular version, THE load-bearing one): for every
  w in [+-q/2]^d with ||w|| >= b_JL and **b_JL <= q/125**
  ([PSS]: q/120 at lambda = 128; q/168 at lambda = 256):
  Pr[||Pi w mod q|| < sqrt(30)·b_JL] <~ 2^-128
  (2^-256 at lambda = 256 with the C2 = 60 constant).

**Consequence at a level (the grounding).** The verifier (or the
recursion, via exactly-transported constraints — SC-L0/SC-L1 step 5)
checks ||p|| <= sqrt(lambda)·beta_i where p is the claimed
projection of the level witness, and the JL-consistency rows
p_j = <pi_j, s> are part of the exactly-extracted constraint system.
Then for the extracted s* (fixed by outer binding BEFORE Pi is
drawn), except with probability 2^-lambda over Pi:

    sum_j ||s*_j||^2 <= (2·lambda/C2) · beta_i^2 / (2·lambda/C2)…
    i.e. ||s*|| <= sqrt(2·lambda/C2) · beta_i = sigma · beta_i,
    sigma = sqrt(256/30) at 256 rows = sqrt(512/60) at 512 rows
          = 2.07 (numerically identical at both settings),

REGARDLESS of how large the a-priori algebraic norm of s* is: Lemma
4.2 quantifies over ALL centered representatives w in [+-q/2]^d, so
there is no "wrap regime" left uncovered — the only hypothesis is
the WINDOW on the bound itself:

    **(C-win)  sigma · beta_i <= q / C1**, C1 = 120 (lambda = 128)
               or 168 (lambda = 256).

House arithmetic at q31 (spike-checked per level, both shapes, both
branches): the window applies to the level's WITNESS bound beta_i —
the digit-decomposed material, 2^14.1-2^16.8 across all schedules —
NOT to the fold norm gamma_i ~ 2^20.9 (the fold is never the object
the projection grounds; its recomposition is R-EB4's business,
Section 2.4). So sigma·beta_i ~ 2^15.1-2^17.8 against q/C1 =
2^24.06 (lambda = 128) / 2^23.60 (lambda = 256): **minimum margin
+6.2 bits (256-row) / +5.8 bits (512-row) over every level of every
schedule — C-win HOLDS comfortably.**
Grade: [CITED] for the lemmas (statements transcribed above;
constants from [PSS]'s recomputation — note [LaB]'s own text says
q/125 where [PSS]'s jl.py says q/120; the spike uses the TIGHTER
125); [PROVEN] arithmetic for the window check; **[MODEL]** for the
512-row error constant in the sense that Lemma 2.2 is itself flagged
"heuristic" by [PSS] (Berry-Esseen-based) — carried at 2^-256, NOT
at DA's modeled 2^-282 (correction, Section 3.2).

*Where used:* SC-L4 step 3; C-win joins the freeze-check export
list (Section 5.4).

### 1.5 SC-L3 — exact-digit grounding: residue pinning, slack exactly 1 [PROVEN mechanism, OBLIGATION plumbing]

**Statement.** Suppose level i's witness entries are committed in
bit-decomposed form and the constraint system contains, for every
bit position, the zero-check b·(b - 1) = 0 (DB's CR-L6 kernel: one
post-commitment challenge point r in K^n, SZ error <= n/|K| ~
2^-490-class per instance), plus the public gadget recomposition
identities (linear, CR-L1 weights). Then the extracted witness's
entries are EXACTLY the claimed digits as centered representatives:
b*·(b* - 1) ≡ 0 (mod q) forces the residue b* ∈ {0, 1}, whose
centered representative is 0 or 1 — an INTEGER statement with no
norm window, no statistical projection term, and slack exactly 1
on every digit bound; the level norm bound follows over Z with
sigma = 1.

*Proof.* x(x-1) ≡ 0 mod q with q prime means x ≡ 0 or 1 in Z_q
(per CRT slot, and the slot-complete CR-L6 check pins every slot —
the projection to any slot field has no zero divisors; DB Section
1.7). The centered representative of the residue 0 or 1 is itself.
Gadget recomposition with public powers of two then bounds each
witness entry by the digit-range bound exactly, and the l2 norm over
the integers follows by summation. No wrap can occur because no
integer lift is ever taken — every statement is a mod-q residue
statement whose truth pins the representative. ∎ **[PROVEN]**
(mechanism; contrast [LaB] Section 6's binary-R1CS treatment, which
proves only the SUM sum_i a_i(a_i - 1) ≡ 0 and therefore needs the
norm window n + 3k < 15q/128 to lift to Z — the house per-position
kernel is strictly stronger and needs no window).

**[OBLIGATION — plumbing, DA 6.4 item 4]:** integrating the
per-position claims is new protocol plumbing with one design fork,
named here so the build round prices it rather than discovers it:
the level constraint systems are QUADRATIC (dot-product form), so
per-position range pinning of base-2^e digits needs bit-level
witness columns (d = sum_j 2^j b_j - offset, each b_j pinned by
b(b-1) = 0) — a dimension-times-e_i growth of the digit part of
each level witness whose byte effect is unpriced in both DA's and
this document's exact-digit rows (Section 2.4(c) flag). The
per-position families aggregate inside the level's own
constraint-RLC — with the K-draw variant (Section 3.2) the
aggregation error is 2^-496-class, so SC-L3's "no heuristic
constant, no window" property is preserved; the residues are pinned
except with that statistical RLC error, which joins the additive
sum of Section 3 (already counted: the exact-digit column's K-draw
term). Alternatively CR-L6 zero-checks over T_data-committed digit
material serve the LEVEL-0 witness only. Mask budgets are EC's
lane.

*Where used:* SC-L4 (the sigma = 1 branch); the fallback boundary
(Section 5.1) — exact-digit is the backstop that holds even if an
external review rejects the heuristic JL constants.

### 1.6 The final level — slack 1, error 0 [PROVEN trivially]

The bare witness is wire data; the verifier checks its norm and
equations directly. Extraction reads it. This anchors the induction:
sigma_{L+1} = 1, and every recursion of SC-L1 terminates here.

## 2. (b) THE LEMMA: how extracted-witness slack composes

### 2.1 SC-L4 — the per-level composition lemma

**Statement.** Consider the house chain of Section 1.1 (level 0
Greyhound fold, levels 1..L LaBRADOR iterations, bare level L), at
q31, with per-level stated bounds beta_0..beta_L (DA's adaptive-base
schedules), and suppose:

- **(C-alg)** every fold/batching challenge difference used in
  extraction is invertible in R_q — the L1/LS18 criterion, asserted
  at derive time (C0', margin 1.30x) [PROVEN, house];
- **(C-ground)** every level i in 1..L carries its own norm
  re-grounding: either the modular-JL projection with window C-win
  satisfied at beta_i (SC-L2), or the exact-digit residue pinning
  (SC-L3); the bare level grounds itself (1.6);
- **(C-cap)** the fold/batching challenge sets are operator-norm
  capped at T_cap (R-EB1);
- **(C-msis)** for every level i, MSIS is hard (>= 128-bit
  [core-SVP] house convention) at the level's TWO binding bounds:
  outer: 2·sigma·beta'_i; inner:
  max(8·T_cap·(1+b_i)·sigma·beta'_i,
      2·(1+b_i)·sigma·beta'_i + 4·T_cap·sigma·beta_i),
  with sigma = 2.07 (JL grounding) or 1 (exact-digit / bare next
  level) applied ONCE per level ([LaB] Remark 5.2).

Then the composed chain is a knowledge-sound proof for the level-0
statement with:

1. **extracted-witness norm slack sigma_0 = 2.07 (JL) or 1
   (exact-digit) — ONE factor, independent of the depth L** (the
   level-0 witness is grounded by level 0/1's own norm statement,
   not by transport through the chain);
2. **per-level MSIS bounds as in (C-msis) — each carrying exactly
   ONE composed grounding factor sigma, never a product over
   levels**;
3. **knowledge error = the SUM of per-level errors** (Section 3
   prices them; interactively this is [LaB] Lemma 3.7; under FS it
   is [PSS] Thm 4.1/Eq. 18, linear in Q).

**Proof.** By downward induction on the level, composing [LaB]
Lemma 3.7 (proof-of-knowledge reductions compose, knowledge errors
add) with the single-level extraction SC-L1.

*Base (level L).* The bare witness is read off the wire; the
verifier checks its norm and equations directly. Extraction slack 1,
error 0 (1.6).

*Step (level i, given level i+1).* By the induction hypothesis the
level-(i+1) protocol is a knowledge-sound proof of level i's target
relation — the consolidated relation with stated bound beta'_i —
with norm slack sigma_{i+1} in {1, 2.07} and additive error. Level
i's extractor (SC-L1) then needs from below EXACTLY TWO things, and
this is the mechanism the whole question turns on:

  (i) *exact algebra*: the level-i verification equations hold for
  the extracted level-(i+1) witness. The inner extractor returns
  them relaxed by challenge differences; SC-L0 clears the relaxation
  exactly in R_q (C-alg). NOTHING about the inner extraction's NORM
  quality enters here — algebra over R_q has no norms.

  (ii) *a norm bound at the stated level*: the level-i last-message
  vectors (z-parts, that, garbage digits) have norm <=
  sigma_{i+1}·beta'_i. This is the induction hypothesis VERBATIM —
  and sigma_{i+1} is a constant in {1, 2.07} fixed by level (i+1)'s
  OWN grounding, NOT a function of levels i+2..L, because level
  (i+1)'s grounding (SC-L2/SC-L3) quantifies over ALL centered
  representatives: however wild the deeper extraction's a-priori
  norms, level (i+1)'s JL window or residue pinning caps what its
  extractor can output at sigma_{i+1}·beta'_i. The deeper levels'
  slack has no channel into this bound.

  With (i) and (ii), SC-L1 runs level i's extraction: outer binding
  at 2·sigma_{i+1}·beta'_i, weak inner openings at
  2(1+b_i)·sigma_{i+1}·beta'_i, inner binding at the (C-msis)
  bounds, and level i's OWN grounding (C-ground) re-grounds the
  extracted level-i witness at sigma_i·beta_i — handing the
  induction to level i-1 with a fresh constant. Knowledge errors add
  by [LaB] Lemma 3.7's rewinding argument (the inner extractor is
  invoked as a subroutine; its failure probability joins additively,
  not multiplicatively into norms).

*Level 0 (Greyhound).* [Grey] Thm 4.1's shape: weak binding at
max(4·(2·T_cap)·betabar, 2·gammabar) with betabar = 2·gammabar and
gammabar = sigma_1·beta'_0 (their kbar = 2·kappa becomes 2·T_cap at
our set — their challenge-sparsity L1 cap plays the role our
operator cap plays); extraction probability eps - eps_1 - m2/|C|;
the extracted committed polynomial is pinned by binding, and — the
Greyhound-specific point — needs NO norm at all (the committed
message is arbitrary mod q; only the DECOMPOSED digit witnesses
carry norms, and those are level-1 material grounded by level 1).
The composed chain's level-0 output is therefore the exact
committed-vector opening the evaluation claims refer to. ∎

**Grade: [PROVEN] as a composition of [CITED] published components
with house-instantiated constants** — precisely: the skeleton
([LaB] Thm 5.1 + Remark 5.2 + Lemma 3.7, [Grey] Thm 4.1, [PSS] Eq.
18) is published and was read in full this session; the house
substitutions (L2 point masses for challenge terms, LS18 for
invertibility, k = 8/GF(q^16) slot structure for the aggregation
terms, T_cap for their constructed caps, CR-L6 for the exact-digit
branch) are each individually [PROVEN] house facts; what is NOT
published anywhere is this chain AT OUR RING — the transfer is this
document, and the standing independent review (Section 5.3) is the
external check on the transfer.

### 2.2 Why the compounded reading fails to apply — and what it WOULD describe

The compounded reading's mechanism — "level k's extractor consumes
level k+1's relaxed witness, so relaxation factors multiply into the
MSIS bound" — requires a channel by which the inner extraction's
norm quality propagates outward. SC-L4's proof shows the two
channels that exist ((i) algebra, (ii) the stated-bound norm) are
both slack-inert: (i) is exact after LS18 clearing, (ii) is capped
by the inner level's own grounding. The multiplication the
compounded reading imagines happens only if a level LACKS its own
grounding, and then it is real. Three concrete protocols where the
compounded arithmetic is the CORRECT one:

1. **Fold-only recursion** (no per-level norm statement): the only
   handle on the level-i witness norm is the recomposed bound
   (1+b)·(previous extracted bound), and the extracted bound
   multiplies by 2·T·(1+b)-class per level — DA's 4.13^(L-1) row is
   exactly this shape. LaBRADOR's JL projection exists precisely to
   break this; a house variant that dropped the projection to save
   its bytes would resurrect it.
2. **The [NS22]-style last-iteration garbage optimization under
   Fiat-Shamir**: [PSS] Appendix I.6 (read this session) shows the
   FS extraction of that optimization carries slack proportional to
   (T_op)^r — exponential in the multiplicity — because witnesses
   can no longer be extracted independently per round. **Design
   rule R-EB2 (exported): the house chain must NOT adopt the
   [NS22] garbage-reduction optimization at any recursed level;
   DA's byte model already uses the full r(r+1)-garbage count, so
   no byte table changes** — but the rule must be recorded so a
   future byte hunt does not re-import it silently. (The bare last
   level MAY use it interactively-style only if a second amortized
   opening is added — [PSS] I.6's suggested fix — not designed
   here.)
3. **Grounding with a broken window**: if some level's bound
   violated C-win (sigma·beta_i > q/C1), Lemma 4.2 gives nothing at
   that level and the norm handle degrades to the fold-only
   transport from the nearest grounded level below — locally
   compounded until re-grounded. C-win is therefore a PER-LEVEL
   freeze obligation, not a one-time check.

This section is the honest content of the compounded row: it is not
a wrong reading of a theorem, it is the right reading of three
DIFFERENT protocols, none of which is ours as designed — and each
of which is one design shortcut away. R-EB1/R-EB2 + the C-win
freeze rows are the fence.

### 2.3 DA's adaptive digit bases ARE the honest-side half of the renormalization

The tranche brief asked whether DA's adaptive bases are "the
renormalization" the conditional lemma needs. Answer: they are
exactly HALF of it, and the necessary half:

- **Honest side (completeness):** re-decomposing the fold at base
  b_i = 2^{e_i} resets the honest witness norm to the digit scale,
  so every level's STATED bound beta_i stays in the narrow band
  2^20.9-2^21.7 instead of growing by sqrt(r_i)·T-class per fold.
  Without this, C-win (beta_i <= q/C1-class ~ 2^23-24) would break
  within two levels — i.e., DA's adaptive bases are what make the
  WINDOW hypothesis of the grounding lemma satisfiable at 31 bits.
- **Extracted side (soundness):** the decomposition alone proves
  nothing about a cheating prover (extracted "digits" are arbitrary
  mod q until checked). The JL projection (SC-L2) or the residue
  pinning (SC-L3) is the other half — it forces the extracted
  witness back to the stated scale.

So the conditional shape "holds iff the recursion re-decomposes and
re-grounds per level" resolves as: DA's chain re-decomposes (his
bases) AND re-grounds (his JL/exact-digit configurations) at every
level — both halves present, SC-L4 applies.

### 2.4 The corrected per-level constant, and the corrected validity line

Three honest corrections to DA's Section 3.4 numbers fall out of the
transcription and the spike. None changes the verdict; they change
margins, kappa, the deep bases, and the branch preference. (All
numbers spike-printed; representative values here.)

**(a) The per-level slack constant is bigger than 121.7, and it
CAPS THE DEEP BASES (R-EB4).** DA's per-level row priced base =
2 (fork) · 2.07 (JL) · 29.4 (dc-conc) = 121.7 = 2^6.93 applied to
gamma_z. The [LaB]-form inner-binding bound instantiated at house
constants is level-local:

    beta_top(i) = 8 · T_cap · (1 + b_i) · sigma · beta'_i,

with b_i = 2^{e_i} the level's decomposition base and beta'_i the
next witness bound (2^14-16.8-class). Three consequences, all
spike-printed per level:

- at DA's SHALLOW levels (e_i = 1-6) this lands 2^26.0-2^30.1 —
  valid MSIS instances, kappa = 10-11;
- at DA's FLOOR levels the adaptive bases reach e_i = 8-10, and
  (1 + 2^9)-class recomposition factors push beta_top to
  **2^31.8-2^34.1 > q — the MSIS instances there are VACUOUS as
  bounded**: DA's fold-norm budget admitted bases the binding
  analysis cannot support. **Design rule R-EB4 (exported): the
  adaptive-base rule must enforce, at every level,
  8·T_cap·(1 + 2^{e_i})·sigma·beta_i(e_i) <= 2^30.5 in addition to
  the fold-norm budget** — in practice this caps e_i <= 7 at the
  floor (vs DA's 9-10), raising the recursion floor from ~500-620
  to ~620-770 rings and the final bare witness by ~18 KiB;
- DA's dc-conc 29.4 was a concentration value where an adversarial
  worst-case cap belongs (Section 1.3's MC finding), and the (1+b)
  recomposition and 8T cross-clearing were not in his model. With
  R-EB4 active: **max beta_top = 2^30.14 (JL branch) / 2^29.93
  (exact-digit) over all levels of both shapes — all valid.**

**(b) The q/8 validity line is not the right line, and removing it
returns most of what (a) costs.** DA's gamma_budget derived
gamma_max = (q/8)/slack from the house C2 discipline (q > 8·beta).
That discipline guards the MASKED ct-round's integer-window
recovery — a protocol object the aggregate layer does not contain
(I-6: no Gaussian-masked openings; all aggregate-layer verification
is mod-q algebra + JL windows + the bare level's direct checks).
The published chain needs only:

    (C-win)   sigma·beta_i <= q/C1    per level (hard), and
    (C-msis)  >= 128-bit MSIS at the Section 2.1 bounds (soft —
              kappa-tunable).

At q31 with the R-EB4-corrected schedules: C-win holds with >= +5.8
bits of margin at every level (Section 1.4); the worst-level MSIS at
the corrected bounds needs **kappa = 11** (spike: kappa >= 11 at the
tightest levels, both branches; kappa = 10 falls short there). Byte
consequences of {kappa 11, R-EB4 base caps, R-EB3} together, spike
tables (T_cap = 33, K-draw aggregation):

    2^20:  exact-digit 259,904 B = 0.991x -> PASS
           512-row JL  285,280 B = 1.088x -> OVER (pre-lever)
    FFN:   exact-digit 283,392 B = 1.081x -> OVER
           512-row JL  312,928 B = 1.194x -> OVER

i.e. the corrections cost +3% (exact-digit) to +9-13% (512-JL) over
DA's corresponding rows; **the 2^20 PASS survives on the exact-digit
branch; the 512-JL branch loses its byte advantage entirely** (its
JL wire + aggregation objects now exceed the digit-claims premium).
The "0.16 bits to spare" thinness DA reported at FFN was an artifact
of measuring the optimistic constant against the over-strict q/8
line; the honest picture is: hard margins of ~6 bits (window), soft
margins bought with kappa (MSIS), base caps at the floor (R-EB4),
no cliff. Dropping the q/8 line also unlocks a relaxed-e0 lever
(level-0 bases 4-5 instead of 1-3, all soundness gates green —
spike Section 4b) worth only 1-6 KiB at these shapes — recorded as
an O-2 export, not adopted here.

**(c) What survives of DA's three-readings table.** The per-level
ROW's structure survives (fresh MSIS per level, cross-level
consistency by committed-value equality — confirmed as [LaB]'s own
architecture); its CONSTANT is corrected by (a)+(b). The exact-digit
row survives with sigma = 1 and no window (SC-L3) — its constant
corrects the same way (~1 bit below the JL row) — and at the
corrected constants it becomes the BYTE-cheaper branch as well
(table above), inverting DA's 5.2 ordering. One byte-honesty flag
on both exact-digit rows (DA's and ours): they price the recursion
in DIGIT form; the per-position range claims need bit-level
witness columns inside the level constraint systems (SC-L3's
plumbing note), whose dimension effect on the level witnesses is
UNPRICED in both models — flagged [MODEL], same assumption both
sides, resolved by the plumbing obligation. The compounded row
survives as the correct arithmetic for the three protocols of
Section 2.2, none of them ours.

## 3. (c) The recursive Fiat-Shamir composition

### 3.1 SC-L5 — the PSS transfer to our ring [CITED + house instantiation]

**What [PSS] proves (Theorems 4.1, 4.2, I.1, Eq. (18); read this
session).** For a (K, Phi)-predicate-special-sound multi-round
protocol, the adaptive FS transform is knowledge sound with error

    2(Q + 1) · sum_i max( (k_i - 1)/|C_i|,
                          p_i^com + sum_l p_{i,l}^chal ),

LINEAR in the prover's Q random-oracle queries (not Q^rounds), with
extractor cost K + Q(K - 1) prover invocations, K = prod k_i. For
base LaBRADOR, stated PARAMETRICALLY in the ring degree d, splitting
factor l, challenge-set well-spreadness B, and challenge operator cap
T_op (Theorem I.1):

    2(Q + 1) · ( 2^-lambda  +  q^-ceil(lambda/log2 q)
                 +  q^-(d/l)  +  (5 + 2l)·r·B )
    + adv_MSIS(kappa, 8·T_op·(b+1)·beta') + adv_MSIS(kappa_1, 2·beta'),

and for the t-fold recursion (Appendix I.5, Eq. (18)) the bracket
SUMS over iterations — additive, still linear in Q — with the norm
checks' slack sqrt(lambda/C2) entering the MSIS norms once per level
("the norms of the M-SIS must tolerate this additional slack, too").

**Transfer conditions at our ring, each checked:**

1. *B-well-spreadness (their Definition 3.1) = the house L2 lemma.*
   Per-slot point mass of the quinary set: B = 5^-128 = 2^-297.2
   over each of the l = 8 slots [PROVEN, SOUNDNESS_REFERENCE 1.3].
   Their framework was built for exactly this parametrization; the
   2026-04-30 zksecurity finding (PARAMS 3.6) is the failure mode
   when B is large — ours is 365 bits from it.
2. *Challenge operator cap T_op.* Their theorem HYPOTHESIZES a
   capped set; the house set must adopt R-EB1 (Section 1.3) for the
   hypothesis to be satisfied. With the cap, T_op = T_cap.
3. *Splitting-factor terms.* Their q^-(d/l) full-entropy aggregation
   term instantiates to q^-16 = 2^-496 (house full-entropy R_q
   engine, per-slot mass [PROVEN]).
4. *Window.* Their "statements restricted to norm bound beta at most
   q/C1" = C-win, checked per level (Section 1.4).
5. *CWSS structure.* The house fold rounds are coordinate-wise
   (r_i challenges per fold round, forked one coordinate at a time)
   — their Appendix G/Theorem G.1 covers exactly this (used by
   Theorem I.1). [Grey]'s Lemma 3.2 gives the same structure for
   level 0.

Grade: **[CITED]** for the framework and Eq. (18); **[PROVEN]** for
transfer conditions 1, 3, 4 (house facts + arithmetic); condition 2
is R-EB1 (design rule, [OBLIGATION] at build time); condition 5 is
structural ([CITED] + inspection).

### 3.2 The per-level error terms at house constants — including the term DA's model missed

House instantiation of the Eq.-(18) bracket, per level i:

| term | house value | source |
|---|---|---|
| modular-JL statistical | 2^-128 (256-row) / 2^-256 (512-row) / ABSENT (exact-digit) | SC-L2; [PSS] Lemma 2.2. **Correction: DA modeled 2^-141 and ~2^-282; the verified soundness-side constants are 2^-128/2^-256** (2^-141 is the per-ROW completeness tail, not the soundness term) |
| ct-constraint aggregation | q^-t = 2^(-31·t) for t parallel Z_q draws | [LaB] protocol (psi/omega step); **THE MISSING TERM — absent from DA 3.5's accounting entirely** |
| full-poly constraint aggregation | 2^-496 | house full-entropy R_q draws (alpha/beta step), per-slot mass |
| fold (amortization) | (5 + 2l)·r_i·B = 21·r_i·2^-297 ~ 2^-288-class | [PSS] Thm I.1 bracket at l = 8, house B |
| claim batching (once, Section 4) | B_claims·2^-297 ~ 2^-293 | SC-L6 |
| GKR/sumcheck SZ (DB engine, once) | ~2^-485-class | DB 10.4 [PROVEN there] |

**The missing term, spelled out.** [LaB]'s protocol aggregates the
constant-coefficient (ct-class) constraints — the JL-consistency
rows p_j = <pi_j, s> and any other F'-family members — with
ceil(lambda/log2 q) parallel uniform Z_q combinations (their
psi/omega step); a nonzero ct-defect survives with probability
q^-ceil(lambda/log2 q). At their q ~ 2^32 and lambda = 128 this is
2^-128 and disappears into the union. At OUR q31 with the same
t = ceil(128/31) = 5 it is 2^-155 pre-FS — fine interactively —
but post-FS it multiplies 2(Q+1) ~ 2^65 and lands at **2^-90: the
whole chain FAILS the 2^-128 target through a term no house document
priced.** DA's 3.5 accounting (fold/batch/SZ/JL) does not contain
it; it is not a flaw in DA's levels but in the transferred protocol
constant at a 31-bit modulus.

**The fix, two options, both cheap (sizing rule R-EB3, exported):**

- (t-up) run t >= ceil((128 + log2(2(Q+1)) + log2 L)/31) = **7**
  Z_q-aggregation repetitions per level (Q = 2^64, L <= 8):
  per-level term 2^-217, post-FS contribution 2^-149. Wire cost:
  the b''-class objects are full R_q polynomials, t·516 B per level;
  t = 7 vs DA's modeled 1,028 B/level aggregation line: **+2,584
  B/level, ~ +18-21 KiB at L = 7-8** [MODEL; spike prices]. This is
  the do-nothing-clever option and its cost is visible at FFN scale.
- (K-draw) replace the t parallel Z_q draws by ONE full-entropy R_q
  draw (house engine): a ct-defect is a Z_q scalar embedded in R_q;
  an R_q-uniform multiple of it survives-as-zero with probability
  q^-D-class << 2^-496 [PROVEN, house conditioning argument].
  Wire cost ~one b''-object, 516-1,032 B/level — CHEAPER than DA's
  modeled line. Cost: the aggregated function is no longer
  ct-structured (the combination spreads defects across all D
  coefficients), so the b''-correction bookkeeping of [LaB]'s
  protocol must be restructured to full-polynomial targets —
  protocol plumbing of the same class as the exact-digit variant
  [OBLIGATION, build round]. Recommended direction, decision to the
  orchestrator with O-2.

### 3.3 The post-FS knowledge-error table [MODEL — constants cited, sum arithmetic spike-checked]

House convention Q = 2^64 (grinding), L = 8 levels, additive per
Eq. (18), times 2(Q+1) ~ 2^65:

| configuration | dominant per-level term | pre-FS sum | post-FS | vs 2^-128 |
|---|---|---:|---:|---|
| 256-row JL (any t) | JL 2^-128 | ~2^-125 | **~2^-60** | **FAIL** (DA modeled 2^-70 — same verdict, worse constant) |
| 512-row JL + t = 5 | ct-agg 2^-155 | ~2^-152 | **~2^-87** | **FAIL — the missing term** |
| 512-row JL + t = 7 | ct-agg 2^-217 | ~2^-214 | **~2^-149** | PASS (DA's "2^-211" row, corrected) |
| 512-row JL + K-draw | JL 2^-256 | ~2^-253 | **~2^-188** | PASS |
| exact-digit (+ K-draw or no ct-class rows) | fold 2^-288-class | ~2^-285 | **~2^-220** | PASS (DA's "2^-217" row, confirmed within a bit) |

Readings: (i) DA's two SOUND configurations survive, with the
512-row one requiring R-EB3 explicitly; the 256-row configuration
stays dead. (ii) The exact-digit column is the most robust — no
heuristic JL constant, no window, no ct-aggregation pressure — and
is now also the branch whose SOUNDNESS analysis carries the fewest
[MODEL] flags; its cost remains bytes (DA 5.2: +10-16 KiB vs
512-JL). (iii) Where DA's post-FS numbers came from: linear-in-Q
loss on the pre-FS union — the right SHAPE ([PSS] Thm 4.1 confirms
linear in Q); the constants shift as tabled.

Two conventions, flagged for the external review rather than decided
here: **(Q-conv)** the house charges Q = 2^64 oracle queries
directly in the error; [PSS]'s own parameter estimates set Q = 0 for
the extractor-runtime loss ("we ignore the security loss caused by
the extractor's runtime"), i.e. the field's published numbers are
LESS conservative than ours on this axis. **(X-run)** the PSS
extractor's expected prover-invocation count K + Q(K-1) with
K = prod_i 8·(2 r_i + 1) is astronomically large at L = 8 as a
worst-case bound (~2^5x-class times Q); this is standard for
expected-time extraction and affects the tightness of the security
REDUCTION, not the protocol's error terms — recorded honestly as
the same posture [PSS] takes, with the same caveat.

### 3.4 FS ordering

Every challenge in the chain must be derived from a state binding
everything it constrains: the fold challenges bind the level's outer
commitment(s) and the JL projection material; Pi binds the (outer)
commitments (SC-L2 requires the witness fixed before Pi); the
batching challenges bind the commitment identities, the claimed
values, AND the evaluation point (Section 4). DB's Section 10.5
table (CRB-N1..N5) already carries the claim-side rows; the
eval-proof-side rows join it as CRB-N6 (Pi after u1; attack:
choose witness after Pi, JL grounding voided) and CRB-N7 (fold c
after JL p and aggregation; attack: the [LaB] App. B argument's
independence structure collapses). Batteries are build-round scope
(same posture as CRB-N1..N5). [OBLIGATION — battery specs, not new
analysis.]

## 4. (d) The RLC-batching knowledge error over the partially split ring, composed through the evaluation proof

AGGREGATION_LITERATURE Section 9 records: "RLC batching of
evaluation claims is folklore over fields; at our 8-slot GF(q^16)
CRT structure with small-norm challenge sets, the knowledge-error
accounting is nowhere in print." DA proved the per-round SOUNDNESS
lemma (PARAMS 4.1, the L2-conditioning argument); DB proved the
claim-side algebra (CR-L4a/b) and both restated the EXTRACTOR to
O-7 (PARAMS 4.4, DB 10.4/12.3). This section is that extractor.
**To our knowledge it is the first written treatment of this
composition; it should be read by the independent review with that
in mind, not as a transcription of anything published.** (The
closest published object is [PSS]'s aggregation of many Falcon
verifications inside one LaBRADOR statement; their pattern —
extract once, then argue per-instance correctness through the
random-combination round's failure density — is the pattern used
here, which is why the result lands as a predicate argument rather
than a forking argument.)

### 4.1 Setting (from DA 4.1 and DB CR-L4, fixed notation)

After DB's engine runs, the verifier holds B batch entries: claimed
values v_{i,s} = f~_i(r)|_s for segments i = 1..B of the committed
vector behind T_data/T_blind, slots s = 1..8, common point
r in K^dw (I-1), all 8 slots per claim (I-3). The batching round
draws independent op-norm-capped quinary gamma_1..gamma_B (I-4 +
R-EB1) and the chain of Sections 1-3 proves the ONE batched claim

    sum_i res_s(gamma_i) · v_{i,s} = (sum_i gamma_i ⊙ f~_i)(r)|_s
    for all 8 slots s

against the commitment, where the batched polynomial's coefficient
vector is a PUBLIC linear image of the committed vector (public
weights assembled from gamma and the segment map).

### 4.2 SC-L6 — the batching extractor (straight-line over the batching round)

**Statement.** Suppose (i) the chain of Sections 1-3 is knowledge
sound for the batched claim (SC-L4 + SC-L5, with their conditions),
(ii) gamma is FS-derived from a state binding the commitment
identities u, ALL claimed values v_{i,s}, and the point r (CRB-N4/
N5 rows), and (iii) claims are slot-complete (I-3). Then there is an
extractor that, with the chain's knowledge error plus an additive
term

    eps_batch = B · 2^-297   (per false-claim event; through FS:
    one more failure-density row inside the [PSS] Thm 4.1 sum,
    contributing 2(Q+1)·B·2^-297 ~ 2^-228 at B = 16, Q = 2^64),

outputs a single opening f* of T_data/T_blind such that EVERY
individual claim is true of f*: f*_i(r)|_s = v_{i,s} for all i, s.

**Proof.** Run the chain extractor ONCE on the batched claim: it
outputs (SC-L4, level-0 clause) the committed vector's opening f*,
pinned by binding across all accepting continuations (two distinct
extracted openings break MSIS at the Section 2.1 bounds — the same
instances already required by C-msis; batching adds NO new MSIS
instance because the batched polynomial is a public linear image of
the SAME committed vector, not a new commitment). f* is fixed
before gamma is drawn: by (ii), gamma's FS state binds u, and f* is
a function of the commitment openings alone (SC-L4's extraction
never uses gamma-forks — this is what "straight-line over the
batching round" means).

Define the TRUE values v*_{i,s} := f*_i(r)|_s — computable from f*
by evaluation. Suppose the claimed and true values differ somewhere:
delta_{i0, s0} := v*_{i0,s0} - v_{i0,s0} != 0. The chain proves (for
f*, exactly — SC-L0) the batched identity, so in slot s0:

    sum_i res_{s0}(gamma_i) · (v*_{i,s0} - v_{i,s0}) = 0 in GF(q^16).

Condition on all gamma_i, i != i0 (independent draws): the equation
demands res_{s0}(gamma_{i0}) = k for a FIXED slot-field constant k
(delta_{i0,s0} is invertible in the FIELD — the slot field has no
zero divisors; this is where partial splitting does the work that
fails at NTT-friendly rings). By L2, res_{s0} is injective on C, so
the probability over gamma_{i0} is <= 5^-128 = 2^-297. Union over
the B claims (the lazy bound; slots need no union — any single
disagreeing slot is caught, I-3): eps_batch = B·2^-297. In the FS
setting this is a challenge-predicate failure density in the
batching round ([PSS] Definition 4.5 shape): the predicate "the
claimed v equal f*'s true values" fails only on a 2^-297-mass set
of gamma per false claim, and Theorem 4.1's sum absorbs it linearly
in Q. So in any accepting FS transcript, except with the stated
probability, v = v* — and f* witnesses every individual claim. ∎

**Grade: [PROVEN]**, on top of SC-L4/SC-L5's conditions; the
FS-ordering hypothesis (ii) is load-bearing (if gamma failed to bind
some v_{i,s}, the prover could choose that value after seeing gamma
and only the gamma-combination would be pinned — DB's E4-N1-analogue
attack, CRB-N4's row); the slot-completeness hypothesis (iii) is
load-bearing (a slot-sampling design re-opens the small-slot escape
— DA 4.1's design rule (i), [PSS] Definition 3.1's B would
effectively collapse).

*Three structural notes for the review.* (1) No forking over gamma:
the classical "B+1 transcripts + invert the challenge matrix"
extractor would multiply the extracted witness by the inverse of a
quinary-challenge matrix — whose entries are NOT short — and is
both unnecessary and norm-toxic here; binding + straight-line
predicate argument avoids it entirely. This is the answer to DB
10.4's flagged row. (2) The norm side: gamma enters the fold with
op(gamma) <= T_cap (R-EB1 applies to batching challenges too —
PARAMS 4.2's E[c^2] = 2 accounting covers honest sizing; the cap
covers extraction). (3) Multi-point merges (DA 4.3 / DB CR-L4a)
happen BEFORE this round inside the DB engine over K with SZ-class
error (2^-49x); they add no ring-challenge structure and nothing to
this extractor.

### 4.3 What this closes

- PARAMS 4.4 ("extractor for the batched composition ... owed as
  part of O-7"): CLOSED by SC-L6.
- DB 10.4's flagged row ("KNOWLEDGE-ERROR composition of all RLCs
  through the evaluation proof's extraction at the partially-split
  ring"): CLOSED — the K-side RLCs (mu, nu, lambda) live inside
  DB's engine with SZ/field errors [PROVEN there]; the ring-side
  RLC (gamma) is SC-L6; the seam between them is the FS state
  ordering (ii), now explicit.
- PARAMS 6.4 item 2: CLOSED by SC-L6; item 3 (concentration/restart
  surcharge transcription for the new folds): SUBSUMED — the
  extraction constants use T_cap worst-case (no concentration claim
  to transcribe on the adversarial side), and the honest-side
  restart discipline stays Q4.1(i) with no soundness surcharge.

## 5. (e) Verdict, grades, and what remains

### 5.1 The verdict row, against AGGREGATION_PARAMS_DESIGN 6.3

**PER-LEVEL HOLDS — the architecture stands; the BaseFold fallback
boundary is NOT engaged.** By SC-L4 (cite: this document Section
2.1), on the four conditions:

> **C-alg** (LS18 difference invertibility — house C0', already
> freeze-checked); **C-ground** (every level re-grounds: modular-JL
> with window, or exact-digit residue pinning — DA's two sound
> configurations are exactly the two branches); **C-cap** (operator-
> norm-capped fold AND batching challenge sets — NEW design rule
> R-EB1, T_cap = 33 working point, spike-measured); **C-msis**
> (>= 128-bit MSIS at the Section 2.1 per-level bounds with the
> CORRECTED constants — satisfied at kappa = 11 WITH the R-EB4
> deep-level base caps; DA's kappa = 10 and his e = 8-10 floor
> bases both fall short of it).

DA's recommended parameters SURVIVE in structure and land with these
adjustments (all spike-quantified, Section 2.4(b) table): kappa 10
-> 11; R-EB4 base caps (floor e_i <= 7, bare witness +~18 KiB); the
512-row-JL configuration additionally needs R-EB3 (t >= 7, +18-21
KiB, OR the K-draw restructure at ~zero bytes [OBLIGATION]).
Net standing: **the exact-digit branch is now preferred on BOTH
axes — soundness (fewest [MODEL] flags: no heuristic JL constant,
no window, no ct-aggregation pressure) and bytes (2^20: 259,904 B =
0.991x PASS; FFN: 283,392 B = 1.081x)** — subject to the shared
digit-plumbing byte flag (2.4(c)); the 512-JL branch remains sound
but byte-dominated (1.088x / 1.194x). The FFN overage stays in the
lever band (~1.08x) — the sign at FFN scale remains the O-2/D-1
discussion, exactly as DA left it. The compounded reading is
REFUTED for our chain as designed (Section 2.2) — it is the correct
arithmetic only for three specifically-excluded design variants, and
R-EB1/R-EB2 + the C-win freeze rows are the standing fence. The
fallback trigger of PARAMS 6.3 ("O-7 proves compounded AND
exact-digit fails to integrate") is therefore NOT pulled on either
horn: the composition is per-level, and the exact-digit branch is
not only integrable but the most robust configuration.

### 5.2 Claim grades

| claim | grade |
|---|---|
| SC-L0 algebraic clearing | [PROVEN] (house L1) |
| SC-L1 one-level extraction at house constants | [CITED] strategy ([LaB] App. B) + [PROVEN] substitutions, conditional on C-cap |
| SC-L2 modular JL + window arithmetic at q31 | [CITED] lemmas (heuristic per [PSS]) + [PROVEN] window check; 512-row constants [CITED] to [PSS] jl.py |
| SC-L3 exact-digit residue pinning | [PROVEN] mechanism; plumbing [OBLIGATION] |
| SC-L4 THE composition lemma | [PROVEN] as composition of [CITED] skeleton + house substitutions; the at-our-ring transfer is this document (review target) |
| SC-L5 PSS/FS transfer | [CITED] + [PROVEN] conditions 1/3/4; R-EB1 [OBLIGATION] |
| missing ct-aggregation term + R-EB3 sizing | [PROVEN] arithmetic (the term is in [LaB]'s protocol and [PSS]'s Eq. 18; only its q31 size is news) |
| post-FS table constants | [MODEL] (cited constants, spike-checked sums; Q-conv flagged) |
| SC-L6 batching extractor | [PROVEN] on SC-L4/L5's conditions; FIRST WRITTEN treatment — priority review target |
| MC operator-norm finding (conc 20.8 below the true op-norm median) + T_cap table | [MODEL] (20k-draw MC; exact tail behavior owed a proof or a larger run at build time) |
| R-EB4 (deep-base cap) necessity + corrected schedules | [PROVEN] arithmetic (beta_top > q at DA's floor bases is a computed fact) + [MODEL] byte consequences |
| corrected per-level constant + kappa = 11 + byte deltas | [MODEL] (spike tables) |
| exact-digit byte rows (both DA's and ours) | [MODEL] — digit-form recursion assumed; bit-plumbing dimension effect unpriced (2.4(c)) |

### 5.3 What remains for the standing independent review (REMEDIATION_PLAN Phase 2.5)

Listed explicitly, in priority order:

1. **SC-L4's transfer** — the composition at k = 8 / GF(q^16) /
   quinary C is the "first of its shape" object (AGGREGATION_
   LITERATURE Section 9's gap); the skeleton is published, the
   instantiation is ours. A reviewer should check the induction
   step's two-channel claim (Section 2.1 step (i)/(ii)) against
   [LaB] Appendix B directly.
2. **SC-L6** — first written anywhere; both hypotheses (FS ordering,
   slot completeness) and the no-forking argument deserve hostile
   reading.
3. **The heuristic JL constants** ([PSS] Lemma 2.2 is flagged
   heuristic by its own authors; C1/C2 at lambda = 256 come from
   their jl.py) — either re-run their script at our parameters at
   build time [OBLIGATION] or prefer the exact-digit branch, which
   removes this item entirely.
4. **R-EB1's cap** — the MC operator-norm distribution (spike) is
   sampling evidence, not a tail proof; the cap needs a freeze row
   and a measured honest resampling rate at build time.
5. **Q-conv / X-run** (Section 3.3) — the house's Q = 2^64 charging
   vs the field's Q = 0 extractor-runtime convention; a reviewer
   should bless one posture.
6. **Wayback-vs-live source identity** — re-verify the three PDFs
   against live ePrint when the bot check lifts (Section 0.2 note).

### 5.4 Exports

**To the orchestrator/ledger (design rules, all build-round):**
- **R-EB1**: operator-norm cap T_cap on fold AND batching challenge
  sampling (resample-until-under, deterministic FS counter; freeze
  T_cap + honest rate). Spike MC at D = 128: T_cap = 33 accepts 38%
  (~3 attempts/challenge), 36 accepts 67%, 42 accepts 94%; the
  Section 2.4 numbers use 33.
- **R-EB2**: no [NS22]-style garbage-count optimization at any
  recursed level under FS ((T_op)^r slack, [PSS] I.6); bare last
  level only, or add the second amortized opening.
- **R-EB3**: ct-aggregation sizing t >= 7 at q31, or the K-draw
  restructure (recommended; plumbing owed).
- **R-EB4**: the adaptive-base rule gains a second constraint —
  8·T_cap·(1+2^{e_i})·sigma·beta_i(e_i) <= 2^30.5 at every level
  (caps floor bases at e_i <= 7; DA's e = 8-10 floor bases are
  binding-vacuous and MUST NOT ship).
- **Freeze rows**: C-win per level (sigma·beta_i <= q/C1); T_cap;
  t; kappa = 11; the R-EB4 inequality per level.
- **Corrections to DA's tables** (PARAMS 3.3/3.4/3.5/5.2/6.1):
  kappa 11, the corrected per-level constant + R-EB4 schedules, the
  corrected JL error constants (2^-128/2^-256), the R-EB3 line
  item, the branch-preference inversion (exact-digit now cheaper);
  DA's verdict language survives, his margins move as Sections
  2.4/3.3 state. The orchestrator reconciles the two documents at
  FINAL (this lane does not edit DA's).

**To EA (D-1 direction note, derived-at-DA's-parameters honored):**
dense re-encoding of Y/UP/Z (~13x fewer committed rings) shrinks
n_0, hence m2 and every r_i, hence: the fold error terms
(21·r_i·2^-297) shrink ~linearly; recursion depth L drops by ~1-2
levels (fewer Eq.-18 summands, fewer R-EB3 objects, fewer C-win
rows); gamma_z drops ~sqrt(13) ~ 1.85 bits, WIDENING the C-win and
beta_top margins by the same ~1.9 bits — i.e. **every margin this
document computed gets strictly easier under EA's dense encoding;
nothing here resists it.** No statement in Sections 1-4 depends on
the slot-form encoding.

## 6. References

1. Beullens, Seiler. "LaBRADOR: Compact Proofs for R1CS from
   Module-SIS." CRYPTO 2023; ePrint 2022/1341 — READ IN FULL this
   session via Wayback-archived PDF (Section 0.2 route note).
   Load-bearing: Lemma 3.7, Lemmas 4.1/4.2, Thm 5.1, Remark 5.2,
   Sections 5.2-5.6, Appendix B, Section 6.
2. Aardal, Aranha, Boudgoust, Kolby, Takahashi. "Aggregating Falcon
   Signatures with LaBRADOR." CRYPTO 2024; ePrint 2024/311 — READ
   (soundness machinery in full) this session, same route.
   Load-bearing: Def 3.1, Lemma 2.2 (+ jl.py constants), Thms 4.1/
   4.2/I.1/G.1 (existence), Eq. (18), Appendix I.5/I.6.
3. Nguyen, Seiler. "Greyhound: Fast Polynomial Commitments from
   Lattices." CRYPTO 2024; ePrint 2024/1293 — soundness sections
   read this session, same route. Load-bearing: Lemma 3.2, Thm 4.1.
4. House: SOUNDNESS_REFERENCE.md (L1/L2, 2.2), Q4_LEMMAS.md (Q4.1,
   Q4.4a-c — the style template and the house precedent for
   JL-composition honesty), AGGREGATION_PARAMS_DESIGN.md (DA),
   AGGREGATION_CLAIM_REDUCTION.md (DB), AGGREGATION_LITERATURE.md
   (Sections 1, 9), params.rs / mod.rs (constants, verified
   2026-07-27).
5. [GHL21] Gentry, Halevi, Lyubashevsky — cited THROUGH [LaB]
   (their Corollaries 3.2/3.3 as restated in [LaB] Lemmas 4.1/4.2);
   not independently retrieved this session [S10-style flag].
6. [NS22] Nguyen, Seiler (CRYPTO 2022 amortization) — cited THROUGH
   [LaB] App. B and [PSS] I.6; not independently retrieved.

---

*Changelog: 2026-07-27 — first edition (U-AG3 Agent EB lane). Written
against DA's published parameter chain at 5d6c6f1; primary sources
retrieved and read in-session (Wayback route); spike landed in the
same tranche. The three-readings question of PARAMS 3.4 is settled
PER-LEVEL with named conditions; four new quantitative findings along
the way: the ct-aggregation term missing from all house accounting
(Section 3.2, R-EB3 fix); the uncapped-challenge-set gap in the
extraction constants, with the MC measurement showing the house conc
value 20.8 sits below the true op-norm median (Section 1.3, R-EB1
fix); the binding-vacuous deep bases in DA's floor schedules
(Section 2.4(a), R-EB4 fix); and the branch-preference inversion —
at the corrected constants the exact-digit configuration beats
512-row JL on bytes as well as on [MODEL]-flag count (Sections
2.4(b), 5.1).*

*2026-08-08 (U-AG-B1 Agent BA) — Section 7 appended: the Section 5.4
freeze-row export is DISCHARGED as a both-direction battery
(scripts/aggregation_freeze_rows.py, run by
tests/test_aggregation_freeze.py under the suite) plus the dated table
below. No text above this changelog was edited; the four BA-F*
transcription findings against Sections 1.3/1.4/2.4 are recorded in
7.3 with the working values pinned.*

## 7. U-AG-B1 freeze-row table (dated addition, 2026-08-08, BA lane)

### 7.1 Where the freeze lives, and what "both directions" means here

The R-EB1..R-EB4 design rules of Section 5.4 (plus kappa = 11 and the
C-win window constants) are FROZEN as of the U-AG-B1 open. The
enforcement point is `scripts/aggregation_freeze_rows.py` (85 rows,
run under the suite by `tests/test_aggregation_freeze.py`): every
pinned constant is RE-DERIVED there from the recorded
formula/derivation transcribed out of this document, DA's tables, and
the two spikes, and asserted equal to its pin — the LKP-7/8/9 pattern
in script form. The derivation chain moving fails the row; an edited
pin fails the row. [MODEL] rows (the Monte-Carlo acceptance table)
pin the recorded measurements and re-assert the spike's own
consistency bands instead of a derivation.

Engine note (export to lane BB): the Rust aggregate layer does not
exist yet. When BB lands it, T_cap, kappa, the R-EB4 base filter, and
the per-level C-win checks MUST also gain derive-time asserts and
`freeze-check` rows in the engine (the LKP precedent — pinned both
directions at derive time, per level, on the actual schedule). Until
then the Python battery above is the single enforcement point, and
the PER-LEVEL instantiation of C-win/R-EB4 remains schedule-side
(spike-checked) rather than engine-side.

### 7.2 The table

| row id | constant | frozen value | both-direction gate (the re-derivation) | source |
|---|---|---|---|---|
| EB1-tcap | T_cap — operator-norm cap on fold AND batching challenge sampling (resample-until-under, deterministic FS counter/salt) | **33** | 20.8 = 1.3·sqrt(2D) < 33 < 256 = 2D; cost of no cap log2(256/33) = 2.96 b (AFS-L6's recovered bits) | 1.3 (C-cap), 5.4; FS F-C2 |
| EB1-diffcap | challenge-DIFFERENCE cap used in extraction bounds | 66 | = 2·T_cap (a difference is a sum of two capped draws) | FS AFS-L6 |
| EB1-mc | [MODEL] MC acceptance at cap 33 / 36 / 42; op-norm p50/p99 | 38.43% / 66.77% / 94.34%; 34.2 / 46.8 | measurement (20k draws, seed 7) — bands re-asserted: 5% <= acc(33) <= 50%, acc(42) >= 90%, ~3 attempts at 33, conc 20.8 < p50 | spike sec 2; 1.3 |
| EB2-rule | [NS22]-style garbage-count optimization at recursed levels under FS | **FORBIDDEN** | rule row ((T_op)^r slack, [PSS] I.6); byte model must keep the FULL garbage count | 2.2 item 2, 5.4 |
| EB2-count | per-level garbage ring count before decomposition | r(r+1) | r(r+1)/2 per family (g, h) x 2 families; = the DA 3.2 recurrence coefficient | DA 3.2 |
| EB3-tmin | ct-aggregation repetitions (t-up option) | **t >= 7** | ceil((128 + log2(2(Q+1)) + log2 L)/31) at Q = 2^64, L <= 8; t = 5 (the [LaB] transfer) FAILS post-FS (2^-90 headline / 2^-86.5 spike sum), t = 7 lands 2^-149 | 3.2 |
| EB3-kdraw | K-draw error-class exponent | 496 | 16·31 (full-entropy R_q per-slot mass q^-16) | 3.2; SR 1.3 |
| EB3-wire | wire lines | t-up +2,584 B/level; K-draw 1,036 B/level | 7·516 − 1,028; 4 + 2·516 (kappa-11 adopted line; the 3.2 band "516-1,032" is the object cost sans the 4 B length prefix) | 3.2; FD F-IF1.7 |
| EB3-adopted | adopted direction | **K-draw** | rule row; restructure plumbing owed to lane BB | FD S1; 5.4 |
| EB4-line | inner-binding validity line | **2^30.5** | < q31; equals kappa-11's C3 coverage 2·sqrt(11·128·31·0.005326) = 2^30.49 (consistency gate) | 2.4(a); DA S1 |
| EB4-emax | floor digit-base cap | **e_i <= 7** | 8·T_cap·(1+2^e)·sigma·beta_i(e) <= 2^30.5 with beta_i(e) = 1.3·sqrt(n·D·(2/3)·4^(e−1)) at the recorded floor sizes 620-770 rings: e = 7 passes, e = 8 fails, BOTH sigma branches; digit magnitude 2^6 = 64 stays inside the [LF+] monomial window | 2.4(a); FS AFS-L5/L6 |
| EB4-btmax | max realized beta_top (R-EB4-capped schedules) | 2^29.93 (exact-digit) / 2^30.40 (JL) | 8·T_cap·(1+2^7)·sigma·beta' at the recorded worst levels (2^20 L3 / 2^20 L7); both <= 2^30.5 | spike 3b [BA-F2] |
| KAP-11 | commitment row count kappa | **11** | C3 line: beta 2^30.40 -> k_Z 1400 -> kappa 11; kappa-10 coverage 2^29.07 falls short of both branch maxima; core-SVP >= 128 bits at both | 2.4(b), 5.1 |
| CWIN-256/512 | C-win window lines | q/125 = 2^24.03 (256-row); q/168 = 2^23.61 (512-row) | derived from q31 and the pinned C1 constants (125 the tighter [LaB] value, 168 [PSS] lambda-256); recorded witness class <= 2^17.8 keeps >= +6.2 / +5.8 b margin | 1.4 [BA-F3] |
| CWIN-jlerr | JL soundness error exponents | 2^-128 / 2^-256 | the corrected constants (DA's modeled 2^-141 / ~2^-282 superseded) | 3.2 |

Scope note: the exact-digit branch is the triple-mandated
configuration; the JL-branch rows (CWIN-*, the JL beta_top max) are
frozen as the RECORDED ALTERNATIVE so a future branch flip cannot
silently re-derive them looser.

### 7.3 Transcription findings recorded at freeze time (doc text unedited)

Hostile-read findings from the U-AG-B1 BA transcription of this
document against its own spike — the EB honesty precedent applied to
EB. None changes a verdict; each is pinned at the WORKING value:

- **BA-F1 (Section 1.4 formula string).** The sigma formula is
  printed as "sqrt(2·lambda/C2) ... sigma = sqrt(256/30) at 256 rows
  = sqrt(512/60)" — which evaluates to 2.92, contradicting the
  section's own printed value 2.07. The working constant everywhere
  (DA 3.4's base 121.7 = 2·2.066·29.4, the spike's S_JL, SC-L4's
  C-msis arithmetic) is **sigma = sqrt(lambda/C2) = sqrt(128/30) =
  sqrt(256/60) = 2.0656** — the published Greyhound/LaBRADOR JL slack
  shape (verifier line sqrt(lambda)·beta against the sqrt(C2)·b lower
  bound). The formula string carries a spurious factor 2 under the
  root (rows = 2·lambda conflated with lambda). Pinned: 2.07 (2dp).
- **BA-F2 (Section 2.4(a)/(b) beta_top prints).** The text quotes
  DA's uncapped floor bases landing at "2^31.8-2^34.1 > q" and the
  corrected JL-branch maximum as "2^30.14"; the spike prints
  2^31.9-2^34.5 (max 2^34.52) and **2^30.39-2^30.40** respectively.
  Verdicts unchanged (uncapped still > q; corrected still <= 2^30.5;
  kappa 11 still covers, at 0.09 b rather than 0.36 b of C3-coverage
  margin). Pinned: the spike values (29.93 / 30.40).
- **BA-F3 (Section 1.4 window print).** "q/C1 = 2^24.06 (lambda =
  128)" matches neither C1 = 120 (2^24.09) nor the spike's tighter
  C1 = 125 (2^24.03). Margins unaffected (>= +6.2 b either way).
  Pinned: 2^24.03 at C1 = 125 per the spike. The 512-row line
  2^23.60 is 2^23.61 at 2dp.
- **BA-F4 (Section 0.2 constant print).** "op_norm(conc) =
  1.3·sqrt(2D) = 20.79" — exact value 20.80 (DA S1 prints 20.8; the
  folding docs inherit "20.79"). Pinned: 20.8.

One cross-document labeling slip recorded for the orchestrator (not
this document's text): LLM_POC_ROADMAP.md Section 3's BA paragraph
glosses R-EB2 as "(K-draw restructure)" and folds the floor-base
correction into "R-EB3/R-EB4" — per Section 5.4 here, R-EB2 is the
NS22 prohibition and R-EB3 is the K-draw/t-up rule. The lane briefs
carried the correct reading; the roadmap gloss should be fixed at
FINAL (roadmap is orchestrator-owned).
