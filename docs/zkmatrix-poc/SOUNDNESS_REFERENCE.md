# Route R Soundness Reference

A self-contained account of the Route R zero-knowledge matrix-product
protocol: every definition, every verification equation, and a proof or
an explicitly labeled model/obligation for every soundness claim. It is
written to be read start-to-finish by a mathematician or an engineer
with no prior exposure to this repository; the protocol documents
(ROUTE_R_DESIGN.md, AUTOMORPHISM_GATE_DESIGN.md,
GADGET_MODULUS_DECISION.md) narrate design history, while this document
states what is true, why, and where each statement is enforced in code.

Status: written 2026-07-09, at branch state U-B5 (gate + tie
first-class) + U-L4 (modulus link). 42-test suite green at that state.

## 0. How to read this, and the honesty legend

Every numbered statement carries one of three grades:

- **[PROVEN]** — a complete argument is given here (or is a standard
  textbook fact), and a machine check exercises it.
- **[MODEL]** — a quantitative engineering model (e.g. a root-Hermite
  lattice-hardness estimate, an empirical tail constant). The model and
  its parameters are stated; freeze-check rows pin them against drift.
- **[OBLIGATION]** — believed and designed, but the formal write-up or
  implementation is still owed. Section 8 lists all of them.

Code map (all paths relative to the repository root):

| layer | code | exercised by |
|---|---|---|
| ring arithmetic, challenges, Gaussians | `zkmatrix-rs/src/ring/mod.rs` | `ring_matmul self-test` (arithmetic section) |
| commitments (BDLOP, CRS expansion) | `zkmatrix-rs/src/ring/commit.rs` | self-test (openings section) |
| the masked round + all claim families | `zkmatrix-rs/src/ring/ct_engine.rs` | self-test (engine, U5, U6, U-B2/B5 sections) |
| digit-decomposed openings | `zkmatrix-rs/src/ring/sigma.rs` | self-test (openings/pi2) |
| cross-modulus link | `zkmatrix-rs/src/ring/link.rs` | self-test (U-L section), `link-demo` |
| the matmul protocol driver + all tests | `zkmatrix-rs/src/bin/ring_matmul.rs` | `self-test`, `freeze-check`, `gate-spike`, `link-demo` |
| parameter-drift guards | `freeze_check()` in `ring_matmul.rs` | `ring_matmul freeze-check` (Python suite runs it) |

Run everything:

    cd zkmatrix-rs && cargo build --release
    ./target/release/ring_matmul self-test
    ./target/release/ring_matmul freeze-check
    cd .. && python3 -m unittest discover -s tests

## 1. Preliminaries

### 1.1 The ring

Fix D = 128 and the cyclotomic ring

    R = Z[X] / (X^D + 1),      R_q = R / q R.

Two moduli are in play:

- q = q31 = 2^31 - 399 (`Q8`), the protocol modulus. q ≡ 17 (mod 32),
  so X^128 + 1 factors mod q into exactly k = 8 irreducible binomials
  X^16 - eta^(2t+1) (eta = `ETA8`, a primitive 16th root of unity).
  R_q is therefore a product of 8 copies of the field GF(q^16); we call
  the factors **CRT slots**. |GF(q^16)| = q^16 ≈ 2^496.
- q46 = 2^46 - 1103 (`Q8_46`), the gadget-layer modulus, same k = 8
  splitting class. Used only where a side-condition budget does not
  close at q31 (Section 6; binary/range gadgets).

The partial (k = 8) splitting is a deliberate choice: full splitting
(q ≡ 1 mod 2D) would make every slot a small field GF(q) and collapse
the per-slot soundness of Section 1.3 from 2^-297 to 2^-31.

**Norms.** For f = sum f_i X^i in R, |f|_inf = max |f_i| with
coefficients centered in (-q/2, q/2]. Multiplication expands norms:
|fg|_inf <= D |f|_inf |g|_inf, and for f with coefficients in
{-2..2}, |fg|_inf <= 2 sum |g_i| (the operator-norm view used by the
parameter chains).

### 1.2 Galois automorphisms

For odd t (mod 2D) define sigma_t : R -> R, X -> X^t. These are the
D = 128 automorphisms of R (the Galois group Gal, abelian, isomorphic
to (Z/2DZ)^*). Three facts used throughout:

1. sigma_t permutes coefficients up to sign (X^{ti} = ±X^{ti mod D}),
   so it preserves |.|_inf exactly and costs O(D) to apply.
2. sigma_t permutes the CRT slots of R_q (it permutes the roots of
   X^D + 1), so "nonzero in every slot" is sigma-invariant.
3. conj := sigma_{2D-1} (X -> X^{-1}) satisfies
   ct(conj(f) g) = <f, g> — the constant coefficient of conj(f)g is
   the coefficient inner product. This is the bridge between ring
   multiplication and the inner products the protocol proves.

### 1.3 Challenge sets and the two soundness engines

**Quinary challenges.** C := { c in R : every coefficient in
{-2,-1,0,1,2} }, sampled uniformly (XOF); |C| = 5^128 ≈ 2^297.2.

**(L1) Invertibility of differences [PROVEN, criterion checked at
derive time].** By Lyubashevsky–Seiler (2018), if every difference of
distinct elements of C has, in every CRT slot, some coefficient profile
bounded away from the field characteristic — concretely, if
2·|c|_inf·(slot-degree condition) < q^(1/k') for the relevant split —
then c ≠ c' implies c - c' is invertible in R_q (nonzero in EVERY
slot). The quantitative criterion is evaluated by `ls18_margin`; at
(k = 8, q31) the margin is 1.30x and at (k = 8, q46) larger; both are
freeze-check rows (`C0'`). Everything below assumes this margin holds;
if a parameter change breaks it, freeze-check fails loudly.

**(L2) Per-slot point mass of quinary challenges [PROVEN].** Fix a CRT
slot S and view the restriction map res_S : C -> GF(q^16). If two
distinct challenges agreed on S, their difference would be zero in S,
contradicting (L1). So res_S is injective, and for uniform c in C and
any fixed target k in GF(q^16):

    Pr[ res_S(c) = k ] <= 5^-128 = 2^-297.

Consequently, for fixed ring elements w_1..w_m, not all zero in slot S,
and independent uniform quinary c_1..c_m:

    Pr[ sum_t c_t w_t = k  in slot S ] <= 2^-297

(condition on all c_t but one with w_t nonzero in S; the remaining
c_t·w_t is injective in res_S(c_t) because w_t is invertible **in the
slot field**). The design documents round this to "2^-296-class"; this
is the engine behind every "one ring challenge replaces 64
repetitions" statement in Route R.

**Full-entropy challenges.** Where a challenge never multiplies a
response (so its norm is irrelevant — e.g. the tie's psi, Section
5.5), it is drawn uniformly from R_q via 128-bit rejection-free
reduction (bias 2^-97 per coefficient). Its per-slot point mass is
q^-16 ≈ 2^-496 [PROVEN, same conditioning argument with res_S now
surjective].

### 1.4 Hardness assumptions

- **MSIS(kappa, n, beta)**: given uniform A in R_q^{kappa x n}, find
  nonzero z with Az = 0 and |z| <= beta. Commitment binding reduces to
  MSIS (Section 2).
- **MLWE(n, m, chi)**: distinguish (A, As + e) from uniform for short
  s, e ~ chi. Commitment hiding reduces to MLWE.

**[MODEL]** Concrete sizes: the frozen shapes were run through the
lattice-estimator (`scripts/estimator_run.py`, ESTIMATOR_NOTE.md):
MSIS binding lands at 136–153 bits classical across all frozen shapes;
MLWE hiding uses the d_lwe = ceil(768·log2(q)/11.7) dimension rule
validated by the same run. Three shapes dip below 128 bits under a
core-SVP **quantum** model; adopting a quantum target costs kappa+1
(documented, not currently adopted). The root-Hermite constant
delta0 = 1.0037 (`LOG2_DELTA0`) is the C3 model; freeze-check pins the
derived (kappa, N_r) of every frozen shape against drift.

### 1.5 Fiat–Shamir and the ordering principle

The protocol is rendered non-interactive with Fiat–Shamir over an XOF
(SHA-256-seeded; random-oracle model assumed **[MODEL]**). Every
challenge is derived from a hash that binds, at minimum, every
commitment and every reveal that the challenge is meant to constrain.
This ordering is not bookkeeping — it is load-bearing, and this
codebase has produced two concrete attacks (F5, and the tie's
psi-order attack, Section 5.6) that break soundness completely when a
single edge of the order is violated. Section 7 tabulates every
challenge, its required predecessors, the attack when violated, and
the regression test that pins it.

## 2. The commitment scheme (BDLOP)

The CRS is A1 in R_q^{kappa x n_r}, A2 in R_q^{msg_r x n_r}, expanded
from a seed (`expand_crs`). A message vector x in R_q^{msg_r} is
committed with fresh ternary randomness rho in R^{n_r},
|rho|_inf <= 1:

    com(x; rho) := (t1, t2),   t1 = A1 rho,   t2 = A2 rho + x.

**(2.1) Hiding [PROVEN reduction, MODEL sizes].** (t1, t2) hides x
under MLWE with ternary secret: the CRS shapes are derived so that the
effective LWE dimension n_r - (kappa + msg_r)·(rows consumed) meets
d_lwe (Section 1.4). Two commitments with correlated messages (used by
the tie masks, Section 5.5) are still hiding: hiding is per-commitment
randomness, independent of message contents.

**(2.2) Relaxed binding [PROVEN reduction].** The opening produced by
extraction (Section 3.3) is *relaxed*: it exhibits (x*, rho*, dc) with
(dc)·t2 = A2 rho* + (dc)·x* etc., where dc = c - c' is an invertible
challenge difference and |rho*| is bounded by the response bound. Two
distinct extracted messages for the same commitment yield a nonzero
short solution to A1 z = 0 with |z| <= 2·B_z·|dc-factor| — an MSIS
break at the C3-derived beta. The parameter chain (C2/C3/C4 in the
design docs) sizes (kappa, n_r, sigma, B_z) so this MSIS instance has
the Section 1.4 hardness; freeze-check pins every frozen instance.

## 3. The masked opening round (the "ct-round")

All claims in Route R about committed data are proven inside one
Schnorr-style masked round (`prove_ct_round_tq` /
`verify_ct_round_tq` in `ct_engine.rs`). One round handles a batch of
commitments and a batch of claims of every family in Section 4
simultaneously.

### 3.1 The protocol

Statement hash h0 binds the CRS, the context string, and every
commitment in the round (`ct_h0`). Then:

1. **Prover, masks.** For each commitment i, sample a Gaussian mask
   vector y_i (parameter sigma from `derive_ct_round_params`, sized to
   the joint bundle). Compute the Ajtai images w1_i = A1 y_i and, for
   every claim, its pre-challenge images (Section 4 lists them per
   family; they are all functions of the mask images Y_i := A2 y_i
   and, for quadratic families, of the witnesses x_i). These form the
   proof head.
2. **Challenge.** c = XOF(h0, head), a quinary challenge (Section
   1.3). Everything in the head is therefore bound before c exists.
3. **Prover, responses.** z_i = c·rho_i + y_i, subjected to joint
   rejection sampling (Q4.2b: one accept/reject decision over the
   whole bundle, ~3.7x fewer restarts than per-commitment); on reject,
   restart the round with fresh masks (the `attempts` counter in every
   test line).
4. **Verifier.** Recompute c from (h0, head); check per commitment
   A1 z_i = c·t1_i + w1_i and the norm bound |z_i| <= B_z; form the
   **virtual openings**

       P_i := c·t2_i - A2 z_i  ( = c·x_i - Y_i for the honest prover )

   and evaluate every claim's check equation (Section 4).

**(3.1) Completeness [PROVEN].** A1 z = A1(c rho + y) = c t1 + w1.
P_i = c t2_i - A2(c rho_i + y_i) = c x_i - Y_i. Each claim family's
check then closes by the algebra given with that family. Rejection
sampling only affects the number of attempts, not acceptance of the
final transcript.

**(3.2) Zero-knowledge surface [PROVEN for responses + linear images;
quadratic images R1-MASKED (built) — HVZK under MLWE].** The
rejection-sampled z_i are distributed independently of rho_i (standard
Lyubashevsky rejection argument; the alpha = 12, M = 2.76 discipline).
w1_i and the LINEAR-claim images (RingClaim/CtClaim, including the
tie's W_ring) are FORCED by their verification equations, hence
simulatable (Q4_LEMMAS.md Q4.3b-ii). The *quadratic* families' images
(Ga, Gb, G0, G1 AND the linear mask images W_quad/W_qring/W_tq) were
previously logged as an owed "leftover-entropy" lemma; the U-P proof
tranche found that framing was an OVERCLAIM and RE-GRADED it to a
PROVEN LEAK: the images are pinned by the revealed z (Y_i = c x_i -
P_i), so the exact identities W + sum a P = c L and c h - (...) = c Q
expose fixed witness-images in the clear FOR EVERY witness, not only
degenerate ones (Q4_LEMMAS.md Q4.3d). For the multiplication gate this
image is the product matrix C itself (Q4.3e; C recovered exactly at
demo params). The unmasked quadratic layer is therefore NOT
zero-knowledge. The fix — R1: additive one-time-pad slots on Ga/Gb/G1
AND W, committed in the round's g-slot space before the challenge —
is BUILT (R1 engine tranche, `ct_engine.rs`): the engine sends only
the masked images Ga~/Gb~/G1~/W~/G0~ and the verifier subtracts the
pad openings; the masked variant is PROVEN HVZK under MLWE alone
(Q4_LEMMAS.md Section R1; gate + tie simulation assembled in
AUTOMORPHISM_GATE_DESIGN.md Appendix B.2; check completeness
machine-checked, `zk_lemma_check.py` OK-3a/3b). The leak identities
and the pad hash-edge are pinned by the live `[R1]` battery — leak
non-recovery pairs for ALL THREE quadratic families (untwisted,
twisted-ring/gate form incl. the Q4.3e C-image, and the quad-ct
Q-leak of Q4.3d-2) plus both-direction order pairs at both monomial
shapes — and a freeze row. See Section 8 item 1.

### 3.3 Extraction (special soundness) [PROVEN]

Given two accepting transcripts with the same head and distinct
challenges c ≠ c', subtract the Ajtai checks:

    A1 (z - z') = (c - c') t1.

dc := c - c' is invertible (L1), so rho* := (z - z')·dc^{-1} is a
relaxed opening of t1 with |z - z'| <= 2 B_z, and
x*_i := t2_i - A2 rho*_i is the extracted message — unique across any
transcript pair by (2.2) (else MSIS breaks). Linear claim checks are
affine in c: subtracting the two transcripts' checks eliminates every
pre-challenge image and pins the claim on the extracted messages
exactly (each family's computation is given in Section 4). Quadratic
families' checks are polynomials in the monomials {c, sigma(c),
sigma(c)·c, c^2}: three transcripts give a Vandermonde-type system
whose determinant is a product of LS18-invertible differences, pinning
the coefficient of every monomial separately — in particular the top
monomial, which carries the claim. Fiat–Shamir converts
special-soundness to knowledge soundness in the random-oracle model
with the standard forking loss **[MODEL]**.

## 4. The claim families

Notation for this section: for a claim with public coefficients
a_(i,j) over committed slots x_(i,j), write

    C_L := sum a_(i,j) t2_(i,j)      (over commitment rows — public),
    ZA_L := sum a_(i,j) (A2 z_i)_j   (verifier-computed),
    W_L := sum a_(i,j) (A2 y_i)_j    (prover image, in the head).

The identity behind every linear family [PROVEN, one line]:

    c·C_L - ZA_L + W_L = c·(sum a x)                            (*)

because c t2 - A2 z + A2 y = c x per slot (Section 3.1 step 4).

### 4.1 Ring-valued linear claims with a public constant (`RingClaim`)

**Claim.** sum a_(i,j) x_(i,j) = K over the full ring, K public
(K = 0 for the homogeneous form).

**Check.** W_L = ZA_L - c·C_L + c·K.

**Completeness** is (*) rearranged. **Extraction [PROVEN]:**
subtracting two transcripts gives 0 = dc·(K - sum a x*), and dc is
invertible, so sum a x* = K exactly — in every slot, every
coefficient. **ZK:** W_L is determined by public data and the check,
hence simulatable. *Code:* `RingClaim`, check in `verify_ct_round_tq`
("Ring-valued claims" block). *Pinned by:* the U-B5 tie batteries and
the U6a rescale/recomposition tests; `CE tie: tampered ring-claim mask
image fails` pins that W_L is load-bearing.

### 4.2 Scalar ct-claims (`CtClaim`)

**Claim.** ct( sum a_(i,j) x_(i,j) + sum phi s + g_l ) = scalar, where
ct(.) is the constant coefficient, s are Ajtai-side (norm-carrying)
slots and g_l is a per-claim mask element committed in the round's
g-slots with ct(g_l) free.

**Check.** The prover reveals h_l := the claim combination evaluated
on the witnesses+mask; the verifier checks ct(h_l) = scalar directly
and checks h_l against c·C_L - ZA_L + W_L (+ Ajtai part) — i.e. the
reveal is FORCED to equal the committed combination by (*), and the
scalar is read off the forced reveal. The g-mask makes the non-ct
coefficients of h_l uniform (that is its only job — ZK for the
combination's other 127 coefficients).

**Extraction [PROVEN]:** as in 4.1, the two-transcript subtraction
pins h_l = sum a x* + sum phi s* + g*_l; ct of a pinned reveal is
pinned. *Code:* `CtClaim` blocks in `ct_engine.rs`. *Pinned by:* the
engine self-test section (theta claims), U6 gadget tests, link tests
(`tampered value fails the q31 ct check`).

### 4.3 Quadratic ct-claims (`QuadCtClaim`) and the F5 lesson

**Claim.** ct( sum_p gamma_p conj(x_(a_p)) x_(b_p) + sum a x + g )
= scalar (the binary gadget's b∘b = b shape, Hadamard gadgets, etc.).

**Check.** With P_i the virtual openings, the verifier computes
E := sum gamma conj(P_a) P_b, which expands to

    E = conj(c)c·Q - conj(c)·Ga - c·Gb + G0,
    Q := sum gamma conj(x_a) x_b,
    Ga := sum gamma conj(x_a) Y_b,   Gb := sum gamma conj(Y_a) x_b,
    G0 := sum gamma conj(Y_a) Y_b,

with (Ga, Gb, G0) prover images in the head. The prover reveals
h := Q + L + g (L the linear part) and the verifier checks
ct(h) = scalar plus the combined equation

    conj(c)c·h = E + conj(c)·Ga + c·Gb - G0
                 + conj(c)(c·C_L - ZA_L + W_L) + (g-part).

**Extraction [PROVEN]:** three transcripts pin the coefficient of the
top monomial conj(c)c, which is exactly h - (Q + L + g) = 0.

**The F5 lesson [PROVEN attack + fix].** An earlier form of the binary
claim used FIXED public coefficients across the batch; a cheating
prover could then shift the committed g-mask to cancel a non-binary
defect ("g-shift attack") — the claim verified against a witness that
was NOT binary. The shipped fix draws fresh scalar randomizers theta
AFTER the mask commitment and applies them to every claim copy; the
attack now requires predicting theta (2^-31 per copy, 9 copies). The
regression `F5: the OLD fixed-coefficient claim ACCEPTS the g-shift
attack / the theta-randomized claims REJECT the same crafting` keeps
both directions pinned. This attack is why Section 1.5's ordering
principle is stated as a principle and audited in Section 7.

### 4.4 Ring-valued quadratic claims, untwisted (`QuadRingClaim`)

**Claim.** sum gamma x_a x_b + sum a x = 0 over the full ring.
**Check.** E2 := sum gamma P_a P_b = c^2 Q - c G1 + G0;
E2 + c·G1 - G0 + c(c·C_L - ZA_L + W_L) = 0. Same three-transcript
extraction; the top monomial is c^2. *Pinned by:* U6a Hadamard tests.

### 4.5 Conjugate-twisted ring-valued quadratic claims
(`TwistedQuadRingClaim`) — the gate's claim form

**Claim.** sum_p gamma_p conj(x_(a_p)) x_(b_p) + sum a x = 0 over the
full ring — no reveal, no scalar, no g-mask.

**Check.** E := sum gamma conj(P_a) P_b as in 4.3, and

    E + conj(c)·Ga + c·Gb - G0
      + conj(c)·( c·C_L - ZA_L + W_L )  =  0.

**Completeness [PROVEN].** Substituting P = c x - Y and the image
definitions, everything except the top monomial cancels term-by-term,
leaving conj(c)·c·(Q + L). Honest witnesses have Q + L = 0.

**Extraction [PROVEN].** Three transcripts with distinct challenges:
the check is a polynomial identity in the monomials
{1, c, conj(c), conj(c)c} with pre-challenge coefficients; the
Vandermonde clearing of Section 3.3 pins the conj(c)c coefficient,
which is Q + L computed on the extracted witnesses. So Q + L = 0
exactly. The pad terms (R1) enter only the lower monomials
{1, c, conj(c)} as pre-challenge images, so the Vandermonde clearing
annihilates them and extraction is unchanged. **ZK surface:**
(Ga, Gb, G0, W) — the Section 3.2 leak; for this exact claim form
(the gate) the leaked image is the product matrix C (Q4_LEMMAS.md
Q4.3e), closed by the R1 pads, now BUILT (the engine sends
Ga~/Gb~/G0~/W~ only; Q4_LEMMAS.md Section R1 / Appendix B.2 of
AUTOMORPHISM_GATE_DESIGN.md).
*Code:* U-B1 + R1 additions to `ct_engine.rs`. *Pinned by:* `CE gate:
tampered {Ga,Gb,G0} garbage image fails`, `tampered linear mask image
W fails`, the `[R1]` leak/order battery, and the full-round negatives
of Section 5.

### 4.6 Digit-decomposed openings (`sigma.rs`)

Derived objects whose combined randomness exceeds the ternary regime
(e.g. gadget-family combinations) are opened by decomposing the
response in base 2^e over L limbs; each limb rides the round as an
ordinary small response, and the verifier recomposes
sum 2^(e·l)·z_l. Soundness is the same subtraction argument applied
limb-wise; the (e, L) chains and their C2 headroom are frozen rows
(`C2-C4` block). *Pinned by:* `pi2 tampered digit response fails`.

### 4.7 Approximate range proofs (ARP) and their budget

To ground "this committed vector is short" (the binary gadget's
non-wrap side condition), the round reveals y = R b + m for an
FS-derived sparse ±1 projection R (drawn from the round hash) and a
committed Gaussian mask m, range-checks y, and ties y to (b, m) with
linear ct-claims. **[MODEL + OBLIGATION; a PROVEN direct-witness bound
now available]:** the extraction constant composing the
Johnson–Lindenstrauss lower bound with relaxed-opening slack is carried
as the conservative parameter SLACK_OP (worst case |c|_1 = 4D);
`arp_budget_ok` evaluates the resulting budget at derive time and
REJECTS shapes that do not close. The U-P tranche added a
self-contained, machine-checked coordinate-wise bound (Q4_LEMMAS.md
Q4.4c) that removes both gaps of the SLACK_OP composition (no integer
lift, no post-R challenge) and lands 2.35 bits tighter at the frozen
point; it does not by itself change the frozen verdicts below (that is
a `gadget_modulus_study.py` numeric call, flagged there), but it makes
the extraction a PROVEN bound rather than only a budget gate. Two facts are permanently
pinned by freeze rows: the budget CLOSES at q46 for binary units up to
n = 512 coefficients and FAILS at n = 1536 (the granularity cap —
binary claims stay partitioned), and it is KNOWN-OPEN at q31 (the row
asserts the failure, so nobody can silently assume it).

## 5. The multiplication gate: C = A·B with everything hidden

Setting: rows a_1..a_r of A are packed as ring elements apack_i
(coefficient vectors), columns b_1..b_m of B as bpack_j, and C's
entries are packed into cpack_j with C[i][j] at coefficient i of
cpack_j. By Section 1.2(3), the true relation is

    C[i][j] = <a_i, b_j> = ct( conj(apack_i)·bpack_j ).

All three matrices are committed; nothing may be revealed.

### 5.1 The obstruction (finding F2) [PROVEN impossibility of the
naive gate]

Route R's linear layers combine committed columns with ONE quinary
ring challenge v (per-slot 2^-297 by L2). The naive bilinear gate
wants ct( w·P_ij ) with P_ij := conj(apack_i)·bpack_j and w a ring
challenge — but ct(w·P) ≠ w·ct(P): the non-constant coefficients of
P_ij ("junk": inner products of a_i against *shifted* b_j) leak into
the constant coefficient the moment a ring challenge multiplies P_ij.
The junk enters through the challenge weights BEFORE any maskable
object exists, and the C-side commitments contain only the true
entries — there is nothing to match the junk against. Every inline
repair (committed corrections, twisted functionals, axis packing) was
checked and fails on the same non-commutation fact
(ROUTE_R_BUILD_REPORT.md F2, GATE_ALTERNATIVES.md Section 5). The
scalar-challenge fallback (r_g = 43–64 repetitions) works but costs
~13–15 MB per matmul claim — the cost this section eliminates.

### 5.2 The trace identity [PROVEN]

**Lemma (killed monomials).** Let T(y) := sum over ALL D
automorphisms sigma_t of sigma_t(y). Then T(X^e) = 0 for every
e in {1, .., D-1}, and T(1) = D.

*Proof.* Write e = 2^a·u with u odd; since 0 < e < D = 2^7, a <= 6.
The map phi(t) := t + 2^(7-a) is a bijection on the odd residues mod
2D (it adds an even constant). Compute
phi(t)·e = te + 2^(7-a)·2^a·u = te + D·u ≡ te + D (mod 2D), since u
is odd. So X^(phi(t)e) = -X^(te) (using X^D = -1), and applying phi
merely permutes the summands of S := sum_t X^(te) while flipping every
sign: S = -S. R is torsion-free over Z, so S = 0. For e = 0 every term
is 1 and S = D. ∎

**Theorem (the gate identity).** For any challenge vectors s (rows)
and v (columns), define the twisted execution combinations

    xa^t := sum_i sigma_t(s_i)·apack_i,
    xb^t := sum_j sigma_t(v_j)·bpack_j,
    xc^t := sum_j sigma_t(v_j)·cpack_j,
    shat^t := sum_i sigma_t(s_i)·X^i          (public),

and G_A := sum_t sigma_t^{-1}( conj(xa^t)·xb^t ),
    G_C := sum_t sigma_t^{-1}( conj(shat^t)·xc^t ).
Then

    G_A = D · sum_ij conj(s_i) v_j · <a_i, b_j>,
    G_C = D · sum_ij conj(s_i) v_j · C[i][j],

both CONSTANT multiples of scalars — junk-free.

*Proof.* Expand one term of G_A: conj and every sigma_t are ring
homomorphisms and the group is abelian, so

    sigma_t^{-1}( conj(xa^t)·xb^t )
      = sum_ij conj(s_i)·v_j · sigma_t^{-1}( conj(apack_i)·bpack_j ).

The challenge factors LEAVE the twist (sigma_t^{-1}(sigma_t(s)) = s) —
this is the whole trick: the weights sit outside the trace. Summing
over t gives sum_ij conj(s_i)v_j·T(P_ij) with
P_ij = conj(apack_i)bpack_j, and by the Lemma
T(P_ij) = D·ct(P_ij)·1 = D·<a_i, b_j>. The C side is identical with
P'_ij = X^(-i)·cpack_j, whose constant coefficient is C[i][j]. ∎

**Corollary (gate soundness at r = 1).** G_A - G_C =
D·sum_ij conj(s_i)v_j·(<a_i,b_j> - C[i][j]). If the defect matrix is
nonzero and (s, v) are drawn (from the pre-hash binding A, B, C's
commitments) AFTER the matrices are committed, then G_A = G_C holds
with probability <= 2^-297-class per CRT slot (L2, applied to the
challenge that multiplies a nonzero defect entry; D is a unit mod q).
Machine check: `gate-spike` verifies the identity, the frontier
points, and the tampered-C negative numerically.

### 5.3 The committed-executions construction (Appendix B / U-B2)

The identity of 5.2 references the DERIVED objects xa^t; opening 3·D
derived combinations per gate would cost more than the repetitions it
replaces. The resolution: the prover RE-COMMITS the executions as
fresh commitments with D message slots per side,

    Y^A with slots YA_t := sigma_t^{-1}(xa^t),   Y^B, Y^C likewise,

and the gate becomes ONE claim of family 4.5 over those slots:

    sum_t conj(YA_t)·YB_t - sum_t conj(shat_tw_t)·YC_t = 0,
    shat_tw_t := sigma_t^{-1}(shat^t)   (public coefficients).

By 4.5's extraction this pins the relation on the committed Y slots
exactly; by 5.2 the honest slots satisfy it, and a defective C makes
it fail (per-slot 2^-297 over s, v). What remains is to bind the Y
commitments to the ORIGINAL commitments — the tie.

### 5.4 The tie problem and its obstruction [PROVEN]

The tie must enforce, per twist t:  YA_t = sigma_t^{-1}(xa^t), i.e. a
relation between committed slots ACROSS a Galois twist. The round's
virtual opening P = c·x - Y transforms as sigma_t(P) =
sigma_t(c)·sigma_t(x) - sigma_t(Y): a twisted committed slot drags the
twisted challenge monomial sigma_t(c) into the check equation. A
single check with pre-challenge images pins witness combinations PER
MONOMIAL (Section 3.3), but the tie is one equation ACROSS monomials —
so no plain multi-twist linear claim can express it. Reveal-based
pivots need a mask on both sides of the twist, and the mask
consistency nu_t = sigma_t(mu_t) is itself a mixed-twist claim —
circular. Unmasked reveals leak the executions. (These dead ends are
recorded because each was actually attempted in design.)

### 5.5 The tie resolution: two-sided masked reveals (Appendix B.1 /
U-B5) [PROVEN]

Per side (shown for A; B, C identical with v):

1. The prover commits Y^A, then uniform masks M = (mu_t) and their
   pre-twisted images N = (nu_t), nu_t := sigma_t(mu_t). The verifier
   never checks this relation.
2. h0 binds ALL commitments; full-entropy challenges psi_t := from
   XOF(h0) (Section 1.3, per-slot 2^-496).
3. The prover reveals F_t := psi_t·YA_t + mu_t.
4. Quinary challenges taui, tauii := from XOF(h0, F) — after F.
5. Two claims of family 4.1 (public constants; all committed slots
   UNTWISTED):

     (i)  sum_t taui_t·( psi_t·YA_t + mu_t )   = sum_t taui_t·F_t
     (ii) sum_t tauii_t·( psi'_t·v'_t + nu_t ) = sum_t tauii_t·sigma_t(F_t)

   where v'_t := sum_i sigma_t(s_i)·apack_i (slots of the ORIGINAL
   commitment with public coefficients sigma_t(s_i)) and
   psi'_t := sigma_t(psi_t). Every Galois twist acts on PUBLIC data
   (psi, s, F) only.

**Completeness [PROVEN].** (i) is the definition of F. For (ii):
honesty means sigma_t(YA_t) = v'_t, so
sigma_t(F_t) = psi'_t·sigma_t(YA_t) + sigma_t(mu_t) = psi'_t·v'_t + nu_t.

**Soundness [PROVEN].** By 4.1's extraction, (i) and (ii) hold over
the extracted slot values. Since taui is drawn after (F, psi, and all
commitments) are fixed, a nonzero per-t residual of (i) survives the
taui batch with per-slot probability <= 2^-297 (L2); so
F_t = psi_t·YA_t + mu_t for every t; likewise (ii) gives
psi'_t·v'_t + nu_t = sigma_t(F_t) for every t. Substitute the first
into the second and apply sigma_t^{-1}:

    psi_t·( YA_t - sigma_t^{-1}(v'_t) ) = sigma_t^{-1}(nu_t) - mu_t.

The right-hand side is FIXED at mask-commitment time; psi_t is drawn
after, uniform with per-slot point mass 2^-496. A nonzero tie defect
YA_t - sigma_t^{-1}(v'_t) in some slot therefore requires the
committed masks to have predicted psi_t in that slot: probability
<= 2^-496 per slot per twist; union over 3 sides x 128 twists x 8
slots is absorbed without moving the security level. ∎

**Zero-knowledge [PROVEN modulo 3.2].** F_t is one-time-padded by
mu_t, hence uniform and simulatable; sigma_t(F_t) is derived public
data; the W images of (i)/(ii) are simulatable from the check; the
masks' commitments are hiding by (2.1) (correlated contents allowed).
The executions never appear unmasked anywhere.

### 5.6 The two order attacks (why Section 7 exists) [PROVEN attacks]

**(A) psi before masks.** If a cheating prover knows psi when choosing
the masks, it commits nu_t := sigma_t(mu_t) - psi'_t·sigma_t(d_t) for
ANY chosen defect d_t, reveals F from the tampered YA, and both (i)
and (ii) verify — the tie is completely broken. Regression: `CE order
regression: psi-before-masks ACCEPTS the crafted-mask defect` (the
attack, demonstrated live) and `... psi drawn after the masks REJECTS
the same crafting`.

**(B) tau before F.** If the reveals F may be chosen after taui/tauii
are known, the prover has h = 128 free ring elements subject to only
TWO batch constraints — an underdetermined linear system it can always
solve, hiding any defect in the slack. This is why step 4 hashes F
before drawing tau. (Caught on paper during the U-B5 derivation; the
shipped order makes it structurally impossible, and attack (A)'s
regression pins the hash-chain discipline that enforces both.)

### 5.7 What the gate + tie cost and where that stands

Measured at the demo shape (12-commitment round, r = 1, attempts 1):
prove ~220 ms / verify ~170 ms; marginal ~1.23 MB per matmul claim
(9 h-slot commitments + 9 opening bundles + 3 reveal vectors + 11
claim images) vs 8.7–12.9 MB for the scalar-gate fallback at the same
shape. Everything scales linearly with h·(inner/D). The scalar gate
remains available behind its flag; the pi2 default switch is the
remaining mechanical step (Section 8).

## 6. The cross-modulus link (finding F3, `ring/link.rs`)

The binary/range gadgets need the ARP side condition (4.7), which
closes at q46 but not at q31 — so bit tensors are committed at q46
while the value chain lives at q31, and a LINK proves the two sides
hold the same integers. Values v_1..v_n in [0, 2^W) (frozen point:
n = 128, W = 4) are committed as values at q31 and as W bit planes at
q46.

**Protocol.** h0_link binds BOTH CRS hashes and BOTH sides' full
commitment lists (including each side's g-mask commitments). From
h0_link derive l rows of signed uniform w-bit weights xi_(l,t)
(frozen: w = 11, l = 24). The prover REVEALS the integers
y_l := <xi_l, v> (computed over Z), the verifier checks the range gate
|y_l| < q46/2, and each side runs one linear ct-claim per row inside
its own round: the q46 side with weights xi_(l,t)·2^i on bit (i, t)
and scalar y_l; the q31 side with weights xi_(l,t) on value t and
scalar (y_l mod q31, centered).

**(6.1) Integer exactness on the grounding side [PROVEN].** The w_max
rule n·2^(w-1)·(2^W - 1) < q46/2 bounds the honest inner product's
absolute value below q46/2, and the range gate forces the CLAIMED y_l
below q46/2 too; the q46 ct-claim pins y_l ≡ <xi_l, V46> (mod q46)
where V46 is the integer recomposition of the committed (proven
binary) bit planes. Two integers in (-q46/2, q46/2) congruent mod q46
are equal, so y_l = <xi_l, V46> over Z. (The gate is deliberately
one-sided: an analogous q31/2 gate would be violated by HONEST y at
the frozen w — a completeness break, not a hardening; the q31 side
needs no integer grounding because only residues are claimed there.)

**(6.2) Per-row detection [PROVEN].** Suppose the value vector V31
committed at q31 differs from V46 mod q31: delta := V31 - V46 ≠ 0
(mod q31). The q31 claim forces <xi_l, V31> ≡ y_l = <xi_l, V46>, i.e.
<xi_l, delta> ≡ 0 (mod q31). Fix a coordinate with delta_t ≠ 0:
conditioned on the other coordinates, xi_(l,t) ranges over 2^w
consecutive integers, whose images xi·delta_t mod the PRIME q31 are
2^w distinct residues; at most one satisfies the equation. So each row
misses with probability <= 2^-w, and l independent rows give
2^(-w·l) = 2^-264 <= 2^-256 (frozen row). xi is drawn from h0_link
AFTER both sides' commitments — same ordering principle; the
`wrong xi (stale h0_link, pre-g derivation) fails` negative pins it.

**(6.3) What the link does NOT rest on.** Its soundness is mod-q
ct-claim algebra plus (6.1)/(6.2) — it does not touch the ARP's
SLACK_OP/JL constants. The q46 BINARY grounding it composes with does
(Section 4.7, with the granularity cap n <= 512 per binary unit).

Measured (U-L2): prove 12–13 ms, verify 8–9 ms, ~155 KB link overhead
at the frozen demo point; honest max|y| = 2^16.7 vs gate 2^45.

## 7. The challenge-ordering audit

Every Fiat–Shamir challenge in the protocol, what its hash must bind,
the concrete attack when the edge is violated, and the regression that
pins it. This table IS the soundness of the non-interactive layer;
any new challenge added to the protocol must be added here.

The four E3-Z rows (the block before the closing Z1 rows) are the
hash edges added or amended by the lookup subprotocol's
zero-knowledge masking (M4_LOOKUP_ZK_DESIGN.md), merged from that
document's Section 3.3 by tranche U-K5e. Their vocabulary, defined once here: h0_lkp is the
lookup statement hash (it binds the context string, the CRS, and
every X/Y/m tensor commitment; E3-Z adds the mask and blinder
commitments — the round/boundary mask polynomials and the committed
(a, u) blinder-leaf pairs that randomize the descent trees' roots
and leaf claims). alpha is the lookup's log-derivative fusion
challenge; nu_j is the new per-layer mask-combination challenge and
G_j the claimed hypercube sum of the layer-j round mask, pinned to
the pre-committed mask coefficients by a linear E4 CtClaim; the psi
in the last row is the lookup's E4 coordinate-batch challenge (a
different psi from the tie row above). The lookup's own baseline
rows — alpha, rho, lambda_k, r_{k,t}, mu_k, psi, c, with batteries
E3-N1..N5 and E4-N1/N2 — live in M4_LOOKUP_DESIGN.md Section 3.3 and
are unchanged except as amended below; because h0_lkp now binds
STRICTLY more data, every one of those existing edges is preserved
(they must simply be re-run under masking). The "spike Z4"/"spike
Z6" demonstrations cited below are the machine-checked toy-scale
attack/defense pairs recorded verbatim in M4_LOOKUP_ZK_DESIGN.md
Section 8; the E3-Z battery itself (E3Z-N1/N2 and companions) landed
with tranche U-K5d (2026-07-10) — the "pinned by" entries below name
the live batteries in the ring self-test (`self_test_lookup_zk`,
sections `[U-K5c]` and `[U-K5d]`).

The last four rows are the Z1 rows — the hash edges added by the
wave-share masking construction (WAVE_SHARE_MASKING_DESIGN.md
Section 2.5), merged by tranche U-Z1 (PA lane, 2026-07-15); the
construction's transcribed lemmas are Q4_LEMMAS.md Q4.2a' (the
multi-round shared-commitment composition) and Q4.10/Q4.10-X (the
pad-coset lemma and its extraction note). Vocabulary, defined once
here: h0_link is the multi-wave layer rig's statement hash
(RANGE_AGGREGATION_DESIGN.md Section 2b) — it now binds the pad
commitments (the shared BDLOP commitments carrying the coset
one-time pads e_{j,w}, wave-major, 9 per wave) alongside the
data/lookup/mask/g commitments; c_w is wave w's ct-round challenge,
whose round list gains the wave's pad commitment
(verifier-derived from the public plan, D-2); c_z is the closing
round's challenge over ALL pad commitments (the nine exact zero-sum
claims sum_w e_{j,w} = 0); sigma~ (the design's masked reveals) are
the per-wave masked shares; the psi in the last row is the pin-batch
challenge (its edge is UNCHANGED — that row is a scope note, not a
new draw). UNLIKE every earlier block in this table, these rows'
batteries WERE planned at transcription time and are now LIVE (flip
recorded 2026-07-16 — the [Z1] battery landed green with tranche
U-Z1's Z1-impl-c, and each "pinned by" entry names the planned leg —
it must be flipped to the live battery name (or the row re-graded)
when the implementation lands; until then the rows carry
design-round authority only (grading convention:
WAVE_SHARE_MASKING_DESIGN.md Section 0.3).

| challenge | drawn from | must follow | attack if violated | pinned by |
|---|---|---|---|---|
| s, v (gate row/col challenges) | pre-hash | A, B, C commitments | choose C after s, v: defeat 5.2's SZ step | `CE full round: wrong C fails` (transcript-level) |
| psi (tie, full-entropy) | h0 | ALL 12 commitments incl. masks M, N | crafted-mask cancellation of any tie defect (5.6-A) | `CE order regression` pair |
| taui, tauii (tie batches) | XOF(h0, F) | the reveals F | reveal-slack attack (5.6-B): 2 constraints, h unknowns | shipped hash chain; 5.6-A regression pins the chain discipline |
| c (round challenge) | XOF(h0f, head) | every commitment, reveal, and prover image in the round | forge any single claim | every tamper battery in the suite |
| c (round challenge) — R1 addendum | XOF(h0, head) | the R1 pad commitments (ma/mb/mw or m1/mw), in h0 | pad re-chosen after c: a t2 shift by c·Delta absorbs a false claim's defect into the pad opening (and a pad choosing −Ga un-masks the head — Q4.3d leak returns) | `R1 order: pad-after-challenge ACCEPTS the un-mask; pad-in-h0 REJECTS` |
| theta (binary-claim randomizers) | post-mask hash | the g-mask commitment | F5 g-shift attack | `F5:` regression pair |
| JL rows R (ARP) | round hash | the ARP mask commitment | steer the projection around a long vector | ARP negatives (U6b) |
| xi (link rows) | h0_link | BOTH sides' commitments incl. g's | pick values after xi: per-row 2^-w becomes 1 | `wrong xi (stale h0_link)` negative |
| zeta (E2 slot-link junk rows) | h0_link | same as xi — both sides' commitments incl. g's | commit junk after zeta (or drop zeta): constant-reading rows miss the junk coordinates and the composed-Hadamard shift returns | `E2 gap: constant-only rows ACCEPT` / `E2: zeta rows REJECT` pair (U-E2) |
| tau (freeze-era witness tie) | — | — | superseded by U-B5 (first-class tie) | removed with its freeze row |
| alpha (lookup fusion) — E3-Z addendum | h0_lkp = H(ctx, CRS, all X/Y/m commitments AND the mask + blinder commitments) | the mask and blinder commitments | blinder mass solved at a KNOWN alpha passes the blinded root cross-check for a FALSE lookup — spike Z6 demonstrates the accept; a fresh alpha rejects the same committed blinders | `[U-K5d] E3Z-N2` F5 pair (both directions live) |
| nu_j (lookup mask combination, one per layer sumcheck) | XOF(prefix through the layer-j claim and the sent G_j) | the round-mask commitment (in h0_lkp) and G_j | G chosen after nu_j absorbs any claim defect: G := G_true + (C_true − C_false)/nu_j waves a false lookup through — spike Z4 demonstrates the accept; the shipped order (G E4-pinned to the pre-committed coefficients) rejects the same crafting | `[U-K5d] E3Z-N1` F5 pair (both directions live) |
| h0_lkp (lookup statement hash) — E3-Z scope note | — (a hash, not a challenge draw) | now binds the mask and blinder commitments alongside the X/Y/m commitments | none new: binding strictly more data preserves every existing edge; each E3-N pair must be RE-RUN under masking | `[U-K5d]` D3 re-runs: E3-N1 (alpha binds masks+blinders) + masked tamper-rejects (E3-N4/N5 class) live; E3-N2/E4-N2 structurally unchanged by masking, inherited by the honest masked pass + committed ct-round (recorded in the tranche ledger) |
| psi (lookup E4 coordinate batch) — E3-Z addendum | XOF(prefix through ALL claimed values, now including every G_j and every mask opening) | the mask openings and the aggregate leaf pins | craft an opened value after psi: coordinate defects orthogonal to psi pass — E4-N1's attack shape on a grown claim set | `[U-K5d]` E4-N1 masked variant (pin psi batches the mask openings) live |
| h0_link (layer statement hash) — Z1 scope note | — (a hash, not a challenge draw) | now binds the pad commitments alongside the data/lookup/mask/g commitments | a pad commitment outside h0_link can be SWAPPED between the wave rounds and the closing round: present pads summing to delta != 0 to the waves and a different zero-sum set to the closing round — any pin total shifts by delta and a false claim ACCEPTS | `[Z1-c]` F5 pair, both directions (LIVE 2026-07-16, e36ee7b) |
| c_w (per-wave round challenge) — Z1 addendum | XOF(h0_w), h0_w = XOF(lkp state, wave index, wave list INCLUDING the wave's pad commitment) | the wave's pad commitment and the masked reveals sigma~ | pads/sigma~ chosen after c_w absorb a claim defect — the R1.2 pad-after-challenge shape lifted to wave shares; the g-mask cross-use forgery class returns if the pad-commitment identity is not in h0_w | `[Z1-c]` pair + `[Z1-e]` re-runs (LIVE 2026-07-16, e36ee7b) |
| c_z (closing-round challenge) — Z1 | XOF(lkp state, closing tag, ALL pad commitments) | every pad commitment | the zero-sum "proven" against a pad set other than the one the waves read | `[Z1-c]` closing direction (LIVE 2026-07-16, e36ee7b) |
| psi (pin batch) — Z1 scope note | unchanged (M4_LOOKUP_DESIGN E4-N1 edge) | pad LAYOUT precedes everything (plan-derived); pad VALUES are drawn independent of psi | none new: the pad term is verifier-added public structure — the pad at (j, w) is "the pad for copy j's wave-w share", a public position, not a psi-dependent object, so no circularity | E4-N1 re-run under masking, `[Z1-e]` set (LIVE 2026-07-16, e36ee7b) |

## 8. Honest limitations and open obligations

1. **Garbage-image ZK (R1 / Q4.3)** [PROVEN LEAK — R1 fix BUILT;
   masked variant PROVEN HVZK under MLWE]: the quadratic families'
   images (Ga, Gb, G0, G1, and the W mask images), sent unmasked,
   leak fixed witness-images for EVERY witness (Q4_LEMMAS.md Q4.3d) —
   for the multiplication gate the leaked image is the product matrix
   C (Q4.3e). The U-P tranche re-derived this as a hard finding (the
   prior "argued near-uniform" framing was retracted as an overclaim).
   The R1 fix — additive one-time-pad slots on Ga/Gb/G1 AND W,
   committed in the round's g-slot space before the challenge — is
   now BUILT in `ct_engine.rs`: every quadratic claim carries pads
   (3 twisted / 2 untwisted), the engine sends only the masked images,
   the verifier subtracts the pad openings, and callers size the
   g-groups with `sample_g_masks` + `r1_pad_count` (a freeze row pins
   the counts). The masked variant is PROVEN HVZK under MLWE alone
   (Q4_LEMMAS.md Section R1); the leak identity and the pad hash-edge
   are pinned by the `[R1]` battery (leak pair + order pair, F5
   style). MEASURED deltas: rounds with an existing g-commitment pay
   slots only (sub-percent, per R1.4); gate-only rounds pay ONE fresh
   g-commitment + opening where none existed (~116 KB at the CE demo
   shape, ~1.35 MB marginal vs 1.23 MB; pi2-CE demo 2.74 MB vs 2.5 MB)
   — an R1.4 costing correction, see Q4_LEMMAS.md R1.4'. At msg_r = 1
   shapes each pad costs a FULL commitment and can break the C2
   std-bundle budget at wave scale (measured: the chain-demo wave,
   177 commitments, 8·beta = 1.26x q31) — wave rounds must use
   msg_r >= 2 (the chain demo now bumps msg_r 1 -> 2, +1 N_r row).
2. **The pi2 default switch — DONE (U-B6), ZK gate CLOSED by R1**: pi2
   runs the committed-executions gate + tie by default
   (`prove/verify_ring_pi2_ce`, two chained rounds + the K2 pivot,
   mask-side-psi variant; the scalar gate stays behind its r_g flag).
   SOUNDNESS is complete, and with the R1 pads built into both pi2
   paths (the CE gate's wide pad commitment and the scalar gate's
   per-repetition pads) the previously-standing instruction "do not
   treat pi2 proofs as zero-knowledge" is LIFTED at the protocol
   level: the round's HVZK reduces to commitment hiding (MLWE) + the
   rejection lemma (Q4.2a). Residual honesty note: HVZK here is
   proof-of-protocol, not a formal statement about the surrounding
   chain (manifest/reveal plumbing carries its own analysis, Sections
   5-6); E2 (item 3) was the composed-H3 soundness gap and is now
   closed.
3. **H3 slot-constancy (E2) — BUILT (U-E2)**: H3 packing puts each
   value at the constant coordinate of its CRT slot, and nothing in
   the pre-E2 engine forced the other slot-field coordinates to zero;
   GF(q^16) multiplication mixes coordinates, so junk with CORRECT
   constants could shift a composed Hadamard's (gate o up's) product
   constants — a chain-wide soundness gap of composed H3 uses (found
   by the M4 review; the audit's C-01). The fix rides the modulus-link
   rows at ZERO extra rows (`ring/link.rs::link_claims_tgt_slot`): the
   q31-side functional reads value t through the slot-constant CRT
   projection row (E1) and pins EVERY other coordinate of the linked
   elements with fresh signed w-bit XOF weights zeta (E2,
   `derive_link_zeta`, drawn from the same h0_link as xi — the shared
   ordering edge, Section 7). A nonzero (value-delta, junk) pair
   survives a row w.p. <= 2^-w (the Section 6.2 point-mass argument),
   2^-264 at the frozen w = 11, l = 24; honest junk coordinates are
   zero so the revealed y and the q46 grounding side are untouched.
   Slot-constancy of downstream products then follows from claim
   exactness (GF(q) closure). Pinned by the U-E2 battery: the
   composed-product shift demonstrated arithmetically, the
   constant-only-rows ACCEPT / zeta-rows REJECT pair on committed
   tensors, and a freeze row on the junk-weight count. Residual scope
   note: this discharges the generic slot-target link; the M4
   compilation's specific tensor wiring (u_s/A_sel/B_sel map weights)
   ships with whichever M4 variant lands.
4. **Norm/concentration models** [MODEL]: TAIL = 1.3 (empirical
   concentration constant), delta0 = 1.0037 (root-Hermite), the
   d_lwe = 768·log2(q)/11.7 rule, and the ARP's SLACK_OP worst-case
   constant. All are conservative-by-construction and pinned by freeze
   rows; Q4.1/Q4.5 carry the write-up obligations. The ARP extraction
   specifically now has a PROVEN self-contained bound (Q4_LEMMAS.md
   Q4.4c) 2.35 bits tighter than the SLACK_OP gate; SLACK_OP stays as
   the derive-time gate but is no longer the best proven bound.
5. **Quantum margins** [MODEL]: three frozen shapes dip below 128-bit
   under core-SVP quantum costing; kappa+1 fixes it if that target is
   adopted (ESTIMATOR_NOTE.md).
6. **Fiat–Shamir** [MODEL]: random-oracle model, standard forking
   loss; SHA-256/XOF instantiation. CLAIM-DISCIPLINE NOTE (2026-07-10
   audit H-07): every quoted algebraic error term in this document and
   the lookup documents (2^-264, 2^-279, 2^-296, 2^-486-class) is the
   FIELD-STATISTICAL term only; the concrete security of any composed
   statement is min(algebraic error, FS/hash security incl. grinding
   and multi-theorem use, commitment-assumption bound, parameter
   bound) — with SHA-256 transcripts the deployable classical target
   remains 128-bit-class, and quantum preimage search halves hash
   margins. Quantitative claims must be published in this min() form.
7. **Gaussian sampling uses f64 exp** [OBLIGATION]: a prototype
   shortcut noted in `ring/mod.rs`; production requires fixed-point
   (constant-time) sampling.
8. **Proof size at scale** [DESIGN NOTE]: MB-class per matmul claim at
   r = 1; small-proof deployments need the aggregation follow-up
   (GATE_ALTERNATIVES.md options 2/3). Prover TIME is not affected.
9. **exp/softmax (M4) and full-scale measurement (M5)** remain ahead
   of this document's scope, as does the planned adversarial-testing
   phase — this reference is that phase's starting inventory.

## 9. Index of adversarial tests

Every soundness argument above is exercised by at least one negative.
All run in `ring_matmul self-test` unless noted.

| attack surface | test line |
|---|---|
| wrong product, gate layer | `CE full round: wrong C (C != A B) fails` |
| tampered execution vector, tie layer | `CE full round: tampered YA fails (the tie claims catch it in-round)` |
| tie mask-order attack | `CE order regression:` pair (accepts under wrong order, rejects under shipped order) |
| gate garbage images | `CE gate: tampered Ga/Gb/G0 garbage image fails` |
| gate linear mask image | `CE gate: tampered linear mask image W fails` |
| tie claim mask image | `CE tie: tampered ring-claim mask image fails` |
| kernel-path divergence | `CE gate: same-seed proofs bit-identical across kernel paths` |
| binary-gadget mask shift (F5) | `F5:` pair (old claim accepts the attack; fixed claim rejects) |
| non-binary witness | `binary gadget: non-binary coefficient fails` |
| gadget garbage term | `binary gadget: tampered garbage term fails` |
| recomposition/rescale/Hadamard defects | U6a negatives |
| scalar-gate layer (fallback path) | `pi2 semantic soundness: C != A B fails` + reveal/digit/context/row tampers |
| link: wrong bits | `tampered bit (recomposition mismatch) fails the q46 ct check` |
| link: wrong values | `tampered value fails the q31 ct check` |
| link: oversized reveal | `y outside the grounding gate fails` |
| link: stale challenge rows | `wrong xi (stale h0_link, pre-g derivation) fails` |
| H3 junk coordinates (composed Hadamard, E2) | `composed H3 break:` arithmetic demonstration + `E2 gap: constant-only rows ACCEPT` / `E2: zeta rows REJECT` pair (U-E2) |
| R1 pad hash-edge / leak arithmetic | `[R1]` battery: leak pairs (all three quad families) + order pairs |
| parameter drift (all frozen budgets) | `ring_matmul freeze-check` (every row) |

---

*Changelog: 2026-07-09 — first edition, written at U-B5 + U-L4 after
the tie-integration round and the full-suite soundness review.*
*2026-07-09 (U-P proof-debt tranche) — Section 3.2 / 4.5 / 4.7 / 8
grade+pointer updates: the quadratic garbage-image ZK obligation was
re-graded to a PROVEN LEAK (the gate leaks C; Q4_LEMMAS.md Q4.3d/e),
the R1 fix specified with a PROVEN-under-MLWE masked variant
(Q4_LEMMAS.md Section R1; AUTOMORPHISM_GATE_DESIGN.md Appendix B.2),
and the ARP extraction given a PROVEN self-contained bound
(Q4_LEMMAS.md Q4.4c). No claim was upgraded to PROVEN with a labeled
gap; the gate ZK moved from "owed lemma" to "known leak + specified
fix", an honesty correction, not an upgrade.*
*2026-07-09 (R1 engine tranche) — the R1 masking is BUILT: every
quadratic claim family in `ct_engine.rs` now sends R1-masked images
with committed pads in the round's g-slot space; Sections 3.2 / 4.5 /
8 re-graded, the R1 pad hash-edge row merged into Section 7, the
`[R1]` leak/order battery and the pad-count freeze row added. Measured
costs and the R1.4 costing correction (gate-only rounds pay one fresh
g-commitment; msg_r = 1 wave shapes break C2) are recorded in Section
8 item 1 and Q4_LEMMAS.md R1.4'.*
*2026-07-09 (U-E2 tranche) — H3 slot-constancy (E2) BUILT: the
slot-target link (`link_claims_tgt_slot`: E1 slot-constant projection
rows + E2 zeta junk pinning at zero extra rows) closes the
composed-Hadamard soundness gap; Section 8 item 3 added (subsequent
items renumbered), the zeta ordering row added to Section 7, the U-E2
battery and junk-count freeze row added to the suite.*
*2026-08-08 (U-AG-B1 tranche, Agent BA) — Section 10 appended: the
aggregation-layer folding-soundness results of
AGGREGATION_FOLDING_SOUNDNESS.md enter the house corpus at the
U-AG-B1 open. The ring/challenge-engine-class entries (AFS-L0, the
pigeonhole entropy cap, AFS-L6) live here beside the L1/L2 engines
and the (2.2) relaxed-binding shape they extend; the
transcription-class lemmas (AFS-L1..L5, L7, L8) live in Q4_LEMMAS.md
Section 9. Lemma ids preserved as cross-references; the folding
document remains the authority for full statements, proofs, and the
F-C1..F-C6 conditions. No pre-existing text edited.*

## 10. Aggregation-layer addendum (U-AG-B1): fold-layer challenge-set and binding facts

Added 2026-08-08 (U-AG-B1 Agent BA). These entries extend the Section
1.3 challenge-engine inventory and the (2.2) relaxed-binding shape to
the aggregation/folding layer designed by the U-AG trench. Authority:
AGGREGATION_FOLDING_SOUNDNESS.md (statements transcribed; ids
preserved). They cover DESIGNED protocol objects — the aggregate
engine is not yet built; the build round (U-AG-B1 BB) owes the
derive-time asserts and the Section 7 hash-edge row merges when the
fold challenges become live code.

**(10.1) AFS-L0 — the fold-layer challenge sets at our ring
[PROVEN].** (a) The quinary set C is a strong sampling set for the
fold role: differences have coefficients in [−4, 4], and the
[LS18]/[LF Lemma 2.3] hypothesis at (t = 8, q31) is
||y||_inf < q^{1/8}/sqrt(8) = 5.19 — margin 1.297x, EXACTLY the C0'
freeze check params.rs already asserts (Section 1.3 L1 is the same
fact in its house form). (b) The slot-diagonal K-set {diagonal
embeddings of GF(q^16)} is a strong sampling set of size q^16 =
2^496: a nonzero difference is nonzero in EVERY slot, hence
invertible (the Section 1.3 full-entropy engine's mass, now with the
strong-sampling reading made explicit). (c) **The pigeonhole entropy
cap** ([LF] Section 3.3's argument, stated as a ring theorem): ANY
strong sampling set in R_q ≅ GF(q^16)^8 has size at most q^16 —
two elements agreeing in one slot differ by a zero divisor. So the
fold-challenge entropy of ANY design at our ring is structurally
capped at 496 bits per challenge; at a FULLY-split ring the cap is
q = 2^31 — the 2026-04-30 break regime (three public LaBRADOR
implementations died exactly there), unfixable by set design. This
is the quantitative justification, stated once, for the k = 8
partial-splitting choice of Section 1.1.

**(10.2) AFS-L6 — the fold binding bound, re-derived in l2
[PROVEN].** The (2.2) relaxed-binding shape at the fold layer, with
the l_inf-native [LF]/[LF+] hypothesis replaced by house l2 objects:
two 2B-weak openings (Delta_j, x_j) of one commitment with
range-pinned ||x_j||_inf < 2B_acc (hence ||x_j||_2 <
2·sqrt(d·m_acc)·B_acc) and op-norm-capped challenge differences
op_2(Delta_j) <= 2·T_cap yield the nonzero MSIS solution
Delta_2·x_1 − Delta_1·x_2 with

    beta_fold(l2) <= 8 · T_cap · sqrt(d·m_acc) · B_acc.

Three lines (op-norm submultiplicativity + triangle inequality —
SC-L1 step 3's arithmetic with the fold's objects), but load-bearing:
the naive l_inf-to-l2 conversion costs sqrt(d·m) and lands the fold's
binding instances 0.4 bits under the R-EB4 validity line at the
smallest plausible shapes (13/48 envelope failures, crossing q at the
larger ones); the l2 route passes 48/48 with >= 0.9 b headroom,
recovering log2(256/33) = 2.96 bits per row. [LF+] Section 6 leaves
the l2 variant open — this is the house's answer for the one step the
chain needs. Frozen constants: T_cap = 33 (R-EB1), kappa = 11,
validity line 2^30.5, floor bases e <= 7 (R-EB4) — all pinned both
directions by `scripts/aggregation_freeze_rows.py` (suite:
`tests/test_aggregation_freeze.py`).

**(10.3) Fold-layer hash edges — pointer row.** The Section 7
ordering audit gains NO live rows yet: the fold challenges are
design-stage. Their complete edge tables (with attacks and planned F5
pairs FSB-1..4, AZB-10) are AGGREGATION_FOLDING_SOUNDNESS.md Section
7 and AGGREGATION_FOLDING_DESIGN.md Section 7 (IXF: the segment-map
and group-map edges in h0_agg, mu after ALL blinded terminals, nu_g
after mu, per-group eval-proof edges per AZ-L4(a); theta-before-rho
inside the eval proof). Per this document's own rule ("any new
challenge added to the protocol must be added here"), those rows MERGE
into Section 7 when lane BB lands the fold challenges as code —
recorded here so the merge is an obligation with an owner, not a
surprise.



