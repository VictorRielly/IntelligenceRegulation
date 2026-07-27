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
