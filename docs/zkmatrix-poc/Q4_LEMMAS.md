# Q4: The Lemma Write-Ups

Status: the accumulated Q4 lemma-writing debt of ROUTE_R_DESIGN.md
(Section 9 item 4), ROUTE_R_BUILD_REPORT.md (Section 2) and
AUTOMORPHISM_GATE_DESIGN.md (Q-A2/Q-A3), stated as numbered lemmas
Q4.1-Q4.6 at the lattice report's discipline: full proofs where
elementary, honest SKETCH labels with literature anchors where not, and
OBLIGATION labels where the statement fixes acceptance criteria for
work that has not been done. Each lemma names the code it covers.
Summary table in Section 8.

Notation: R_q = Z_q[X]/(X^D + 1), D = 128; quinary challenge set C
(coefficients in {-2..2}, E[c_i^2] = 2); c-bar = c - c' a challenge
difference (LS18-invertible); ||.|| is l2 over the coefficient
embedding unless marked. "The report" = the repo's lattice report
(zk-matrix-multiplication-lattice PDF): Lemma 6.3 (rejection-sampling
ZK), Theorem 8.3 (3-special soundness), Section 11 (parameter chain).
References: [Lyu12] Lyubashevsky, EUROCRYPT 2012 (Fiat-Shamir with
aborts); [BDLOP16] Baum et al., SCN 2018 commitments; [LS18]
Lyubashevsky-Seiler, EUROCRYPT 2018; [ALS20]
Attema-Lyubashevsky-Seiler, CRYPTO 2020; [LNP22]
Lyubashevsky-Nguyen-Plancon, CRYPTO 2022 = eprint 2022/284; [KLS18]
Kiltz-Lyubashevsky-Schaffner, EUROCRYPT 2018; [RV13]
Rudelson-Vershynin, Hanson-Wright inequality (ECP 2013).

---

## Q4.1 — Concentration-bound restart discipline

Covers: `ring/sigma.rs::derive_digit_params` / `prove_opening_digits`
(`center_sq`, the `restarts` counter), `ring/ct_engine.rs::
derive_ct_round_params` / `prove_ct_round` (the `center_sq > 0`
restart checks), `scripts/route_r_params.py::op_norm/combine`
(conc = true columns), and every C2/C3 row derived from them.

**Setting.** Combination centers v = c * u (single) or bundles
v = (c * u_1, ..., c * u_L) are sized by the concentration operator
norm T_conc = 1.3 * sqrt(E[c^2] * D * t) * B0 instead of the
worst-case l1 norm 2D * t * B0. The prover computes v after drawing
the challenge and RESTARTS the round (fresh masks, same statement) if
||v||^2 > center_sq = T_conc^2.

**Lemma Q4.1a (exact second moment).** For c in R with independent
coefficients of variance E[c^2] and any fixed u in R,
E_c ||c * u||^2 = D * E[c^2] * ||u||^2.

*Proof.* The k-th coefficient of the negacyclic product is
(c * u)_k = sum_j (+-) c_j u_{k-j mod D} with signs from the X^D = -1
wrap. Coefficients of c are independent and centered, so the cross
terms vanish and E[(c*u)_k^2] = sum_j E[c_j^2] u_{k-j}^2 =
E[c^2] * ||u||^2. Summing over the D output coefficients gives the
claim; signs square away. **PROVEN** (this is the design Section 3
identity; quinary E[c^2] = 2, the scripts' E_C2).

**Lemma Q4.1b (restart probability / completeness cost).** With
T_conc set at the 1.3-tail, the restart probability is
p_exc = Pr_c[||v||^2 > 1.69 * E||v||^2], and ||v||^2 is a quadratic
form in the independent, bounded (|c_i| <= 2, subgaussian) challenge
coefficients; by Hanson-Wright [RV13],
p_exc <= 2 exp(-c0 * min(delta^2, delta) * D_eff) for delta = 0.69 and
an effective dimension D_eff that grows with the bundle (t combined
columns, L digits) — exponentially small in the bundle dimension. The
expected number of restarts is p_exc / (1 - p_exc); the code's
restart counters measure percent-level rates at demo shapes,
consistent with the bound. **SKETCH** (the inequality is cited, not
re-derived; the constant c0 and the exact D_eff for negacyclic
quadratic forms are not worked — the empirical counters are the
current evidence at operating shapes).

**Lemma Q4.1c (soundness accounting — where the 2^-64-class surcharge
does and does not arise).**

(i) *With the restart rule (as implemented):* the verifier's norm
gates (`bound_sq`, `center_sq`-derived beta terms) are checked
worst-case on every ACCEPTED transcript; the extractor consumes only
accepted transcripts; therefore the restart rule adds **no** soundness
surcharge. Its entire cost is Q4.1b's completeness factor. The rule is
prover-side only and the verifier never learns whether restarts
happened (but see Q4.5a for what the *count* would leak if exposed —
the salt design is the template).

(ii) *Without the restart rule (the design's flagged alternative):*
every reduction step whose norm inequality uses an honest-combination
bound B_conc (the `combine(t, ., conc = true)` terms feeding beta —
Pi1's op*B_rho, Pi2's op^3*B_rho_v class terms) holds only with
probability 1 - p_exc over the challenge; under Fiat-Shamir the
adversary grinds challenges, so the knowledge error grows by
<= (Q+1) * p_exc with Q = 2^64 hash queries. Keeping the design's
2^-256-class interactive discipline would need p_exc <= 2^-(256+65),
which the 1.3-tail does NOT provide (it is percent-level). So the
restart rule is **load-bearing**: concentration sizing without it is
not "2^-64-surcharged" but broken at this security discipline.
The design's "~2^-64-class" phrasing described tail levels achievable
with larger tail factors; the implemented discipline (restart rule)
makes the question moot.

Status: (i) **PROVEN** (elementary, given the worst-case gates in
`verify_ct_round`/`verify_opening_digits`); (ii) **SKETCH** — the
per-protocol inventory of which beta terms are honest-combination
terms (and hence would need the exception argument in a no-restart
variant) is written for Pi1/Pi2 shapes but not mechanically checked;
it is only needed if a no-restart variant is ever proposed.

---

## Q4.2 — Rejection sampling with multiple bundles (the M-product)

Covers: `ring/ct_engine.rs::prove_ct_round` (the three independent
`rejection_accept` calls: std rho bundle, Ajtai s bundle, digit
bundle — the header comment "the repetition rate is the product of
the M's (the joint-scaling rework is the Q4 lemma's scope)"),
`ring/mod.rs::rejection_accept` (log_m = 1 + 1/288, the alpha = 12
discipline).

**Setting.** Per attempt, the round draws independent Gaussian mask
bundles y_i with parameters sigma_i = alpha * T_i (alpha = 12,
||v_i|| <= T_i), sets z_i = y_i + v_i, and accepts iff ALL bundle
tests pass, each implementing the report's Lemma 6.3 / [Lyu12] Thm 4.6
with M_i = exp(t/alpha + 1/(2 alpha^2)), t = 12: M_i = e^(1 + 1/288)
= 2.7616.

**Lemma Q4.2a (product law).** The per-attempt acceptance probability
of the honest prover is prod_i (1/M_i) (up to the per-bundle 2^-100-
class tail defects), and conditioned on acceptance the joint response
distribution is within sum_i 2^-100-class statistical distance of the
product of center-independent Gaussians.

*Proof.* The three accept tests use independent uniform draws u_i and
depend on disjoint (y_i, v_i); the events are independent given the
attempt, so probabilities multiply. Per bundle, Lemma 6.3 gives
acceptance 1/M_i and output distance 2^-100-class from
rho_{sigma_i}; a hybrid over the three bundles adds the distances.
For three active bundles: expected attempts 2.7616^3 = 21.1 (two
active: 7.63). **PROVEN.**

**Lemma Q4.2b (joint scaling — the variant that reduces the
product).** Keep the same sigmas, masks, and responses, but replace
the k independent tests by ONE test on the summed exponent
S = sum_i (||v_i||^2 - 2<z_i, v_i>) / (2 sigma_i^2), accepting iff
u < exp(S - log M_joint) for
M_joint = exp(t * sqrt(k) / alpha + k / (2 alpha^2)).
Then the acceptance probability is 1/M_joint and the accepted joint
response distribution is within one 2^-t^2/2-class defect of the same
product-of-Gaussians target. At alpha = t = 12:

| active bundles k | product of M's (as coded) | M_joint | improvement |
|---|---|---|---|
| 2 | 7.63 | 4.18 | 1.83x |
| 3 | 21.06 | 5.72 | 3.68x |

*Proof.* The joint source/target density ratio is
prod_i rho_{sigma_i}(z_i) / rho_{sigma_i}(z_i - v_i) = exp(S): the
rejection decision lawfully depends on the concatenated vector only
through the scalar S, so the one-dimensional form of Lemma 6.3
applies to S directly. Writing z_i = y_i + v_i,
S = -sum_i (||v_i||^2 + 2<y_i, v_i>) / (2 sigma_i^2); the constant
part is bounded by k/(2 alpha^2) since ||v_i|| <= T_i = sigma_i /
alpha, and the linear part L = sum_i <y_i, v_i>/sigma_i^2 is a
centered Gaussian with variance sum_i ||v_i||^2/sigma_i^2 <=
k/alpha^2 (independence across bundles). Cutting L's tail at t
standard deviations (one event, probability <= 2 e^{-t^2/2} =
2^-102.9 at t = 12, versus k such events in the product scheme)
bounds exp(S) <= M_joint on the kept set, and [Lyu12] Thm 4.6's
argument applies verbatim with this M. Since neither sigmas nor the
accepted output distribution change, soundness and proof sizes are
untouched; only the restart rate improves. **PROVEN** (full proof; the
engine change — one summed test replacing three — is a build item,
noted for the next engine tranche).

*Interaction with the ARP:* the ARP reveal's rejection (`arp_attempt`)
stays OUTSIDE this joint test by design: its restart must re-commit
the mask and re-derive R (the FS-with-aborts loop in ring_matmul.rs
U3b), so it multiplies the mask-commit loop, not the ct-round
attempts. Folding it in would break the commit-before-R ordering.

---

## Q4.3 — Garbage-term ZK simulation (the U6 quadratic layer)

Covers: `ring/ct_engine.rs::prove_ct_round` (the `gq = [Ga, Gb, G0]`
and `gr = [G1, G0]` constructions and `w_quad`/`w_qring`),
`verify_ct_round` (the sigma(c) c h = E + ... check), the module
header's "ZK NOTE (Q4-class)", and `ring/commit.rs` (A2 rows).

**Setting.** Per sigma-twisted quadratic claim the prover sends, in
the clear and before the challenge, Ga = sum_p gamma_p sigma(x_ap)
Y_bp, Gb = sum_p gamma_p x_bp sigma(Y_ap), G0 = sum_p gamma_p
sigma(Y_ap) Y_bp, plus W_quad; Y_i := A2 y_i are the message-side
mask images of the Gaussian masks. The reveals h carry a g-mask with
ct(g) = 0 and uniform other coefficients.

**Lemma Q4.3a (mask-image uniformity — the leftover-entropy
requirement on N_r, stated precisely).** Under the knapsack-MLWE
assumption at dimension d_kn = N_Z - k_Z - msg_Z, the tuple
(A2, A2 y) for a Gaussian y with the round's sigma is computationally
indistinguishable from (A2, uniform R_q^msg_r), provided

    N_r >= kappa + msg_r + ceil(768 * log2 q / (11.7 * D)),

i.e. EXACTLY the C4 line of the parameter chain — C4 is not only the
commitment-hiding condition but the garbage-simulation entropy budget.
(A statistical alternative — regularity/smoothing [GPV08-class] —
would need sigma at q^{msg_Z/N_Z}-scale, far above the rejection
sigmas; the computational route is the one the parameters support.)
**SKETCH** (reduction shape standard; the precise hybrid over the
round's several mask bundles sharing one A2 is written but not
mechanically checked).

**Lemma Q4.3b (the masked pieces simulate).** (i) Each reveal
h = Q + L + g with ct(g) = 0, other coefficients uniform and
independent: h is uniform on the hyperplane ct(.) = scalar — a
one-time pad on the D-1 non-ct coefficients. **PROVEN** (exact,
information-theoretic). (ii) Each W_claim/W_quad/W_qring carries the
additive term (A2 y_G)_{sl(l)} of its OWN g-slot; under Q4.3a that
term is indistinguishable-from-uniform and independent of the other
consumed images, so the W's simulate as fresh uniforms consistent
with the verification equation. **SKETCH** (inherits Q4.3a).

**Q4.3c (the gap — bilinear garbage terms are unmasked).** Ga, Gb
(and G1) carry NO additive mask slot: they are bilinear images
sum_p gamma_p sigma(x_ap) Y_bp whose conditional distribution, over
uniform Y, is uniform on the R_q-submodule generated by the
secret-dependent multipliers {gamma_p sigma(x_ap)}. For generic x
that submodule is all of R_q (a uniform element of R_q at k = 8 is
non-invertible w.p. ~ 8 q^-16 = 2^-493-class, LS18), and simulation
by "sample Ga, Gb uniform, solve G0 from the check equation" goes
through. But gadget witnesses are structured: an all-zero bit plane
(legal and common — high bits of small values) zeroes the multipliers
of every quad term referencing it, collapsing the support of Ga to a
proper submodule — distinguishable from uniform in one sample; the
simulator as stated FAILS for exactly the tensors the binary gadget
exists to handle. Discharge routes: **(R1)** add an additive mask
slot to each of Ga/Gb/G1 (one more g-slot per quad claim and +3 ring
elements per claim ~ +3 * D * log2 q bits) — then the simulator
samples them uniform, solves G0, and indistinguishability reduces to
Q4.3a + Q4.2a; recommended, engine change. **(R2)** a per-claim
regularity hypothesis on x — unacceptable here (degenerate bit
tensors are the norm). Status of Q4.3 overall: **SKETCH with a named
OBLIGATION** — the simulator's structure and entropy accounting are
written; R1 must land in the engine (or R2 be argued per claim class)
before the quadratic layer's ZK claim is discharged. This is a real
finding of the write-up, not a formality: the current U6 binary
gadget's garbage terms can leak bit-plane degeneracy.

---

## Q4.4 — ARP extraction: JL lower bound composed with relaxed-opening
slack

Covers: `ring/ct_engine.rs::SLACK_OP` (= 4D), `JL_C` (= 13),
`derive_arp_params`, `arp_budget_ok`, `arp_claims`,
`sample_arp_mask`/`arp_attempt` (commit-before-R ordering);
`ring_matmul.rs` U3b/U6b assertions and the `freeze_check` ARP gates;
finding F3 and GADGET_MODULUS_DECISION.md throughout.

**Setting.** The ARP grounds ||b|| for a committed witness b: mask m
committed (Ajtai slot) before R = XOF(h0) with iid entries in
{0,+1,-1} w.p. (1/2, 1/4, 1/4); reveal y = R b + m, rejection-sampled
and range-gated ||y|| <= y_bound; rows linear ct-claims tie y_i =
<R_i, b> + m_i. The code carries the extracted bound

    extract = SLACK_OP * 2 * y_bound / sqrt(rows / JL_C).

**Lemma Q4.4a (JL lower bound — cited).** For R as above with `rows`
rows and any FIXED w in R^n: ||R w||_2^2 >= (rows / JL_C) ||w||_2^2
except with probability ~2^-128-class over R ([LNP22] Lemma 2.8-class;
constant as carried in code, JL_C = 13). **CITED** — adopted, not
re-proven here; the constant must be transcribed from the paper when
Q4.4' (below) is worked, since 13-vs-26-class factors decide q31.

**Lemma Q4.4b (what the coded composition actually establishes —
honest status).** The intended derivation is: (1) two accepting
transcripts pin, per row, y_i = <R_i, b*> + m*_i (mod q), with b* the
BDLOP-extracted messages (message-side relations are exact mod-q
algebra — the engine header's derivation) and m* the Ajtai-extracted
mask with ||c-bar m*|| <= 2 B_s (integers, from the response norm
gate); (2) lift the mod-q relation to Z by multiplying with c-bar and
bounding every term's integer representative — the y and m* terms are
bounded by ||c-bar||_1 * |y|-class and 2 B_s, which is what SLACK_OP *
2 * y_bound conservatively charges; (3) apply Q4.4a to lower-bound the
left side and divide. Two steps are NOT proven: **[GAP 1, integer
lift]** c-bar acts by negacyclic convolution within ring chunks and
does not commute with the coefficient-selection structure of R, so
the vector the lift actually bounds is a challenge-mixed image, not
R b* itself; **[GAP 2, challenge dependence]** Q4.4a applies to
vectors fixed before R; b* is binding-fixed before R (good), but the
lifted vector of step (2) depends on c-bar, drawn after R. Therefore:
as coded, `SLACK_OP = 4D` is a *conservative derive-time budget gate*
(worst-case in every constant it composes) — it is NOT yet a proven
extraction bound, at q31 OR q46. Finding F3's q46 closure (0.84-bit
margin, GADGET_MODULUS_DECISION.md Section 1) rests on this
composition; the gap is about the derivation's validity, not about
constants that could still grow (||c-bar||_1 <= 4D is the worst case
of the factor it stands for). **OBLIGATION.**

**Lemma Q4.4' (the candidate direct-witness lemma — target statement;
what SLACK_OP would need to be, and under which lemma).** *Statement
to prove:* Let the round's commitments bind (b*, m*) before R is
derived from h0, and let the verifier accept only if the ARP
ct-claims verify and ||y|| <= y_bound. Then, except with the round's
knowledge error plus 2^-lambda over R: the extracted b* satisfies

    ||b*|| <= S_eff * y_bound / sqrt(rows / JL_C'),   S_eff ~ 2.

*Proof route (LNP22-style, direct-witness):* (i) message-side
exactness pins the per-row mod-q relations (no c-bar on b*); (ii) a
MOD-q anti-concentration form of the projection lemma: for any fixed
(b*, m*) with ||b*|| above the bound, the per-row values
<R_i, b*> + m*_i mod q land in the +-y-window with probability
bounded away from 1 per row, independently across rows — so all
`rows` range gates pass with probability 2^-256-class; (iii) the
range gate on the REVEALED integer y (this is where integers enter —
nowhere else). This is the composition [LNP22] uses (eprint 2022/284,
their approximate range proofs; the mod-q projection bound is their
Lemma 2.8/2.9-class machinery): the ||c-bar||_1 factor never touches
the witness, and only a ~2-class constant from the two-transcript
mask relaxation survives. **UNPROVEN — stated as the target;** the
paper's exact lemma statements and constants must be transcribed and
the Ajtai-mask relaxation composed before any budget moves onto it.
Quantitatively (from `scripts/gadget_modulus_study.py`): the q31
budget closes iff the composed slack is <= 3.79 at alpha = 3 (<= 11.4
at alpha = 1); if Q4.4' lands at S_eff = 2 the q31 margin is 0.9 bits
(alpha = 3) — the decision study therefore treats Q4.4' as a deletion
path, not a decision (option (c) verdict).

---

## Q4.5 — Digit-bundle salt aborts (Pi1/Pi2)

Covers: `ring_matmul.rs::prove_ring_pi1` (the salt loop),
`digit_fits`, `pi1_h0`/`pi2_h0` (salt in the statement hash),
`verify_ring_pi1`/`verify_ring_pi2` (the `salt > 64` cap), and the
in-file comment "abort transcripts are simulatable exactly like
rejection aborts".

**Setting.** The combined randomness rho_v = sum_j v_j rho_j must fit
L balanced base-2^e digits; on the rare overflow draw the prover
bumps a public salt in h0 and redraws v. The final proof carries the
accepted salt s; the verifier recomputes v from (h0, s) and rejects
s > 64.

**Lemma Q4.5a (abort transcripts are simulatable).** The only
abort-dependent output is the accepted salt value s (aborted salts
produce NO other public data — no masks or responses are emitted
before the fit check). Let p(rho) = Pr_v[some coefficient of
sum_j v_j rho_j does not fit (e, L)]. The simulator samples s
geometric with parameter 1 - p_hat, truncated at 64, for the PUBLIC
estimate p_hat; the statistical distance to the real transcript
distribution is <= sup_admissible_rho |p(rho) - p_hat| * E[s] + the
truncation mass. If p(rho) <= p* uniformly over honest (iid ternary)
rho, taking p_hat = 0 gives distance <= 65 p*. The digit capacity is
sized so the fit bound sits at the concentration tail of Q4.1b, so
p* is exponentially small in the per-coefficient tail —
"the honest abort probability per draw is tiny" (the code's own
comment), hence the distance is negligible and simulation is exact
to that order. **PROVEN conditional** on the uniform tail bound p*
(same cited concentration inequality as Q4.1b; a derive-time p* gate
per shape would discharge it numerically — freeze-check candidate).

**Lemma Q4.5b (FS grinding accounting for the salt).** A malicious
prover may evaluate the challenge derivation at up to 65 salt values
(cap enforced by the verifier) and choose the most favorable v: every
per-challenge soundness term multiplies by at most 65 = 2^6.03. At
the design's per-challenge error 2^-296.2 this gives 2^-290.2, and
post-FS (Q+1)^2 * eps <= 2^-162 — still 34 bits inside the C1'
target. Each salt trial is also one hash query, already inside the
Q = 2^64 budget; the cap's role is to pin the multiplicative factor
at 65 instead of Q + 1 (an uncapped salt would cost the full 2^64
factor and eat the C1' margin: 2^-296.2 * 2^64 * 2^129.5-grinding
would miss 2^-128 — the cap is load-bearing, not cosmetic).

*Proof.* Counting: the adversary's success is a union over <= 65
challenge derivations, each with the per-challenge error; the union
bound gives the factor. The verifier's recomputation of v from
(h0, s) makes any other salt path non-accepting. **PROVEN**
(elementary; both numbers from the design Section 2 accounting).

---

## Q4.6 — Twisted-execution ZK aggregate (the trace gate's Q-A2)

Covers (forward): AUTOMORPHISM_GATE_DESIGN.md Sections 2, 5 and Q-A2;
`ring_matmul.rs` gate-spike (identities only — it correctly has no ZK
layer to cover yet); the future U-A1 "traced claim sums" engine
feature and U-A2 gate build.

**Setting.** The trace gate runs h twisted executions from ONE
challenge pair (s, v): the twists sigma(s), sigma(v) are
deterministic, so the h executions expose h correlated combinations
of the same witnesses. The design checks the SUMMED identity
G_A - G_C = 0 against a single prover-supplied garbage aggregate, and
the 3h combos are opened by amortized (batched, possibly
digit-decomposed) responses.

**Obligation Q4.6 (the simulation obligation, stated precisely).**
The gate build must exhibit a simulator producing, from the statement
and h0 alone, the JOINT distribution of (i) the batched amortized
opening responses for the 3h combos, (ii) the traced garbage
aggregate(s), (iii) all reveals — indistinguishable from the real
prover's under the round's assumptions. Sufficient conditions this
lemma fixes as the build's acceptance criteria:

- **(O1) Aggregates only — an information-theoretic constraint, not a
  style choice.** Per-sigma objects must never be revealed: h
  executions individually would consume ~h * msg_r ring elements of
  mask-image against only N_r-class mask entropy per commitment
  (at the full group h = 128, msg_r = 32: 4096 image slots against
  N_r ~ 57-62 mask slots — joint uniformity is impossible, and
  distinguishers exist regardless of assumptions). The traced-sum
  engine feature must expose ONLY the summed identity's aggregate;
  differential/debug paths that print per-sigma claim data are ZK
  breaks, not test conveniences — the build's negative battery
  should include a per-sigma-exposure canary.
- **(O2)** Every batch response is rejection-sampled; the multi-batch
  restart rate follows Q4.2 (the joint-scaling variant applies to the
  batch bundles and is worth taking here, where bundle counts are
  largest).
- **(O3)** The garbage aggregate carries an additive mask slot: the
  sigma-sum of bilinear terms inherits Q4.3c's degeneracy (summing
  over H does not restore full support when the underlying
  multipliers are structured), so Q4.3's R1 applies to the aggregate
  exactly as to a single claim's Ga.
- **(O4)** Mask-image entropy: C4 at the gate layer's shape must
  cover the aggregate count plus the W-images consumed per claim
  (Q4.3a with the gate's msg_r and batch counts substituted).

Under (O1)-(O4) the simulator is the composition of Q4.2a (responses),
Q4.3a/b (images and reveals), and the identity-solving step for the
last aggregate — no new simulation technique is required; what is
required is that the build not violate (O1)/(O3) structurally.
**OBLIGATION** — assigned to the trace-gate build tranche
(U-A1/U-A2); this statement is its exit criterion, per the
discipline that caught F1/F2 (equations on paper first).

---

## 8. Status summary

| lemma | subject | status |
|---|---|---|
| Q4.1a | exact second moment of challenge combinations | PROVEN |
| Q4.1b | restart probability (completeness cost) | SKETCH (Hanson-Wright cited; empirical counters corroborate) |
| Q4.1c | restart-rule soundness accounting | PROVEN (i, as implemented) / SKETCH (ii, no-restart variant inventory) |
| Q4.2a | M-product law for multi-bundle rejection | PROVEN |
| Q4.2b | joint-scaling variant (21.1 -> 5.7 attempts) | PROVEN (engine change is a build item) |
| Q4.3a | mask-image uniformity; C4 = leftover-entropy line on N_r | SKETCH (standard reduction, hybrid unchecked) |
| Q4.3b | masked reveals/W's simulate | PROVEN (h) / SKETCH (W's, inherits Q4.3a) |
| Q4.3c | bilinear garbage terms unmasked — degenerate-tensor leak | OBLIGATION (engine fix R1 recommended) |
| Q4.4a | JL lower bound | CITED |
| Q4.4b | the coded SLACK_OP composition | OBLIGATION (two named gaps; budget gate, not proven bound — at q46 too) |
| Q4.4' | direct-witness ARP extraction, S_eff ~ 2 | UNPROVEN target statement (deletion path for F3's q46 layer) |
| Q4.5a | salt-abort transcripts simulatable | PROVEN conditional (uniform tail bound; freeze-check gate suggested) |
| Q4.5b | salt grinding: x65, cap load-bearing | PROVEN |
| Q4.6 | twisted-execution aggregate simulation (O1-O4) | OBLIGATION (trace-gate build exit criterion) |

The honest reading across the set: the two places where write-up
turned into FINDINGS rather than bookkeeping are Q4.3c (the current
quadratic layer's garbage terms can leak bit-plane degeneracy — an
engine change is recommended before U6 gadgets carry real data) and
Q4.4b (the ARP's extraction constant is a budget gate at both moduli,
which reframes F3's q46 closure as "best-grounded available" rather
than "proven" — priced accordingly in GADGET_MODULUS_DECISION.md).
