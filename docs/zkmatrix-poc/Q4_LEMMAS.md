# Q4: The Lemma Write-Ups

Status: the accumulated Q4 lemma-writing debt of ROUTE_R_DESIGN.md
(Section 9 item 4), ROUTE_R_BUILD_REPORT.md (Section 2) and
AUTOMORPHISM_GATE_DESIGN.md (Q-A2/Q-A3), stated as numbered lemmas
Q4.1-Q4.6 at the lattice report's discipline: full proofs where
elementary, honest SKETCH labels with literature anchors where not, and
OBLIGATION labels where the statement fixes acceptance criteria for
work that has not been done. Each lemma names the code it covers.
Lemmas Q4.7-Q4.9, added by tranche U-K5e, transcribe the
zero-knowledge masking lemmas of the lookup subprotocol's E3-Z design
round (M4_LOOKUP_ZK_DESIGN.md Section 4) at the same discipline; they
live over GF(q^16), not the lattice ring, so their setting is defined
where they start (the notation paragraph below is the lattice
layer's). Summary table in Section 8.

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
Rudelson-Vershynin, Hanson-Wright inequality (ECP 2013); [XZZPS19]
Xie-Zhang-Zhang-Papamanthou-Song, Libra, CRYPTO 2019 = eprint
2019/317 (the ZK sumcheck/GKR masks adapted in Q4.7-Q4.9).

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

Covers: `ring/ct_engine.rs::prove_ct_round` /
`prove_ct_round_tq` (the `gq = [Ga, Gb, G0]`, `gr = [G1, G0]` and
`gtq = [Ga, Gb, G0]` constructions and `w_quad`/`w_qring`/`w_tq`),
`verify_ct_round_tq` (the sigma(c) c h = E + ... check), the module
header's "ZK NOTE (Q4-class)", and `ring/commit.rs` (A2 rows).

**REVISION NOTE (U-P1, 2026-07-09).** This lemma was re-derived from
scratch during the proof-debt tranche and a PRIOR OVERCLAIM WAS FOUND
AND RETRACTED. The old Q4.3c argued the garbage terms simulate "for
generic x" and fail only for degenerate (all-zero) bit planes. That
mechanism is WRONG: it treats the mask images Y as a fresh entropy
source that hides the witness, but Y is pinned by the revealed
response z, so the exposed combinations are witness-images regardless
of Y's marginal distribution or the witness's genericity. The correct
statement (Q4.3d/e below) is that EVERY quadratic claim — twisted,
untwisted, ct-projected, the gate included — leaks a fixed public
linear/quadratic image of its witness in the clear, and for the
committed-executions gate that image is the product matrix C itself.
The old sub-lemmas Q4.3a/b are kept (they are true as far as they go)
but re-graded; Q4.3c is rewritten as Q4.3c'. The R1 fix (now a full
spec, Section R1 below) is upgraded to mask W as well as Ga/Gb/G1.
Every identity below is machine-checked in `scripts/zk_lemma_check.py`.

**Setting.** Per sigma-twisted quadratic claim the prover sends, in
the clear and before the challenge, Ga = sum_p gamma_p sigma(x_ap)
Y_bp, Gb = sum_p gamma_p x_bp sigma(Y_ap), G0 = sum_p gamma_p
sigma(Y_ap) Y_bp, plus W_quad; Y_i := A2 y_i are the message-side
mask images of the Gaussian masks. The reveals h carry a g-mask with
ct(g) = 0 and uniform other coefficients. Write P_i := c t2_i - A2 z_i
for the verifier-computable virtual openings; the honest algebra gives
P_i = c x_i - Y_i (Section 3.1 of SOUNDNESS_REFERENCE), so
**Y_i = c x_i - P_i** — the identity that drives Q4.3d.

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
**SKETCH, and BESIDE THE POINT for the leak.** (reduction shape
standard; the precise hybrid over the round's several mask bundles
sharing one A2 is written but not mechanically checked.) Q4.3d shows
that Y's marginal uniformity does NOT rescue ZK: the leak is an
algebraic identity that holds pointwise for every Y, so however
uniform A2 y looks in isolation, the exposed combinations W + aP = cL
etc. are the same fixed witness-images. Q4.3a remains a true statement
about the marginal (and is what commitment hiding rests on), but it is
not the lever for the quadratic-layer ZK question.

**Lemma Q4.3b (which head pieces genuinely simulate).** (i) Each
reveal h = Q + L + g with ct(g) = 0, other coefficients uniform and
independent: h is uniform on the hyperplane ct(.) = scalar — a
one-time pad on the D-1 non-ct coefficients. **PROVEN** (exact,
information-theoretic) — BUT note (Q4.3d) that h taken TOGETHER with
W_quad still leaks c Q, because the same g-slot mask image appears in
both and cancels. (ii) The LINEAR-claim images: W_claim (of a linear
`CtClaim`) and W_ring (of a linear `RingClaim`) are FORCED by their
verification equations — the verifier recomputes W_ring = ZA - c C
+ c K and W_claim = c h - c C + ZA - ZS from public/response data, so
the prover must send exactly that value and it carries zero
information; the simulator recomputes it. **PROVEN** (this is what
"linear-claim images simulate" means, and it is correct only for the
linear families). The tie's W_ring images (Appendix B.1) are of this
kind. (iii) The QUADRATIC-claim images W_quad/W_qring/W_tq are NOT
forced individually — they enter the quad check as one free term among
{Ga, Gb, G0, W} — and they DO leak (Q4.3d); the old claim that they
"simulate as fresh uniforms" is retracted. **CORRECTED.**

**Lemma Q4.3d (transcript-determinism and the exact leak).** Fix an
accepting transcript (com, head, z) with challenge c. Substituting
Y_i = c x_i - P_i (the Setting's identity, with P verifier-computable)
into the head definitions makes every head image a deterministic
affine function of the witness x and verifier-computable data. Two of
these functions collapse to VERIFIER-COMPUTABLE witness-images:

  (L1, the linear leak) For any quadratic claim with linear part
  L := sum a x, the linear mask image satisfies the algebraic identity

        W + sum_l a_l P_l  =  c L                                (Q4.3d-1)

  because a_l P_l = a_l(c x_l - Y_l) sums to c L - W. The left side is
  the head element W plus a verifier combination of the P table, so
  **c L is public**; c is quinary and invertible except with
  probability ~ 8 q^-16 = 2^-493-class (LS18), so the witness-image
  **L is public**.

  (Q1, the ct-quadratic leak) For a `QuadCtClaim` with reveal
  h = Q + L + g (g in message slot sl):

        c h  -  ( W_quad + sum_l a_l P_l + P_sl )  =  c Q       (Q4.3d-2)

  where P_sl = c t2_sl - A2 z_sl is verifier-computable. The g-slot
  mask image (A2 y)_sl sits in BOTH W_quad and P_sl and CANCELS, so the
  g-mask that hides the non-ct coefficients of h does NOT hide Q: **c Q
  is public**, hence the full ring element **Q is public** (c
  invertible). The g-mask still does its job — it hides h's non-ct
  coefficients individually — but the pairing with W_quad defeats it
  for Q.

Both identities are exact ring identities (no distribution assumed);
both are machine-checked (`zk_lemma_check.py`, OK-1/OK-2a). The
consequence: the quadratic layer as built reveals, in the clear, the
witness's quadratic-form value Q and its linear image L. **PROVEN
LEAK** — this is a hard negative, not a missing sketch.

**Lemma Q4.3e (corollary — the committed-executions GATE leaks C).**
The gate is one `TwistedQuadRingClaim` (Section 4.5 /
AUTOMORPHISM_GATE_DESIGN.md Appendix B) with quadratic part
Q = sum_s conj(YA_s) YB_s and linear part
L = -sum_s conj(shat_tw_s) YC_s = -G_C, where by the trace theorem
(Section 5.2) G_C = D * sum_ij conj(s_i) v_j C[i][j]. By Q4.3d-1 the
transcript makes c L public, hence L = -G_C public, hence

        G_C = D * sum_ij conj(s_i) v_j C[i][j]

is a public ring element. With s, v public and D a unit, this is 128
linear equations (the coefficients of G_C) in the rows*cols entries of
C; for any nondegenerate (s, v) the system has full column rank and
**C is recovered exactly**. Verified at the demo parameters (D = 128,
q = 2^31 - 399, rows = 4, cols = 3): rank 12/12, exact recovery
(`zk_lemma_check.py`, OK-4). Since C = A B is hidden by its commitment
(MLWE), no simulator lacking C can produce this transcript.
**Therefore the committed-executions gate, with W_tq sent in the
clear, is NOT zero-knowledge: it leaks the product matrix.**
This is the same failure for every quadratic claim (binary gadget
included: Q4.3d-2 leaks its bit-tensor autocorrelation Q); the gate is
the loudest instance because its leaked image is the very quantity the
protocol exists to hide. The fix is R1 (below), now mandatory rather
than recommended.

**Q4.3c' (superseded — the old degeneracy story, corrected).** The
retracted argument observed that Ga = sum gamma sigma(x_a) Y_b, viewed
as a function of a *free* Y, has support the submodule generated by
{gamma sigma(x_a)}, and worried only about that support collapsing for
all-zero bit planes. Q4.3d shows the premise (Y free) is false: Y is
pinned by z, so the leak is present for GENERIC x too, and the
degenerate-tensor case is merely one visible symptom of a leak that is
always there. The discharge route is unchanged in spirit but its scope
is larger: **(R1)** additive one-time-pad slots on Ga, Gb, G1 AND on
W (the old spec missed W — see Q4.3d-1); **(R2)** a per-claim
regularity hypothesis is not merely "unacceptable for degenerate
tensors" but INSUFFICIENT in principle (it cannot mask the exact
identities Q4.3d-1/2, which hold for every x). Only R1 closes it.
Status of Q4.3 overall: the leak is **PROVEN**; the fix (R1) is
specified below and **BUILT** (the R1 engine tranche — see the
Section R1 status line and R1.4').

---

## R1 — the committed garbage-mask hardening spec (BUILT)

**STATUS (R1 engine tranche, 2026-07-09): BUILT.** The spec below is
implemented in `ct_engine.rs`: every quadratic claim family
(QuadCtClaim, QuadRingClaim, TwistedQuadRingClaim) carries committed
pads in the round's g-slot space (layout in the engine's
quadratic-layer header; callers size the groups with `sample_g_masks`
+ `r1_pad_count`), the prover sends only the masked images, and the
verifier subtracts the pad openings. The R1.2 hash-edge row is merged
into SOUNDNESS_REFERENCE.md Section 7 and pinned by the live `[R1]`
battery: leak non-recovery pairs for all three quadratic families
(Q4.3d-1 untwisted, the gate-form C-image of Q4.3e, and the Q4.3d-2
Q-leak) and both-direction order pairs at both monomial shapes;
freeze-check pins the pad counts. Measured deltas and one costing
correction: R1.4' below.

This is the exact spec the engine tranche implemented to discharge
Q4.3d/e. It sharpens the post-merge R1 note (Q4.3c') into prover
messages, hash edges, a soundness argument for the masked variant, and
cost deltas. Completeness of every check equation below is
machine-checked in `scripts/zk_lemma_check.py` (OK-3a twisted, OK-3b
untwisted); the twisted algebra also covers the ct-projected variant
(same monomial structure, plus the untouched reveal h).

### R1.1 New prover messages (per quadratic claim)

Draw fresh UNIFORM ring pads (no ct constraint — they are one-time
pads, not reveals) and commit them in g-group message slots that h0
already binds:

- **Twisted families** (`QuadCtClaim`, `TwistedQuadRingClaim`; the
  gate is one of these). Three pads (ma, mb, mw). Because the check
  multiplies the Ga and W terms by sigma(c) and the Gb term by c, the
  two sigma(c)-side pads are committed PRE-CONJUGATED so that a
  STANDARD virtual opening supplies the twisted monomial:

      slot holds conj(ma);  P_MA := c*conj(ma) - Y_MA;
                            conj(P_MA) = sigma(c)*ma - conj(Y_MA)
      slot holds mb;        P_MB := c*mb - Y_MB
      slot holds conj(mw);  P_MW := c*conj(mw) - Y_MW;
                            conj(P_MW) = sigma(c)*mw - conj(Y_MW)

  The prover sends the MASKED head images (same element count as
  today, values shifted):

      Ga~ = Ga + ma,   Gb~ = Gb + mb,   W~ = W + mw,
      G0~ = G0 + conj(Y_MA) + Y_MB + conj(Y_MW).

  Masked check (verifier subtracts the three pad openings):

      sigma(c) c h = E + sigma(c) Ga~ + c Gb~ - G0~
                     + sigma(c)(c C_L - ZA_L + W~)
                     - conj(P_MA) - P_MB - conj(P_MW).

  For `TwistedQuadRingClaim` (the gate) drop h (RHS top monomial is 0);
  everything else is identical.

- **Untwisted family** (`QuadRingClaim`). The check multiplies G1 and
  W by c only (no twist), so two PLAIN pads (m1, mw):

      slot holds m1;  P_M1 := c*m1 - Y_M1
      slot holds mw;  P_MW := c*mw - Y_MW
      G1~ = G1 + m1,  W~ = W + mw,  G0~ = G0 + Y_M1 + Y_MW,
      check:  E2 + c G1~ - G0~ + c(c C_L - ZA_L + W~)
              - P_M1 - P_MW = 0.

The pads ride the round's existing g-commitment (they share its
randomness rho and its response z), so R1 adds NO new response bundle
and NO new rejection test — only message slots and their A2 rows.

### R1.2 Hash-ordering requirement (Section 7 rows — MERGED)

R1 introduces no new challenge. Its one ordering requirement is that
the pads be committed BEFORE the round challenge c — which is already
enforced, because the pads live in g-commitments and c = XOF(h0,head)
with h0 binding every commitment. The requirement is nonetheless
load-bearing; its audit row is MERGED into SOUNDNESS_REFERENCE.md
Section 7 (the engine tranche landed) and pinned by the live `[R1]`
order pair:

| challenge | drawn from | must follow | attack if violated | pinned by |
|---|---|---|---|---|
| c (round challenge) — R1 addendum | XOF(h0, head) | the R1 pad commitments (ma/mb/mw or m1/mw), in h0 | pad re-chosen after c: t2 shift by c·Delta absorbs a false claim's defect; pad = -Ga un-masks the head, Q4.3d leak returns | `R1 order: pad-after-challenge ACCEPTS the un-mask; pad-in-h0 REJECTS` |

The attack is the exact analogue of the F5 g-shift (Section 4.3 of
SOUNDNESS_REFERENCE): a pad chosen with knowledge of c can cancel the
witness image it is meant to hide (and, sharper — as the built
regression demonstrates — a pad OPENING re-chosen after c absorbs a
false claim's defect at the top monomial, so the unbound-pad world
loses soundness too). The regression demonstrates BOTH directions,
like the F5 pair.

### R1.3 Soundness and ZK of the masked variant

**Soundness UNCHANGED [PROVEN].** The masked check is the old check
plus terms that vanish under three-transcript extraction: each pad
term sigma(c) ma - conj(P_MA) (resp. c mb - P_MB, etc.) is, by the
pad's own message-side identity, a pre-challenge image times a
challenge monomial — exactly the shape the Vandermonde clearing of
SOUNDNESS_REFERENCE Section 3.3 already annihilates. The top monomial
(sigma(c) c for twisted, c^2 for untwisted) still carries Q + L only;
the pads contribute to strictly lower monomials. So extraction pins
Q + L = 0 as before; per-slot knowledge error 2^-296 is untouched. (In
particular the pads cannot help a cheating prover: they are committed
before c and enter only lower monomials.)

**ZK now PROVEN under MLWE only [PROVEN, machine-checked completeness].**
The simulator: sample z (rejection Gaussian, witness-independent —
standard Lyubashevsky), compute w1/P/E and the pad openings P_M* from
z; sample h uniform on ct(.) = scalar (Q4.3b-i); sample Ga~, Gb~, W~
(resp. G1~, W~) UNIFORM; solve the check for the unique G0~; program
the RO at (h0, head) = c. Indistinguishability: Ga~ = Ga + ma is a
perfect one-time pad because ma is uniform and, apart from Ga~, appears
only inside the hiding pad commitment and inside P_MA (where Y_MA masks
it) — so (Ga~, Gb~, W~) are jointly uniform and independent of the
witness, EXACTLY (information-theoretic), and the pad commitments are
hiding under the round's MLWE assumption. G0~ is then the forced
check-solution in both worlds, so it matches automatically. No
knapsack-MLWE-on-images (old Q4.3a), no smudging, no regularity
hypothesis is needed — the masked variant's HVZK reduces to the
commitment hiding already assumed plus the rejection lemma (Q4.2a).
This is the discharge; the residual engine-build OBLIGATION it named
has since been met (the R1 tranche — R1.4' for the measured deltas).

### R1.4 Cost deltas

Per quadratic claim: +3 (twisted) or +2 (untwisted) message slots in
the g-commitment, i.e. +3 (or +2) ring elements of t2 and the matching
A2 rows in the CRS shape; the head element COUNT is unchanged (Ga~,
Gb~, G0~, W~ replace Ga, Gb, G0, W). No new response, no new rejection
bundle, so prover TIME grows only by 3 (or 2) extra A2-matvec rows and
a handful of ring mults per claim — sub-percent at every measured
shape. Proof SIZE grows by +3 (or +2) ring elements per claim:
~3 * D * ceil(log2 q) bits = 3 * 128 * 31 bits ≈ 1.5 KB per twisted
claim at q31. For the committed-executions gate (ONE twisted claim per
matmul) the marginal is ~1.5 KB against the gate's measured
~1.23 MB/claim (SOUNDNESS_REFERENCE 5.7) — a ~0.1% size increase to
close the ZK leak. The binary gadget (U6) carries one quad claim per
partitioned unit; the delta scales with the unit count and is likewise
sub-percent of the gadget's opening volume. Freeze-check should gain
one row pinning "quad-claim g-slot count includes the R1 pads" so a
future refactor cannot silently drop them.

### R1.4' — measured costs and a costing correction (engine tranche)

The R1.4 estimate above holds for rounds that ALREADY carry a
g-commitment (quad ct-claim rounds: the pads ride its tail slots and
share its rho/z — slots only, sub-percent, as promised). It missed two
cases, both measured when the engine tranche landed:

- **Gate-only rounds have no g-commitment to ride.** The
  TwistedQuadRingClaim rounds (the CE gate + tie demo and pi2-CE's
  round W) previously had NO g-commitment, so R1's pads cost one
  FRESH commitment + opening at the round's (wide) shape, not +3 t2
  rows. Measured: CE gate + tie marginal ~1.35 MB vs ~1.23 MB
  (~+116 KB, ~9%) at rows=4/inner=128/cols=3 msg_r=128; pi2-CE
  ~2.74 MB vs ~2.5 MB at 128x256x64 msg_r=256. Still far below the
  8.7-12.9 MB scalar gate; folding the 3 pad slots into an existing
  wide commitment's msg_r is the recorded follow-up optimization.
- **msg_r = 1 shapes break at wave scale.** With one message slot per
  commitment, EVERY pad costs a full commitment (3 per quad ct-claim),
  and the wave round's C2 std-bundle budget can fail at q31: the
  chain-demo wave hit 177 commitments, 8*beta = 1.26x q. Rule: rounds
  carrying quadratic claims use msg_r >= 2 (the chain demo bumps
  msg_r 1 -> 2 riding one extra N_r row, the standard C4 pattern).
  The scalar-gate pi2 pays +3 pad slots/repetition (measured
  ~218 KB/rep vs ~202 — the pads share the per-rep g-group).

Prover/verifier TIME at the measured shapes is unchanged within noise
(CE gate + tie 202/180 ms; pi2-CE 2.0 s/1.0 s; suite total ~32 s).

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
of the factor it stands for). **OBLIGATION — but SUPERSEDED as the
proven bound by Q4.4c (U-P4):** the coded `SLACK_OP = 4D` line stays
as the derive-time gate the engine runs, but the ACTUAL proven
extraction bound is now Q4.4c (2.35 bits tighter, no lift, no c-bar).
Q4.4b's two gaps remain unclosed only for the specific SLACK_OP
composition, which nothing needs to rest on any more.

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

**Lemma Q4.4c (self-contained coordinate-wise direct-witness bound —
DISCHARGED, U-P4).** A weaker-than-Q4.4' but fully PROVEN bound that
already beats the coded SLACK_OP gate, with none of Q4.4b's gaps.

*Statement.* Suppose the round binds (b*, m*) before R = XOF(h0) is
drawn, the ARP linear ct-claims pin y_i ≡ <R_i, b*> + m*_i (mod q) for
every row i (message-side, EXACT mod q — no c-bar), and the verifier
accepts only if each revealed integer y_i lies in the window
[-y_bound, y_bound] (with 2 y_bound < q). Then

    ||b*||_inf <= 2 y_bound   except with probability <= 2^-rows,
    hence  ||b*||_2 <= 2 y_bound * sqrt(n).

*Proof.* Suppose some coordinate has |b*_j| > 2 y_bound (centered
representative). Fix any row i; condition on m*_i and on all entries of
R_i except R_ij (all fixed before R_ij by independence of the JL
entries), so v := <R_i, b*>_{k != j} + m*_i is fixed mod q and
y_i ∈ {v, v + b*_j, v - b*_j} (mod q) as R_ij ∈ {0, +1, -1} with
probabilities (1/2, 1/4, 1/4). The window has width 2 y_bound < |b*_j|,
so no two of {v, v ± b*_j} that differ by |b*_j| can both be window
integers; hence at most one of v and v+b*_j is in the window, and at
most one of v and v-b*_j. The window-hit probability is therefore
1/2·1[v in W] + 1/4·1[v+b in W] + 1/4·1[v-b in W]: if 1[v in W] = 1 the
other two indicators are 0 (sum 1/2); if 1[v in W] = 0 the sum is at
most 1/4·(1+1) = 1/2. So Pr[row i's range gate passes] <= 1/2, for
EVERY b*_j including the near-q/2 wrap regime (the wrap only makes
v+b and v-b close to each other, never to v, and R_ij = ±1 carries
total mass 1/2). The rows use disjoint entries of R, so the events are
independent given (b*, m*): Pr[all rows pass] <= 2^-rows. Since R is
drawn strictly after (b*, m*) are binding-fixed, the whole argument
uses R's randomness ALONE. **PROVEN** (machine-checked: the per-row
1/2 bound is tight at 0.490 in `zk_lemma_check.py` OK-5b; the l2 value
2 y_bound sqrt(n) is OK-5a).

*Why this discharges Q4.4b's gaps.* GAP 1 (integer lift through c-bar)
never arises — the argument reads the revealed integer y_i directly
against the mod-q ct-claim, no lift. GAP 2 (challenge dependence) never
arises — b* and m* are fixed before R, and c-bar (the round challenge)
does not enter at all. So the two named gaps are RESOLVED for THIS
bound. The price is that the l_inf -> l_2 conversion costs a full
sqrt(n) rather than JL's sqrt(rows/JL_C); Q4.4c is thus LOOSER than the
Q4.4' target (S_eff ~ 2 via JL) but TIGHTER than the coded gate.

*Numeric standing (machine-checked, `zk_lemma_check.py` OK-5a).* At
the frozen ARP point (n = 512, rows = 256, alpha = 3): y_bound =
2^14.23; coded extract_bound (SLACK_OP = 4D, JL) = 2^22.08; Q4.4c
extract = 2 y_bound sqrt(n) = 2^19.73 — **2.35 bits tighter** than the
coded gate. So every budget that closes under the coded gate closes by
>= 2.35 more bits under Q4.4c, and Q4.4c requires no unproven lemma.
Whether the extra margin moves q31 from KNOWN-OPEN to closing is a
numeric call for `gadget_modulus_study.py` (the coded gate's ~2.9-bit
q31 shortfall vs the study's threshold), OUT OF THIS DOC'S LANE —
flagged as a follow-up, NOT claimed. Q4.4c stands on its own as a
proven direct-witness bound; Q4.4' remains the tighter target for when
the JL constant is transcribed.

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
- **(O3)** The garbage aggregate carries additive mask slots: by the
  CORRECTED Q4.3d (not the retracted degeneracy story), the
  sigma-sum of bilinear terms leaks its aggregate quadratic/linear
  witness-image for EVERY witness (not only structured ones), so
  Q4.3's R1 applies to the aggregate exactly as to a single claim's
  (Ga, Gb, W) — and, per the U-P2 spec, W must be masked too.
- **(O4)** Mask-image entropy is NOT the operative condition (Q4.3d
  supersedes the leftover-entropy framing): the aggregate's ZK rests
  on the R1 pads being uniform and their commitments hiding, i.e. on
  MLWE at the gate layer's C4 shape (which the round already assumes),
  not on A2 y looking uniform.

Under (O1)-(O4) the simulator is the composition of Q4.2a (responses),
Q4.3b (linear images and reveals) + R1 (masked quadratic images), and
the identity-solving step for the last aggregate — no new simulation
technique is required; what is required is that the build not violate
(O1)/(O3) structurally.
**OBLIGATION** — assigned to the trace-gate build tranche
(U-A1/U-A2); this statement is its exit criterion, per the
discipline that caught F1/F2 (equations on paper first).

---

## Q4.7 — Adapted Libra counting (lookup round masks are uniform on
the check variety)

Covers: M4_LOOKUP_ZK_DESIGN.md Section 3.2 (the M1 round masks) and
Section 4 component 4; `scripts/logup_zk_mask_spike.py` (certificate
Z3c); (forward) the U-K5b masked-sumcheck engine build and the U-K5d
battery item E3Z-N4 (the same rank certificates as derive-time
canaries at engine shapes).

**Setting (shared by Q4.7-Q4.9 — the E3-Z lookup masking).** These
three lemmas live in the SiLU-lookup subprotocol of
M4_LOOKUP_DESIGN.md, not the lattice layer: all arithmetic is over
the field K = GF(q^16) (q = 2^31 - 399, |K| ~ 2^496), and the
protocol is the LogUp-GKR fractional descent — per instance, a
witness tree and a table tree of fractional values, descended layer
by layer (root = layer 0, leaves = layer J) by one sumcheck per layer
(the "layer sumcheck"), each reducing a claim about layer j to the
four boundary values of layer j+1. M4_LOOKUP_ZK_DESIGN.md (the E3-Z
design round) adds three mask families, all committed under the
lookup statement hash h0_lkp BEFORE the fusion challenge alpha and
all fresh per pass: M1 round masks (this lemma), M2 boundary masks
(Q4.8a), M3 blinder leaves (Q4.8b, Q4.9). Symbols, defined once here:

- **ell** — the number of rounds of one layer sumcheck (tree
  variables plus instance bits plus the ZK dummy variable w, one w
  per layer sumcheck); **d_t** — the degree of round t's polynomial
  (the E3-Z pattern: 5 for the first tree round when the children
  are masked, 3 for the other tree rounds, 2 for the w-round).
- **g^(j)** — the layer-j round mask, Libra Construction 1 shape
  [XZZPS19]: g^(j)(x_1..x_ell) = a_0 + g_1(x_1) + ... + g_ell(x_ell)
  with each g_t univariate of degree d_t; the constant terms of the
  g_t are absorbed into a_0, so g^(j) has exactly
  **n_g := 1 + sum_t d_t** free K-coefficients.
- **G_j** — the hypercube sum of g^(j), sent by the prover and
  E4-pinned. An "E4 pin" is a linear CtClaim with public weights over
  committed data — the [PROVEN] family of SOUNDNESS_REFERENCE.md
  Section 4.2; a pinned value carries no free choice for the prover.
- **nu_j** — the mask-combination challenge (Libra's rho, renamed
  because rho is taken by instance batching), drawn from the
  transcript hash after the layer claim C_j and G_j are fixed; the
  layer sumcheck then runs on F_j + nu_j·g^(j) with initial claim
  C_j + nu_j·G_j, where F_j is the layer summand (boundary-masked
  per Q4.8a).
- **Exposure / pad** — an exposure is a transcript value visible to
  the verifier; a pad is a committed uniform mask degree of freedom.
  Every hiding claim below is a rank statement: exposures are affine
  (or variety-constrained) images of pads with full row rank.

**Hypotheses.** (H1) The n_g coefficients of g^(j) are drawn uniform
in K, fresh for this pass (mask reuse across passes subtracts out and
reopens the leak — battery item E3Z-N3), and committed under h0_lkp
before alpha, hence before nu_j. (H2) nu_j != 0 (guard (b) of
M4_LOOKUP_ZK_DESIGN.md Section 3.4; a zero nu_j erases the mask from
the run, and the derive-time guard restarts the draw). (H3) The
verifier's forced relations are the ell per-round checks
gtilde_t(0) + gtilde_t(1) = C_t (gtilde_t the sent round polynomial,
C_t the running claim, folded forward by Lagrange evaluation at the
round challenge) plus the end check on the final claim — ell + 1
relations in total.

**Lemma Q4.7 (counting and uniformity).** Per layer sumcheck the
mask-bearing exposures are: the d_t + 1 evaluations of each round
polynomial, the sum G_j, and the end opening g^(j)(r, c) (r the
tree-round challenges, c the w-round challenge). Their count net of
the forced relations is

    (sum_t (d_t + 1)) + |{G_j}| + |{g^(j)(r,c)}| - (ell + 1)
        = (sum_t d_t + ell) + 1 + 1 - ell - 1
        = 1 + sum_t d_t = n_g,

exactly the free-coefficient count of g^(j). The affine map from the
n_g mask coefficients to the full exposure vector (G_j, every round
evaluation, the opening) has full rank n_g, with exactly ell + 1
forced check relations among the exposures. Consequently, under
(H1)-(H3), the exposures are uniform on the **check variety** — the
affine subspace of exposure vectors satisfying the ell + 1
verification relations for the given initial claim — independently
of the witness. The simulator therefore needs no witness: per round
it samples d_t evaluations free (the remaining one is forced by the
running check) and it solves the g-opening from the end check.

*Proof sketch (transcribed from M4_LOOKUP_ZK_DESIGN.md Section 4
component 4; the counting is Libra Theorem 4.1's [XZZPS19], adapted
to the E3-Z round-degree pattern).* Every exposure of the masked run
is (a witness-and-challenge-determined value) plus nu_j times a fixed
affine functional of the mask coefficients: the round evaluations
evaluate F_j + nu_j·g^(j) at public points, and G_j and the opening
are affine in the coefficients outright. The ell + 1 check relations
hold identically on every honest run (completeness), so the exposure
vector always lies on the check variety, whose dimension is the
displayed count, n_g. Full rank of the coefficient-to-exposure map —
the content beyond the counting — means the mask contribution alone
sweeps the whole variety: the image of a uniform vector of K^{n_g}
under a full-rank affine map onto an n_g-dimensional affine variety
is uniform on it, and adding the witness-determined part is a
translation inside the same variety (the check relations already
account for it). Uniformity on the variety follows for every
witness. The rank claim is where a degeneracy could hide, and the
rank is exactly what the spike certifies. QED sketch.

*Spike certificate.* `logup_zk_mask_spike.py` Z3c at the probed
layer (ell = 3 rounds of degrees 5/3/2, so n_g = 11): the affine map
from the 11 mask coefficients to (G, all round-polynomial
evaluations, g(r, c)) has rank 11 with exactly ell + 1 = 4 forced
check relations — "the Libra Thm 4.1 counting, machine-checked"
(output recorded verbatim in M4_LOOKUP_ZK_DESIGN.md Section 8).

Status: **[PROVEN at engine scale — battery E3Z-N4 green (U-K5d,
2026-07-10)]**: the coefficient-to-exposure map is rank-certified
n_g with exactly ell + 1 forced relations as a derive-time canary at
engine shapes (the `[U-K5d]` battery in the ring self-test), and the
committed masked pass plus the engine-scale m-recovery harness
(`[U-K5c]`) close the leak these masks exist for.

---

## Q4.8 — Boundary-mask and blinder-pad rank (one-time-padded
boundary values)

Covers: M4_LOOKUP_ZK_DESIGN.md Section 3.2 (the M2 boundary masks
and the M3 final blinders) and Section 4 components 5-6;
`scripts/logup_zk_mask_spike.py` (certificates Z3c interior, Z3b
leaf); (forward) the U-K5c blinder build and the U-K5d E3Z-N4
canaries.

**Setting.** Notation of Q4.7's shared setting, plus the two mask
objects this lemma is about:

- **Rp_j, Rq_j** — the layer-j boundary masks (M2): committed
  bivariate polynomials of degree (1, 2) in (z_1, w) — six
  K-coefficients each — with the Boolean w-sums
  **SP_j(z_1) := Rp_j(z_1, 0) + Rp_j(z_1, 1)** and SQ_j likewise
  (z_1 is the fold coordinate of the layer's claim point z, w the ZK
  dummy variable). The masked layer polynomial is
  p^dot_j(z) := p_j(z) + Zhat_j(z)·SP_j(z_1) with
  Zhat_j(z) := z_2(1 - z_2) (z_2 the first suffix coordinate of z;
  Zhat vanishes on the hypercube, so every summed relation sees the
  true tree), and q^dot_j likewise with SQ_j. Interior layers
  2 <= j <= J-1 carry the mask; layer 1 and the leaf layer J do not
  (they are actual hypercube values — obstruction O-2 of the design
  — and are handled by blinders instead).
- **Blinder leaves** (M3) — committed pairs (a, u) with u != 0 at
  public dummy leaf positions; the leaf value there is (p, q) =
  (a, u). Per tree: two TOP blinders, one in each half of the leaf
  layer (their exposures are Q4.9's), and two FINAL blinders, one at
  an even and one at an odd position — the last sumcheck's boundary
  points (0, r) and (1, r) give nonzero eq-weight only to positions
  of matching parity, so both parities must be padded. Freeze row
  LKP-6 pins the placement.

At the end of the layer-j sumcheck the prover sends the four masked
boundary values vp0 := p^dot_{j+1}(0, r), vp1 := p^dot_{j+1}(1, r),
vq0, vq1 (r that sumcheck's tree-round challenges), plus, for
j >= 2, the openings Rp_j(mu, c), Rq_j(mu, c), where mu is the fold
challenge that formed the layer's incoming claim point and c is the
sumcheck's w-round challenge; every opening is E4-pinned.

**Lemma Q4.8a (interior layers: rank 6/6).** Fix an interior layer
j. The transcript exposes exactly three functionals of Rp_j's six
coefficients: SP_j(0) and SP_j(1), which enter the boundary values
sent at the end of the layer-(j-1) sumcheck (the values that claim
layer j) as the pads E_r·SP_j(0) and E_r·SP_j(1), where
E_r := r_1(1 - r_1) is the public Zhat-factor at the two boundary
points and r_1 is that sumcheck's first tree-round challenge; and
the opening Rp_j(mu, c). The same three functionals of Rq_j are
exposed. Hypotheses: the twelve coefficients of the pair
(Rp_j, Rq_j) uniform and fresh per pass, committed under h0_lkp
before alpha; guard (a) of the design's Section 3.4 (r_1 not in
{0, 1}, so E_r != 0); and the w-round challenge c outside {0, 1}
(not one of the enumerated restart guards — see the sketch's closing
note). Claim: the six exposures are a full-row-rank (rank 6) affine
image of the twelve pad coefficients, so the four interior boundary
values and the two openings of each interior layer are JOINTLY
one-time-padded — uniform on K^6, independent of the witness — and
the simulator samples them uniform (Z3d does exactly this).

*Proof sketch (component 5 of the design's Section 4).* Write
Rp_j(z_1, w) = sum_{a <= 1, b <= 2} r_ab z_1^a w^b. SP_j(0) reads
the z_1-constant half (r_00, r_01, r_02) through the w-weight vector
(2, 1, 1) — the sum of the w = 0 and w = 1 Vandermonde rows; and
SP_j(1) - SP_j(0) reads the z_1-linear half (r_10, r_11, r_12)
through the same vector — the two Boolean sums touch disjoint halves
of the coefficient space. The opening Rp_j(mu, c) reads both halves
through the w-Vandermonde row (1, c, c^2), which for c outside
{0, 1} lies outside the span of the Boolean-sum rows — three
independent rows per polynomial, six for the pair. The boundary
values expose SP_j/SQ_j only through the common nonzero scalar E_r,
which changes no rank. Closing note on thinness, flagged rather than
papered over: the design doc carries this independence argument in
one parenthetical, and c not in {0, 1} is not on its Section 3.4
restart-guard list — it falls under the design's Section 7 item 1
("rank degeneracies", each of probability ~2/|K| ~ 2^-495 per pass),
which the E3Z-N4 derive-time canaries are specified to catch at
engine shapes. The toy-scale rank is machine-checked. QED sketch.

*Spike certificate.* Z3c: "middle-layer boundary + opening exposures
have rank 6/6 over the R-mask coefficients".

**Lemma Q4.8b (leaf layer: rank 4/4 and the fresh-pad ledger).** The
last (leaf-layer) sumcheck's children are the TRUE leaf MLEs,
blinder-extended and unmasked (obstruction O-2), so its four
boundary values expose leaf data directly; the blinder pads are what
hide them. Hypotheses: every blinder pair (a, u) uniform with u
restarted if zero (guard (c)), fresh per pass, committed under
h0_lkp before alpha; nonvanishing eq-weight of every blinder
position at the boundary points and at the final evaluation point z*
(guard (d)); the parity placement of freeze row LKP-6. Name the four
leaf boundary exposures E1 := vp0 (the p-side value at (0, r)),
E2 := vp1 (p-side at (1, r)), E3 := vq0 and E4 := vq1 (q-side,
same two points). Claim: (E1, E2, E3, E4) is an affine image, with
full row rank 4, of the tree's eight blinder pad coordinates —
jointly one-time-padded. The fresh-pad ledger below records which
uniform pad dimension pays for which exposure, with no dimension
spent twice between this lemma and Q4.9. Writing a_f0/u_f0 for the
(a, u) components of the final blinder at the even position,
a_f1/u_f1 for the odd one's, and a_tL/u_tL, a_tR/u_tR for the two
top blinders' (left and right half of the leaf layer):

| exposure | fresh pad dimension | also present, already spent (at the top, Q4.9) |
|---|---|---|
| E1 = vp0 | a_f0 | a_tL, a_tR |
| E2 = vp1 | a_f1 | a_tL, a_tR |
| E3 = vq0 | u_f0 | u_tL, u_tR |
| E4 = vq1 | u_f1 | u_tL, u_tR |

In words: the top of the tree (Q4.9) spends the four dimensions
(u_tL, u_tR, a_tL, a_tR); each leaf exposure needs only ONE fresh
dimension and gets its own (the matching-parity final blinder's a on
the p-side, u on the q-side); no dimension is double-counted, so the
leaf boundary is one-time-padded JOINTLY with the top's uniformity
rather than in isolation. The folded end values p(z*), q(z*) are
derived from E1..E4 by the public mu-fold (no new exposure), and the
two aggregate pins per tree — the P-pin and Q-pin of the design's
Section 3.2 leaf interface — are check equations over committed
data, not exposures.

*Proof sketch (component 6).* The p-side leaf MLE contains each
blinder's a-value weighted by its position's eq-weight, and the
q-side contains the u-values likewise. The boundary point (0, r)
gives nonzero eq-weight only to even positions and (1, r) only to
odd ones, so the parity placement hands each of E1/E2 (respectively
E3/E4) at least one nonzero entry in a fresh a-column (respectively
u-column), and the 4x4 sub-block of the exposure map on the fresh
dimensions (a_f0, a_f1, u_f0, u_f1) is diagonal with nonzero
diagonal by guard (d) — full row rank 4. QED sketch.

*Spike certificate.* Z3b: "the 4 final boundary values are a
FULL-RANK affine image of the blinder pads (rank 4/4)" — the spike's
own gloss records that the parity placement is what makes the
(1, r)-weighted rows nonzero.

Status (both parts): **[PROVEN at engine scale — battery E3Z-N4
green (U-K5d, 2026-07-10)]**: the leaf 4/4 and R-mask 6/6 rank
certificates run as derive-time canaries at engine shapes, covering
the w-round-challenge condition flagged in Q4.8a's closing note.

---

## Q4.9 — Top variety (layer-1 quadruples uniform on the cross-check
variety)

Covers: M4_LOOKUP_ZK_DESIGN.md Sections 3.1-3.2 (the M3 top blinders
and the solved mass) and Section 4 component 3;
`scripts/logup_zk_mask_spike.py` (certificate Z3d); (forward) U-K5c
and the U-K5d E3Z-N4 canaries.

**Setting.** Notation of Q4.7/Q4.8. Per instance the prover sends
two layer-1 quadruples: (p_1(0), p_1(1), q_1(0), q_1(1)) for the
witness tree and (p'_1(0), p'_1(1), q'_1(0), q'_1(1)) for the table
tree (primes mark the table side). The verifier derives each tree's
roots P = p_1(0)·q_1(1) + p_1(1)·q_1(0) and Q = q_1(0)·q_1(1),
checks Q_w != 0 and Q_t != 0 (subscripts w/t = witness/table tree),
and checks the root cross-check P_w·Q_t = P_t·Q_w. The top blinders
(one per half of each tree's leaf layer, Q4.8's setting) enter the
top as follows: each half's Q-product gains exactly one blinder
factor u (u_tL or u_tR on the witness side; the twins u'_tL, u'_tR
on the table side), and each half's fractional mass gains the
additive blinder mass a/u. One table-side blinder value is not drawn
but SOLVED: a'_tR := u'_tR·(beta_w - rest), where beta_w is the
witness tree's total blinder mass and "rest" collects the table
tree's other blinder masses — the solve makes the two trees' total
blinder masses equal, which is the completeness condition of the
blinded cross-check.

**Hypotheses.** Every blinder u drawn uniform nonzero (guard (c));
the free blinder a-values uniform; all blinders fresh per pass and
committed under h0_lkp before alpha — the E3Z-N2 ordering edge: a
blinder mass solved at a KNOWN alpha is exactly the spike-Z6 attack,
and it passes the blinded cross-check for a false lookup; and the
mass solve above.

**Lemma Q4.9.** Define the **cross-check variety** as the set of
8-tuples (the two quadruples) whose four q-values are nonzero and
which satisfy the single relation P_w·Q_t = P_t·Q_w. In the real
protocol the sent 8-tuple is uniform on this variety: seven of the
eight values are uniform (the q-values uniform on K* := K \ {0}),
and the eighth is the unique solution of the cross-check. The
witness-free simulator that samples seven values uniform (q's
nonzero) and solves the eighth from the cross-check therefore
reproduces the real distribution exactly. Moreover the real world's
solved PAD (a'_tR) and the simulator's solved EXPOSURE (the table
tree's p'_1(1)) are determined by the same relation — the real and
simulated varieties coincide, so no distinguisher exists at the top.

*Proof sketch (component 3 of the design's Section 4).* Each of the
four q-values is a public-after-challenge half-product times exactly
one fresh uniform nonzero factor u: a fixed nonzero multiple of a
uniform element of K* is uniform on K*, and the four u's are
independent, so the four q-values are independent uniform on K*.
Each p-value satisfies p_1(h) = (S_h + beta_h)·q_1(h) for its half
h, with S_h the half's honest fractional mass and beta_h its blinder
mass carrying one fresh additive a/u term (a uniform, u fixed
nonzero, so a/u uniform): given the q-values, the three p-values
whose a's are free draws are independent uniform. That spends seven
fresh pad dimensions — u_tL, u_tR, u'_tL, u'_tR, a_tL, a_tR, a'_tL —
on seven exposures. The eighth exposure p'_1(1) carries the solved
pad a'_tR, and its defining equation (the blinder-mass equality)
multiplied through by the derived Q-values is exactly the root
cross-check — the one relation the verifier tests. So the real
8-tuple is uniform on the cross-check variety, and the
sample-seven-solve-one simulation is exact. The pad dimensions spent
here and in Q4.8b are disjoint (the ledger there), so top and leaf
uniformity hold jointly. QED sketch.

*Spike certificate.* Z3d: a witness-free simulator (uniform samples
plus forced values only — this lemma's sampling at the top, Q4.7's
per-round sampling, Q4.8's uniform boundaries and openings) produces
transcripts the verifier ACCEPTS, root cross-check included; the
design's component 3 records that the simulator's solved value and
the real world's solved pad coincide on the same variety.

Status: **[PROVEN at engine scale — battery green (U-K5c/d,
2026-07-10)]**: the blinder-ordering pair E3Z-N2 (mass solved at a
KNOWN alpha ACCEPTS / fresh alpha REJECTS the same committed
blinders) and the rank canaries are live, and the U-K5 build landed —
the lookup's non-ZK deployment label (M4_LOOKUP_DESIGN.md Sections
3.5/8) is LIFTED at the subprotocol level (honest-verifier ZK,
proof-of-protocol; measured numbers in that document's Section 3.5
update).

---

## 8. Status summary

| lemma | subject | status |
|---|---|---|
| Q4.1a | exact second moment of challenge combinations | PROVEN |
| Q4.1b | restart probability (completeness cost) | SKETCH (Hanson-Wright cited; empirical counters corroborate) |
| Q4.1c | restart-rule soundness accounting | PROVEN (i, as implemented) / SKETCH (ii, no-restart variant inventory) |
| Q4.2a | M-product law for multi-bundle rejection | PROVEN |
| Q4.2b | joint-scaling variant (21.1 -> 5.7 attempts) | PROVEN (engine change is a build item) |
| Q4.3a | mask-image uniformity (marginal of A2 y) | SKETCH — and beside the point for the ZK leak (Q4.3d) |
| Q4.3b | which head pieces genuinely simulate | PROVEN (h; linear-claim + tie W's forced) / CORRECTED (quad W's do NOT — retraction) |
| Q4.3d | transcript-determinism; exact W+aP=cL and ch-...=cQ leaks | PROVEN LEAK (machine-checked, OK-1/2a) |
| Q4.3e | corollary: the committed-executions GATE leaks C | PROVEN LEAK (rank 12/12 recovery, OK-4) |
| Q4.3c' | superseded degeneracy story, corrected | RETRACTED/REWRITTEN |
| R1 | committed garbage-mask hardening spec (pads Ga/Gb/G1 + W) | PROVEN (masked variant HVZK under MLWE, complete OK-3a/b) / BUILT (engine tranche; `[R1]` battery + freeze row; costs R1.4') |
| Q4.4a | JL lower bound | CITED |
| Q4.4b | the coded SLACK_OP composition | OBLIGATION (two gaps) — SUPERSEDED as the proven bound by Q4.4c |
| Q4.4c | self-contained coordinate-wise direct-witness bound | PROVEN (2.35 bits tighter than the coded gate; no lift, no c-bar) |
| Q4.4' | direct-witness ARP extraction, S_eff ~ 2 (JL constant) | UNPROVEN target (tighter than Q4.4c; needs LNP22 transcription) |
| Q4.5a | salt-abort transcripts simulatable | PROVEN conditional (uniform tail bound; freeze-check gate suggested) |
| Q4.5b | salt grinding: x65, cap load-bearing | PROVEN |
| Q4.6 | twisted-execution aggregate simulation (O1-O4) | OBLIGATION (trace-gate build exit criterion; O3/O4 corrected per Q4.3d) |
| Q4.7 | E3-Z lookup round masks: adapted Libra counting, exposures uniform on the check variety | PROVEN at engine scale (E3Z-N4 rank canaries green, U-K5d 2026-07-10) |
| Q4.8 | E3-Z boundary/blinder pads: interior rank 6/6 (a), leaf rank 4/4 + fresh-pad ledger (b) | PROVEN at engine scale (E3Z-N4 canaries green, U-K5d 2026-07-10) |
| Q4.9 | E3-Z top: layer-1 quadruples uniform on the cross-check variety | PROVEN at engine scale (E3Z-N2 pair + canaries green, U-K5c/d 2026-07-10) |

The honest reading across the set, after U-P and the U-K5e
transcription:

- **Q4.3 became a hard FINDING, sharper than before.** The old Q4.3c
  ("leaks only for degenerate tensors") was an OVERCLAIM and is
  RETRACTED. The corrected result (Q4.3d/e) is that the quadratic
  layer leaks a fixed witness-image for EVERY witness, and the gate
  leaks the product matrix C. This is not zero-knowledge. The fix
  (R1) is fully specified, its masked variant is PROVEN HVZK under
  MLWE alone, and the engine build has LANDED (R1.4' for measured
  costs; the `[R1]` battery pins the leak identity and the pad
  hash-edge in the live suite).
- **Q4.4 was partially DISCHARGED.** Q4.4c gives a self-contained,
  machine-checked, direct-witness l_inf/l_2 extraction bound with
  none of Q4.4b's two gaps, 2.35 bits tighter than the coded
  SLACK_OP gate at the frozen point. Q4.4b's gaps now block only the
  (now-unused) SLACK_OP composition; Q4.4' remains the tighter JL
  target for a later transcription pass.
- **Q4.7-Q4.9 are the E3-Z transcription (tranche U-K5e), now graded
  at engine scale.** They transcribe M4_LOOKUP_ZK_DESIGN.md Section 4
  components 3-6; every rank and uniformity claim is machine-checked
  at toy scale (`logup_zk_mask_spike.py` certificates Z3b/Z3c/Z3d)
  AND at engine shapes — battery E3Z-N4 of tranche U-K5d runs the
  rank certificates as derive-time canaries, and the `[U-K5c]`
  committed masked pass + engine-scale m-recovery harness close the
  histogram leak these lemmas' masks exist for. With that battery
  green (2026-07-10), the lookup subprotocol's non-ZK deployment
  label is LIFTED at the subprotocol level — honest-verifier ZK,
  proof-of-protocol; the FFN integration (U-K8) and chain-wide
  composition remain open obligations tracked in M4_LOOKUP_DESIGN.md.
- Everything else (Q4.1/Q4.2/Q4.5) is unchanged from its prior grade.
