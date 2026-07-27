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
is NOT engaged** — with three honest corrections to DA's constants
(Sections 2.4, 3.2) that cost roughly kappa 10 -> 11 and single-digit
KiB, not the architecture.

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
concentration value 29.4 in its place — sound for honest sizing,
NOT for extraction bounds. **Design rule R-EB1 (exported): the
aggregate layer's fold-challenge sampling (and batching-challenge
sampling, Section 4) MUST enforce an operator-norm cap T_cap by
resampling, with T_cap and its honest resampling rate frozen as
derive-time constants.** The spike's Monte-Carlo section measures
the operator-norm distribution of quinary challenges at D = 128
(singular values via evaluation at the odd 256th roots of unity):
T_cap ~ 24-26 rejects only a percent-level fraction and T_cap = 28
essentially nothing [MODEL — MC at 10^4 draws; exact percentiles
printed by the spike]. All Section 2.4 tables are given as functions
of T_cap ∈ {21, 25, 28, 42}. Without R-EB1 the honest worst-case
T = 256 costs ~3.3 bits over T_cap = 25 in beta_top — the
architecture survives even that (Section 2.4 table), so R-EB1 is an
efficiency rule, not a viability condition.

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

House arithmetic at q31 (spike-checked, Section 2.4 table): DA's
level bounds run beta_i ~ 2^20.9-2^21.7, so sigma·beta_i ~
2^21.9-2^22.8 against q/C1 = 2^24.09 (lambda = 128) / 2^23.60
(lambda = 256): **margin 1.3-2.2 bits (256-row) / 0.8-1.7 bits
(512-row) at every level of every DA schedule — C-win HOLDS.**
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

**[OBLIGATION — plumbing, DA 6.4 item 4]:** committing each level's
witness bit-decomposed and running the CR-L6 instances per level is
new protocol plumbing: the bit-width blowup of the committed level
witnesses (x e_i per level), the per-level zero-check transcripts,
and their mask budget (EC's lane) are build-round work, priced by DA
(Section 5.2 exact-digit rows) at the byte level only.

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

Two honest corrections to DA's Section 3.4 numbers fall out of the
transcription. Neither changes the verdict; both change margins and
one changes kappa. (All numbers spike-printed; representative values
here.)

**(a) The per-level slack constant is bigger than 121.7.** DA's
per-level row priced base = 2 (fork) · 2.07 (JL) · 29.4 (dc-conc) =
121.7 = 2^6.93 applied to gamma_z. The [LaB]-form inner-binding
bound instantiated at house constants is

    beta_top = 8 · T_cap · (1 + b) · sigma · beta',

and since beta' ~ sqrt(2)·gamma/b (the z-decomposition parts
dominate), (1+b)·beta' ~ sqrt(2)·(1+1/b)·gamma, so

    beta_top ~ 8 · T_cap · sqrt(2)·(1+1/b) · 2.07 · gamma
             ~ (2^8.9 to 2^9.6) · gamma   at T_cap = 25-28,

vs DA's 2^6.93·gamma — i.e. **the honest constant costs ~2.0-2.7
bits over the modeled one** (and would cost 3.3 more at the uncapped
worst T = 256 — R-EB1's price of admission). Mechanically: DA's
29.4 was a concentration value where an adversarial worst-case cap
belongs, and the (1+b) recomposition and the 8T cross-clearing were
not in the model.

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

At q31 with DA's schedules: C-win holds with 0.8-2.2 bits of margin
(Section 1.4); the top-instance MSIS at the corrected constant
beta_top ~ 2^30.1 gives ~110-115 [core-SVP] bits at kappa = 10 —
BELOW the line — and recovers to ~133 bits at **kappa = 11**
(k_Z = 1408). Byte cost of kappa 10 -> 11: +516 B per outer
identity and per level message, plus the t-hat term growth in every
level's witness — the spike re-runs DA's schedule machinery at
kappa = 11 end-to-end: **2^20 layer stays PASS (~0.98-0.99x
budget); FFN moves ~1.06x -> ~1.08-1.09x-class** [MODEL, spike
tables] — inside the O-2/EA lever discussion, not a new wall. The
"0.16 bits to spare" thinness DA reported at FFN was an artifact of
measuring the optimistic constant against the over-strict q/8 line;
the honest picture is: hard margins of ~1-2 bits (window), soft
margins bought with kappa (MSIS), no cliff.

**(c) What survives of DA's three-readings table.** The per-level
ROW's structure survives (fresh MSIS per level, cross-level
consistency by committed-value equality — confirmed as [LaB]'s own
architecture); its CONSTANT is corrected by (a)+(b). The exact-digit
row survives with sigma = 1 and no window (SC-L3) — its constant
corrects the same way (8·T_cap·(1+b)·beta' with sigma = 1, ~1 bit
below the JL row). The compounded row survives as the correct
arithmetic for the three protocols of Section 2.2, none of them
ours.

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
