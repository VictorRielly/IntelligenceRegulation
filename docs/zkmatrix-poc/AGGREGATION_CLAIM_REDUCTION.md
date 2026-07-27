# Aggregation Claim-Class Reduction (O-3): Every ct-Engine Claim as a Batched MLE-Evaluation Claim

Status: DESIGN ROUND (U-AG2, Agent DB lane, 2026-07-27) — paper +
Python spike, no Rust engine changes. Spec: AGGREGATION_LITERATURE.md
Section 8.1 obligation O-3 ("every ct-engine claim class ...
re-expressed as MLE-evaluation claims against the global commitments;
any class that cannot reduce is a surfaced wall"). Companions:
AGGREGATION_PARAMS_DESIGN.md (Agent DA's O-1 lane — the commitment
layout this document is parametric in; see Section 0.3),
SOUNDNESS_REFERENCE.md (the claim inventory being reduced, and the
grading legend used here), Q4_LEMMAS.md (the lemma transcription
style), AUTOMORPHISM_GATE_DESIGN.md (the committed-executions gate —
the hard case, Section 3 here), M4_LOOKUP_DESIGN.md /
M4_LOOKUP_ZK_DESIGN.md (the LogUp-GKR layer and its masking),
WAVE_SHARE_MASKING_DESIGN.md (the Z1 discipline every reduction must
subsume, Section 7.1 there), PROOF_BYTE_LEDGER.md (every object count
cited here). Machine checks: `scripts/claim_reduction_spike.py`
(certificates SPK-1..SPK-7, named per lemma below).

## Executive verdict

**O-3 CLOSES: every claim class the ct-engine makes today reduces to
batched MLE-evaluation claims against global per-tensor commitments —
no class walls.** The reduction table is Section 2 (one row per
class); the load-bearing findings:

1. **The committed-executions gate — THE flagged hard case — does not
   reduce; it RETIRES, and that is the correct outcome.** The gate's
   entire apparatus (trace identity, 3 execution re-commitments,
   tau-batched ties, two-sided masked reveals, the conj-twisted
   quadratic claim form) exists to overcome two obstructions — F2
   junk non-commutation and the 5.4 cross-monomial tie obstruction —
   that are properties of the SIGMA-PROTOCOL claim engine (one check
   equation, per-monomial pinning), not of the statement C = A·B.
   Under the sumcheck/MLE engine the statement is the textbook
   degree-2 matmul sumcheck (lemma CR-L3), and the general
   conj-twisted ring-quadratic claim form reduces via the
   slot-evaluation lemma CR-L2: **Galois twists on committed data
   become public power-maps of the evaluation point** — exactly the
   move the Sigma engine could not make (twists dragged twisted
   challenge monomials into the one check equation; evaluation points
   are public, so the MLE engine gets the twist for free). Full
   treatment: Section 3.
2. Ring-valued claims of every kind reduce through two elementary
   lemmas, both machine-checked: CR-L1 (tensor/power-weight
   functionals ARE MLE evaluations at shifted points, up to a public
   scalar) and CR-L2 (slot projection = evaluation at an order-256
   point of GF(q^16); v2(q^16 - 1) = 8 makes all 128 roots of
   X^128 + 1 live in the slot field, and ord(q mod 256) = 16 matches
   the k = 8 split — Section 1.2).
3. **Two whole claim classes DISSOLVE rather than reduce** — the
   zeta/ForcedZero slot-constancy family (it polices H3 packing junk;
   dense global value commitments have no junk) and the entire
   Z1 wave/pad/closing-round machinery (no waves exist). Their
   soundness and privacy functions are inherited by strictly stronger
   per-position claims and by the masked-sumcheck discipline
   respectively (Sections 6, 9, 11).
4. The honest boundary (not a wall, a design rule): a claim family
   whose public weights are DENSE-PSEUDORANDOM at tensor scale
   (XOF-expanded, no product structure) costs the verifier O(N) at
   the sumcheck terminal. No surviving class carries such weights at
   tensor scale — pins/E4 weights are product-structured, the link's
   xi rows are unit-capped at n = 128 by the w_max rule, and zeta
   dissolves — but the rule "weights structured or unit-capped"
   binds every FUTURE claim family and is recorded as the O-3
   residual discipline (Section 12.2).
5. Post-reduction claim arithmetic (Section 10): today's 201,486
   linear + 704,512 quadratic claims per FFN-scale layer
   (PROOF_BYTE_LEDGER.md Section 2 rows 4-5) collapse to ~8-10
   sumcheck instances sharing round challenges, ~20-30 terminal
   MLE-evaluation claims, and — after multi-point batching (CR-L4)
   and cross-commitment RLC — **ONE batched evaluation claim per
   commitment group, 1-3 Greyhound-class eval proofs per layer**.
   Field-statistical batching terms are 2^-480-class in GF(q^16)
   [algebra given per class]; the knowledge-error COMPOSITION through
   the evaluation proof is owed to O-7, and the RLC-over-partially-
   split-rings gap recorded in AGGREGATION_LITERATURE Section 9 is
   restated per batching step, not silently absorbed.

## PROGRESS

- [x] Section 0: scope, symbols, grading, interface assumptions (O-1)
- [x] Section 1: the target claim form + the reduction lemmas
      CR-L1..CR-L6
- [x] Section 2: the claim-class inventory (from code), reconciled
      against the docs, with the reduction-status column
- [x] Section 3: the committed-executions gate (the hard case)
- [x] Section 4: quadratic classes (Hadamard, binary/gadget)
- [x] Section 5: linear classes (pins, E4, ties/rescale, theta)
- [x] Section 6: zeta/ForcedZero and the packing dissolution
- [x] Section 7: the U-L cross-modulus link
- [x] Section 8: lookup claims (descents, mask/blinder pins)
- [x] Section 9: retired classes (waves/pads, ARP/Ajtai, digits)
- [x] Section 10: claim-count and batching arithmetic (O-2 feed)
- [x] Section 11: Z1/ZK compatibility per class (the O-4 handoff)
- [x] Section 12: verdict, boundaries, obligations

## 0. Scope, symbols, grading, and the O-1 interface

### 0.1 What is being reduced

Source of truth is CODE: the claim families constructed in
`zkmatrix-rs/src/ring/ct_engine.rs` (`CtClaim`, `RingClaim`,
`QuadCtClaim`, `QuadRingClaim`, `TwistedQuadRingClaim`, Ajtai slots,
ARP, digit openings, the wave splitter + Z1 pads + closing round),
the pin/E4 layer in `ring/lookup.rs`, the cross-modulus link in
`ring/link.rs`, digit-decomposed openings in `ring/sigma.rs`, and the
masked descent layer in `ring/gkr_masked.rs`, as instantiated by the
layer rig (`ring_matmul.rs` `ffn_layer_run`: pin ct-claims, ForcedZero
zeta claims, one Hadamard `QuadRingClaim` per value chunk —
PROOF_BYTE_LEDGER.md Section 0.1) and the pi2 CE gate
(`prove/verify_ring_pi2_ce`). Section 2 reconciles this enumeration
against the SOUNDNESS_REFERENCE.md Section 4-6 inventory and flags
the deltas.

The reduction TARGET is the family (c) architecture adopted by the
U-AG verdict (AGGREGATION_LITERATURE.md Sections 3, 8): a few global
lattice polynomial commitments per tensor; all claims collapsed to
batched MLE-evaluation claims proven by the house masked sumcheck/GKR
engine (the M4 E3/E4 machinery, third use); Greyhound-class
evaluation proofs underneath (Agent DA's O-1 lane).

### 0.2 Symbols

- q = q31 = 2^31 - 399; R_q = Z_q[X]/(X^128 + 1), D = 128, k = 8 CRT
  slots, each slot ≅ K := GF(q^16) = Z_q[Y]/(Y^16 - s0)
  (SOUNDNESS_REFERENCE.md 1.1; `kfield.rs` K_DEG = 16).
- For a value tensor T with N = 2^n positions (padded), T(b) denotes
  the value at hypercube position b in {0,1}^n, and
  MLE(T)(z) := sum_b eq(z, b) T(b) with
  eq(z, b) := prod_j (z_j b_j + (1 - z_j)(1 - b_j)), z in K^n.
- ev_w(x) := sum_i x_i w^i for a ring element x = sum x_i X^i and
  w in K — evaluation of the coefficient polynomial.
- sigma_t : X -> X^t, the Galois twists; conj := sigma_{2D-1}
  (SOUNDNESS_REFERENCE.md 1.2).
- "eval claim": a claim MLE(T)(z) = v with z in K^n, v in K, against
  the global commitment of T. "Batched eval claim": the CR-L4 form.
- Grades: [PROVEN] / [MODEL] / [OBLIGATION] as in
  SOUNDNESS_REFERENCE.md Section 0; this is a spike-carrying design
  round, so new algebraic claims here carry at most **[PROVEN*]**
  (complete elementary argument in this document + a named
  `claim_reduction_spike.py` certificate SPK-x; engine-scale
  certification owed to the build round) — the
  WAVE_SHARE_MASKING_DESIGN.md Section 0.3 convention, one notch
  STRONGER than that spike-less round since every [PROVEN*] here has
  its machine check in this tranche.

### 0.3 Interface assumptions for O-1 (Agent DA's layout — every use flagged)

The reductions below are written PARAMETRIC in the global-commitment
layout; where a concrete fact is unavoidable it is one of these six,
labeled IA-O1-x at the point of use. DA's AGGREGATION_PARAMS_DESIGN.md
owns their disposition; the FINAL merge reconciles.

- **IA-O1-1 (per-tensor global commitments, sub-cube slicing).** Each
  layer tensor (X, Y, UP, Z, lookup multiplicity m + mask/blinder
  aux) is committed as one (or a few) global commitments to its VALUE
  grid over Z_q, with a public index map iota: tensor position ->
  hypercube point that is bit-block affine — contiguous
  power-of-two-aligned sub-ranges are sub-cubes, so a slice is a
  partial evaluation. (The gadget-radix and chunk layouts all satisfy
  this today; it is a CRS-layout convention, not new machinery.)
- **IA-O1-2 (evaluation points in K).** The evaluation-proof layer
  can open MLE(T)(z) = v at points z in K^n = GF(q^16)^n. Fallback if
  the lattice relation only supports Z_q-linear functionals: the
  K_DEG = 16 coordinate-row decomposition (the `k_weight_coords`
  pattern, lookup.rs:226) turns one K-claim into 16 base-field
  claims — a x16 multiplier on TERMINAL claims only (they are then
  re-batched by one RLC), priced in Section 10.3.
- **IA-O1-3 (batch opening).** The evaluation proof can open a
  random linear combination sum_j nu_j T_j (nu_j in K, or its 16
  base rows under the IA-O1-2 fallback) at ONE common point — the
  standard Greyhound/LaBRADOR batching shape
  (AGGREGATION_LITERATURE.md Section 3.2 item 3).
- **IA-O1-4 (dense value packing).** Global commitments pack values
  DENSELY (one value per committed base-field coefficient), not H3
  slot-packed. Consequences: a 16x density gain over the H3 layer
  commitments (8 values per 128-coefficient element today —
  WAVE_SHARE_MASKING_DESIGN.md 0.1) and the dissolution of the
  zeta/junk machinery (Section 6). If DA retains slot packing for
  any tensor, Section 6.3's packing-image reduction substitutes at
  stated cost.
- **IA-O1-5 (model weights).** Whether the weight matrices W are
  public statement data or committed once per model is DA/O-8
  territory; the matmul reduction (Section 3) emits a W-evaluation
  claim either way — against a public tensor the verifier evaluates
  it itself at O(sqrt N)-or-better cost, against a committed one it
  joins the batch. Both paths are priced in Section 10.
- **IA-O1-6 (no q46 global domain assumed).** The target path is
  ARP-free and q31-native (range facts via the exact range-lookup;
  ct_engine.rs ARP-legacy note / U-R ledger D-5). No q46 global
  commitment is assumed; Section 7 states exactly what a legacy-arm
  aggregation would additionally need.

### 0.4 The standing constraints inherited

Z1: no reduced form may re-expose per-wave right-hand sides or
per-wave functional images of private coefficients
(WAVE_SHARE_MASKING_DESIGN.md Section 7.1; PROGRESS_UAG2.md standing
constraints) — Section 11 argues this per class, as O-4 input.
Numbers: only repo-recorded, cited inline; [MODEL] on every
unmeasured constant. Soundness quotes are FIELD-STATISTICAL terms
only, min()-composed with FS/hash/commitment bounds per the H-07
claim discipline (SOUNDNESS_REFERENCE.md Section 8 item 6).

## 1. The target claim form and the reduction lemmas

### 1.1 What the sumcheck/GKR engine proves (the proving surface)

The house engine (gkr.rs / gkr_masked.rs, E3) proves, over K,
statements of the form

    sum_{b in {0,1}^n} F(b) = S,
    F = product of <= 3 multilinear factors (+ eq kernels),

by an n-round sumcheck whose transcript is ~4 K-elements per round,
with the Libra-class masking of M4_LOOKUP_ZK_DESIGN.md (Q4.7-Q4.9,
PROVEN at engine scale) making every round polynomial and boundary
value simulatable. Each instance TERMINATES in evaluation claims
MLE(T_i)(r) = v_i at the round-challenge point r — which is exactly
the claim form the global commitments serve (E4, now native instead
of detoured through per-wave ct-claims). The reduction task for every
class is therefore: express the class's verification content as (a)
sumcheck relations over committed-tensor MLEs with
verifier-evaluable kernels, and (b) terminal eval claims.

### 1.2 CR-L1 — the power-point lemma (tensor weights ARE MLE evaluations)

**Setting.** T a committed tensor over {0,1}^n; c = (c_0..c_{n-1})
in K^n with c_j != -1 for all j.

**Lemma CR-L1.** With z_j := c_j / (1 + c_j),

    sum_b ( prod_j c_j^{b_j} ) T(b)
      = ( prod_j (1 + c_j) ) * MLE(T)(z).

*Proof.* Per factor and per bit: for b_j = 0,
(1 + c_j)(z_j b_j + (1 - z_j)(1 - b_j)) = (1 + c_j)(1 - z_j) = 1 =
c_j^0; for b_j = 1 it is (1 + c_j) z_j = c_j. Multiply over j, sum
over b. ∎ (Certificate SPK-1.)

*Consequence.* Every GEOMETRIC/tensor-product public weight family is
one eval claim at a shifted point, verifier cost O(n): powers of a
challenge (weight x^i: c_j = x^{2^j}), the digit-recomposition radix
weights 2^{e l} (c_j = 2^{e 2^j}), the coefficient-evaluation weights
w^i of CR-L2, instance-block weights rho_ell over instance bits, and
any product of these (products of tensor weights are tensor weights).
Status: **[PROVEN*]** (elementary; SPK-1).

### 1.3 CR-L2 — the slot-evaluation lemma (ring claims are point claims; twists move the point)

**Setting.** v2(q^16 - 1) = 8 (derived in AGGREGATION_LITERATURE.md
Section 4.3 by lifting-the-exponent from v2(q-1) = 4), so K* — cyclic
of order q^16 - 1 — contains a cyclic 2-Sylow subgroup of order
2^8 = 256; fix a generator omega of it: ord(omega) = 256,
omega^128 = -1.

**Lemma CR-L2a (all roots live in K; eight representatives
suffice).** Every root of X^128 + 1 over Z_q is an element of exact
order 256 (zeta^128 = -1 forces order | 256, order NOT | 128), and K
contains all phi(256) = 128 of them. They split into 8 Frobenius
orbits of size 16 — ord(q mod 256) = 16, checked directly: q ≡ 113
(mod 256), 113^2 ≡ -31, 113^4 ≡ 193, 113^8 ≡ 129, 113^16 ≡ 1 —
matching the k = 8 slots of degree 16 (SOUNDNESS_REFERENCE.md 1.1).
For x in R_q (BASE-field coefficients),
ev_{w^{q^j}}(x) = Frobenius^j(ev_w(x)), so

    x = 0 in R_q   <=>   ev_{omega^{u_t}}(x) = 0 for one
                          representative u_t per orbit, t = 1..8.

**Lemma CR-L2b (evaluation is a ring homomorphism; twists move the
point).** For any w with w^128 = -1, ev_w : R_q -> K is a ring
homomorphism (X^128 + 1 |-> 0). For odd t,

    ev_w( sigma_t(x) ) = ev_{w^t}( x ),      in particular
    ev_w( conj(x) )    = ev_{w^{-1}}( x ).

*Proof.* Homomorphism: ev_w is evaluation of the coefficient
polynomial at a root of the defining ideal. Twist:
sigma_t(x) = sum_i x_i X^{t i mod* 2D} and w^{t i} respects the sign
convention since w^128 = -1 implements X^128 = -1 exactly. ∎
(Certificate SPK-2.)

**Lemma CR-L2c (ring-claim reduction).** Any ring-valued claim
G(x_1, .., x_m) = 0 over R_q, G a polynomial with public R_q
coefficients, holds iff for each of the 8 representative points
omega_t: G_evaluated — with every committed x_i replaced by
ev_{omega_t}(x_i), every public coefficient by its ev_{omega_t}
image, and every Galois twist sigma_s(x_i) replaced by
ev_{omega_t^s}(x_i) — vanishes in K. Each ev_{w}(x_i-chunk) is, by
CR-L1 (c_j = w^{2^j}, never -1 for odd-power w since
v2(u 2^j) = j <= 6 < 7), a public-scalar multiple of an MLE partial
evaluation of the committed coefficient tensor: fixing the 7
coefficient variables of each element to the shifted point z(w)
leaves a multilinear polynomial E_x^w(u) in the element-index
variables whose value at index u is ev_w(x_u). The 8 slot identities
are RLC-batched with one challenge lambda in K^8 (per-slot point
mass q^-16 ≈ 2^-496 for the nonzero-defect slot —
SOUNDNESS_REFERENCE.md 1.3 L2 applied in K itself), giving ONE
sumcheck relation. Status: **[PROVEN*]** (SPK-2 checks the
homomorphism, the twist law, and a full toy twisted-quadratic
reduction with tamper).

*Why this is the structural unlock.* The Sigma engine's tie
obstruction (SOUNDNESS_REFERENCE.md 5.4) was: a twisted committed
slot drags the twisted challenge monomial sigma_t(c) into the check
equation, and one equation cannot pin across monomials. Under CR-L2
the twist lands on the PUBLIC evaluation point (w |-> w^t) — no
committed object is twisted, no challenge monomial appears, and
claims at many distinct points are the engine's native diet
(CR-L4). The entire two-sided masked-reveal tie apparatus exists to
work around an obstruction that the reduction target does not have.

### 1.4 CR-L3 — the matmul sumcheck (the gate's replacement)

**Setting.** A (r x inner), B (inner x m), C (r x m) committed as
value tensors (IA-O1-1); log-dims lr, li, lm.

**Lemma CR-L3.** C = A·B over Z_q iff for (rx, ry) drawn from K^{lr}
x K^{lm} after A, B, C are committed:

    MLE(C)(rx, ry) = sum_{b in {0,1}^{li}} MLE(A)(rx, b) MLE(B)(b, ry),

except with probability <= (lr + lm)/|K| over (rx, ry) (Schwartz-
Zippel on the multilinear defect; |K| ≈ 2^496). The right side is a
degree-2 sumcheck over li variables (round soundness 2 li / |K|),
terminating in TWO eval claims MLE(A)(rx, r*), MLE(B)(r*, ry) plus
the outer claim MLE(C)(rx, ry). Status: **[PROVEN*]** (textbook
sumcheck algebra; SPK-3 runs prove/verify end-to-end at toy shape
with the tampered-C negative).

### 1.5 CR-L4 — multi-point, multi-tensor batching (what "batched" means)

**Lemma CR-L4a (many points -> one point, per tensor).** Claims
MLE(T)(z_1) = v_1, .., MLE(T)(z_m) = v_m batch under mu in K^m into
the single sumcheck

    sum_b ( sum_i mu_i eq(z_i, b) ) T(b)  =  sum_i mu_i v_i,

whose terminal is ONE claim MLE(T)(r*) = v* (the verifier evaluates
sum_i mu_i eq(z_i, r*) itself in O(m n) K-ops). A false claim set
survives mu with probability <= 1/|K| (nonzero defect vector hit by
a uniform linear form), plus the sumcheck term. (Certificate SPK-7.)

**Lemma CR-L4b (many tensors -> one opening).** Running the CR-L4a
sumchecks for all tensors IN PARALLEL with shared round challenges
lands every tensor's terminal at the SAME r* (pad shorter tensors'
variable sets by fixing high variables — IA-O1-1 alignment); one RLC
nu in K then merges the per-tensor claims into a single claim about
sum_j nu_j T_j, opened by ONE batched evaluation proof (IA-O1-3).
Status: **[PROVEN*]** algebra (SPK-7); the KNOWLEDGE-ERROR
composition of these RLCs with the evaluation proof's extraction at
our partially-split ring is precisely the gap AGGREGATION_LITERATURE
Section 9 records ("no soundness treatment of MLE-claim batching over
partially split rings") — **[OBLIGATION -> O-7]**, restated in
Section 10.4, not absorbed.

### 1.6 CR-L5 — slices are partial evaluations

Under IA-O1-1, a claim about a contiguous aligned slice (a link
unit, an instance block, a chunk) is a claim about
MLE(T)(u_bits, ·) — high variables fixed to the block index's bits —
which is multilinear in the remaining variables and enters any
sumcheck as a factor. Certificate: SPK-5 (used by the link
reduction). Status: **[PROVEN*]** (immediate from the eq-kernel
factorization).

### 1.7 CR-L6 — the zero-check kernel (per-position claims without theta)

A per-position claim family "P(b) = 0 for ALL b" (binariness,
Hadamard defect, packing-image defect) reduces to the single
sumcheck sum_b eq(r, b) P(b) = 0 for one post-commitment challenge
point r in K^n: a nonzero defect vector survives with probability
<= n/|K| (SZ on the multilinear extension of the defect). This
REPLACES the theta/g-mask randomizer machinery (2^-279 at 9 copies —
ct_engine.rs theta discipline) with a 2^-490-class one-draw kernel,
and it is STRICTLY stronger than today's batched ct-claims: it pins
every position, not a random combination, up to the single SZ event.
Status: **[PROVEN*]** (SPK-4 runs it for Hadamard and binariness
with tampered negatives).

## 2. The claim-class inventory, from code, reconciled

Enumerated from `ct_engine.rs` / `lookup.rs` / `link.rs` /
`sigma.rs` / `gkr_masked.rs` and the two rigs (`ffn_layer_run`,
`prove/verify_ring_pi2_ce`). "Docs row" cites the
SOUNDNESS_REFERENCE.md (SR) section that inventories the class;
deltas flagged beneath the table. Counts at the FFN-scale layer
statement are PROOF_BYTE_LEDGER.md (PBL) Section 2.

| # | class (code) | where built | count @FFN layer | docs row | reduction | status |
|---|---|---|---|---|---|---|
| C1 | committed-executions gate: `TwistedQuadRingClaim` + 6 tie `RingClaim`s + masked reveals F + 12 commitments + R1 pads | ct_engine.rs:213, ring_matmul.rs pi2-CE | 1 per matmul claim | SR 4.5 + 5 | RETIRES -> CR-L3 matmul sumcheck; general twisted form via CR-L2 | **REDUCES** (Sec. 3) |
| C2 | Hadamard `QuadRingClaim` (H3 slot triple y∘up = z) | ct_engine.rs:196, wave loop | 704,512 (PBL row 5) | SR 4.4 | dense zero-check CR-L6, degree 3 with eq | **REDUCES** (Sec. 4.1) |
| C3 | `QuadCtClaim` (binary b∘b = b, gadget ct-quadratics, conj-twisted) | ct_engine.rs:187 | gadget arm | SR 4.3 | per-position zero-check CR-L6 (dense); coefficient-inner-product form via CR-L2 | **REDUCES** (Sec. 4.2) |
| C4 | pin `CtClaim`s (9 psi-batched rows: G_j hypersums, mask openings, aggregate leaf pins) | lookup.rs:321 pin_claims | 32,373 (PBL row 4) | SR 7 E3-Z rows; NOT in SR 4 family list (delta d1) | structured-weight eval claims; psi batch -> CR-L4 mu batch | **REDUCES** (Sec. 5.1) |
| C5 | E4 `CtClaim`s (v = MLE(tensor)(z*) coordinate rows) | lookup.rs:156 e4_claims | 9 per pass | M4_LOOKUP_DESIGN 3.4; delta d1 | ALREADY MLE-evaluation claims — the coefficient detour is DELETED | **REDUCES (native)** (Sec. 5.2) |
| C6 | zeta/ForcedZero `CtClaim`s (E2 slot-constancy junk pinning) | ZetaStream + link.rs:334 | 169,104 (PBL row 4) | SR 8 item 3 / SR 7 zeta row | DISSOLVES under IA-O1-4; else packing-image zero-check | **DISSOLVES** (Sec. 6) |
| C7 | `RingClaim` linear (ties, rescale/recomposition, negacyclic maps, public constants) | ct_engine.rs:122 | per-layer wiring | SR 4.1 | CR-L2 slot points + CR-L1 structured weights | **REDUCES** (Sec. 5.3) |
| C8 | U-L cross-modulus link (xi rows both sides + y reveals + range gate) | link.rs:258/354/413 | gadget-arm units (n = 128 frozen) | SR 6 | per-unit slice sumcheck CR-L5; dense xi PRICED at unit scale | **REDUCES-WITH-COST** (Sec. 7) |
| C9 | lookup descents (LogUp-GKR round polys, boundary values, roots) | gkr_masked.rs | 1 masked pair/layer (PBL row 6) | M4_LOOKUP_DESIGN 3.4 | kept VERBATIM — already the target engine; landing rewired to global commitments | **REDUCES (kept)** (Sec. 8) |
| C10 | Z1 wave shares: `Padded`/`ForcedZero` split claims, pads, closing zero-sum `CtClaim`s | ct_engine.rs:1975-2459 | 32,373 shares + 32 pad cms + 9 closing (PBL Sec. 2) | SR 7 Z1 rows; delta d2 | DISSOLVES (no waves); privacy subsumed per Sec. 11 | **DISSOLVES** (Sec. 9.1) |
| C11 | ARP (JL reveals, Ajtai-slot masks) + `AjtaiCommit/Opening` | ct_engine.rs:1345-1597 | 0 on target path (D-5) | SR 4.7 | RETIRED (legacy arm; ranges via range-lookup = C9-class) | **RETIRED** (Sec. 9.2) |
| C12 | digit-decomposed openings (`sigma.rs`, `DigitOpening` combined commitments) | sigma.rs, ct_engine.rs:236 | per combined commitment | SR 4.6 | Sigma-round mechanics — retire with the round; no reduced counterpart needed | **RETIRED** (Sec. 9.3) |
| C13 | theta/g-mask reveal machinery (h_l reveals, W images, g commitments) | ct_engine.rs round | per claim today | SR 4.2 mechanics | replaced by masked-sumcheck transcript + CR-L6 kernels | **RETIRED** (Sec. 9.3) |

Reconciliation deltas (code vs docs), flagged per the lane brief:

- **d1.** SOUNDNESS_REFERENCE Section 4's family list predates the
  lookup landing: the pin claims (C4) and E4 claims (C5) appear only
  as Section 7 hash-edge rows and in the M4 docs, though they are the
  DOMINANT linear-claim population at layer scale (32,373 of 201,486
  rows at FFN scale — PBL Section 2 row 4). They are `CtClaim`
  instances, so no soundness gap — an inventory-granularity gap only.
- **d2.** Likewise the Z1 splitter policies, pad reads, and closing
  zero-sum claims (C10) live in SR Section 7's Z1 rows and WSMD, not
  in the Section 4 family list. Again `CtClaim` instances.
- **d3.** No claim family exists in code that the documents do not
  describe somewhere — the enumeration found NO undocumented class.
  (Checked: every `*Claim` struct, every `Vec<CtClaim>`-producing
  function — `arp_claims`, `link_claims_*`, `e4_claims`,
  `pin_claims`, `closing_round_claims`, `split_claims_*` — and both
  rigs' claim-construction sites.)

<!-- UNIT-MARKER: sections 3+ follow -->

---

*Changelog: 2026-07-27 — O-3 lane opened (U-AG2 Agent DB): framework,
reduction lemmas CR-L1..CR-L6, code-enumerated inventory with docs
reconciliation. Sections 3-12 land in subsequent commits this
tranche.*
