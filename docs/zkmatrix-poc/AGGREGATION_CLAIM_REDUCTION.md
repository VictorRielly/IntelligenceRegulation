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

## 3. The committed-executions gate (C1) — the hard case, treated first

### 3.1 What the gate certifies, and what it costs today

The gate + tie construction (AUTOMORPHISM_GATE_DESIGN.md Appendices
B/B.1; SOUNDNESS_REFERENCE.md Section 5) certifies ONE statement:
C = A·B over committed packed matrices, at r = 1 with per-slot
2^-296-class soundness. Its apparatus, per matmul claim:

1. the trace identity (SR 5.2): T(y) = sum over all D automorphisms
   kills every non-constant monomial, converting per-entry ct-facts
   into one ring equation over TWISTED EXECUTION combinations
   xa^t = sum_i sigma_t(s_i) apack_i;
2. three fresh execution COMMITMENTS Y^A, Y^B, Y^C re-committing the
   h = 128 combinations per side (wide msg_r = h·inner/D shapes at
   production — AGD B.2's build note);
3. the TIE: per side, mask commitments M, N with nu_t = sigma_t(mu_t)
   (never checked), full-entropy psi_t, masked reveals
   F_t = psi_t Y_t + mu_t (mask-side-psi variant at production),
   quinary tau_i/tau_ii drawn after F, two `RingClaim`s with public
   constants — the 5.4 obstruction's resolution;
4. ONE `TwistedQuadRingClaim`:
   sum_t conj(YA_t) YB_t - sum_t conj(shat_tw_t) YC_t = 0;
5. R1 pads masking (Ga, Gb, G0, w_tq) — without which the round
   leaks the product matrix C exactly (Q4_LEMMAS.md Q4.3e).

Measured cost (AGD B.1/B.2): gate + tie marginal ~1.23 MB per matmul
claim at the demo shape (9 commitments 593 KB + 9 openings 446 KB +
F reveals 186 KB + claim images 5 KB), ~2.5-2.74 MB whole pi2-CE
round at 128x256x64 — MB-class PER MATMUL CLAIM, the scale problem
this tranche exists to kill.

### 3.2 Why the apparatus exists: two engine-specific obstructions

Every piece of C1's machinery answers an obstruction of the
SIGMA-PROTOCOL claim engine, not of the statement:

- **F2 (junk non-commutation, SR 5.1).** ct(w·P) != w·ct(P): a ring
  challenge mixes the packed pair-products' junk coefficients into
  the constant term, and nothing committed matches the junk. This is
  an artifact of PACKING rows into ring elements and compressing
  with RING challenges. The trace identity exists to kill the junk.
- **The tie obstruction (SR 5.4).** The round's virtual opening
  P = c·x - Y drags sigma_t(c) into any twisted claim; one check
  equation pins per-monomial, so no plain claim can cross a twist.
  The two-sided masked reveals exist to move every twist onto public
  data.

The reduction target has NEITHER obstruction. Values are committed
on the hypercube (no packing junk exists — IA-O1-1/IA-O1-4), and
CR-L2b moves Galois twists onto the PUBLIC evaluation point. The
correct reduction of C1 is therefore not a translation of its
machinery but its RETIREMENT: prove the underlying statement in the
engine that does not need the machinery.

### 3.3 The reduction: CR-1 (matmul instances)

**Claim CR-1.** Let A, B, C be committed as global value tensors
(IA-O1-1; A and C are layer tensors already in the global set, B is
the weight tensor — IA-O1-5). The statement C = A·B is proven by one
CR-L3 sumcheck: challenges (rx, ry) from the FS state binding all
three commitments, li rounds of degree-2 sumcheck, terminal claims

    MLE(A)(rx, r*),  MLE(B)(r*, ry),  MLE(C)(rx, ry),

all three entering the layer's CR-L4 batch. Soundness (field-
statistical): (lr + lm)/|K| SZ + 2·li/|K| rounds ~ 2^-490-class at
li <= 14 (inner = 11008-class — TARGET_CONTRACT shapes); the FS
ordering edge is the standard one (rx, ry, and round challenges all
follow the three commitments — Section 10.5's table). What the
engine must prove: one masked degree-2 sumcheck of li rounds per
matmul (three matmuls per FFN layer: gate-proj, up-proj, down-proj).
Prover cost class: O(r·m·inner) K-mult-class work with the standard
linear-time sumcheck schedule — the whole-prove multiplier is O-6's
model to build, flagged [MODEL] here.

**What retires with it, item by item:** the trace identity (no junk
to kill), Y^A/Y^B/Y^C (no derived objects need re-committing — the
sumcheck references A, B, C directly), the tau ties and the entire
masked-reveal complex psi/F/tau_i/tau_ii/M/N (no twist ever touches
committed data), the h = 128 twisted executions (the "(twisted
executions) x (1/packing density) = D" frontier law of AGD Section 3
priced a cost the MLE engine simply does not pay — its analogue is
the li sumcheck rounds, LOGARITHMIC in inner rather than linear in
D), and the R1 pads on the gate claim (the leak surface they mask —
garbage images pinned by revealed responses — has no counterpart;
the sumcheck transcript is masked by the E3 machinery instead,
Section 11 row C1).

Status: **REDUCES (by retirement)** — [PROVEN*], certificates SPK-3
(matmul sumcheck honest/tampered end-to-end) and SPK-2 (the twist
law that makes the retirement safe for the general form, next).

### 3.4 The general conj-twisted quadratic form: CR-2

C1's claim FORM (`TwistedQuadRingClaim`,
sum_p gamma_p conj(x_{a_p}) x_{b_p} + sum a x = 0 over R_q) is more
general than the gate instance, and the engine offers it to any
caller. The form itself reduces — this is where CR-L2 earns its
keep:

**Claim CR-2.** For committed element vectors x with global
coefficient commitments, the claim
sum_p gamma_p conj(x_{a_p}) x_{b_p} + sum_j a_j x_j = 0 over R_q is
equivalent (CR-L2a) to the 8 slot identities, t = 1..8:

    sum_p ev_t(gamma_p) · Ea_p^t · Eb_p^t
      + sum_j ev_t(a_j) · Ej^t  =  0   in K,

where ev_t := ev_{omega_t}, Ea_p^t := ev_{omega_t^{-1}}(x_{a_p})
(the conj twist moved to the point, CR-L2b), Eb_p^t :=
ev_{omega_t}(x_{b_p}), and every E is a public-scalar multiple of a
partial MLE evaluation of its committed tensor (CR-L1/CR-L2c). RLC
the 8 identities with lambda in K^8 (defect survives with per-slot
point mass <= q^-16 ~ 2^-496 — the L2 argument run inside K);
when the claim ranges over ELEMENT INDEX u (a per-chunk family, as
in the Hadamard case), wrap the per-u identity in a CR-L6 zero-check
over the index variables. Terminals: eval claims at the (public,
omega-shifted) points z(omega_t^{±1}) composed with the batch point —
all CR-L4-batchable. Sigma-twists other than conj reduce identically
with point w |-> w^t. Status: **[PROVEN*]** — SPK-2 verifies, at a
toy negacyclic ring with the toy field carrying an order-2D_toy
root: the hom law, the twist law, and accept/reject of a full toy
conj-twisted quadratic claim under the 8-point (toy: D_toy-point)
RLC with a tampered witness.

*Residual-use audit.* Callers of the twisted form in code: the
pi2-CE gate (retired by CR-1) and the U6/gadget conj-ct-quadratics
(C3 — Section 4.2, which uses the coefficient-inner-product special
case). No caller needs CR-2's full generality on the target path;
it is recorded because O-3's contract is that the FORM reduces, not
merely today's instances — any future twisted claim rides CR-2
instead of re-importing the tie.

### 3.5 The gate verdict, in one paragraph

The committed-executions gate — the U-AG verdict's flagged hard case
— REDUCES, and the reduction is a retirement: the matmul statement
becomes one textbook degree-2 sumcheck per matmul (CR-1), and the
conj-twisted ring-quadratic claim form that the gate forced into
existence becomes an 8-point evaluated bilinear identity under the
slot-evaluation lemma (CR-2), with every Galois twist acting on
public evaluation points rather than committed data. Nothing in the
gate's soundness content is lost: CR-1 pins C = A·B exactly (up to
2^-490-class SZ in |K| ~ 2^496, versus 2^-296-class per-slot today
— the reduced form is STRONGER on the field-statistical axis), and
the wide execution commitments, ties, masked reveals, trace
identity, and their ~1.23 MB/claim wire cost (AGD B.1) leave the
protocol entirely. The crux flagged by the verdict — "its
conj-twisted structure vs the MLE claim form" — dissolves on
inspection: the conj-twisted structure was the Sigma engine's way of
paying for packing; the MLE engine does not pack.

## 4. Quadratic classes (C2, C3)

### 4.1 CR-3 — Hadamard `QuadRingClaim` (C2)

**Today.** One `QuadRingClaim` per value chunk:
y_chunk · up_chunk - z_chunk = 0 over R_q on H3 slot-packed elements
(the wave loop's `quads_loc`, PBL Section 0.1), 704,512 claims at
FFN scale carrying 3 ring polys each — 1,090.6 MB of quad-claim
layer, 5.46% of the artifact (PBL Section 2 row 5) — plus the E2
zeta family policing the packing junk that makes per-slot products
mean per-value products (SR 8 item 3).

**Claim CR-3.** With G (gate), U (up), Z committed as dense global
value tensors (IA-O1-4), the whole family is ONE zero-check
(CR-L6):

    sum_b eq(r, b) · ( G(b) · U(b) - Z(b) )  =  0,

r drawn from the FS state binding the three commitments; a nonzero
Hadamard defect at ANY position survives with probability
<= n/|K| ~ 2^-486 at n = 23 (SZ on the defect's MLE). Degree 3 per
round (eq · G · U), n rounds, terminals MLE(G)(r*), MLE(U)(r*),
MLE(Z)(r*) — three eval claims into the CR-L4 batch. This is
per-position exactness, strictly stronger than today's per-chunk
ring claims, with NO packing precondition — the slot-constancy
machinery it leaned on is not translated but obviated (Section 6).
Status: **REDUCES — [PROVEN*]**, certificate SPK-4 (toy zero-check,
honest accept + single-position tamper reject).

*Cost note.* 704,512 claims x 1,548 B -> ~n·4 K-elements of shared
round transcript + 3 terminal claims: the class's wire contribution
drops from 1,090.6 MB to KB-class [DERIVED from PBL row 5 and the
CR-L6 transcript shape]. If DA retains H3 packing for any of the
three tensors (against IA-O1-4), CR-3 runs on the VALUE tensor
extracted by the packing-image map and Section 6.3's claim binds
packed to dense — same terminal count, one extra linear sumcheck.

### 4.2 CR-4 — `QuadCtClaim` (C3: binariness and gadget ct-quadratics)

**Today.** ct( sum_p gamma_p conj(x_{a_p}) x_{b_p} + sum a x + g )
= scalar — the binary gadget's b∘b = b shape rides
ct(conj(b)·b) = <b, b> (coefficient inner product,
SOUNDNESS_REFERENCE 1.2 fact 3), F5-hardened by post-commitment
theta randomizers, g-masked, ARP-side-conditioned at q46.

**Claim CR-4.** Two sub-cases, both closing:

- **(a) Per-position families (binariness and friends).** The
  statement "b_i in {0,1} for all i" is the zero-check
  sum_b eq(r, b) · B(b)·(B(b) - 1) = 0 (CR-L6, degree 3) — one
  sumcheck per bit-tensor, terminal MLE(B)(r*). The theta
  randomizers, the g-masks, and the F5 g-shift surface all retire
  with the ct-claim form; the ordering discipline they enforced
  (randomizer after commitment) survives as the standard "r after
  commitment" edge of CR-L6, one row in Section 10.5. The ARP
  non-wrap side condition is NOT translated: on the target path
  range facts come from the exact range-lookup (C9/D-5), and
  binariness proven positionally over Z_q needs no norm grounding
  at all — b(b-1) = 0 in Z_q IS the integer statement for b in
  {0,1} (no wrap is possible: the claim is per-position, not a
  weighted sum).
- **(b) Genuine bilinear ct-functionals.** The general form is a
  public bilinear functional of committed coefficient vectors:
  ct(gamma · conj(x) · y) = <x, coeffs(gamma·y)> = x^T M_gamma y
  with M_gamma the negacyclic matrix of the public gamma. Reduce by
  CR-2's special case: the scalar claim is the constant coefficient
  of a ring equation, and ct(w) = (1/D)·T(w) = (1/D) sum over all
  slots/conjugates — or directly: run the CR-2 slot identities and
  take the public K-linear "constant coefficient" functional of the
  8 slot values (ct is a Z_q-linear combination of the 8
  representative evaluations' traces — a public 8-row K-to-Z_q map
  the verifier applies to the batched slot claims; the trace over
  the Frobenius orbit is verifier-side arithmetic on CLAIMED slot
  values, no new claim). Terminals: the CR-2 eval claims. Status:
  **REDUCES — [PROVEN*]** (SPK-4 leg (a); leg (b) inherits SPK-2's
  certificates; the ct-via-trace identity ct = (1/D)·T(·) is SR
  5.2's killed-monomial lemma read backwards and is exercised by
  SPK-2's hom check).

## 5. Linear classes (C4, C5, C7)

### 5.1 CR-5 — the pin claims (C4)

**Today.** Every masked-descent claim (G_j hypersums, mask openings,
aggregate leaf P/Q pins) is a PINNED VALUE — a public-weight
K-linear functional of committed mask/blinder/tensor data equal to a
transcript value — decomposed into K_DEG = 16 coordinate rows and
batched by 9 psi copies into 9 `CtClaim`s per wave-context
(lookup.rs pin_claims; 32,373 pin rows at FFN scale, PBL Section 2
row 4), then SPLIT across waves with Z1 coset pads.

**Claim CR-5.** Under global commitments the pin layer keeps its
STRUCTURE and loses its DETOUR:

1. Every `PinTerm` weight family is product-structured: Lagrange
   tensor weights L_{z*} (the doubling recursion — a pure tensor
   product, CR-L1-evaluable in O(n)), kappa-multiplication
   coordinate rows (`k_weight_coords` — a fixed 16 x 16 public
   matrix per term), hypersum weights (`g_hypersum_weights` — fixed
   per-degree constants), point-opening weights (powers — CR-L1),
   psi copies (9 x 16 scalars), rho instance weights (32 block
   scalars over 5 instance bits — CR-L1). NONE is dense-pseudorandom
   at tensor scale — the pin layer passes the Section 12.2 weight
   rule as built.
2. Each pinned value therefore becomes ONE K-valued eval-style claim
   against the aux commitment (mask/blinder columns — IA-O1-1) or
   the data tensors, entering the CR-L4 mu-batch directly; the
   16-coordinate-row decomposition is needed only under the IA-O1-2
   fallback, and the 9-copy psi batch (2^-279 at 9 copies — the
   theta convention) is SUBSUMED by the single CR-L4 mu draw
   (2^-490-class): fewer challenges, stronger term.
3. The Z1 SPLITTING of pins across waves — the C-02 machinery —
   dissolves with the waves (Section 9.1); the pin TOTALS T_j (the
   only pin values with transcript existence post-Z1) become
   ordinary batched-claim right-hand sides.

Status: **REDUCES — [PROVEN*]**, certificate SPK-6a (toy
K-coordinate decomposition: `k_weight_coords`-style rows against
direct extension-field arithmetic, plus an RLC-batch tamper).

### 5.2 CR-6 — the E4 claims (C5): the detour deleted

**Today.** The descents terminate in v^X = MLE(X~)(z*), v^Y, v^M —
ALREADY MLE-evaluation claims — which e4_claims/pin_claims then
re-express as coefficient-level ct-claims against per-wave BDLOP
commitments because that is the only claim form the Sigma engine
serves (M4_LOOKUP_DESIGN 3.4: "no new claim family").

**Claim CR-6.** Under the reroute these claims are served NATIVELY:
the descent's terminal IS the eval claim, handed to the CR-L4 batch
against the global X/Y/m commitments. The rho-weighted concatenation
X~ across 32 instances is CR-L1 structure (block weights over 5
instance bits; IA-O1-1 alignment), so v^X-claims land on the SAME
global commitment as every other X-claim. The e4_claims /
pack_functional code path — the E4 coefficient detour, psi copies
included — is deleted, not translated. Status: **REDUCES (native) —
[PROVEN*]** (no new algebra beyond CR-L1/CR-L4; exercised by SPK-7's
batch certificate).

### 5.3 CR-7 — `RingClaim` linear families (C7)

**Today.** sum a_(i,j) x_(i,j) = K over R_q — the tie claims (retired
with C1), rescale/recomposition links, negacyclic-block public maps,
shift/gadget-matrix wiring (SR 4.1; U6a batteries).

**Claim CR-7.** A ring-valued linear identity sum_j a_j x_j = K is,
by CR-L2a/c, 8 evaluated identities
sum_j ev_t(a_j)·Ej^t = ev_t(K) — K-linear relations among partial
MLE evaluations with public K-scalars ev_t(a_j) (the verifier
evaluates each public ring coefficient at 8 points once, O(8D) per
distinct coefficient). Families over element indexes (rescale chains,
recomposition ladders with radix weights 2^{e l}) wrap in CR-L6
zero-checks with CR-L1 tensor weights — the gadget radix is
geometric, hence tensor-structured. Terminals: eval claims at
omega-shifted points, CR-L4-batched. The public constant K (tie
form) is verifier-side data exactly as today (SR 4.1's "constant is
STATEMENT data" note carries over: it must be FS-bound before the
zero-check point r is drawn). Status: **REDUCES — [PROVEN*]**
(SPK-2's evaluated-identity certificate covers the linear case as
the degree-1 instance).

## 6. C6 — zeta/ForcedZero slot-constancy: a class that DISSOLVES

### 6.1 What the class is for

The E2 zeta rows pin the NON-CONSTANT CRT coordinates of H3
slot-packed elements to zero (SR 8 item 3): GF(q^16) multiplication
mixes coordinates, so junk with correct constants could shift a
composed Hadamard's products — a soundness patch for the PACKING,
not a fact about the witness values. Post-Z1 they are ForcedZero
claims with no reveal wire (WSMD 2.4); at FFN scale they are still
169,104 claim rows carrying h + w_claim polys — 83% of the linear
claim layer's bytes (PBL Section 2 row 4: 169,104 of 201,486 rows).

### 6.2 CR-8 — the dissolution

**Claim CR-8.** Under IA-O1-4 (dense value commitments) the class is
VACUOUS: there are no junk coordinates because there is no packing —
every committed coefficient IS a value the claims read. The Hadamard
family that slot-constancy protected is reduced positionally by CR-3
with no packing precondition. Nothing is translated because the
INVARIANT ("products of slot constants are products of values") is
enforced by construction of the dense grid. The 169,104 rows and
their zeta-weight machinery (derive_link_zeta, ZetaStream, the
w = 11 / l = 24 frozen point) leave the protocol. Status:
**DISSOLVES — [PROVEN*]** (definitional given IA-O1-4; SPK-6b's
negative leg shows the dense zero-check catching exactly the defect
class E2 existed for).

### 6.3 The fallback if packing survives (IA-O1-4 violated)

If DA's layout keeps H3 packing for some tensor, the invariant
becomes a PACKING-IMAGE claim between two committed objects: packed
x and dense v satisfy x_u = sum_{t<k} v_{uk+t}·e_t with e_t the k =
8 fixed public basis ring elements — per-coefficient:
x(u, i) = sum_t E(i, t)·v(u, t) with E the public 128 x 8 matrix
E(i, t) = e_t[i]. That is one CR-L6 zero-check over (u, i) of a
relation whose kernel the verifier evaluates from E in O(D·k) — and
"junk-free" is IMPLIED (x in the packing image has zero junk by
construction of e_t). One extra linear sumcheck + 2 terminals per
packed tensor; the zeta point-mass machinery (2^-264 at w = 11,
l = 24) is replaced by the 2^-486-class CR-L6 kernel. Status:
[PROVEN*] (SPK-6b: toy packing map, honest accept, junk-bearing
witness rejected).

## 7. C8 — the U-L cross-modulus link (q46 <-> q31)

### 7.1 What must be preserved exactly

The link's soundness is NOT claim-form algebra alone — it is integer
arithmetic (SR 6.1/6.2): the w_max rule bounds |<xi_l, V>| below
q46/2 so residue equality mod q46 IS integer equality; the range
gate on revealed y_l forces the claimed integer below the wrap; the
per-row 2^-w point mass needs xi entries ranging over 2^w
CONSECUTIVE INTEGERS (small signed weights — a structured or large
challenge would break the counting argument AND the non-overflow
bound). So the reduction may change WHERE the two sides' residue
claims are proven, but not the weight family, the reveal, or the
gate. Both sides' claims are plain linear ct-functionals
(link_claims_gnd / link_claims_tgt(_slot)).

### 7.2 CR-9 — the reduction, unit-scoped

**Claim CR-9.** Fix a link instance: n values (frozen point n = 128,
W = 4 bit planes, w = 11, l = 24 — SR 6), values committed inside a
q31 global tensor at an aligned slice (IA-O1-1), bit planes inside a
q46-domain commitment (IA-O1-6: only if a q46 domain exists at all —
see 7.4). Per side and per row l:

1. The claim <xi_l, V_slice> ≡ y_l (mod q_side) is a sumcheck over
   the slice's log2(n) = 7 variables (CR-L5): the kernel is
   MLE(xi_l), which the verifier evaluates DIRECTLY at the terminal
   point in O(n) = O(128) base-field ops — dense weights are
   affordable exactly because the w_max rule CAPS the unit size.
2. The l = 24 rows and both sides batch by CR-L4 (mu over rows,
   shared terminal point per side); terminals: one eval claim per
   side per instance (at boolean-prefixed points (u_bits, r_low) —
   the slice index composes with the batch point).
3. The reveals y_l, the range gate |y_l| < q46/2, and the mod-q
   scalar bookkeeping (centered residues both sides) carry over
   VERBATIM as public verifier checks — they were never ct-round
   material.
4. The ordering edge (xi from h0_link binding BOTH sides'
   commitments — SR Section 7 xi row) carries over: xi must derive
   from FS state binding both GLOBAL commitments; the E2 zeta rows
   that shared the edge dissolve (CR-8).

Verifier cost: O(l·n) = O(3,072) base-field ops per instance + the
shared sumcheck rounds — trivial at gadget-arm scale. Status:
**REDUCES-WITH-COST**, the cost being (a) O(l·n) terminal
kernel evaluations per instance — linear in LINKED volume, and (b)
the q46 side requires a second commitment domain (7.4). [PROVEN*]
algebra — certificate SPK-5 (toy two-modulus link: slice-sumcheck
identity, integer-exactness honest/tamper, range-gate logic).

### 7.3 The honest scale boundary (recorded, not hit)

The dense-xi kernel makes the link verifier LINEAR in linked volume:
at tensor scale (5.6e6 values) it would cost ~24 x 5.6e6 ~ 1.3e8
base-field ops ~ seconds-class single-threaded [MODEL from the A1
kernel constants, RING_MULT_BOTTLENECK.md 6.5] — busting the R2
budget. This is NOT hit on the target path: the layer rig links
NOTHING at tensor scale (ranges via the q31-native range-lookup,
D-5; the link exists at gadget-unit scale n = 128 where the w_max
rule pins it). The boundary is recorded as a design rule (Section
12.2): any FUTURE tensor-scale cross-modulus need must either accept
the linear verifier term or redesign the link with structured small
weights — an open problem this document does NOT claim to solve
(the per-row 2^-w counting argument does not survive naive
tensor-structuring of xi; a candidate replacement would need its own
soundness round).

### 7.4 The q46 domain question (IA-O1-6)

The target path needs NO q46 global commitment: the layer rig is
ARP-free and q31-native. If the legacy gadget arm must ever ride the
aggregate, DA's layout gains a (small) q46-domain commitment for the
bit planes and CR-9 applies as written; the g46 grounding side's
ct-claims are the same CR-L5 shape at q46. Flagged to DA; NOT
assumed; NOT a wall (the legacy arm is out of the aggregation
contract's scope — PROGRESS_UZ.md Z2 legacy-arm labeling,
WSMD 0.1(a)).

## 8. C9 — the lookup layer (LogUp-GKR): kept, re-landed

### 8.1 What stays verbatim

The descents ARE the target engine: the masked LogUp-GKR sumcheck
over K (gkr_masked.rs; M4_LOOKUP_DESIGN 3.4) with the Q4.7-Q4.9
masking PROVEN at engine scale. Round polynomials, boundary values,
lambda/mu/r challenge schedule, the fused kappa := Y pair binding,
the characteristic ceiling N_inst < q and its per-layer instancing —
all carry over unchanged. The aggregation reroute touches ONLY the
landing (what happens to the terminal claims) and the grounding of
the pin layer (Sections 5.1-5.2).

### 8.2 CR-10 — the re-landed lookup

**Claim CR-10.** Per layer: the witness descent terminates in v^X,
v^Y claims and the table descent in v^M (M4_LOOKUP_DESIGN 3.4);
under the reroute these are CR-L4 batch entries against the global
X, Y, m commitments (CR-6), the mask-polynomial and blinder pins are
CR-5 structured claims against the aux commitment, and the aggregate
root cross-check stays verifier arithmetic on claimed (blinded)
values exactly as in the masked design. The range arm (exact [0,256)
table) is the SAME shape with its own m column — no ARP, no q46.
What the engine must prove: the two descents (depth 23 + depth 8 at
2^20-class; dw 24 + dt 9 at FFN scale — PBL Section 2 row 6) plus
the batched terminal sumcheck — all already-built machinery. What is
DELETED: the E4 coefficient detour (CR-6), the per-wave pin
splitting + pads (C10), and the multiplicity column's per-wave
commitment slots (m joins a global aux commitment — IA-O1-1).
Status: **REDUCES (kept engine, re-landed terminals) — [PROVEN*]**
(no new algebra; the moving parts are CR-5/CR-6/CR-L4, certified by
SPK-6a/SPK-7).

## 9. Retired and dissolved machinery (C10-C13)

### 9.1 C10 — waves, pads, closing round: DISSOLVES

The wave partition exists because the Sigma round's C2 cap binds at
~134 commitments per round (WSMD 0.1); the Z1 pads exist because
SPLITTING claims across waves revealed per-wave partials (C-02); the
closing round exists to ground the pads' zero-sum. Under the reroute
there is no round cap (no rounds), no split (claims are global
sumchecks), no partials (nothing per-wave exists to reveal) — the
entire C10 complex dissolves: `plan_waves`, `split_claims_*`,
`WavePadLayout`, `draw_wave_pads`, `closing_round_claims`, the 32
pad commitments and 9 closing claims at FFN scale (PBL Section 2).
The PRIVACY function does not dissolve — it is subsumed, argued
class-by-class in Section 11 (this is the WSMD 7.1 second branch:
the privacy argument is RE-DERIVED on the masked-sumcheck machinery,
and Q4.10's coset lemma is retired WITH its leak surface, not
weakened). The zero-sum forgery lever (WSMD 4.2) has no analogue:
there are no shares to shift. Status: **DISSOLVES** — with the
Section 11 obligation set as the O-4 handoff.

### 9.2 C11 — ARP + Ajtai slots: RETIRED (already legacy)

ARP is non-ZK at the frozen operating point and demoted to the
legacy q46 block chain (ct_engine.rs header: "ARP IS LEGACY, NOT
ZK-GRADE", audit C-01; D-5 makes the layer rig ARP-free). The
Ajtai-slot (ABDLOP) machinery exists only to norm-ground ARP masks
— the splitter already rejects Ajtai-bearing claims
(`AjtaiClaimUnsupported`, audit M-01). On the target path the range
facts ride the exact range-lookup (CR-10). Nothing to reduce;
recorded so the inventory is total. If the legacy arm is ever
aggregated, ARP would be a REAL problem (its JL reveals and
rejection clipping have no MLE-claim counterpart and its ZK defect
is structural) — but that arm is outside the contract scope
(Section 7.4). Status: **RETIRED**.

### 9.3 C12/C13 — digits, theta/g/reveal mechanics: RETIRED with the round

Digit-decomposed openings, combined-commitment `DigitOpening`s, the
theta randomizer rows, the g-mask commitments and ct reveals h_l,
the per-claim W images, R1 pads — all are mechanics OF the masked
Sigma round: they open commitments and mask reveal surfaces that the
reroute's proof objects (sumcheck transcripts + evaluation proofs)
do not have. Their FUNCTIONS map as: opening soundness -> the
evaluation proof's extraction (DA/O-1, O-7); reveal masking -> the
E3 masked transcript (Q4.7-9) + terminal blinding (Section 11);
ordering discipline (F5/theta, R1.2, g-before-theta) -> the
Section 10.5 FS table. Status: **RETIRED** (functions transferred,
no residual claim content).

## 10. Claim-count and batching arithmetic (the O-2 feed)

### 10.1 Surviving sumcheck instances per FFN layer

The complete layer (TARGET_CONTRACT.md Section 1: three matmuls +
Hadamard + SiLU + requant edges; the PBL ledger unit is ONE
activation tensor — its "lower bound on the naive pass" footnote
carries over to every count here):

| instance | lemma | degree | rounds [MODEL where est.] |
|---|---|---|---|
| matmul gate-proj / up-proj / down-proj | CR-1 | 2 | ~12-14 each (log inner at 4096/11008-class) |
| Hadamard zero-check | CR-3 | 3 | ~23 (n = log 5.6e6) |
| SiLU lookup descent pair | CR-10 (kept) | 3 | 253 + 28 (M4_LOOKUP_DESIGN 3.4; dw 24 + dt 9 at FFN — PBL Sec. 2 row 6) |
| range lookup descent pair (arm R) | CR-10 | 3 | ~same pair |
| requant/rescale zero-checks | CR-7 | <= 3 | ~23 x 1-2 |
| packing-image checks (only if IA-O1-4 violated) | CR-8 fallback | 2 | ~23 per packed tensor |
| the terminal batch sumcheck | CR-L4 | 3 (eq·kernel·T) | ~23 (shared across all tensors) |

Total masked-round transcript: the descent pairs are today's 1,651
K-elements (103.2 KiB at the canonical 4 B/limb — PBL Section 3.1);
the NEW instances add ~420-600 K-elements ~ **+27-40 KiB [MODEL,
derived: ~130-160 added rounds x 3-4 K-elements x 64 B]**. Flagged
to O-2: the AGGREGATION_LITERATURE Section 3.2 byte model budgeted
"one descent pair"; the true post-reduction transcript is descent
pair + matmul/Hadamard/batch rounds — inside the 150-260 KiB band
only if the (a)-compressor line absorbs it, O-2's arithmetic to pin.

### 10.2 Terminal evaluation claims, before and after batching

Batch ENTRIES before batching (each an MLE-evaluation claim at a
known point against one global commitment): 9 matmul terminals
(3 x {A, B=weights, C}) + 3 Hadamard + ~6 lookup tensor terminals
(v^X, v^Y, v^M x two arms) + ~80-120 pin/mask/blinder entries
(CR-5; the ~40-60 pinned values per descent pair x two arms) + ~2-4
requant + link entries where the gadget arm rides ~ **~110-170
entries [MODEL]**. After CR-L4a (per-tensor mu batch, shared
terminal point) and CR-L4b (cross-commitment nu RLC): **ONE batched
evaluation claim per commitment group; 1 eval proof at the target
layout (IA-O1-3), up to 3 if the weight domain or a q46 domain stays
separate.** Versus today's per-layer population: 201,486 linear +
704,512 quadratic claims + 477,814 openings (PBL Section 2) ->
~10 sumcheck instances + ~150 batch entries + 1-3 eval proofs.

### 10.3 The IA-O1-2 fallback multiplier

If the evaluation-proof layer serves only Z_q-linear functionals,
every K-valued terminal claim decomposes into K_DEG = 16 base-field
coordinate rows (`k_weight_coords` pattern): the 1-3 batched claims
become 16-48 base rows, re-batched by one more base-field RLC to
1-3 OPENINGS — the x16 lives in verifier-side row bookkeeping, not
in eval-proof count [DERIVED]. Recorded so DA can trade it against
native-K support in the lattice relation.

### 10.4 Soundness terms (field-statistical; H-07 min() discipline applies)

| term | draw | bound | grade |
|---|---|---|---|
| outer SZ points (rx, ry, zero-check r) | K^n after commitments | <= n/|K| ~ 2^-489-class at n <= 23, |K| ~ 2^496 | [PROVEN*] per CR-L3/CR-L6 |
| sumcheck rounds | K per round | <= deg/|K| per round; summed ~ 2^-485-class over ~650 rounds | [PROVEN*] (standard) |
| slot RLC lambda (CR-L2c) | K^8 | per-slot point mass q^-16 ~ 2^-496 | [PROVEN*] (L2 in K) |
| point batch mu (CR-L4a) | K^m, m ~ 170 | <= 1/|K| + sumcheck term | [PROVEN*] algebra |
| cross-commitment nu (CR-L4b) | K^{#groups} | <= 1/|K| | [PROVEN*] algebra |
| KNOWLEDGE-ERROR composition of all RLCs through the evaluation proof's extraction at the partially-split ring (small-norm challenge sets, relaxed openings) | — | — | **[OBLIGATION -> O-7]** — the AGGREGATION_LITERATURE Section 9 gap, restated; nothing here discharges it |
| FS/ROM, grinding, multi-theorem | — | min() with 128-bit hash class | [MODEL] — standing convention (SR Section 8 item 6) |

### 10.5 The FS-ordering table for the new challenges (SR Section 7 format; batteries owed to the build round)

| challenge | drawn from | must follow | attack if violated | pinned by (planned) |
|---|---|---|---|---|
| rx, ry / zero-check r | FS state binding ALL referenced global commitments | every commitment the instance reads | commit C after (rx, ry): SZ event voided, any product accepted | CRB-N1 F5 pair |
| round challenges r_t | prefix through round poly g_t | g_t | the classic sumcheck order attack (M4 E3-N4's shape) | CRB-N2 (E3-N4 re-run at the new instances) |
| lambda (slot RLC) | after commitments | the ring-claim family's commitments | park a defect in an un-RLC'd slot | CRB-N3 |
| mu (terminal point batch) | prefix through ALL claimed terminal values | every claimed v absorbed | choose v after mu: only the mu-combination pinned — E4-N1 one level up | CRB-N4 (E4-N1 analogue) |
| nu (cross-commitment RLC) | prefix through the mu-batch terminals | the batched claims | shift one tensor's claim against another's | CRB-N5 |
| eval-proof challenges | DA/O-1 schedule | the batched opening statement | DA's table | O-1 |

## 11. Z1/ZK compatibility per class — the O-4 handoff

The reduced protocol has exactly THREE exposure surfaces: (i) masked
sumcheck round transcripts, (ii) terminal/claimed evaluation values,
(iii) evaluation-proof internals. Surface (i) is covered by the
built Q4.7-Q4.9 machinery for the lookup descents and EXTENDS to the
new instances (same GMask/sc_degrees pattern at degree <= 3 — an
O-4 build item, not new mathematics). Surface (ii) is the
aggregate-only-pin discipline of U-K5c, generalized: raw per-tensor
terminals are random linear images of private tensors and MUST be
blinded (blinder tensors riding the aux commitment, folded into the
batch — the M4 blinding-leaf pattern; O-4 owns the counting lemma).
Surface (iii) is the ZK layer on Greyhound/LaBRADOR (toolkit ePrint
2026/1289 composition or house pads) — shared with DA, recorded in
AGGREGATION_LITERATURE 6.1. Per class:

| class | Z1-masked object today | reduced-form exposure | re-exposes anything Z1 hides? | O-4 obligations |
|---|---|---|---|---|
| C1 gate | R1 pads mask (Ga, Gb, G0, W) — the C-leak Q4.3e | matmul rounds (i) + A/B/C terminals (ii) | NO — no per-wave/garbage surface exists | mask budget for 3 matmul instances; blind terminals |
| C2 Hadamard | R1 pads on 704,512 quads | one zero-check (i) + 3 terminals (ii) | NO | same pattern |
| C3 binary/gadget | g-masks + theta | zero-check (i) + B terminal (ii) | NO | same |
| C4/C5 pins/E4 | aggregate-only pins + blinder leaves (U-K5c) | batch entries (ii) | NO — PROVIDED the aggregate-only discipline is kept (raw pinned values never sent) | carry the U-K5c blinder ledger into the batch; counting canary analogue of E3Z-N4 |
| C6 zeta | wire already deleted (identically zero — WSMD 1.2) | NOTHING (class dissolved) | NO | none |
| C7 RingClaims | W_ring forced/simulatable (SR 4.1) | terminals (ii) | NO | blind terminals |
| C8 link | y reveals are a LABELED legacy exposure (Z2 arm — WSMD 0.1a), not Z1-masked | y reveals unchanged (public integer checks) | NO CHANGE — the label carries over verbatim; note: y CANNOT be coset-padded (mod-q pads break the integer range gate) — the label is the honest state | keep the Z2 label; unit-scope only |
| C9 lookup | Q4.7-9 masks + blinders (PROVEN at engine scale) | same masked descents (i) + batch entries (ii) | NO | re-run mask batteries at the re-landed shape |
| C10 waves/pads | the Q4.10 coset pads on 9(W-1) shares — C-02's subject | NOTHING per-wave exists; totals become batch RHS | **NO — the leak's domain is abolished**: the 9(W-1)-dimensional share quotient (WSMD 1.1) has no counterpart object | the WSMD-Section-3-style simulator for the AGGREGATED transcript + the R3 rank/recovery battery analogue (PBL Section 4) — O-4's first deliverable |
| C11 ARP | non-ZK structurally (C-01) | retired | — | none (one more reason it cannot ride) |
| C12/C13 | round mechanics | retired | — | none |

**The subsumption statement (WSMD 7.1, second branch, discharged at
design level):** the reduced transcript is a function of global
commitments (MLWE-hiding), masked sumcheck transcripts (Q4.7-9
class), blinded aggregate terminals (U-K5c class), and eval-proof
internals (O-4 ZK layer) — the per-wave right-hand sides Z1 masks
have NO counterpart object, so nothing Z1 hides can be re-exposed.
This re-derives, rather than preserves, the privacy argument; the
formal simulator and battery analogue are O-4's deliverables, named
above, with no identified blocker.

## 12. Verdict, boundaries, obligations

### 12.1 VERDICT row

**O-3 CLOSES.** Every claim class reduces, dissolves into a
strictly-stronger reduced form, or retires with its function
transferred; the table is complete (Section 2; C1-C13) and no class
is WALLED. Summary: REDUCES — C1 (by retirement; CR-1/CR-2), C2
(CR-3), C3 (CR-4), C4 (CR-5), C5 (native; CR-6), C7 (CR-7), C9
(kept engine; CR-10); REDUCES-WITH-COST — C8 (unit-scoped dense-xi
kernels, O(l·n) per instance, plus a q46 domain if the legacy arm
ever rides); DISSOLVES — C6, C10; RETIRED — C11, C12, C13. The
committed-executions gate — the verdict's flagged hard case — is the
retirement case, Section 3.5. The family (d)/BaseFold fallback
trigger is NOT pulled.

### 12.2 Residual design rules (the boundaries that kept this closed)

1. **Weights structured or unit-capped.** Any claim family whose
   public weights are dense-pseudorandom at tensor scale costs the
   verifier O(N) at the sumcheck terminal. Surviving families
   comply (pins/E4 product-structured; link unit-capped n = 128;
   zeta dissolved). Binding on all future claim families and on
   DA's claim interface.
2. **No tensor-scale cross-modulus link.** Section 7.3's boundary:
   the target path needs none; a future need must accept the linear
   verifier term or fund a new soundness round for structured small
   weights.
3. **The IA-O1 assumptions (Section 0.3)** — six, each flagged at
   its point of use — must be confirmed by DA at the FINAL merge;
   IA-O1-2's x16 fallback and IA-O1-4's packing fallback are priced
   (10.3, 6.3), so neither is closure-threatening.
4. **The near-wall, named honestly:** if zeta/E2 had needed
   TRANSLATION instead of dissolution, its 169,104 dense-XOF-weight
   rows would have been rule-1's counterexample at tensor scale —
   the one place the reduction would have walled. Dissolution
   (IA-O1-4) is therefore load-bearing, and IA-O1-4 is the single
   most important interface fact for DA to confirm.

### 12.3 Obligations handed on (none block O-3's closure)

- **O-4:** the aggregated-transcript simulator + R3 battery
  analogue; mask budgets for the new sumcheck instances; terminal
  blinding counting lemma; the eval-proof ZK layer (with DA);
  Section 11's per-class rows are the input list.
- **O-7:** knowledge-error composition of the CR-L4 RLC chain
  through the evaluation proof's extraction at the partially-split
  ring (Section 10.4's flagged row); the Section 10.5 F5 batteries
  (CRB-N1..N5) at build time.
- **O-2:** the +27-40 KiB [MODEL] transcript delta of Section 10.1
  and the 1-vs-3 eval-proof count of Section 10.2 are inputs to the
  byte model.
- **O-6:** prover multipliers for the new instances (matmul
  sumchecks at O(r·m·inner) K-mult class) — [MODEL] until measured.

---

*Changelog: 2026-07-27 — O-3 lane opened (U-AG2 Agent DB): framework,
reduction lemmas CR-L1..CR-L6, code-enumerated inventory with docs
reconciliation. Same day: Section 3 (the committed-executions gate —
REDUCES by retirement, CR-1/CR-2, twist-on-points), Sections 4-6
(CR-3..CR-8: Hadamard/binary zero-checks, pins/E4/RingClaims, zeta
dissolution + packing fallback), Sections 7-9 (link
REDUCES-WITH-COST unit-scoped, lookup kept + re-landed,
waves/pads/ARP/digits dissolved or retired), Sections 10-12 (claim
counts + batching soundness terms + FS table, Z1/ZK per-class O-4
handoff, VERDICT: O-3 CLOSES, no walls, fallback not pulled).
Machine checks: scripts/claim_reduction_spike.py SPK-1..SPK-7 —
LANDED, 25/25 OK in ~15 ms, every reduction leg with a tamper
negative. One honesty note from the spike's own history: the
reduced-link tamper leg first ran over a p = 97 toy field and the
initial draft's closure bug aside, the small-field configuration is
exactly where accidental mu-xi zeros live at ~1/p per draw — the leg
now runs at the real (q31, q46) pair and the incident is recorded in
the spike's comments as a live illustration of why the production
sumcheck field is GF(q^16) ~ 2^496.*
