# M4 Lookup ZK Design (E3-Z): Masking the LogUp-GKR Transcript

Status: design round COMPLETE (equations + machine-checked spike, no
engine code — the AUTOMORPHISM_GATE_DESIGN discipline: paper first).
This is tranche U-K5 (E3-Z) of M4_LOOKUP_DESIGN.md Section 8: the
obligation opened by that document's Section 3.5 ("the lookup
subprotocol as specified is NOT zero-knowledge"). Every masked check
equation below is exercised end-to-end by
`scripts/logup_zk_mask_spike.py` (pure stdlib, exact arithmetic, 11 OK
assertion lines including two F5 ordering pairs; output recorded in
Section 8). Companions: M4_LOOKUP_DESIGN.md (the construction being
masked; its Sections 3.3–3.5 are assumed throughout), Q4_LEMMAS.md
Sections Q4.3d/e and R1 (the house standard this document is written
to), SOUNDNESS_REFERENCE.md (grading conventions, Section 3.2 for what
already simulates, Section 7 for the audit-table format),
AUTOMORPHISM_GATE_DESIGN.md Appendix B.2 (the simulator style copied in
Section 4).

Grading follows the soundness reference's legend: **[PROVEN]** /
**[MODEL]** / **[OBLIGATION]**; **[SKETCH]** marks arguments given here
in full but not yet transcribed into the soundness reference.

**The verdict in one paragraph.** Libra-class masking DOES close over
this transcript, but not verbatim — two structural mismatches had to be
resolved, and both resolutions are machine-checked. (1) Libra's
layer-value masks vanish at any point with a Boolean coordinate, and
our fold-based Papini–Habock descent evaluates children exactly at such
points ((0, r) and (1, r)); the fix is a one-factor vanishing
polynomial z_2(1 − z_2) with masks linear in the fold variable, plus
Libra's own dummy-variable trick to carry the mask correction inside
the next sumcheck. (2) The tree's top (roots and layer-1 values) and
its leaf claims cannot be masked by any hypercube-agreeing polynomial
at all — those ARE hypercube values; the fix is blinding leaves:
committed (a, u) pairs whose fractional masses are constant in alpha
(so they can never alias a table pole — soundness untouched) and equal
across the two trees by construction. With the round masks (Libra
Construction 1 shape) on top, every prover-sent value in the lookup
transcript becomes either uniform, uniform-on-a-check-variety, or
forced by a verification equation, and the simulator reduces to MLWE
commitment hiding plus the engine's existing [PROVEN] ct-round
machinery. The multiplicity-histogram leak (v^M) is closed
structurally: the masked design never sends per-tensor MLE values —
only blinded aggregates are claimed. Cost: ~2.3k committed K-elements
(~37k dce, ~+2e-4 dce/el — a sharpening of the parent doc's ~100
K-element guess, still ~4 orders inside the Class-3 budget), ~+17 KB of
transcript (~120 → ~140 KB/pass), prover and verifier deltas
sub-percent [MODEL]. E3-Z stays design-blocking for ZK deployments
until the U-K5 build lands, but the design risk is now retired: the
spike demonstrates the leak (m recovered exactly from one unmasked
transcript), the masked completeness, the recovery failure, both
ordering attacks, and soundness under masking.

## PROGRESS

- [x] Section 0: symbols and setting
- [x] Section 1: the leak inventory, sharpened (exact identities)
- [x] Section 2: literature anchors + the two structural obstructions
- [x] Section 3: the masking spec (M1/M2/M3), exact equations, hash
      edges, cost delta
- [x] Section 4: the simulator, component by component (graded), and
      the re-graded Section 3.5 table
- [x] Section 5: soundness non-interference
- [x] Section 6: build plan (U-K5a..e), negative battery, freeze rows
- [x] Section 7: what could kill this (+ priced fallbacks)
- [x] Section 8: spike output (recorded verbatim)

## 0. Symbols and setting

Everything from M4_LOOKUP_DESIGN Section 0 is in scope (q = 2^31 − 399;
K = GF(q^16), |K| ≈ 2^496; N, T, m, MLE, dce). New symbols:

- **Layer index j** — the descent's layers, root = layer 0, leaves =
  layer J (witness J = 23 per instance, table J = 9 after blinders,
  Section 3.1). The layer-j sumcheck reduces a claim about layer j to
  the four boundary values of layer j + 1.
- **z** — the incoming claim point of a layer sumcheck (z = (mu, r) of
  the previous layer); **r** its sumcheck challenges; **b** the Boolean
  summation variables; **w** the ZK dummy variable (one per layer
  sumcheck, new here).
- **g^(j)** — the layer-j ROUND mask (M1): a committed sum of
  univariates, Libra Construction 1 shape. **G_j** — its hypercube sum.
  **nu_j** — the mask-combination challenge (Libra's rho; renamed
  because rho is taken by instance batching).
- **Rp_j, Rq_j** — the layer-j BOUNDARY masks (M2): committed
  bivariate polynomials of degree (1, 2) in (z_1, w), 6 K-coefficients
  each. **SP_j(z_1) := Rp_j(z_1, 0) + Rp_j(z_1, 1)** (similarly SQ_j).
- **Blinder leaf** — a committed pair (a, u), u ≠ 0, placed at a public
  dummy position; leaf value (p, q) = (a, u); fractional mass a/u (M3).
- **Exposure / pad** — an exposure is a transcript value visible to the
  verifier; a pad is a committed uniform mask degree of freedom. The
  hiding arguments below are rank statements: exposures are affine (or
  variety-constrained) images of pads with full row rank.
- **E4 pin** — a value sent in the transcript whose correctness is
  enforced by a linear CtClaim over committed data (public weights),
  exactly the `pack_functional` shape of M4_LOOKUP_DESIGN Section 3.4.

The spike models Fiat–Shamir as a seeded challenge tape (same
convention as `logup_gkr_spike.py`); ordering attacks are modeled by
letting the adversary read the tape before crafting, exactly as the
parent spike's OK-2c/2e did.

## 1. The leak inventory, sharpened (the Q4.3d discipline)

M4_LOOKUP_DESIGN Section 3.5 graded every row LEAK on the R1 principle
(a deterministic function of (witness, public challenges) is a leak
unless proven otherwise). Here is each row again with the exact
algebraic identity exposed and its class: **recoverable-witness-image**
(the R1 class — a public linear system recovers a witness object
exactly, like Q4.3e's C recovery) or **aggregate-statistic** (a
deterministic witness image not shown to invert, still a leak by the
house standard).

| transcript value | exact exposed identity | class |
|---|---|---|
| table-descent round polynomials and boundary values | every p-side value of the table tree is AFFINE in m with PUBLIC coefficients: parents are p' = p_L q_R + p_R q_L with the q-tree fully public (q-leaves are alpha − t_j over public fused rows), so each round-poly evaluation and each vp is sum_j c_j(challenges) m_j + c_0 | **recoverable-witness-image**: ONE transcript recovers m EXACTLY. Spike Z1a proves the affineness by probe reconstruction; Z1b solves the system: rank T/T, exact recovery. This is Q4.3e one level up: m is the activation histogram — the input distribution of the layer |
| table root pair (P_t, Q_t) | Q_t = prod_j (alpha − t_j) is PUBLIC; P_t/Q_t = sum_j m_j/(alpha − t_j) — one K-element = 16 base-field linear equations in the 256-dim m per pass (spike Z1c checks the identity exactly) | recoverable across passes even WITHOUT the descent: ~16 passes at fresh alphas give ≥ 256 equations; with the descent (row above) one pass suffices |
| witness round polynomials g_{k,t} (~281 per pass) | g_{k,t}(x) = sum over the Boolean suffix of eq(z, ·)-weighted products of layer-(k+1) values — challenge-keyed sums of degree-2 monomials in subtree aggregates of {alpha − w_i} | aggregate-statistic: no full-witness inversion is claimed at N = 2^23, but every value is a deterministic witness image pinned by public challenges (Q4.3d: the simulator cannot produce them without the witness) |
| witness boundary values vp0/vp1/vq0/vq1 (~31 × 4) | vp_c = p_{k+1}((c, r)), the true layer MLE at a public-after-challenge point | aggregate-statistic (same as above); at the LEAF layer these become the row below |
| witness roots (P_w, Q_w) | Q_w = prod_i (alpha − w_i) — a challenge-keyed digest of the fused multiset; P_w/Q_w = sum_i 1/(alpha − w_i) | aggregate-statistic per pass; multiset-distinguishing across passes (fresh alpha each pass = fresh digest of the SAME tensor pair: an offline dictionary test on candidate witnesses) |
| final MLE values v^X, v^Y | 16 base-field linear equations per pass in the committed tensor coefficients (L_{z*}-weighted) | aggregate-statistic with LINEAR ACCUMULATION across passes: p passes leak 16p independent equations on the 5.6e6-dim tensor — bounded but growing, exactly the "bounded leak" shape the R1 history killed |
| final MLE value v^M | 16 base-field linear equations per pass in the 256-dim m | **recoverable-witness-image across ≤ ~16 passes** (and one pass via the table descent anyway) |
| m commitments | MLWE-hiding | NOT a leak [PROVEN] (unchanged) |

Honest summary of what an adversary learns from one unmasked pass: the
complete multiplicity histogram of every layer's activations (exactly —
not statistically), plus ~1,400 K-elements of challenge-keyed digests
of the activation tensors that support offline hypothesis testing and
accumulate linearly across passes. The unmasked transcript is not
"bounded leakage"; part of it is a plaintext readout of a witness
object. This is what E3-Z must close.

## 2. Literature anchors, and why Libra does not port verbatim

**Chiesa–Forbes–Spooner** (ePrint 2017/305): zero-knowledge sumcheck by
masking — prove H = sum f by drawing a random polynomial g, sending
G = sum g, drawing rho, and running the sumcheck on f + rho·g; the
verifier finishes with an opening of g at the challenge point. Their g
is as large as f (sent as a PCP oracle) — sound foundation, unusable
cost.

**Libra** (Xie–Zhang–Zhang–Papamanthou–Song, ePrint 2019/317, CRYPTO
2019), the two constructions we adapt: (i) *ZK sumcheck* (their
Construction 1): the mask can be SMALL — g(x_1..x_l) = a_0 + g_1(x_1)
+ … + g_l(x_l) with each g_t univariate of the round degree d, because
the l rounds expose exactly l(d+1) − (l−1) = ld + 1 independent linear
constraints on the summed polynomial and g supplies exactly ld + 1
uniform coefficients (their Theorem 4.1's counting; machine-checked for
our shape in spike Z3c). (ii) *ZK GKR* (their Construction 2): the
layer-value evaluations ˙V(u), ˙V(v) are masked by replacing V with a
low-degree extension ˙V(z) = V(z) + Z(z)·sum_{w∈{0,1}} R(z_1, w),
where Z(z) = prod_t z_t(1 − z_t) vanishes on the hypercube (so all
summed relations still see the true circuit) and R is a committed
2-variable polynomial of variable-degree 2, opened at (u_1, c) and
(v_1, c); a 4×7 full-rank matrix makes the four exposures jointly
uniform. **zkCNN** (Liu–Xie–Zhang, ePrint 2021/673) deploys exactly
this masking at CNN scale over GKR. **2023–2026 scan** (this round's
literature check): no published improvement supersedes the small-mask
technique for GKR-style transcripts; the field has instead pushed
hiding into the polynomial-commitment layer (Zeromorph, ePrint
2023/917-class hiding multilinear PCS) or reuses Libra's masks
unchanged (e.g. SUMMER, ePrint 2025/1688, for sumcheck+LogUp-GKR
training proofs). Our commitment layer is BDLOP + CtClaims, so the
PCS-hiding route does not apply; the small-mask route is the one to
adapt.

**Obstruction O-1 (half-Boolean boundary points).** Libra's GKR sends
layer values at FULLY random points u, v (their two-point reduction
draws both coordinates fresh), so Z(u) ≠ 0 and the LDE mask is alive.
Our Papini–Habock fold sends the four boundary values p_{j+1}(0, r),
p_{j+1}(1, r), q_{j+1}(0, r), q_{j+1}(1, r) — the first coordinate is
BOOLEAN by construction (the child-selector variable), and any mask
term Z(z)·S with the full vanishing polynomial dies there:
Z((c, r)) = c(1 − c)·(…) = 0. A verbatim Libra port masks nothing at
our boundary. *Resolution:* vanish in ONE suffix coordinate only —
Ẑ(z) := z_2(1 − z_2) — which is zero on the hypercube (z_2 Boolean)
but nonzero at (c, r) (z_2 = r_1, random); and make the mask LINEAR in
z_1 so the verifier's mu-fold commutes with it (the folded claim then
carries the mask value SP(mu) implicitly, no extra opening). The
correction that the next sumcheck owes — its incoming claim is now
masked — rides Libra's own dummy variable w: the mask is
Ẑ(z)·sum_{w∈{0,1}} R(z_1, w) with R of degree (1, 2), the summand gains
the term eq(b, 0)·Ẑ(z)·R(z_1, w), and the verifier finishes with one
opening R(mu, c) per mask — three exposures against six coefficients,
full rank (spike Z3c: rank 6/6 for the (Rp, Rq) pair). A pleasant
byproduct of the one-factor Ẑ: the degree bump hits ONE round per layer
(the first b-round goes from degree 3 to 5), not all of them.

**Obstruction O-2 (tops and leaves are hypercube values).** The roots
and the layer-1 quadruple are actual node values of the tree, and the
final claims must pin TRUE leaf MLEs against the commitments (E4). No
hypercube-agreeing mask can touch either — a mask that preserves the
tree's values preserves exactly what these messages reveal. Libra has
no analogue of our root cross-check (their output layer is public), and
their input layer hides behind a hiding PCS we don't have. *Resolution:*
randomize the VALUES with blinding leaves (Section 3.1): committed
(a, u) pairs at public dummy positions. Their masses a/u are CONSTANT
as rational functions of alpha (u is committed before alpha and does
not contain it), so by partial fractions they can never cancel or fake
a pole — the lookup's soundness content is untouched (Section 5) —
while multiplicatively randomizing Q-products and additively
randomizing masses and leaf MLEs. The final claims are restructured so
that ONLY blinded aggregates are ever claimed: v^X, v^Y, v^M as
individual values disappear from the transcript (Section 3.2, "the
leaf interface").

## 3. The masking spec (E3-Z)

Three mask families. M1 masks the round polynomials, M2 the interior
boundary values, M3 the tops and the leaf layer. All mask data is
committed in the statement wave, BEFORE alpha, alongside m — h0_lkp
binds it (Section 3.3).

### 3.1 Committed objects and where they live

| object | shape (K-elements) | count per pass | where it lives | committed when |
|---|---|---|---|---|
| g^(j) round masks (M1) | 1 + sum of round degrees = 3k + 20 at witness layer k (ℓ = k + 6 variables: k tree + 5 instance + 1 w; degrees 5, 3×(ℓ−2), 2) | Σ_{k=1..22} (3k+20) = 1,199 witness + Σ_{k=1..8} (3k+20) = 268 table | dedicated small mask commitment(s) in the statement wave (msg_r ≥ 2 per the R1.4' rule); coefficients dense-packed, 16 base coeffs per K-element | before alpha, in h0_lkp |
| Rp_j, Rq_j boundary masks (M2) | 6 each (degree (1,2) in (z_1, w)) | 2 × (21 witness interior layers + 7 table) = 336 | same mask commitment | before alpha |
| blinder leaves (M3) | (a, u) per leaf; 2 top + 2 final leaves per tree = 8 | 8 × 2 trees × 32 instances = 512 | ride each instance's m-commitment group (+1 ring element of message: 8 K-el = 128 coeffs) | before alpha |
| **total** | | **~2,315 K-el = 37,040 dce** | | |

Placement of the blinder leaves inside each padded tree (public, fixed
by freeze row LKP-6): two TOP blinders, one in each half of the leaf
layer (they randomize the two layer-1 values and hence the roots); two
FINAL blinders, one at an even position and one at an odd position
(the last sumcheck's boundary points (0, r) and (1, r) give nonzero
eq-weight only to matching parities — both must be padded). The table
tree's 256 rows exactly fill depth 8, so blinders push the table
descent to depth 9 (+1 layer sumcheck; the witness tree's dummy space
absorbs its blinders at depth 23). One table-side blinder value is not
drawn but SOLVED: a'_tR := u'_tR ·(beta_w − rest), making the two
trees' total blinder masses equal — the completeness condition of the
root cross-check. Every u is drawn nonzero; degenerate draws restart
(Section 3.4's guard list).

### 3.2 The masked protocol, exactly

Per descent (witness and table identically; single-instance notation —
the instance eq-batching adds its 5 variables to every layer sumcheck
and changes nothing about the masks; Section 7 item 2 flags the
formulation dependency).

**Masked layer polynomials (M2).** For interior layers 2 ≤ j ≤ J − 1:

    p^dot_j(z) := p_j(z) + Ẑ_j(z) · SP_j(z_1),   Ẑ_j(z) := z_2 (1 − z_2),
    SP_j(z_1)  := Rp_j(z_1, 0) + Rp_j(z_1, 1),

and the same for q with Rq_j. Layer 1 and layer J (leaves) carry NO
LDE mask (O-2); the root layer is derived, not sent.

**The top.** The prover sends the layer-1 quadruple (p_1(0), p_1(1),
q_1(0), q_1(1)) per instance tree. The verifier derives the roots
P = p_1(0) q_1(1) + p_1(1) q_1(0), Q = q_1(0) q_1(1), checks
Q_w, Q_t ≠ 0 and the cross-check P_w Q_t = P_t Q_w, and forms the first
claim C_1 = fold_mu0(p_1) + lambda_1 · fold_mu0(q_1) at z = (mu_0).

**The layer-j sumcheck** (variables b ∈ {0,1}^j then w ∈ {0,1};
with instance batching, b includes the 5 instance bits). Summand:

    F_j(b, w) := (1 − w) · eq(z, b) · [ p^dot_{j+1}(0,b) q^dot_{j+1}(1,b)
                 + p^dot_{j+1}(1,b) q^dot_{j+1}(0,b)
                 + lambda_j · q^dot_{j+1}(0,b) q^dot_{j+1}(1,b) ]
                 + eq(b, 0) · E_j · [ Rp_j(z_1, w) + lambda_j · Rq_j(z_1, w) ],

where E_j := Ẑ_j(z) = z_2(1 − z_2) is PUBLIC (z is the incoming claim
point) and the correction term is ABSENT at j = 1 (its incoming claim
is unmasked). Because the masked children agree with the true children
on the hypercube (Ẑ vanishes there), the hypercube sum of the wiring
term is the true relation; the correction term sums (over b = 0, both
w) to exactly the incoming claim's mask value
E_j·(SP_j(mu) + lambda_j·SQ_j(mu)) — which is precisely what the
mu-fold of the previous layer's masked boundary values deposited into
C_j, by z_1-linearity of SP. Completeness is therefore exact (spike
Z2 runs every equation).

**Round masking (M1).** Draw nu_j ∈ K* from the transcript hash (after
the claim C_j is fixed; the mask commitment is already in h0_lkp). The
sumcheck runs on F_j + nu_j·g^(j) with initial claim C_j + nu_j·G_j,
where G_j (the hypercube sum of g^(j), a public-weight functional of
the committed coefficients: 2^ℓ a_0 + 2^{ℓ−1} Σ_t g_t(1)) is sent and
E4-pinned. Per-round checks are unchanged: g̃(0) + g̃(1) = C, fold
C ← g̃(r_t) by Lagrange interpolation. Round degrees: first b-round 5
when the children are masked (the Ẑ factor rides z_2 = b_1 only), 3
for the other b-rounds, 2 for the w-round — i.e. 6/4/3 evaluations.

**End of the layer-j sumcheck.** The prover sends the four masked
boundary values vp0 = p^dot_{j+1}(0, r), vp1 = p^dot_{j+1}(1, r),
vq0, vq1, plus the openings g^(j)(r, c) and (for j ≥ 2) Rp_j(mu, c),
Rq_j(mu, c) (c is the w-round challenge; every opening is E4-pinned).
The verifier checks

    C_end = (1 − c) · eq(z, r) · [ vp0·vq1 + vp1·vq0 + lambda_j·vq0·vq1 ]
            + Π_t (1 − r_t) · E_j · [ Rp_j(mu, c) + lambda_j·Rq_j(mu, c) ]
            + nu_j · g^(j)(r, c),

draws mu_j and lambda_{j+1}, and folds:
z' = (mu_j, r), C_{j+1} = fold_mu(vp) + lambda_{j+1}·fold_mu(vq).

**The leaf interface (aggregate-only E4 claims).** The last sumcheck's
children are the TRUE leaf MLEs (blinder-extended); its boundary
quadruple is sent raw — padded by the final blinders. After the last
fold the verifier holds p(z*) and q(z*) and checks them against exactly
TWO pinned aggregates per tree:

    p(z*) = H(z*) + [ MLE of the committed a-column ](z*)          (P-pin)
    q(z*) = alpha·H(z*) + D(z*) + [ MLE of the committed u-column ](z*)
            − [ MLE(X̂) + Y·MLE(Ŷ) ](z*)                            (Q-pin)

with H, D the public indicator MLEs of the honest and dummy positions
and X̂, Ŷ the tensor columns (zero off the honest block). Table side:
the P-pin's aggregate spans [m-columns ⊕ a'-blinders] and the Q-pin's
public part includes the verifier-computed fused-row MLE. **v^X, v^Y
and v^M are never sent or individually claimed** — each pin is one
16-coordinate CtClaim row family over multiple commitments, exactly the
`pack_functional` shape (same psi batch, same 9 claims). This closes
the histogram channel structurally: no functional of m alone appears in
the transcript.

### 3.3 Transcript order and the new hash edges (Section 7 audit format)

The lookup transcript hash chain of M4_LOOKUP_DESIGN Section 3.3 is
amended as follows. New structural rule, stated once: **all mask and
blinder commitments enter h0_lkp** (they precede alpha), and **masks
are one-time — fresh per pass** (reuse subtracts: two transcripts with
the same g reveal the unmasked difference of two runs; battery
E3Z-N3).

| challenge | drawn from | must follow | attack if violated | pinned by (planned) |
|---|---|---|---|---|
| alpha (AMENDED row) | h0_lkp = H(ctx, CRS, all X/Y/m commitments AND the mask + blinder commitments) | the mask and blinder commitments | blinder mass solved at a known alpha passes the blinded cross-check for a FALSE lookup — spike Z6 demonstrates the accept; fresh alpha rejects the same committed blinders | E3Z-N2 F5 pair |
| nu_j (mask combination, one per layer sumcheck) | XOF(prefix through the layer-j claim and the sent G_j) | the mask commitment (in h0_lkp) and G_j | G chosen after nu absorbs any claim defect: G := G_true + (C_true − C_false)/nu waves a false lookup through — spike Z4 demonstrates the accept; the shipped order (G E4-pinned to the pre-committed coefficients) rejects the same crafting | E3Z-N1 F5 pair |
| r_{j,t} and the w-round challenge c_j | XOF(prefix through round t's poly) | round t's masked polynomial | classic sumcheck order attack (unchanged) | E3-N4 battery, extended to the w-rounds |
| mu_j | XOF(prefix through the four masked boundary values) | the boundary values | choose the four after mu (unchanged) | E3-N5 |
| psi (E4 batch, AMENDED row) | XOF(prefix through ALL claimed values, now including every G_j and every mask opening) | the mask openings and aggregate pins | craft an opened value after psi: coordinate defects orthogonal to psi pass | E4-N1, scope extended |
| c (E4 ct-round) | unchanged; h0_round binds the full lookup transcript including masks | everything above | unchanged; restarts re-derive c only — masks are committed data, not per-round samples, so NO new rejection-sampling surface exists and restarts cannot grind them | E4-N2 |

### 3.4 Completeness guards (restart conditions)

Each of the following is checked at derive time and triggers a restart
of the affected draw; each has probability ≤ 2/|K| ≈ 2^-495 per event
[PROVEN, union bound over ~500 events per pass — negligible and, per
Section 4, the simulator conditions on the same events so no channel
opens]: (a) any first-round sumcheck challenge r_1 ∈ {0, 1} (would kill
E_{j+1}); (b) nu_j = 0; (c) a blinder u drawn 0; (d) eq-weight of a
blinder position vanishing at a boundary point or z* ; (e) the existing
pole-hit guards (Q = 0). Freeze row LKP-6 pins the guard list.

### 3.5 Cost delta (against Section 7 of the parent doc)

Committed: 2,315 K-elements = 37,040 dce (Section 3.1 table) on top of
the m columns' 8,192 — total lookup commit ~45k dce per pass =
**2.5e-4 dce/el** (was 4.5e-5; the parent doc's "~100 K-elements"
mask guess is corrected here to ~2.3k — the counting is per-layer,
not per-pass). Still ~4 orders inside the 2–4 dce/el Class-3 budget.

Transcript delta [arithmetic shown, MODEL]: w-round polys 30 × 3 × 64 B
= 5.8 KB; first-b-round degree bump (4 → 6 evals) 28 × 2 × 64 B =
3.6 KB; G values 30 × 64 B = 1.9 KB; openings (g, Rp, Rq) ≈ 86 × 64 B
= 5.5 KB; table depth 9 (one more layer sumcheck) ≈ 1 KB. **Total ≈
+18 KB → ~140 KB/pass** (the ~120 KB baseline; both under the
eq-batched instance reading — the parent doc's 253-round count did not
include instance-bit rounds, flagged in Section 7 item 2).

Prover: the correction summand is O(1) per layer; mask evaluations are
O(ℓ) per round; the degree-5 first rounds add 2 evaluations over
2^{ℓ−1} points for one round per layer — total well under 1% of the
43 K-mult/el budget [MODEL]. Verifier: +O(#rounds) K-ops for the new
check terms plus weight expansion over the ~2.3k-coefficient mask
commitments — noise against the 2.3e7 ring-op tensor weight expansion.
E4: the openings add ~1.9k coordinate rows to the psi batch; the batch
stays 9 CtClaims (psi copies unchanged).

## 4. The simulator, component by component (Appendix B.2 style)

The claim: the masked lookup transcript is HVZK — a simulator with the
statement only (commitments, table digest, shapes) produces transcripts
computationally indistinguishable from honest ones, reducing to MLWE
commitment hiding plus the engine's existing ct-round machinery.
Spike Z3d implements the descent-level simulator literally: uniform
samples plus forced values, no witness touched, verifier accepts.

1. **Commitments (m, masks, blinders) [PROVEN under MLWE].** All are
   BDLOP commitments; hiding is per-commitment randomness
   (SOUNDNESS_REFERENCE 2.1). The solved blinder value a'_tR is a
   deterministic function of other COMMITTED values — contents
   correlation, which 2.1 already covers (the tie-mask precedent).

2. **Challenges [PROVEN].** All are hash outputs; the simulator
   programs the RO / recomputes them (FS, ROM — repo convention).

3. **Per-instance tops [PROVEN at spike scale; general-shape rank
   lemma an OBLIGATION, U-K5d].** Exposures per instance: two layer-1
   quadruples (roots are derived). Real distribution: q_1(0) = Q_half ·
   u_top-products — one uniform nonzero factor each (u_tL, u_tR and the
   table twins) makes the four q-values independent uniform on K*;
   p_1(half) = (S_half + beta_half)·q_1(half) with each half's blinder
   mass carrying a fresh a/u — uniform given the q's; ONE relation
   binds the eight values: the cross-check (equivalently, the mass
   equality that solved a'_tR). Simulator: sample seven values uniform
   (q's nonzero), solve the eighth from the cross-check — exactly what
   Z3d does; the real world's solved pad (a'_tR) matches the sim's
   solved exposure (p'_1(1)) — the varieties coincide.

4. **Round polynomials [PROVEN, the adapted Libra counting;
   transcription to Q4_LEMMAS an OBLIGATION].** Per layer sumcheck the
   verifier sees ℓ(d_t+1)-style evaluations of F + nu·g, of which the
   ℓ round checks and the end check are forced: free exposures =
   (Σ_t (d_t + 1)) + |{G}| + |{g(r,c)}| − (ℓ + 1) = 1 + Σ_t d_t = n_g,
   the exact coefficient count of g^(j). Spike Z3c machine-checks this:
   the affine map from g-coefficients to (G, all round evaluations,
   g(r, c)) has rank n_g = 11 with exactly ℓ + 1 = 4 forced relations
   at the probed layer. The exposures are therefore uniform on the
   check variety; the simulator samples them so (round polys: d free
   evaluations per round given the running check; g-opening: solved
   from the end check — Z3d's construction).

5. **Interior boundary values and mask openings [PROVEN at spike
   scale, same caveat as 4].** Per interior layer: four boundary
   values, padded by E_r·SP_{j+1}(0/1), E_r·SQ_{j+1}(0/1) (E_r ≠ 0 by
   guard), plus the two openings Rp_j(mu, c), Rq_j(mu, c). Exposure
   map: {SP(0), SP(1), R(mu, c)} per polynomial — three independent
   functionals of six coefficients (degree (1,2): the (0/1)-sums touch
   disjoint halves of the w-Vandermonde and the (mu, c) evaluation is
   independent for c ∉ {0,1}). Spike Z3c: rank 6/6 for the pair.
   Simulator: uniform boundary + uniform openings (Z3d).

6. **Leaf boundary and the aggregate pins [PROVEN at spike scale].**
   The four leaf boundary values are affine in the blinder pads with
   full row rank (spike Z3b: rank 4/4 — the parity placement of the
   final blinders is what makes the (1, r)-weighted rows nonzero); the
   folded p(z*), q(z*) are then derived, and the two pins per tree are
   check equations, not exposures. Fresh pad accounting (the ledger):
   E1 ← a_f0 (a_tL, a_tR also present, spent at the top but E1 needs
   only ONE fresh dim), E2 ← a_f1, E3 ← u_f0, E4 ← u_f1; the top
   spent (u_tL, u_tR, a_tL, a_tR) — no dim is double-counted.

7. **The E4 layer [PROVEN — existing machinery].** The aggregate pins
   and mask-opening pins are linear CtClaims: their reveals are forced
   by verification equations and g-masked per the engine's existing
   round (SOUNDNESS_REFERENCE 3.2, Q4.3b-ii, R1) — the simulator is
   the engine's. No quadratic claim is added by E3-Z, so no new R1
   surface opens.

8. **What still leaks, honestly.** (i) Shape metadata: N_inst, tree
   depths, instance count, the table digest — public by design, not
   witness. (ii) Restart counts from the Section 3.4 guards — each
   restart fires with probability ~2^-495; the channel is empty for
   any physical number of passes [PROVEN, union bound]. (iii) HVZK is
   proof-of-protocol, not a chain-wide statement — the same honesty
   note as R1.3's; manifest/reveal plumbing carries its own analysis.
   (iv) Nothing else: in particular the multiplicity histogram has NO
   remaining channel — no functional of m alone is sent (the v^M row
   is gone, the table-descent p-side is masked, P_t is
   blinder-randomized).

**The Section 3.5 table, re-graded** (the U-K5 exit criterion of the
parent doc, met at design level):

| prover-sent value | unmasked grade | masked grade |
|---|---|---|
| round polynomials | LEAK | uniform on the check variety (M1; component 4) [PROVEN at spike scale] |
| boundary values (interior) | LEAK | one-time-padded (M2; component 5) [PROVEN at spike scale] |
| layer-1 values / roots | LEAK | uniform on the cross-check variety (M3 top blinders; component 3) [PROVEN at spike scale] |
| leaf boundary values | LEAK (v^X/v^Y/v^M class) | one-time-padded (M3 final blinders; component 6) [PROVEN at spike scale] |
| v^X, v^Y, v^M | LEAK (v^M recoverable) | REMOVED from the transcript (aggregate-only pins) — no residual channel |
| E4 reveals | inherited the v leak | forced/g-masked as before; inherits nothing (component 7) [PROVEN] |
| m / mask / blinder commitments | not a leak | not a leak (MLWE) [PROVEN] |

## 5. Soundness non-interference (the R1.3 pattern)

The masks cannot help a cheating prover; every argument is either an
identity or is spike-checked.

1. **Round masks (M1).** g^(j) is committed before alpha (hence before
   nu_j), and G_j is pinned to the committed coefficients by an E4
   CtClaim. For any claimed C: the sumcheck proves
   Σ(F + nu·g) = C + nu·G_j; with G_j = Σg forced, this is Σ F = C —
   the mask cancels IDENTICALLY, contributing zero soundness error
   (stronger than Libra's setting, where G is pinned only through the
   opening). The one load-bearing edge is the pin itself: with G
   unpinned, G := G_true + (C_true − C_false)/nu absorbs any claim
   defect — spike Z4 accepts a FALSE LOOKUP this way and the shipped
   order rejects the same crafting (the E3Z-N1 pair). This is the
   exact analogue of R1.2's pad-after-challenge attack.

2. **Boundary masks (M2).** The masked children agree with the true
   children on every summed point, so the layer relations proved are
   the true tree relations; the mask enters the checks only through
   (i) the Ẑ-terms, whose evaluations at the boundary and correction
   points are pinned by the E4-opened Rp/Rq values, and (ii) the
   correction summand, a committed-polynomial term. Extraction is
   unchanged: the leaf ends are pinned by the aggregate CtClaims
   ([PROVEN] family), and the descent induction runs on sumcheck
   soundness with per-round degree ≤ 5 instead of ≤ 3 for one round
   per layer: per-pass error ≤ Σ_rounds deg/|K| ≈ 5·470/2^496 ≈
   2^-486.8 — the Section 6 accounting of the parent doc absorbs it
   without moving the psi-capped total (2^-279).

3. **Blinders (M3).** Committed before alpha. Their masses are
   constants as rational functions of alpha (no alpha in a blinder
   leaf), so if the blinded cross-check passes at random alpha then,
   by Schwartz–Zippel over the committed data, the rational identity
   Σ_i 1/(α − w_i) + β_w = Σ_j m_j/(α − t_j) + β_t holds identically;
   both fractional parts vanish at infinity, so the constant parts
   must be EQUAL (β_w = β_t) and the pole parts must match separately
   — which is exactly the unblinded lookup statement, with the same
   error bound (N + T + ν)/|K|. A cheating prover gets no room: it
   cannot place a pole with a constant (spike Z5: a wrong y under full
   honest-order masking still rejects at the cross-check), and solving
   masses to fake the check requires knowing alpha first — the
   E3Z-N2 ordering edge, both directions demonstrated (spike Z6).

4. **Interaction with the lookup's own challenges.** alpha, rho/zeta,
   lambda_j, mu_j, r_{j,t} keep their derivations; h0_lkp binds
   STRICTLY more data (masks, blinders) — every existing F5 pair
   (E3-N1..N5) remains valid and is re-run under masking at U-K5d.
   nu_j and the w-round challenges are new draws inside the existing
   chain (Section 3.3 rows). psi must now also follow the mask
   openings (E4-N1's scope grows; same attack shape).

5. **Interaction with the E4 ct-round.** E3-Z adds only LINEAR claim
   rows (aggregates + openings) — extraction rides the [PROVEN]
   CtClaim family; no new challenge monomials enter the ct-round, so
   the Vandermonde/extraction structure of SOUNDNESS_REFERENCE 3.3 is
   untouched. The lookup transcript remains deterministic prover work:
   masks are committed data (uniform slots, NOT Gaussian samples), so
   there is no new rejection-sampling surface and a ct-round restart
   re-derives c only — the link-round pattern of E4-N2 is unchanged.

## 6. Build plan: the U-K5 sub-tranches

Discipline as in the parent doc's Section 8: paper-first is DONE (this
document); every hash edge lands with its F5 pair; every frozen
constant gets a freeze row.

- **U-K5a — mask/blinder plumbing.** Statement-wave commitment slots
  for the mask coefficients (msg_r ≥ 2), blinder extension of each
  instance's m-group, the mass solve, the Section 3.4 guard list.
  Exit: freeze row **LKP-6** (mask coefficient counts by the 3k+20 /
  6-per-polynomial / 8-per-tree-per-instance formulas; blinder
  positions; guard list; the mask-freshness rule).
- **U-K5b — masked sumcheck core.** The w-variable, the correction
  summand, the 6/4/3 evaluation pattern, nu_j derivation, G_j and
  opening claims through `pack_functional`. Exit: honest ACCEPT at toy
  and FFN shapes; the "boundary ≠ true MLE" mask-liveness canary;
  measured prover/verifier deltas recorded against Section 3.5's
  [MODEL] rows.
- **U-K5c — blinders + aggregate leaf interface.** Blinder leaves in
  both trees, the aggregate-only P-pin/Q-pin rows (v^X/v^Y/v^M
  retired), the depth-9 table descent. Exit: end-to-end masked pass on
  a committed FFN-shape tensor; the Z1-class m-recovery harness runs
  at engine scale and FAILS; freeze row **LKP-7** (masked transcript
  shape: round counts, evaluation pattern, byte count at the frozen
  FFN point).
- **U-K5d — the negative battery.**
  - **E3Z-N1** (F5 pair, spike Z4): G unpinned / crafted after nu
    ACCEPTS a false lookup; shipped order REJECTS.
  - **E3Z-N2** (F5 pair, spike Z6): blinder mass solved at known alpha
    ACCEPTS; fresh alpha REJECTS the same committed blinders.
  - **E3Z-N3** (mask freshness): two passes sharing one g-mask — the
    transcript difference reproduces the unmasked leak (demonstrated),
    and the engine refuses mask reuse (enforced).
  - **E3Z-N4** (rank canaries): the Z3b/Z3c exposure-rank certificates
    as derive-time checks at engine shapes, plus the guard-restart
    regression.
  - Re-run E3-N1..N5 and E4-N1/N2 under masking.
- **U-K5e — the re-grade and the label lift.** Transcribe the adapted
  Libra counting lemma (component 4), the boundary-mask rank lemma
  (component 5), and the top-variety lemma (component 3) into
  Q4_LEMMAS.md; merge the Section 3.3 rows into SOUNDNESS_REFERENCE
  Section 7; re-grade the parent doc's Section 3.5 to this document's
  Section 4 table with measured numbers; lift the non-ZK deployment
  label. Exit: the parent doc's row 12 ([OBLIGATION — NOT ZK unmasked])
  updated to PROVEN-at-engine-scale with the battery green.

## 7. What could kill this (each with a mitigation or a priced fallback)

1. **Rank degeneracies at engine shapes.** The hiding is a set of
   generic-full-rank conditions (Z3b/Z3c classes). Each degenerates
   with probability ~1/|K| per pass; the Section 3.4 guards restart
   on the enumerable ones and the E3Z-N4 canaries check the rest at
   derive time. Residual risk LOW; cost of a restart negligible.
2. **The instance-batching formulation.** The 4-boundary-value batched
   descent REQUIRES the eq-batched reading (instance bits as sumcheck
   variables, rho_ell = eq(zeta, bits(ell))): per-instance quadruples
   would need per-instance boundary masks (~×32 mask material — still
   noise — and 32× the boundary transcript). The parent doc's Section
   5 wording admits both readings; **U-K3 must land the eq-batched
   formulation or U-K5 inherits the ×32 variant** — a process
   dependency, not a design risk. MEDIUM (process), LOW (cost).
   **RESOLVED: U-K3 landed the eq-batched formulation** (`ring/gkr.rs`
   — instance bits as sumcheck variables, one 4-value boundary per
   layer; the M4_LOOKUP_DESIGN Section 5 build note records it), so
   U-K5 proceeds on the single-quadruple variant as designed here.
3. **The adaptation fails review** (the w-correction algebra or the
   top-variety argument breaks at a place the spike's shapes don't
   exercise). The design's whole surface is machine-checked at toy
   scale including both F5 pairs, so the residual is the scale-up.
   Fallback A (recorded): **commit the transcript** — send every
   round poly/boundary value as a BDLOP commitment and prove the
   ~400 fold/check relations as linear CtClaims (they are all
   public-coefficient linear relations once the challenges are fixed),
   with the two root cross-checks as R1-padded quadratic claims:
   ~2.3k committed K-elements of transcript + ~400 sequential
   commitment epochs; ~0.5–1.5 MB proof and +10–20% prover latency
   [MODEL] — ugly but inside every budget. Fallback B (the parent
   doc's Section 9 item 1): statement-level randomization (fresh
   randomizing re-commitments of X, Y per proof) — ≥ +2 dce/el ≈ +36%
   pass commit: budget-busting; kept only as the fallback of last
   resort. A dominates B.
4. **FS/ROM multi-challenge simulation.** The simulator programs ~400
   challenges; standard hybrid, the repo-wide [MODEL] forking/grinding
   convention absorbs it (the 151-bit margin).
5. **Operational mask freshness.** One-time masks reused across passes
   subtract out (E3Z-N3 demonstrates the leak's return). Enforced by
   derive-time freshness + the freeze row; the same class of
   discipline the chain already applies to round masks. LOW.
6. **HVZK scope.** Honest-verifier, proof-of-protocol — same residual
   honesty note as R1.3/B.2; no new exposure class identified.

## 8. Spike output (recorded verbatim)

`python3 scripts/logup_zk_mask_spike.py`, 2026-07-10, exit 0 (5.3 s):

    OK Z1a: the unmasked table-descent transcript is an AFFINE function of the multiplicity column m with public coefficients (probe-reconstructed, 40 K-values)
    OK Z1b: m RECOVERED EXACTLY from one unmasked transcript (rank 8/8) -- the activation histogram leaks, the Q4.3e analogue one level up
    OK Z1c: the unmasked table root pair satisfies P_t/Q_t = sum_j m_j/(alpha - t_j) exactly -- the root values are deterministic witness statistics, as graded in Section 3.5
    OK Z2: the fully masked protocol (round masks g/nu/G, boundary masks Rp/Rq with the w-variable correction, blinder leaves with solved mass equality, pinned openings, root cross-check, leaf pins) ACCEPTS the honest witness, and sent boundary values differ from the true MLEs (masks live)
    OK Z3a: the SAME recovery pipeline against the masked transcript returns a wrong histogram (recovered != m) -- the Z1b leak is closed
    OK Z3b: leaf-layer exposure/pad rank certificate: the 4 final boundary values are a FULL-RANK affine image of the blinder pads (rank 4/4) -- jointly one-time-padded
    OK Z3c: mask-saturation certificates: middle-layer boundary + opening exposures have rank 6/6 over the R-mask coefficients; one layer's round-poly/G/opening exposures have rank 11 = #mask coefficients with exactly 4 forced check relations -- the Libra Thm 4.1 counting, machine-checked
    OK Z3d: a WITNESS-FREE simulator (uniform samples + forced values only) produces transcripts the verifier ACCEPTS (descent checks, corrections, root cross-check); the E4 pin layer is the engine's existing [PROVEN] ct-claim simulator
    OK Z5: a false lookup (one wrong y) under the FULL masking machinery, honest order, still REJECTS at the root cross-check -- masking does not help a cheating prover
    OK Z4: mask-ordering F5 pair: a mask claim OUTSIDE the statement hash (G chosen after nu) absorbs the doctored layer-1 defect and the false lookup ACCEPTS; the shipped order (G pinned to the pre-committed mask, E4 class) REJECTS the same crafting
    OK Z6: blinder-ordering F5 pair: a blinder mass solved at a KNOWN alpha ACCEPTS the same false lookup (blinders must be bound by h0_lkp before alpha); a fresh alpha REJECTS the same committed blinders
    all logup_zk_mask_spike assertions passed

(Z5 prints before Z4 because the Z4 attack reuses Z5's built objects;
the pair semantics are unaffected.)

Reproduction notes: toy field GF(97^3) (~2^19.8) imported from
`logup_gkr_spike.py` with the kappa := Y fusion; witness tree N = 32
(12 honest pairs, 4 blinder leaves, dummies), table T = 8 rows padded
to 32 with its own 4 blinder leaves; the unmasked recovery baseline
uses the original 16-leaf table tree. The Fiat–Shamir tape convention
and all K-arithmetic are the parent spike's.

---

*Changelog: 2026-07-10 — first edition (E3-Z design round, tranche
U-K5): sharpened leak inventory with exact identities and classes (m
recovered from one unmasked transcript, machine-checked); literature
anchors (CFS17, Libra Constructions 1–2, zkCNN; 2023–2026 scan: no
supersession) and the two structural obstructions to a verbatim Libra
port; the masking spec M1/M2/M3 with exact masked check equations,
amended hash-edge rows, guard list, and cost arithmetic (~37k dce
committed, ~+18 KB transcript); component-by-component simulator with
grades and the re-graded Section 3.5 table (v^X/v^Y/v^M removed from
the transcript entirely); soundness non-interference incl. the
constants-vs-poles blinder lemma; U-K5a..e build plan with the E3Z-N1..
N4 battery and freeze rows LKP-6/7; risk register with priced
fallbacks; spike output recorded (11/11 OK, two F5 pairs).*
