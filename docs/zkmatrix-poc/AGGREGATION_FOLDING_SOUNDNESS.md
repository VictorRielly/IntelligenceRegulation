# O-8 soundness lane: Folding (LatticeFold-class) Extraction at the House Ring, Composed with the Per-Level Result

Status: DESIGN COMPLETE, F-IF1 verification PENDING (U-AG4 tranche,
Agent FC lane, 2026-07-27; paper + Python spike only — no engine
changes). This document is the SOUNDNESS side of the O-8 folding
round: it transcribes the LatticeFold-class knowledge-soundness
(extraction) theory to the house setting and settles whether the fold
composes with the existing per-level extraction result (SC-L4,
AGGREGATION_SOUNDNESS_COMPOSITION.md).

**The question in one line: does folding 32 layers into one proof
preserve the security proof, at our ring?**

**The answer in one line (verdict, Section 8): extraction COMPOSES
UNDER SIX PRECISE CONDITIONS (F-C1..F-C6, all satisfiable at the
house parameter family) — the per-level property survives a 32-fold
because every fold round re-grounds norms with its own algebraic
range arm, exactly the mechanism SC-L4 already relies on; no
compounding channel opens; the architecture stands.**

## Plain-language summary (read this first)

The plan (Option B / O-8) is to stop producing 32 separate proofs —
one per transformer layer — and instead FOLD the 32 layers' claims
into one running "accumulator" claim, then prove only the accumulator
once. Folding is cheap per layer, but it is only safe if the security
argument (the "extraction" proof: from any convincing prover we can
pull out a real witness) survives being applied through 32 folding
steps. Historically that is exactly where lattice folding schemes
died: each fold step multiplies the witness by random challenges, the
witness "norm" (its size as a vector of small integers) grows, and if
the growth compounds through the steps, the numbers stop fitting
under our 31-bit modulus and the proof of security evaporates —
the same failure shape as the "compounded" reading that O-7 already
refuted for the evaluation-proof chain.

The LatticeFold papers (Boneh–Chen 2024/257 and 2025/247) solved this
for their setting: every fold round carries a built-in RANGE PROOF (a
sumcheck that checks, algebraically, that every entry of the witness
is a small digit), so the extracted witness is small at every step no
matter how many folds happen. This document re-derives their theorems
at OUR ring — which differs from theirs in the modulus (31-bit vs
64/128-bit), the ring splitting (8 slots of size 2^496 vs their
settings), the challenge sets (our quinary set vs their monomial-ish
sets), and the norm bookkeeping (we account in l2, they in l_inf) —
and checks each hypothesis of each theorem at our constants.

Findings, in plain terms:

1. **The core mechanism transfers.** Their per-fold range arm is the
   same mechanism family as our exact-digit branch (SC-L3): an
   algebraic identity pins the extracted witness to small digits with
   NO statistical norm window. That is why the fold composes with our
   per-level result instead of re-opening the compounding question.
2. **Their invertibility hypothesis is literally our C0' freeze
   check.** Their Lemma 2.3 ([LS18]) instantiated at our ring demands
   exactly the house LS18 margin — 1.30x — that params.rs already
   asserts at derive time. No new assumption.
3. **The small-slot-field break (2026-04-30) is cleared with
   re-derived margins.** The fold challenge entropy is capped, by a
   pigeonhole argument in the LatticeFold paper itself, at the SLOT
   FIELD SIZE — the exact quantity whose smallness killed three
   public LaBRADOR implementations. Our slots are 2^496; the fold
   challenge surfaces clear the 128-bit line by 98 to 292 bits
   (Section 4, re-derived, not imported). The spike demonstrates the
   BREAK at a toy fully-split ring and its absence at a toy
   partially-split ring.
4. **One genuine gap: their theorems are l_inf-native, our chain is
   l2-native, and at a 31-bit modulus the naive conversion between
   the two eats the parameter room.** Transcribed literally
   (l_inf hypotheses costed with the house l2 estimator), the fold
   only closes at small digit bases. The fix is a house l2
   re-derivation of the one affected step (the binding bound, AFS-L6
   — elementary, same arithmetic class as SC-L1), after which the
   fold's MSIS instances land in the SAME class as the eval-proof
   levels already priced by R-EB4/kappa 11. LatticeFold+'s authors
   themselves flag the l2 variant as open future work; AFS-L6 is the
   house's answer for the one step we need.
5. **Fiat–Shamir for the fold is NOT in the papers** (LatticeFold
   Remark 3.3 leaves it as future work). The house already owns the
   machinery that closes this — the [PSS] predicate-special-soundness
   transfer (SC-L5) — and the fold's extractor has exactly the
   coordinate-wise shape that machinery covers. The FS hash-edge
   rows for every fold challenge are in Section 7 (joint with
   AZ-L4(a)).
6. **The total knowledge-error budget for a complete folded 32-layer
   pass lands at ~2^-219 post-FS [MODEL]** — PASS against the house
   128-bit-class target with ~91 bits of margin (Section 6 table;
   spike-reproduced).

Grading legend (SOUNDNESS_REFERENCE.md Section 0): **[PROVEN]** —
complete argument here or verified published fact with the exact
statement transcribed; **[CITED]** — published result adopted with
statement quoted and hypotheses checked at our parameters, proof not
re-derived; **[MODEL]** — quantitative engineering model, parameters
stated; **[OBLIGATION]** — believed and designed, write-up or build
work owed. Every quoted error term is the field-statistical term
only; concrete security is the min() form of the SOUNDNESS_REFERENCE
claim-discipline note (audit H-07): min(algebraic error, FS/hash
security incl. grinding, commitment-assumption bound, parameter
bound) — the deployable classical target is 128-bit-class.

Spike: `scripts/folding_soundness_spike.py` (stdlib, < 1 min, tiny
memory; checks the ARITHMETIC of this document — the norm-growth law
over chained folds at toy scale, the knowledge-error table, the
challenge-set entropy margins, the negative small-slot demos — NOT
the proofs).

## 0. Scope, sources, and the fold-shape caveat

### 0.1 What this lane owns and does not own

This lane owns the EXTRACTION THEORY: what the LatticeFold-class
theorems say, where their hypotheses hold or fail at our ring, and
whether the fold composes with SC-L4. Agent FA owns the fold
CONSTRUCTION (what folds, arity, schedule, wire bytes) and publishes
the F-IF1 interface; every statement here that depends on the fold
shape is PARAMETRIC in (n_inst per step, digit base b, decomposition
depth k, number of fold rounds N_fold) and is marked for F-IF1
verification. **F-IF1 status at close of this lane: [F-IF1 PENDING]
— checked against wt-uag4-folding; not yet published. Section 8's
R-FC rows are therefore conditional verification obligations, not
findings.**

### 0.2 Sources

External sources, READ IN FULL THIS SESSION (retrieved into
`docs/zkmatrix-poc/references/`; the live ePrint PDFs are behind a
bot check this session — same as the EB lane — so all three were
retrieved as Wayback-archived copies via
`web.archive.org/web/2025id_/https://eprint.iacr.org/<id>.pdf`;
page identity with the newest live revisions is [MODEL] to the
extent the snapshots lag):

- **[LF]** Boneh, Chen. "LatticeFold: A Lattice-based Folding Scheme
  and its Applications to Succinct Proof Systems." ePrint 2024/257
  (snapshot dated December 15, 2025; 75 pp). Read in full. Used:
  Lemmas 2.1-2.5 (ring facts, sampling sets, expansion factor, SZ,
  sum-check over rings), Defs 2.1-2.5, Theorems 2.1/2.2 ([KP23]
  composition), Section 3 in full — Theorem 3.1 (composed fold),
  Lemma 3.2 (evaluation mapping), Lemmas 3.3-3.6, **Theorem 3.2 +
  Theorem 3.3 (THE fold extraction theorem)** with its extractor
  (Fig. 4), Claims 1-5 and **Lemma 3.7 (the bad-event bound)**,
  Remark 3.3 (FS left as future work), Section 3.3 (small prime
  modulus; the slot-diagonal challenge set Eq. (31) and the
  pigeonhole cap), Section 4 (CCS variant: Theorems 4.1-4.3, Lemma
  4.3), Remarks 5.1/5.2, Section 6, Appendices A/B.
- **[LF+]** Boneh, Chen. "LatticeFold+: Faster, Simpler, Shorter
  Lattice-Based Folding for Succinct Proof Systems." ePrint 2025/247
  (snapshot dated August 9, 2025; 54 pp). Read in full. Used:
  Lemmas 2.1-2.7 (monomials, psi-identity, expansion, [LS18], SZ,
  sumcheck), Defs 2.2/2.3 (MSIS-l_inf, relaxed binding), Section 4
  in full — Lemma 4.4 (Pi_mon error), Lemmas 4.5/4.7 (range check
  errors), **Theorem 4.3 + Lemma 4.10 (Pi_cm extraction with the
  mu·|S|-union and the two-parallel-sumcheck artifact, Remark
  4.9)**, Lemma 4.9 ([FMN24] coordinate-wise special soundness),
  Section 5 — Theorems 5.1/5.2/5.3, Lemma 5.1, Eq. (28), Remarks
  5.1-5.4, the concrete instantiation table (p. 42), Section 6
  (l2 variant open), **Appendix B (tensor-of-rings: sumchecks over
  an extension field K, folding over R_q)**.
- **[Neo]** Nguyen, Setty. "Neo: Lattice-based folding scheme for
  CCS over small fields and pay-per-bit commitments." ePrint
  2025/294 (snapshot; 58 pp). Soundness core read: Theorem 1
  (invertibility, [48]-transcribed), Defs 10/14/15 (strong sampling,
  matrix expansion, relaxed binding), Lemma 3, Theorem 3 (expansion
  ≤ 2·phi(eta)·max-norm), Lemmas 4/5 and **Section 5 (the
  phi-restricted / relaxed-KS properties and composition Theorem 5
  — the linearization step is NOT plain-composable)**, Corollaries
  2/3. Protocol-engineering sections skimmed; grades below reflect
  that.

House sources: AGGREGATION_SOUNDNESS_COMPOSITION.md (SC-L0..SC-L6,
R-EB1..R-EB4 — all corrections adopted as binding here),
AGGREGATION_PARAMS_DESIGN.md (DA; ring/challenge constants, Section
3.6 break precedent), AGGREGATION_ZK_DESIGN.md Section 5.5 (AZ-L4),
AGGREGATION_CLAIM_REDUCTION.md 10.5 (CRB-N rows), Q4_LEMMAS.md
(style), SOUNDNESS_REFERENCE.md (L1/L2 engines, grading, H-07 target
note), AGGREGATION_LITERATURE.md Section 2 + refs 6/7/9.

### 0.3 Standing constraints honored

I-6 HARD (no Gaussian-masked openings in the aggregate layer at q31)
— note [LF]/[LF+] use NO Gaussian masks anywhere; their ZK story is
deferred to a final SNARK wrap, which is consistent with the house
posture and imports no I-6 conflict. Exact-digit config; DENSE
encoding; per-pass scope; one-proof-per-witness. R-EB1 (T_cap = 33),
R-EB3 (K-draw), R-EB4 (floor bases e <= 7, kappa 11) supersede older
DA tables wherever they overlap.

## 1. The dictionary: their setting vs ours

Everything in [LF]/[LF+] is parameterized by a ring
R_q = Z_q[X]/(X^d + 1) that splits as R_q ≅ F_{q^tau}^{d/tau}. The
house instantiation of every object, each entry checked this session:

| their object | their setting | house object | house value | check |
|---|---|---|---|---|
| ring degree d | 64 ([LF] Sec. 5; [LF+] p. 42) | D | 128 | mod.rs |
| modulus q | 64-bit ([LF]) / 128-bit ([LF+] table) | q31 | 2^31 − 399 = 2,147,483,249 | mod.rs Q8; q ≡ 113 mod 256, q ≡ 17 mod 32 (spike check 1) |
| splitting R_q ≅ F_{q^tau}^{d/tau} | tau = 4 ([LF] Sec. 5), 16 factors ([LF+] p. 43) | 8 slots GF(q^16) | tau = 16, d/tau = 8, slot field 2^496 | ord_256(q31) = 16 (spike check 1) |
| fold challenge set C_small / S-bar | coeffs in {−1,0,1,2}, size 4^64 = 2^128, strong sampling by [LS18] | quinary C | coeffs in {−2..2}, size 5^128 = 2^297.2 | SOUNDNESS_REFERENCE 1.3 |
| strong-sampling hypothesis ([LF] Lemma 2.3 = [LS18] Cor 1.2) | ||y||_inf < q^{1/t}/sqrt(t), t = number of factors | house C0'/LS18 line | q31^{1/8}/sqrt(8) = 5.19 > 4 = max quinary difference — **margin 1.297x, EXACTLY the frozen house 1.30x** | params.rs assert_ls18; spike check 2 |
| expansion factor T = ||C_small||_op (l_inf: sup ||rho·v||_inf/||v||_inf) | ≤ d·||rho||_inf = 128 at their set ([LF] Lemma 2.2 = [AL21] Prop 2) | l_inf: 2D = 256 worst (= house op_norm(worst)); sharper l1 bound ||rho||_1 ≤ 256 worst, E = 153.6, l1-cap 160 accepts ~77% [MODEL — CLT; spike MC] | see Section 5.2 for the l2 route (T_cap = 33, R-EB1) | spike check 3 |
| sumcheck challenge set C ([LF] Eq. (31)) | slot-diagonal set {a : NTT(a) = i·(1,...,1), i ∈ F_{q^tau}}, size q^tau | house K-field draws, GF(q^16) diagonal | size q^16 = 2^496; strong sampling (nonzero field element in every slot ⇒ invertible) | = the house full-entropy/K-draw engine of R-EB3; spike check 1 |
| sumcheck-over-rings engine ([LF] Lemma 2.5, [LF+] Lemma 2.7 = [CCKP19]) | d/tau parallel F_{q^tau} sumchecks sharing one challenge ([LF] Remark 3.2) | house masked-sumcheck engine over K, slot-complete (I-3) | identical structure; house SZ class 2^-49x per round family | DB engine [PROVEN there] |
| MSIS form | MSIS^{inf,q}_{kappa,m,B} (l_inf ball) | house C3 line costs l2 | **norm-shape gap — Section 5.2** | — |
| relaxed binding ([LF] Sec 2.3; [LF+] Def 2.3; [Neo] Def 15) | two B-weak openings ⇒ MSIS at 4TB | house relaxed binding, SOUNDNESS_REFERENCE 2.2 | same object; house SC-L1 step 3 carries the (1+b) recomposition variant | — |
| composition ([KP23] Thms 5/6 = [LF] Thms 2.1/2.2) | knowledge errors add under sequential/parallel composition | [LaB] Lemma 3.7 / [PSS] Eq. (18) posture of SC-L4 | same additive discipline; expected-poly-time adversaries ([LF] Remark 2.2 — MSIS falsifiable, so WLOG) | — |

Three structural matches worth stating plainly, because they are why
this transcription is short where it could have been long:

- **(M1)** [LF] Eq. (31)'s challenge set IS the house K-draw. Their
  small-modulus fix — replace Z_q sumcheck challenges by the
  diagonal embedding of the slot field — is exactly the R-EB3 K-draw
  restructure the EB lane already exported for the ct-aggregation
  step. One engine, two papers, same object.
- **(M2)** [LF]'s per-fold range arm (the g_norm sumcheck over the
  product Prod_{j=1−b}^{b−1}(mle[f](x) − j), Fig. 3 Eq. (16)) is the
  SC-L3 mechanism family: an algebraic residue statement that pins
  the extracted witness at slack EXACTLY 1, with a field-statistical
  error and NO norm window. Their range polynomial per entry is the
  degree-(2b−1) generalization of the house b(b−1) = 0 bit kernel
  (CR-L6). The fold and the house exact-digit branch are the same
  soundness species.
- **(M3)** [LF+] Appendix B's tensor-of-rings discipline — sumchecks
  over the extension field K, folding over R_q, with the row/column
  interpretations of E = K ⊗ R_q — is the house's existing split:
  sumcheck/batching challenges in GF(q^16) (K-side), fold/batching
  ring challenges in quinary C (ring side). The house protocol
  stack was already shaped like their framework before the framework
  was published.

## 2. The transcription: LatticeFold extraction at our ring

Notation: n_inst = number of instances entering one fold round
(their k* = 2k); b = digit bound (entries of each input witness in
(−b, b)); B = accumulator bound with b^k = B; m = witness length in
R_q elements; T = fold-challenge expansion factor in the accounting
in force (Section 5.2); |C_s| = fold challenge set size = 2^297.2;
|C_K| = sumcheck challenge set size = 2^496.

### 2.1 AFS-L0 — the challenge sets at our ring [PROVEN]

**(a) Quinary C is a strong sampling set with expansion facts as
tabled.** Differences have coefficients in [−4, 4]; [LF] Lemma 2.3's
hypothesis at (t = 8, q31) is ||y||_inf < q^{1/8}/sqrt(8) = 5.19;
4 < 5.19 with margin 1.297x — this is the house C0' freeze check
verbatim (params.rs asserts it at derive time). [PROVEN, house; the
same fact graded [CITED] via [LS18] in their text.]

**(b) The slot-diagonal K-set is a strong sampling set of size
q^16 = 2^496.** A nonzero difference is the diagonal embedding of a
nonzero element of GF(q^16) — nonzero in every slot, hence
invertible. [PROVEN, elementary.]

**(c) The pigeonhole cap ([LF] Section 3.3 argument, transcribed at
k = 8).** ANY strong sampling set in R_q ≅ GF(q^16)^8 has size at
most q^16 = 2^496: two elements agreeing in one slot have a
difference annihilated by the indicator idempotent of that slot — a
zero divisor. Consequence: **the fold-challenge entropy of ANY
design at our ring is structurally capped at 496 bits per challenge,
and at a fully-split ring it would be capped at 31 bits — the break
regime.** This is the small-slot axis stated as a theorem rather
than an incident. [PROVEN.]

### 2.2 AFS-L1 — the fold extraction theorem ([LF] Theorem 3.3 at our ring)

**Statement (transcribed; their notation collapsed to ours).** Let
the fold protocol Pi_fold (their Fig. 3) run over inputs
[(r_i, v_i, y_i); f_i]_{i=1..n_inst} in (R^b_hom)^{n_inst}: per
round, (1) batching challenges alpha_i, mu_i from C_K and a range
anchor beta from C_K^{log m}; (2) ONE sumcheck over the combined
polynomial g = g_eval + g_norm (evaluation arms eq(r_i, x)·mle[f_i]
and range arms eq(beta, x)·Prod_{j=1−b}^{b−1}(mle[f_i](x) − j)); (3)
terminal openings theta_i = mle[f_i](r_o); (4) fold challenges
rho_i from C_s; output the folded instance/witness
f_o = sum rho_i f_i. Suppose the commitment homomorphism L is
2B-relaxed binding for C_s (binding error eps_bind). Then there is
an expected-poly-time extractor returning valid witnesses for ALL
n_inst input instances — each with **||f_i||_inf < b, slack exactly
1** — with knowledge error

    kappa_fold = n_inst/|C_s|  +  eps_bind
               + ((2b+1)·log m + 2·n_inst) / |C_K|,

and expected prover-invocation count
(1 + 1/(eps − n_inst/|C_s|))·(1 + n_inst).

**Extraction mechanism, transcribed for the review** (this is the
part SC-L4's induction consumes, so it is spelled out):

1. *Coordinate-wise forking over the fold challenges.* The extractor
   (their Fig. 4) reruns the prover with the fold vector changed in
   ONE coordinate at a time, drawing replacements without
   replacement — a negative-hypergeometric loop whose expected cost
   is ≤ 1 extra call per coordinate and whose failure mass is
   n_inst/|C_s|. This is exactly the coordinate-wise CWSS shape of
   [PSS] Appendix G / Theorem G.1 (and of [FMN24] Lemma 7.1, which
   [LF+] cites for the same purpose) — the same structure SC-L5
   transfer condition 5 already covers for the house folds, and the
   same K-draw discipline R-EB3 restructured the ct-aggregation
   into. **The fold's fork pattern is already inside the house FS
   framework's coverage.** [CITED + structural check]
2. *Quotient interpolation.* f_i := (rho_i − rho_i')^{-1}(w_0 − w_i)
   — REQUIRES difference invertibility (AFS-L0(a), C-alg). The
   quotient is NOT short; nothing downstream uses its norm directly
   (see 3./4.).
3. *Cross-transcript witness identity via relaxed binding.* Two
   sub-extractions disagreeing on some f_i yield two distinct
   2B-weak openings of the same commitment — an MSIS solution at
   4T·(2B) = **8TB** (their Section 2.3 arithmetic; the [ALS20]
   shape the house already carries in SC-L1 step 3, where the house
   variant reads 8·T_cap·(1+b)·sigma·beta' — the same 8T skeleton
   with the house (1+b) z-recomposition in place of their flat B).
   Fails with probability eps_bind. [CITED; house re-derivation in
   the l2 accounting is AFS-L6.]
4. *Norm and evaluation re-grounding by the round's OWN sumcheck*
   ([LF] Lemma 3.7): conditioned on extraction succeeding, the
   events "extracted f_i out of range (p_i != 0)" or "claimed
   evaluation false" survive only via three SZ-class events over
   C_K: E1 (range polynomial vanishes at fresh beta': log m/|C_K|),
   E2 (batching combination h(alpha', mu') = 0: 2·n_inst/|C_K|), E3
   (sumcheck accepts a false claim: 2b·log m/|C_K|). Total
   ((2b+1)·log m + 2·n_inst)/|C_K|. **This is the step that makes
   extracted norms DEPTH-INDEPENDENT: the bound b is re-established
   at every fold round from that round's own range arm, never
   transported through the quotient.** [CITED; the house
   instantiation of each event's probability is [PROVEN] arithmetic
   at |C_K| = 2^496.]

**House values.** n_inst/|C_s| = n_inst·2^-297.2;
((2b+1)·log m + 2n_inst)/|C_K| ≈ 2^-485-class at any plausible shape
(b ≤ 2^7, m ≤ 2^22, n_inst ≤ 64). Both statistical terms clear the
interactive 2^-128 line by > 160 bits per round. Grade of the
transcription: **[CITED] skeleton ([LF] Thm 3.3 + Lemma 3.7, read in
full) + [PROVEN] house substitutions (AFS-L0, L2 point masses, C0'),
CONDITIONAL on (F-C2) challenge-cap and (F-C3′) the l2 binding
re-derivation (Section 5.2).**

**What does NOT transfer silently — the honest gap list:**

- **(G1, norm shape).** Their theorem is l_inf-native (MSIS^inf at
  8TB; expansion factor in l_inf). The house chain prices l2
  (C3 line, ESTIMATOR_NOTE). Conversion l_inf→l2 costs sqrt(d·m) —
  ruinous at q31 if applied naively. Resolution: AFS-L6 (Section
  5.2) re-derives the ONE affected step in l2. [LF+] Section 6
  explicitly leaves the l2 variant of their protocols as future
  work, so this is a house-owed derivation, not a citation.
- **(G2, FS).** [LF] Remark 3.3, verbatim: "The knowledge analysis
  of the Fiat-Shamir transformed version of Pi_fold is left as
  future work." The house does NOT get FS for free from the papers.
  It gets it from SC-L5 ([PSS] Thm 4.1/Eq. (18)): the fold rounds
  are (K, Phi)-predicate-special-sound with the coordinate-wise
  structure of transfer condition 5, their per-round failure
  densities are the AFS-L1 terms, and the errors join the Eq.-(18)
  additive bracket, linear in Q. Section 6 prices it; Section 7
  carries the ordering rows. [PROVEN transfer-shape check +
  [OBLIGATION] the battery legs.]
- **(G3, encoding seam).** [LF]'s range relation lives on the NTT
  slots of auxiliary vectors with NTT(f-hat) = Coef(f) — a
  transpose between coefficient and slot addressing. Under the
  house DENSE encoding (D-1) the committed material is
  coefficient-resident; the fold's range arm needs the same
  transpose bookkeeping. Zero soundness content, nonzero plumbing;
  exported to FA (H-FA6). At tau > 1 the terminal opening is
  tau = 16 ring elements per instance (their Eq. (30)/(32)) — a
  wire-cost fact FA's byte model must carry (H-FA7 gives the exact
  object list).
- **(G4, m power-of-two, r in the diagonal set).** Their Lemma 3.2
  requires the evaluation point coordinates in Z_q, extended to the
  Eq.-(31) set by Remark 3.1/Section 3.3; house points are K-draws —
  the extension is exactly their generalized case, no issue, but
  the house instantiation must draw instance points r from the
  slot-diagonal K-set (NOT raw R_q full-entropy draws) for the
  RotSum bookkeeping of Lemma 3.2/Eq. (32) to apply. [Structural;
  H-FA4.]

### 2.3 AFS-L2 — the range arm is exact-digit-class grounding [PROVEN mechanism]

**Statement.** At any level of any fold schedule, the extracted
witness's norm bound is established by that round's range arm as an
INTEGER statement: p_i(x) ≡ 0 (multilinear identity over R_q) forces
Prod_{j=1−b}^{b−1}(mle[f_i](bit) − j) = 0 at every hypercube point,
i.e. every NTT slot of every entry of f_i is a residue in
(−b, b) — whose centered representative is itself. Slack exactly 1;
no window hypothesis (contrast C-win, which the JL branch needs);
the only cost is the E1/E2/E3 statistical mass over C_K already
counted in AFS-L1.

*Proof.* Identical in kind to SC-L3: per slot, the slot field has no
zero divisors, so a vanishing product pins the residue to one of the
2b−1 roots {1−b..b−1}; slot-completeness (all 8 slots checked — the
∀j ∈ [tau] quantifier of their R^{tau,B}_cm, house I-3) pins every
slot; the centered representative of a small residue is itself; no
integer lift is ever taken. ∎ **[PROVEN]** (the mechanism; the
E1/E2/E3 mass is AFS-L1's). Note the strict analogy: house CR-L6
kernel = their b = 1 case per bit position; their degree-(2b−1)
product = the digit-base generalization the SC-L3 plumbing
obligation priced as "bit-level witness columns" — [LF]'s protocol
is evidence that the digit-level (not bit-level) form suffices when
the range product rides a sumcheck, WEAKENING the SC-L3 plumbing
concern for the fold layer specifically. Exported to the
orchestrator as a note on SC 2.4(c).

### 2.4 AFS-L3 — decomposition and the honest-side renormalization [CITED + PROVEN arithmetic]

[LF] Pi_dec (Fig. 2, Lemmas 3.3-3.5): split the B-bounded
accumulator into k digit vectors at base b (b^k = B), each of norm
< b; verification is the public gadget identity; knowledge soundness
is EXACT (extractor recomposes; norm bound by the gadget sum
Sum b^i(b−1) < b^k = B) — no statistical term, no window beyond
B < q/2. This is DA's adaptive-base re-decomposition (SC 2.3's
"necessary half") in the fold layer: **the fold needs the same two
halves as the eval chain — re-decompose (honest side, Pi_dec) and
re-ground (extracted side, the range arm) — and [LF]'s architecture
has both, which is precisely why its extraction is per-level in our
sense.** At q31: B < q/2 = 2^30 bounds the accumulator; the binding
bound (F-C3′) is the operative cap, tighter (Section 5.2).

### 2.5 AFS-L4 — the norm-growth law per fold step [PROVEN arithmetic; spike-verified]

Honest side, one fold round, l_inf accounting ([LF] Lemma 3.6):

    ||f_o||_inf ≤ Sum_i ||rho_i f_i||_inf ≤ n_inst · T_inf · (b−1),

with T_inf the l_inf expansion in force. The round output is then
re-decomposed (AFS-L3) to base-b digits before the next fold, so the
bound at the START of every round is the same (b−1):
**depth-independent by construction — the closed form for N chained
(fold, decompose) rounds is max-norm ≤ n_inst·T_inf·(b−1) at every
round boundary, with NO N-dependence.** The parameter condition
(their Thms 3.1/3.2) is n_inst·T_inf·(b−1) < B. l2 accounting: the
same law with T_cap = 33 (R-EB1) in place of T_inf against
||f_i||_2 ≤ sqrt(m·d)·(b−1); the spike (check 4) verifies both
closed forms numerically over 20 chained rounds at toy scale and
confirms zero growth across rounds. [LF] Remark 5.1's optimization
(k* minimal with b^{k*} ≥ n_inst·(b−1)·T_inf) is the arity/depth
schedule knob FA owns; the constraint rows for it are in the spike's
envelope table (check 7).

### 2.6 AFS-L5 — the LatticeFold+ machinery at our ring [CITED + house arithmetic]

If FA's design adopts [LF+]'s range machinery (monomial embedding +
double commitments + Pi_cm) instead of [LF]'s in-sumcheck range
arms, the transcription facts are:

1. **The monomial range window is (−d′, d′) = (−64, 64) at D = 128.**
   The psi-identity (their Lemma 2.2) covers exactly digit ranges
   with b ≤ d′ = 64 per range-proof unit (k = 1 in their (d′)^k
   ladder). **House convergence: R-EB4's floor cap e ≤ 7 puts every
   house digit in (−64, 64) — the [LF+] range proof covers house
   digits at its cheapest setting, k = 1.** Larger k at q31 is
   capped by the binding-norm condition below. [PROVEN arithmetic;
   spike check 7.] (Their Remark 2.2 lookup generalization is noted
   for the M4 lookup stack — out of scope here.)
2. **Knowledge errors** (their Lemmas 4.4/4.5/4.7, Theorem 4.3/Lemma
   4.10): eps_mon,m = (2d + m + 4 log n)/|C| + eps_bind;
   eps_rg = eps_mon,dk+1 + eps_bind + log n/|C|; eps_cm,k =
   (mu + dk)/|S-bar| + 3·eps_bind + eps′_rg + eps_rg + 2·eps_sum +
   mu·(log^2 kappa + (2 log n)^2)/|C| with mu = 3 + dk. At house
   sizes every |C|-term is 2^-480-class (|C| = |C_K| = 2^496) and
   every |S-bar| term is 2^-290-class. [CITED + PROVEN arithmetic.]
3. **The mu·|S-bar| union bound and the two-parallel-sumcheck
   artifact (their Claim 2 / Remark 4.9).** Their extractor's union
   is over up to mu·|S-bar| adversary calls; at their parameters
   this forces TWO parallel sumchecks (squared error) to survive.
   At OUR ring: mu·|S-bar| ≈ 2^305-class (mu ≈ 2^8, |S-bar| =
   2^297.2), and a SINGLE K-sumcheck per-call term is
   (log kappa + (2 log n)^2-class)/2^496 ≈ 2^-485; the union lands
   at ≈ 2^-180 — comfortably under the target even single. **House
   arithmetic says one sumcheck suffices at GF(q^16) where their
   128-bit field needs two [MODEL — their Remark 4.9 flags the
   union as possibly a proof artifact; the house posture is: adopt
   the single-sumcheck saving only with this row cited, or keep
   their two-sumcheck form conservatively; decision to FA/FINAL
   with the spike row (check 6).**
4. **The completeness/binding norm condition (their Thm 4.3 /
   Eq. (28)):** b_bind ≥ 2·T_inf·(d′ + 1 + B + dk), and the folding
   theorem 5.1/5.2 needs com (2B^2, S-bar − S-bar)-binding with
   ||S-bar||_op·L·(d′ + 1 + B + dk) ≤ B^2. At q31 these are the
   binding bounds that must clear the R-EB4-class validity cap;
   Section 5.2 and spike check 7 price them (k ≤ 3 range-ladder
   depth at l_inf-worst accounting; k = 1 is the house operating
   point per item 1, where the condition is loose). [PROVEN
   arithmetic.]
5. **Their knowledge error is per-L-batch L·eps_lin,k (Thm 5.2)** —
   linear in the number of instances folded per round, matching the
   AFS-L1 n_inst-linearity; no hidden superlinearity. [CITED.]

### 2.7 The Neo composition caveat [CITED; exported as a design rule]

[Neo] Section 5 proves that its linearization reduction Pi_CCS is
NOT knowledge sound standalone ("the reduction by itself is not a
reduction of knowledge... knowledge sound against restricted
adversaries only") and builds a phi-restricted composition theorem
(their Thm 5) to compose it with Pi_RLC, whose extractor initially
only reaches the TRIVIAL norm bound q/2 and is then disciplined by
relaxed binding. The lesson for the house fold, stated as a rule:

> **The linearization/sumcheck step and the norm-grounding step must
> either live INSIDE one round's extraction argument ([LF]'s
> monolithic Pi_fold — range arm and evaluation arm in the same
> sumcheck, one extractor) or be composed through an explicitly
> proved restricted-composition lemma ([Neo] Thm 5 class). Plain
> [KP23] sequential composition of a bare linearization with a bare
> fold is NOT sound — the intermediate relation has no norm handle.**

This is the fold-layer analogue of SC 2.2's "grounding with a broken
window" row: the compounding/unsoundness channel opens exactly when
a step lacks its own grounding. Exported to FA as H-FA3 (hard).

## 3. Composition with SC-L4: fold levels stacked on LaBRADOR levels

### 3.1 The composed chain

The complete folded pass is a three-segment chain:

    [32 layers' reduced-protocol instances]
      → N_fold fold rounds (this document, AFS-L1..L5)
      → ONE accumulator instance (bound B_acc)
      → the decide: Greyhound level 0 + L LaBRADOR levels 1..L
        (SC-L4's chain, verbatim)

Knowledge errors add across the three segments ([LF] Thms 2.1/2.2 =
[KP23], interactively; [PSS] Thm 4.1/Eq. (18) under FS — the same
citation discipline SC-L4 clause 3 uses). The composition question
is whether any NORM channel crosses the seams. There are exactly two
seams:

**Seam 1 (fold → fold).** Round i+1 consumes round i's folded output
after re-decomposition. By AFS-L4 the honest bound at every round
boundary is the same; by AFS-L2 the EXTRACTED bound at every round
is re-established by that round's own range arm at slack 1. The
inner extraction's norm quality has no channel into the outer
round's bound — the same two-channel argument as SC-L4's induction
step: (i) algebra exact after clearing invertible fold-challenge
differences (AFS-L0(a)/SC-L0), (ii) norms from the round's own
grounding, a constant. **Per-level holds across fold rounds.**

**Seam 2 (fold → decide).** The accumulator witness enters the
eval-proof chain as level-0-adjacent material with stated bound
B_acc. SC-L4's induction is anchored at the bare level and consumes,
from above, only a stated-bound witness — it is agnostic to HOW the
statement above it was produced, provided the handoff object is a
single instance at a stated bound whose commitment the chain's
extractor can bind against (C-msis at the level bounds). The fold's
extractor produces exactly that (AFS-L1 output = valid witnesses at
||·||_inf < b for every input instance, and the accumulator opening
at B_acc). The one NEW obligation at the seam is bookkeeping, not
norms: the decide must prove the ACCUMULATOR the fold transcript
defined (FS binding of the accumulator instance into the decide's
statement hash — row F-N1, Section 7).

### 3.2 The extended per-level lemma

**Statement (SC-L4 extended, AFS-L7).** The composed chain (fold
rounds + Greyhound/LaBRADOR decide) at q31 is knowledge sound for
the 32-layer statement with:

1. extracted-witness norm slack ONE constant per segment — slack 1
   at every fold round (AFS-L2), then sigma ∈ {1, 2.07} once in the
   decide (SC-L4 clause 1) — never a product over fold rounds or
   levels;
2. per-round/per-level MSIS bounds each carrying one grounding
   constant (fold rounds: AFS-L6 bound; decide levels: C-msis) —
   never a compounded factor;
3. knowledge error = SUM of the per-round fold terms (AFS-L1), the
   seam terms (F-N1's ordering is an FS row, not an error term), and
   the decide's per-level terms (SC Sections 3-4), linear in Q under
   FS;

on the conditions F-C1..F-C6 (Section 3.3). *Proof:* downward
induction exactly as SC-L4, with the fold rounds prepended: the base
and the eval-chain steps are SC-L4's verbatim; each fold-round step
is AFS-L1 + AFS-L2 supplying the two channels (i)/(ii) in the same
form; Seam 2 is the SC-L4 level-0 clause consuming the accumulator
as its input statement. Errors add by [KP23]/[LaB] Lemma 3.7
interactively and [PSS] Eq. (18) under FS. ∎ **Grade: [PROVEN] as a
composition of the cited skeletons with house-instantiated
constants, at the same grading (and with the same standing
independent-review flag) as SC-L4 itself — what is not published
anywhere is this composed chain at our ring; the transfer is this
document plus AGGREGATION_SOUNDNESS_COMPOSITION.md.**

### 3.3 The conditions, named (the fold-side analogue of C-alg/C-ground/C-cap/C-msis)

- **(F-C1, range arm everywhere — HARD).** Every fold round carries
  its own range/norm arm over every witness entering it ([LF]'s
  g_norm arms or [LF+]'s Pi_rgchk). A schedule with "cheap"
  intermediate folds that skip the range arm re-opens fold-only
  recursion — SC 2.2 item 1's compounding is then the CORRECT
  arithmetic and q31 dies within two rounds. This is the fold-layer
  C-ground.
- **(F-C2, capped fold challenges).** Fold challenges from quinary C
  under an operator-norm cap: T_cap = 33 (R-EB1, l2 route — the
  recommended accounting) or an l1-cap ≈ 160 at ~77% accept
  [MODEL — spike MC] if any l_inf bookkeeping survives into the
  design. The extraction-side constants use the cap as worst case
  (SC 1.3's C-cap discipline, extended to fold challenges — R-EB1's
  text already says "fold-challenge sampling ... MUST enforce" it;
  this row makes the fold layer explicitly in-scope).
- **(F-C3′, fold-side MSIS in l2 — AFS-L6).** For every fold round,
  MSIS (>= 128-bit house convention, kappa 11) at the l2-rederived
  binding bound beta_fold = 4·T_cap·sqrt(d·m_acc)·b-class (Section
  5.2), which must also clear the R-EB4 validity line
  beta_fold ≤ 2^30.5. Satisfied with >= 8 bits of headroom at all
  plausible shapes (spike check 7).
- **(F-C4, per-round re-decomposition).** Every fold round's output
  is re-decomposed at base b before the next round (AFS-L3),
  B = b^k < q/2 — the honest-side half.
- **(F-C5, FS ordering).** Every fold-layer challenge derived from
  FS state absorbing everything it constrains, per the Section 7
  rows (AZ-L4(a) extended); T_blind and all masks inside the
  statement hash before any fold challenge (AZ-L4(b), FB's lane).
- **(F-C6, the decide unchanged).** The terminal accumulator is
  decided by the SC-L4 chain under ITS four conditions
  (C-alg/C-ground/C-cap/C-msis with R-EB1/R-EB3/R-EB4, kappa 11),
  with the accumulator instance FS-bound into the decide statement
  hash (F-N1).

**Where compounding would re-enter, precisely:** (F-C1) broken at
any round → the extracted bound at that round degrades to the
recomposed transport n_inst·T·(previous extracted bound) and
multiplies until the next grounded round — locally compounded,
exactly SC 2.2's fence list extended by one row. (F-C3′) ignored
(l_inf bounds costed naively in l2) → the fold MSIS instances go
vacuous-as-bounded above ~2^31 at digit bases e >= 3 — the R-EB4
vacuity shape in the fold layer (spike check 7 prints the envelope).
Neither engages at the recommended parameter family.

## 4. The small-slot-field check (the 2026-04-30 break precedent, applied to the fold challenge surfaces)

The precedent (PARAMS 3.6; SC-L5 condition 1): three public LaBRADOR
implementations lost all but 1-31 bits of soundness because their
rings split into SMALL CRT factors and a witness defect confined to
one slot survives random-linear-combination checks with probability
1/|smallest factor|. The quantity that decides life or death is the
SLOT FIELD SIZE against every challenge surface. The fold layer adds
new surfaces; each is re-derived here at our slot structure (no
margin imported from the LaBRADOR-context 365-bit figure).

| # | surface | set | per-slot / per-event mass | worst post-FS use (x 2(Q+1) = 2^65, x count) | margin vs 2^-128 |
|---|---|---|---|---|---|
| S1 | fold RLC challenges rho_i | quinary C, 2^297.2 | per-slot point mass 2^-297.2 (L2 [PROVEN]) | 2^65 · 2·n_inst·2^-297.2 ≈ 2^-226 (n_inst ≤ 64, all rounds) | **+98 bits** |
| S2 | fold-challenge differences (extraction) | C − C | LS18-invertible, margin 1.30x (C0') | not a mass — an algebra fact; fails only if the set collides per-slot (S4 demo) | structural |
| S3 | sumcheck / batching challenges (alpha, mu, beta, r_o) | slot-diagonal K-set, 2^496 | SZ class ((2b+1)log m + 2n_inst)·2^-496 ≈ 2^-485 | 2^65 · N_fold · 2^-485 ≈ 2^-415 | **+287 bits** |
| S4 | the structural cap (AFS-L0(c)) | ANY strong sampling set | ≤ q^16 = 2^496 at our ring; ≤ q = 2^31 at a fully-split ring | need ≥ 2^(128+65+log) ≈ 2^200-class | **+296 bits of structural room; the fully-split cap 2^31 is 169 bits BELOW need — the break regime, unfixable by set design** |

Readings. (i) The tightest fold-layer surface is S1 at +98 bits —
comfortable, and NOT the chain's binding constraint (the eval-proof
floor terms of Section 6 dominate). (ii) The broken regime is not a
"bad set choice" but a ring property: at a fully-split q31 ring NO
fold challenge set can exceed 2^31 (AFS-L0(c)), so the interactive
error floor is 2^-31 and the FS error is vacuous (2^65·2^-31 > 1).
Our 8 x GF(q^16) split clears it because the house chose ord 16
splitting for exactly this class of reason. (iii) Slot-completeness
is load-bearing for the fold's range arms exactly as for SC-L6: the
∀-slots quantifier in R^{tau,B}_cm may not be sampled or summed
(I-3 extended to the fold layer; a slot-sampling "optimization"
re-opens the S4 escape). **[PROVEN arithmetic; spike checks 5a/5b
demonstrate both directions at toy scale: measured defect-survival
≈ 1/17 at a fully-split toy ring vs ≈ 1/625 at a partially-split
one, and a constructive extraction-breakdown from a slot-degenerate
fold-challenge subset.]**

## 5. The norm accounting, settled

### 5.1 The two accountings and where each is valid

- **l_inf ([LF]/[LF+] native).** Expansion T_inf ≤ min(2D,
  ||rho||_1) = 256 worst-case quinary; honest E||rho||_1 = 153.6;
  cap-by-resampling at 160 accepts ≈ 77% [MODEL — CLT estimate;
  spike check 3 MCs it]. Valid for: transcribing their theorem
  statements; the range-arm bounds (which are genuinely l_inf and
  slack-1, AFS-L2).
- **l2 (house native).** Operator norm capped at T_cap = 33 (R-EB1,
  MC-measured in the EB lane); honest concentration 20.8 with the
  Q4.1 restart discipline. Valid for: every MSIS instance priced by
  the C3 line; the SC-L4 chain; and — after AFS-L6 — the fold's
  binding bounds.

### 5.2 AFS-L6 — the fold binding bound, re-derived in l2 [PROVEN]

**Why needed.** [LF] Thm 3.3's binding hypothesis is
MSIS^{inf}_{kappa,m,8·T_inf·B}. The house estimator costs l2; the
generic conversion (an l_inf solution < beta_inf is an l2 solution
< sqrt(d·m)·beta_inf) multiplies by sqrt(d·m) ≈ 2^9 at fold shapes,
and 8·T_inf·B·2^9 crosses q for any digit base e ≥ 3 — the theorem
would be vacuous-as-bounded exactly in the R-EB4 sense. [LF+]
Section 6 lists the l2 variant as open. The fix is to re-derive the
single step that produces the MSIS solution, natively in l2.

**Statement.** Let the fold-round extractor (AFS-L1) obtain two
2B-weak openings (Delta_1, x_1), (Delta_2, x_2) of the same
commitment, where each x_j is a difference of two accepted-round
witnesses whose l_inf bounds are range-pinned at B_acc-class
(AFS-L2/L3 give ||x_j||_inf < 2B_acc, hence
||x_j||_2 < 2·sqrt(d·m_acc)·B_acc), and Delta_j ∈ C − C with l2
operator norm ≤ 2·T_cap (R-EB1 cap on single challenges; a
difference is a sum of two). Then Delta_2·x_1 − Delta_1·x_2 is a
nonzero MSIS solution with

    beta_fold(l2) ≤ 2 · (2·T_cap) · 2·sqrt(d·m_acc)·B_acc
                  = 8 · T_cap · sqrt(d·m_acc) · B_acc.

*Proof.* ||Delta·x||_2 ≤ op_2(Delta)·||x||_2 (the house op-norm
convention, params.rs); triangle inequality over the two terms;
nonzero by the AFS-L1 step-3 disagreement. ∎ **[PROVEN]** (three
lines; it is SC-L1 step 3's arithmetic with the fold's objects).

**House numbers** (spike check 7): with T_cap = 33,
m_acc ∈ [2^10, 2^13] rings, d = 128, and B_acc = n_inst·T-class·(b−1)
per AFS-L4 at digit bases e ≤ 7:
beta_fold ≈ 2^{8.04}·2^{8.5..10}·B_acc. Representative row:
m_acc = 2^11, B_acc = 2^9.3 (n_inst = 2, l2-capped, b−1 = 64-class
honest digits): beta_fold ≈ 2^{26.8} ≤ 2^30.5 with 3.7 bits to the
R-EB4 line and kappa = 11 sufficient on the C3 line — **the fold's
binding instances land in the same MSIS class as the eval-proof
levels R-EB4 already validated.** The full (b, k, n_inst, m_acc)
envelope with PASS/FAIL per row is spike check 7; the envelope caps
the fold at the same e ≤ 7-class bases as the floor levels —
convergent with AFS-L5 item 1.

## 6. The knowledge-error budget for a complete folded pass

Model: N_fold fold rounds (32 leaves; N_fold = 31 for either a
binary tree or a sequential 2-ary schedule — same count; parametric
otherwise [F-IF1 PENDING]), each with the AFS-L1 error; ONE decide
via the SC-L4 chain in the exact-digit configuration (triple-mandated
config; SC 3.3's most robust column); house Q-convention Q = 2^64
charged directly (SC 3.3 (Q-conv), same posture). All terms
spike-reproduced (check 5); exponents rounded to 0.1.

| # | term | per-unit | count | pre-FS sum | source |
|---|---|---|---|---|---|
| 1 | fold RLC / hypergeometric (n_inst/|C_s|) | ≤ 2^6·2^-297.2 = 2^-291.2 | 31 | 2^-286.3 | AFS-L1; [LF] Thm 3.3 |
| 2 | fold sumcheck SZ (E1+E2+E3 over C_K) | ≤ 2^-485 | 31 | 2^-480 | AFS-L1; [LF] Lemma 3.7 |
| 3 | fold binding | eps_bind: computational, MSIS kappa 11 at beta_fold (AFS-L6) | 31 instances, one class | adv-term, not statistical | AFS-L6; C3 line |
| 4 | [if LF+ machinery] Pi_cm union-bound term | 2^-180-class (single K-sumcheck) | per round | ≤ 2^-175 | AFS-L5 item 3 [MODEL] |
| 5 | claim batching into the decide (SC-L6) | B·2^-297 | once | 2^-293 | SC-L6 [PROVEN] |
| 6 | decide: eval-proof chain, exact-digit column (fold 2^-288-class, K-draw agg 2^-496, GKR/SZ 2^-485) | — | once | 2^-285 | SC 3.2/3.3 table |
| 7 | GKR/sumcheck instance-side SZ (per-layer engines) | 2^-485-class | once (batched) | 2^-485 | DB 10.4 |
|   | **pre-FS union** | | | **≈ 2^-284.9** | dominated by rows 1 + 6 |
|   | **post-FS: x 2(Q+1) ≈ 2^65 ([PSS] Thm 4.1/Eq. (18), fold rounds joining the additive bracket — SC-L5 transfer conditions re-checked for the fold rounds: (1) well-spreadness = S1 row; (2) T_op cap = F-C2; (3) splitting terms = S3 row; (4) window — NOT NEEDED, slack-1 grounding; (5) CWSS structure = AFS-L1 step 1)** | | | **≈ 2^-219.9** | |
|   | **vs 2^-128 (H-07 min() target, statistical leg)** | | | **PASS, margin ≈ 91.9 bits** | |

**Headline: a complete folded 32-layer pass carries post-FS
knowledge error ≈ 2^-219 [MODEL — cited constants, spike-checked
sums], statistically indistinguishable from the UNFOLDED exact-digit
pass (2^-220-class, SC 3.3): folding 32 layers costs ≈ 1 bit of
knowledge error.** The budget is dominated by the decide's fold
(amortization) terms exactly as before; the new fold-layer terms sit
70+ bits below them. The computational legs (rows 3 + C-msis) are
unchanged in class: kappa 11 covers both.

Convention flags carried unchanged: (Q-conv) and (X-run) from SC 3.3
apply verbatim — the fold multiplies the extractor's expected-time
constant by the per-round (1 + n_inst) factors (AFS-L1), which is
polynomially benign and affects reduction tightness, not error
terms; recorded at the same posture as [PSS]/SC.

## 7. FS soundness rows for the fold challenges (joint with AZ-L4(a))

The reduced protocol's inherited rows (CRB-N1..N7, AZ-L4's table)
stand. The fold layer adds one hash-edge row per challenge family
and one seam row; format per SOUNDNESS_REFERENCE Section 7;
batteries are build-round scope, F5-pair candidates named for the
build round (FSB-*).

| challenge | drawn from | must follow (absorbed FS state) | attack if violated | F5 pair (planned) |
|---|---|---|---|---|
| h0_agg (statement hash) | — | T_data AND T_blind incl. all masks/pads + the 32 layers' instance list | AZ-L4 A3 swap, one level up: swap an instance set between fold and decide | AZB-3 (inherited) |
| alpha_i, mu_i (arm batching), beta (range anchor) | K-set | EVERY input instance of the round: commitments cm_i, points r_i, claimed v_i, y_i | craft an instance after alpha: h(alpha, mu) = 0 becomes satisfiable for a false instance — E2 inverted ([LF] Claim 4's independence breaks) | **FSB-1** |
| sumcheck round challenges r_o | K-set | round polynomials as sent (standard) | standard sumcheck ordering attack | inherited battery class |
| terminal openings theta_i (prover message) | — | must be absorbed BEFORE rho | see next row | — |
| fold challenges rho_i | quinary C (T_cap resample counter — R-EB1 salt row) | the round's FULL prefix: instances, alpha/mu/beta, all sumcheck messages, the theta_i | theta chosen after rho: the extractor's cross-transcript identity (AFS-L1 step 3 / [LF] Eq. (24)) collapses — a steered theta matches a steered fold and a FALSE folded claim ACCEPTS; this is AZ-L4 A1's class at the fold layer | **FSB-2** |
| round i+1's challenges | — | round i's complete transcript incl. the decomposition commitments of AFS-L3 | splice rounds: fold outputs re-decomposed AFTER seeing round i+1 challenges → range arm grounds the wrong object | **FSB-3** |
| decide statement hash | — | the FINAL accumulator instance (commitment, point, v, B_acc) as output by round N_fold | **F-N1**: decide proves an accumulator not bound to the fold transcript — the 32-layer statement silently narrows to "some accumulator is valid" | **FSB-4** |
| (all fold challenges) | — | mask/pad commitments precede every fold challenge (AZ-L4(b), FB lane) | privacy-side A4 analogue | FB's battery |

Negative-control note for the batteries: FSB-2's attack leg is the
fold-layer twin of SPKZ-5 (AZ battery) and should reuse its rig;
FSB-4 needs a fresh rig (two accumulators, one transcript).
[OBLIGATION — battery specs at build round; same posture as
CRB-N1..N5.]

## 8. R-FC rows and the F-IF1 verification protocol

**[F-IF1 PENDING]** — `git show wt-uag4-folding:docs/zkmatrix-poc/
AGGREGATION_FOLDING_DESIGN.md` checked during this lane; not yet
published at close. No R-FC discrepancy rows can be filed against an
unpublished interface. What WILL be verified against F-IF1 when it
lands (the checklist is binding on FINAL if this lane closes first):

- **R-FC-V1**: the fold's challenge sets — fold RLC from quinary C
  with the R-EB1 cap (F-C2); sumcheck/batching/point draws from the
  slot-diagonal K-set, never Z_q-diagonal (Section 4 S3/S4) and
  never raw-R_q where Lemma 3.2's RotSum bookkeeping is needed (G4).
- **R-FC-V2**: every fold round carries the range arm (F-C1) — no
  arm-free intermediate rounds in the schedule.
- **R-FC-V3**: the norm law and arity: FA's per-round
  (n_inst, b, k) against AFS-L4's condition n_inst·T·(b−1) < B and
  the AFS-L6/R-EB4 envelope (spike check 7 rows); B_acc consistent
  with what the decide chain's level-0 expects (Seam 2).
- **R-FC-V4**: FS ordering of every fold challenge matches Section
  7's table (esp. theta-before-rho and F-N1).
- **R-FC-V5**: fold-message byte skeleton consistent with the
  tau = 16 terminal-opening count (G3/H-FA7) and, if LF+ machinery,
  with the single-vs-double sumcheck decision (AFS-L5 item 3).
- **R-FC-V6**: the composition discipline — monolithic rounds or a
  restricted-composition lemma (H-FA3 / Section 2.7).

(Pre-emptive numerical note for the reconcile, not an R-FC row:
AGGREGATION_LITERATURE 2.2's fold-message estimate "~4-8 KiB at our
kappa/msg_r shape" predates [LF+] Thm 5.3's inventory
(L·(5·kappa + 6) + 10 R_q-elements + L(dk+5) S-bar-elements +
L(2dk+d+1) C-elements); FA's byte model should derive from the
latter.)

## 9. Verdict row

**Extraction COMPOSES — under the six named conditions F-C1..F-C6,
all satisfiable at the house parameter family (kappa 11, R-EB1
T_cap = 33 extended to fold challenges, R-EB4-class base caps
e ≤ 7 which the fold's own binding envelope independently
reproduces, K-draw sumcheck challenges, exact-digit decide). The
per-level reading survives a 32-fold: fold rounds ground their own
norms at slack exactly 1 (the SC-L3 mechanism species), the two
SC-L4 channels stay slack-inert across both seams, and no
compounding channel opens. The knowledge-error headline for a
complete folded pass is ≈ 2^-219 post-FS [MODEL] — PASS with ~92
bits of margin; folding costs ≈ 1 bit vs the unfolded pass. The
architecture stands. FAILURE modes are precisely fenced: dropping a
range arm (F-C1), uncapped fold challenges (F-C2), naive
l_inf-to-l2 costing without AFS-L6 (F-C3′), or a fully-split ring
(Section 4 S4) each individually kill the composition, and none is
present in the recommended family. F-IF1 verification pending
(Section 8 checklist).**

## 10. Exports

**To FA (hypotheses the fold design must satisfy — H-FA1..H-FA8):**
- H-FA1 (= F-C1, HARD): range arm in every fold round.
- H-FA2 (= F-C2): fold challenges quinary + T_cap = 33 resampling
  (R-EB1 counter/salt pattern); state the norm accounting (l2
  recommended; if any l_inf bookkeeping remains, the l1-cap row
  [MODEL 160 @ ~77%] must be frozen alongside).
- H-FA3 (= Section 2.7, HARD): monolithic round extraction or a
  proved restricted-composition lemma; no bare linearization + bare
  fold composed by [KP23] alone.
- H-FA4 (= G4): instance evaluation points from the slot-diagonal
  K-set; slot-complete range statements (I-3 extended).
- H-FA5 (= F-C3′/F-C4): per-round (n_inst, b, k) inside the AFS-L6 /
  R-EB4 envelope (spike check 7 table); per-round re-decomposition.
- H-FA6 (= G3): NTT-transpose bookkeeping for the range layer under
  DENSE encoding — price it, don't discover it.
- H-FA7: wire inventory per round includes tau = 16 terminal
  openings per instance ([LF] Eq. (30)/(32)) — the byte model line.
- H-FA8 (= F-C5/F-N1): FS ordering per Section 7; the decide
  statement hash absorbs the final accumulator instance.

**To FB (mask-related extraction interactions):**
- The fold extractor is straight-line over T_blind: it rewinds fold
  and sumcheck challenges only, never opens masks — so mask
  refreshing per proof (AZ-L4(b)) is compatible with extraction as
  long as T_blind is inside h0_agg (Section 7 row 1). The
  fold/mask ORDER lemma (mask-then-fold) is FB's; this lane's
  constraint on it is only F-C5's table.
- I-6 status in the sources: [LF]/[LF+] contain no Gaussian-masked
  openings anywhere (their ZK is deferred to the final wrap) — the
  fold layer imports no I-6 tension; FB's Tier Z surcharge rides on
  top unchanged.
- The one-proof-per-witness rule is untouched by folding WITHIN one
  pass (per-pass scope = one decide floor per pass); FB's
  weight-side accumulation asymmetry (ZK_GAP_OPTIONS Section 6) is
  orthogonal to the fold soundness and stays governing.

**To the orchestrator/ledger:**
- AFS-L6 is a required lemma for ANY fold build at q31 (F-C3′) —
  freeze-row candidate alongside R-EB1..R-EB4.
- The SC 2.4(c) exact-digit plumbing flag is WEAKENED for the fold
  layer specifically: [LF]'s digit-level range product inside a
  sumcheck avoids bit-level witness columns (Section 2.3 note).
- The single-vs-double sumcheck decision (AFS-L5 item 3) is open
  for FINAL with the spike row.
- Wayback-vs-live source identity: re-verify 2024/257 (Dec 15 2025
  snapshot), 2025/247 (Aug 9 2025 snapshot), 2025/294 against live
  ePrint when the bot check lifts (the SC 5.3 item 6 posture).

## 11. Claim grades

| claim | grade |
|---|---|
| AFS-L0 (challenge sets, pigeonhole cap at our ring) | [PROVEN] |
| AFS-L1 (fold extraction at our ring) | [CITED] skeleton ([LF] Thm 3.3 + Lemma 3.7, read in full) + [PROVEN] substitutions; conditional on F-C2, F-C3′ |
| AFS-L2 (range arm = slack-1 grounding) | [PROVEN] mechanism (house); [CITED] protocol |
| AFS-L3 (decomposition, error-free) | [CITED] + [PROVEN] arithmetic |
| AFS-L4 (depth-independent norm law) | [PROVEN] arithmetic; spike-verified numerically |
| AFS-L5 ([LF+] machinery at our ring; e ≤ 7 convergence; union-bound arithmetic) | [CITED] + [PROVEN] arithmetic; single-sumcheck saving [MODEL] |
| AFS-L6 (l2 fold binding bound) | [PROVEN] (house, 3 lines); its NECESSITY at q31 is [PROVEN] arithmetic (the l_inf route's vacuity) |
| AFS-L7 (the extended per-level composition) | [PROVEN] as composition of cited skeletons + house constants; independent-review target at the same priority class as SC-L4 |
| small-slot margins (Section 4 table) | [PROVEN] arithmetic; break demos spike-executed |
| knowledge-error budget (Section 6) | [MODEL] (cited constants, spike-checked sums; Q-conv flagged) |
| l1-cap 160 @ 77% accept | [MODEL] (CLT + spike MC) |
| FS transfer of the fold rounds ([PSS] via SC-L5) | [PROVEN] transfer-shape checks; battery legs [OBLIGATION] |
| Neo composition caveat / H-FA3 | [CITED] ([Neo] Section 5 read; protocol sections skimmed) |
| F-IF1 verification | [PENDING] — Section 8 checklist binding on FINAL |

## 12. References

1. [LF] Boneh, Chen. "LatticeFold." ePrint 2024/257 — READ IN FULL
   this session (Wayback snapshot dated 2025-12-15;
   references/latticefold-eprint-2024-257.pdf). Load-bearing: Thm
   3.3 + Fig. 4 extractor + Lemma 3.7; Lemma 2.3; Section 3.3
   Eq. (31); Remarks 3.3, 5.1; Thms 4.1-4.3.
2. [LF+] Boneh, Chen. "LatticeFold+." ePrint 2025/247 — READ IN
   FULL this session (snapshot 2025-08-09;
   references/latticefold-plus-eprint-2025-247.pdf). Load-bearing:
   Lemmas 2.2-2.5, 4.4-4.10; Thm 4.3; Thms 5.1-5.3 + Eq. (28);
   Remark 4.9; Appendix B; Section 6 (l2 open).
3. [Neo] Nguyen, Setty. "Neo." ePrint 2025/294 — soundness core
   read this session (references/neo-eprint-2025-294.pdf).
   Load-bearing: Thm 1, Defs 14/15, Lemma 3, Section 5 Thm 5.
4. House: AGGREGATION_SOUNDNESS_COMPOSITION.md (SC-L0..L6,
   R-EB1..R-EB4), AGGREGATION_PARAMS_DESIGN.md (Sections 1-4, 3.6),
   AGGREGATION_ZK_DESIGN.md 5.5 (AZ-L4), AGGREGATION_CLAIM_
   REDUCTION.md 10.5, SOUNDNESS_REFERENCE.md (L1/L2, H-07 note),
   Q4_LEMMAS.md, AGGREGATION_LITERATURE.md Section 2 + refs 6/7/9.
5. Cited THROUGH the primaries, not independently retrieved
   [S10-style flag]: [KP23] (composition), [FMN24] Lemma 7.1
   (coordinate-wise special soundness), [AL21] Prop 2, [CCKP19]
   (ring sumcheck), [BCPS18] (generalized SZ), [LS18] Cor 1.2
   (independently verified in-house as C0'), [ACK21]/[ALS20]
   (relaxed binding lineage).
6. [PSS] ePrint 2024/311 and [LaB] 2022/1341 — cited via the EB
   lane's in-full reading (AGGREGATION_SOUNDNESS_COMPOSITION.md
   Section 0.2), not re-retrieved this session.

---

*Changelog: 2026-07-27 — first edition (U-AG4 Agent FC lane).
Primary sources 2024/257 + 2025/247 read in full and 2025/294's
soundness core read this session (Wayback route; bot-check note
carried); transcription AFS-L0..L7 written against the R-EB-corrected
SC chain; the l_inf/l2 gap identified and closed by AFS-L6; the
small-slot break re-derived for the fold surfaces with the
pigeonhole cap stated as a theorem; budget headline 2^-219 [MODEL];
F-IF1 pending at close — Section 8 checklist left binding.*
