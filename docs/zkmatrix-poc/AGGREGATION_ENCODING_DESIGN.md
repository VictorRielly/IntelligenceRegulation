# D-1 + O-2: The Y/UP/Z Encoding Decision and the Reconciled Byte Model

Status: DESIGN COMPLETE (U-AG3 tranche, Agent EA lane, 2026-07-27;
paper + Python spike only — no engine changes). Closes **D-1** (the
dense-vs-slot encoding question U-AG2's FINAL reconciliation R-2
surfaced as the round's biggest open lever) and **O-2** (the reconciled
closed-form byte model: DA's AGGREGATION_PARAMS_DESIGN Section 5
skeleton x DB's AGGREGATION_CLAIM_REDUCTION Section 10 instance list x
the encoding decided here), and analyzes the pass-vs-layer budget
scope with a recommendation (adoption is the FINAL's call, not this
lane's).

Verdict in one line (full row in Section 5): **dense re-encoding of
Y/UP/Z is SOUND with NO added claims, is what keeps the 2^20-layer
PASS alive at all under the honest reconciled model (0.92x budget vs
1.00x for completed slot form), and moves the FFN layer from 1.11x to
1.02x of budget at the ledger-unit scope — at the line but still OVER
by 1.8%, with the one line that covers the gap (the masked descent
pair, 36-40% of the artifact) named and GKR/O-8-owned.** The R-2
hypothesis that dense encoding shrinks the evaluation proof by
~sqrt(13) is REFUTED (Section 2.4, an honest negative): the eval proof
is recursion-floor-dominated; dense's real wins are the norm chain
(e0 = 1 -> 4, extraction headroom 0.20 -> 0.82 bits, 151x smaller
decomposed witness), the dissolution of the packing-image apparatus,
verifier time (0.93 -> 0.06 s at FFN [MODEL]), and a ~34x softening of
the O-7 kill-switch's byte floor (Section 6.1).

Spike: `scripts/aggregation_byte_model_spike.py` (stdlib, sub-second,
21/21 self-checks; imports Agent DA's `greyhound_params_spike.py`
READ-ONLY and reproduces its six recorded verdict totals exactly
before printing anything — every number quoted below is printed by it
unless cited elsewhere). Companion docs: AGGREGATION_PARAMS_DESIGN.md
(DA/O-1 — the layout and level machinery), AGGREGATION_CLAIM_REDUCTION
.md (DB/O-3 — the claim reductions this decision feeds),
PROOF_BYTE_LEDGER.md (unit costs, budgets, the baseline inventory),
TARGET_CONTRACT.md (the budget wording Section 4 is decided against).

Grading legend (SOUNDNESS_REFERENCE.md Section 0): **[PROVEN]** /
**[PROVEN*]** (complete argument here + spike certificate; engine
certification owed to the build round — the DB convention) /
**[MODEL]** / **[OBLIGATION]**.

Lane discipline: AGGREGATION_SOUNDNESS_COMPOSITION.md,
AGGREGATION_ZK_DESIGN.md, slack_composition_spike.py and
aggregation_zk_spike.py belong to Agents EB/EC and are not touched;
everything exported to them is collected in Section 6.

## 0. Scope and sources

D-1 asks (PROGRESS_UAG3.md, EA lane; PROGRESS_UAG2.md R-2): Agent DA's
layout kept Y/UP/Z slot-form (16 coefficients per element, copied from
the ledger encodings), violating Agent DB's interface assumption
IA-O1-4 (dense value packing) — and NEITHER lane derived which
encoding is right. This document derives it: Section 1 enumerates
every consumer of slot structure from source and docs; Section 2
derives the soundness and the price of dense re-encoding and states
the recommendation per tensor class. O-2 then rebuilds the byte model
with the decision in (Section 3), Section 4 does the budget-scope
analysis, Section 5 the verdict.

Sources, all verified in-worktree this session:

- Code: `zkmatrix-rs/src/ring/ct_engine.rs` (claim engine; the
  slot-packed Hadamard note at :145, wave machinery :1975-2459),
  `ring/link.rs` (:289-345 the E1/E2 header + `crt_coord_rows` :314,
  `derive_link_zeta` :334, `link_claims_tgt_slot` :354),
  `ring/lookup.rs` (`slot_pin_weights` :266-307 with its U-K8 header,
  `pin_claims` :321, `e4_claims` :156, `k_weight_coords` :226,
  `fuse_pair` :95), `src/bin/ring_matmul.rs` (`slot_pack` :1320, the
  U-K8 chain header :11615-11676 — the sentence the whole question
  turns on — standalone zeta rows :12659-12660, `ZetaStream`
  :15407-15431).
- Docs: WAVE_SHARE_MASKING_DESIGN.md 0.1/1.2, SOUNDNESS_REFERENCE.md
  Section 8 item 3, M4_LOOKUP_DESIGN.md 3.1/3.4/7'',
  AGGREGATION_PARAMS_DESIGN.md 2/3/5/6/7, AGGREGATION_CLAIM_REDUCTION
  .md 0.3/2/3/4.1/6/8/10/11/12, PROOF_BYTE_LEDGER.md 0-3,
  TARGET_CONTRACT.md 1-5, PROGRESS_UAG2.md FINAL.
- The spike imports `greyhound_params_spike.py` (DA's 15-anchor
  battery re-run as self-check A1; DA's six verdict totals reproduced
  bit-exactly as self-check A2) — the R-8 configuration-overlap
  cross-check is therefore machine-enforced, not eyeballed.

Standing constraints inherited unchanged: I-6 (no Gaussian-masked
openings anywhere in the aggregate layer at q31), Z1 discipline (the
three exposure surfaces of AGGREGATION_CLAIM_REDUCTION Section 11),
codex-audit-* read-only, numbers only from repo-recorded sources.

## 1. D-1 part one: every consumer of slot structure, from source

### 1.1 What H3 slot form is, and the sentence that explains it

H3 packing puts value t at the CONSTANT coordinate of CRT slot
t mod k of ring element floor(t/k) — 8 values per 128-coefficient
element, 16 committed coefficients per value (`slot_pack`,
ring_matmul.rs:1320; WAVE_SHARE_MASKING_DESIGN 0.1). The committed
element is sum_t value_t * e_t over the k = 8 slot idempotents e_t.
Why the layer tensors ever took this form is stated verbatim in the
U-K8 chain header (ring_matmul.rs:11626-11627):

> "Y lives ONLY slot-packed (H3) so the downstream Hadamard can
> consume it"

— i.e. the packing exists so that ONE ring multiplication of committed
elements executes 8 value products in parallel (slot-wise product of
constants = product of values), which is the only way the
Sigma-protocol claim engine can express a Hadamard fact: its claim
forms are ring equations over committed ring elements
(`QuadRingClaim`, ct_engine.rs:145 "slot-packed Hadamard"). Everything
else in the slot-form ecosystem is downstream of that one decision.

### 1.2 The consumer enumeration

One row per place slot structure is load-bearing today; "disposition"
answers the D-1 question for that row: does the NEW engine (MLE claims
+ CR-L2 slot evaluation + Greyhound eval proofs) still need it, or was
it a Sigma-engine artifact?

| # | consumer | where (code/doc) | what the slot form serves | disposition under the new engine |
|---|---|---|---|---|
| S1 | Hadamard `QuadRingClaim` y∘up − z = 0 per packed element (704,512 claims at FFN scale) | ct_engine.rs:145/:196; wave loop `quads_loc` ring_matmul.rs ~16736; PBL 0.1 row 5 | ring mult on packed elements = 8 parallel slot-field products; slot CONSTANTS multiply to value products — the Sigma engine's only Hadamard expression | **Sigma artifact — RETIRES.** CR-3 (AGGREGATION_CLAIM_REDUCTION 4.1) proves G(b)·U(b) − Z(b) = 0 per position over dense values by ONE zero-check sumcheck; no committed ring element is ever multiplied. |
| S2 | E1 slot-constant projection reads | `crt_coord_rows` link.rs:314; link.rs:289-306 header; M4_LOOKUP_DESIGN 3.4 | extracting value t from a packed element: values are NOT coefficients — each sits behind a public 128-wide CRT projection row | **artifact of the packing itself — RETIRES.** Dense values ARE the committed coefficients; the read is the identity map. |
| S3 | E2 zeta junk pinning (169,104 claim rows at FFN = 83% of the linear-claim layer's bytes) | `derive_link_zeta` link.rs:334; `link_claims_tgt_slot` link.rs:354; standalone xi = 0 rows ring_matmul.rs:12659-12660; `ZetaStream` :15407; SOUNDNESS_REFERENCE 8.3; WSMD 1.2 | polices the 15/16 NON-value coordinates per value that packing creates — junk with correct constants could shift a composed Hadamard's products (the audit-found composed-H3 gap) | **DISSOLVES (CR-8).** At dense there are no junk coordinates to police; the invariant is enforced by construction of the value grid. The frozen w = 11 / l = 24 machinery leaves the protocol. |
| S4 | `slot_pin_weights` — the E1-composed lookup pin adapter (U-K8) | lookup.rs:266-307 and its header; M4_LOOKUP_DESIGN 3.4 | lets the lookup's Q-pin / E4 layer read VALUES out of slot-packed Y by folding per-value K weights through the projection rows | **an ADAPTER by its own doc comment** ("same claim family, different public weight computation") — the lookup consumes values, not slots. At dense the adapter is deleted; weights revert to the plain Lagrange tensor rows. RETIRES. |
| S5 | U-L link slot-target variant | `link_claims_tgt_slot` call sites ring_matmul.rs:6795/6890/6902 | reads link-row values through E1 (+ pins junk via E2) when the linked tensor is packed | **RETIRES as a variant.** The link is unit-scoped (CR-9, n = 128 frozen); against dense targets the dense form `link_claims_tgt` (link.rs:413) is the claim, unchanged in soundness content (weights, reveals, range gate untouched). |
| S6 | committed-executions gate packing economics | AUTOMORPHISM_GATE_DESIGN Section 3 frontier law "(twisted executions) x (1/packing density) = D" | packing density is one axis of the gate's cost frontier | **dies with the gate.** C1 RETIRES entirely under CR-1 (the matmul sumcheck); its packing economics have no successor object. |
| S7 | kappa := Y pair fusion + all descent arithmetic over K | `fuse_pair` lookup.rs:95; M4_LOOKUP_DESIGN 3.2/3.4 | uses the slot FIELD K = GF(q^16) (the generator Y, {1, Y} independence) — NOT the H3 packing of any commitment | **KEPT — not a packing consumer.** K-field structure (CR-L2, the sumcheck field, slot-complete batched checks I-3, per-slot-injective quinary weights I-4) is a property of the RING and the claim engine, orthogonal to how tensor values are laid out in commitments. |
| S8 | aux K-element material: m column, mask columns, blinder columns | `PinTerm::Kelems` lookup.rs:253-256; `k_weight_coords` :226; M4_LOOKUP_DESIGN 3.1 | K-elements stored as 16 CONSECUTIVE base coefficients — a K-coordinate layout in which every committed coefficient is data (no junk coordinates exist) | **KEPT as-is.** Already "dense" in the packing-image sense; enters the digit chain as the 31-bit value class (Section 2.3). |

Completeness: the enumeration was driven by every code reference to
slot structure in the claim path — `grep` over `slot|crt_coord|H3|
pack` in ct_engine.rs, all `link_claims_tgt_slot`/`derive_link_zeta`/
`ZetaStream`/`slot_pin_weights`/`slot_pack` call sites in
ring_matmul.rs, and the docs rows (WSMD 0.1/1.2, SOUNDNESS_REFERENCE
8.3, M4_LOOKUP_DESIGN 3.1/3.4). Kernel-side slot arithmetic
(`slot_mul_g`, the A1/U-K9 lanes) is prover-INTERNAL arithmetic over
the ring and is encoding-neutral — it appears in no claim and is not a
consumer. No consumer outside S1-S8 was found.

### 1.3 The two structural findings

**F-1 (all load-bearing consumers are Sigma artifacts).** S1-S6 — every
consumer for which slot form is load-bearing — exist to work around
the Sigma engine's claim form (one check equation over committed ring
elements): S1 buys 8-way products, S2/S4 buy the value reads back, S3
patches the soundness hole the packing opened, S5 is S2 at the link,
S6 died with its gate. The two survivors (S7, S8) consume the slot
FIELD, not the packing. Under the sumcheck/MLE engine — whose native
diet is exactly per-position value claims (CR-L6) and MLE terminals —
**no claim class needs Y/UP/Z slot-packed.** This is DB's IA-O1-4
argument run in the opposite direction and grounded in code: not only
does the reduction PREFER dense, nothing anywhere still requires slot.
[PROVEN* — the enumeration above + DB's CR-3/CR-8/CR-10 reductions,
each spike-certified in DB's lane.]

**F-2 (the width finding — the part R-2 missed).** H3 commits
value_t · e_t, and the slot idempotents e_t have FULL-RANGE mod-q
coefficients: the slot-form witness is 31-bit per committed
coefficient regardless of how small the values are. Dense commits the
value itself: 8-bit (X offset codes, Y = SiLU int8, UP requantized
int8), 15-bit (Z = Y∘UP, |Z| <= 127^2), 31-bit only for the tiny aux
class (S8; m counts, uniform mask/blinder material)
[TARGET_CONTRACT.md Section 2; ring_matmul.rs U-K8 header]. So dense
re-encoding shrinks the level-0 witness on BOTH axes: 12.24x fewer
rings (2,157,768 -> 176,328 at FFN — R-2's "~13x", now exact) AND
~12x fewer limbs per ring (l0 = 31 at DA's forced e0 = 1 -> avg 2.5).
Total decomposed witness: 66,890,808 -> 441,920 limb-rings, **151x**.
This is why the digit-base row relaxes (Section 2.3) — the effect DA's
val_bits = 31 modeling could not see, because for slot form 31 was
correct. [PROVEN arithmetic — spike D-1 table.]

## 2. D-1 part two: soundness, price, and the recommendation

### 2.1 Is dense re-encoding sound, and what claims must be added?

**Claim (the D-1 derivation).** Committing Y, UP, Z densely (one value
per committed base-field coefficient, segments of T_data per DA 2.1)
and slot-packing NOTHING is sound for the complete reduced protocol,
and requires **zero added claims**: no packing-image sumcheck, no
consistency claims, no zeta successor.

*Derivation.* Two things could make dense encoding unsound or force
added claims: (i) some consumer still needs slot semantics that the
dense layout no longer provides; (ii) two representations of the same
tensor coexist and must be tied.

(i) is settled by the Section 1.2 enumeration: every surviving claim
that touches Y/UP/Z consumes VALUE MLEs — the Hadamard zero-check
CR-3 reads G(b), U(b), Z(b); the lookup descent's terminal v^Y =
MLE(Y~)(z*) is an MLE of the VALUE tensor by definition
(M4_LOOKUP_DESIGN 3.4), today reached through the S4 adapter and at
dense reached natively (CR-6: "the descent's terminal IS the eval
claim"); the link reads value slices (CR-9, CR-L5); pins/E4 read
committed coefficients with product-structured weights (CR-5). Dense
value grids serve all of these directly. The one candidate for a
slot-semantics residue — "slot-constancy of downstream products",
the property S3 enforced — is not a property of the witness at all:
it is a property OF THE PACKING ("a soundness patch for the PACKING,
not a fact about the witness values", AGGREGATION_CLAIM_REDUCTION
6.1), and CR-3's per-position exactness is strictly stronger than
what the zeta rows plus per-chunk ring products ever pinned (CR-8).

(ii) does not arise: the packing-image claim class
(AGGREGATION_CLAIM_REDUCTION 6.3) exists precisely to tie a PACKED
commitment x to a DENSE commitment v (x_u = sum_t v_{uk+t} e_t). With
a single dense representation there is no second object to tie. The
claims that consume Y/UP/Z all land on the same dense segments, and
cross-claim consistency is exactly what the shared global commitment
provides (IA-O1-1, confirmed as R-1).

What must be RE-DERIVED (not added): the level-0 digit decomposition
now runs on 8/15/31-bit value classes (Section 2.3) — a layout
parameter, not a claim; the lookup pin weights revert from
`slot_pin_weights` to plain Lagrange rows (a code deletion, build
round); the Statement v3 manifest gains per-segment value-width
classes and per-class digit bases (obligation E-O1, Section 5.2).
Extraction is unchanged in kind: the commitment layer binds digit
vectors and the C2'/C3 chains of DA Section 3 apply verbatim at the
new (smaller) bounds; an extracted value can exceed its class width
only inside the extraction slack, and every INTEGER fact about values
continues to come from the range/lookup claims, never from the
commitment layer — same as today. ∎ [PROVEN* at design level; the
per-class decomposition plumbing is E-O1.]

**The counterfactual price of keeping slot form** (what "as drawn"
actually costs, made concrete — DB 6.3 priced the sumcheck, R-2 did
not price the whole apparatus): to run DB's reduction at all, the
as-drawn layout must commit DENSE COPIES of Y/UP/Z alongside the
packed forms (the packing-image claim is "between two committed
objects", 6.3) — +16,512 commits at FFN — plus 3 packing-image
zero-check sumchecks (27 rounds each at FFN over the (u, i) packed
coordinate space, degree 2) and 6 more batch entries. The completed
slot configuration ("slot+image" in the spike) is therefore BIGGER
than DA's as-priced rows by both apparatus and bytes, and bigger than
dense by 6.2-8.1% of the whole artifact at every configuration
(Section 3.3). Slot form is not a cheaper alternative that trades
bytes for familiarity; under the new engine it is strictly dominated.

### 2.2 What dense re-encoding saves — and the honest negative

Savings, at the FFN shape unless noted (all spike-printed):

1. **The norm chain (the big one, F-2):** level-0 digit base e0 = 1
   (sign-binary, DA's forced row) -> 4 under per-level slack, 2 -> 5
   under exact-digit; decomposed witness 66.9e6 -> 441,920 limb-rings
   (151x); C2' extraction headroom 0.20 -> 0.82 bits (exact-digit:
   0.72 -> 0.94); top-MSIS 132.6 -> 141.4 core-SVP bits [MODEL,
   core-SVP floor]. The q31 chain stops being razor-thin exactly where
   DA flagged it thinnest.
2. **The apparatus:** zeta stays dissolved with no packing-image
   successor (S3 + 6.3 both vacated); at slot+image those cost ~12 KiB
   of transcript + entries per layer AND ~1.06e6 extra committed
   coefficients.
3. **Bytes:** dense beats the completed slot form by 6.2-8.1%
   everywhere; against DA's (incomplete) slot rows the honest
   reconciled comparison is Section 3.3's table — headline: the
   2^20-layer PASS survives ONLY at dense (0.92x vs 1.00x), and FFN
   improves 1.11x -> 1.02x at the ledger-unit scope.
4. **Verifier:** the level-1 statement pass shrinks with m2 and l0 —
   0.93 s -> 0.060 s at FFN, 0.18 -> 0.029 s at 2^20 [MODEL,
   ring-MAC accounting] — the R2 headroom goes from 2.2x to 33x.
5. **Prover commit-path marginal:** +25.6 us/el (+4% on whole-prove)
   -> +0.2 us/el (+0.03%) [MODEL] — the e0 = 1 31-limb decomposition
   was the entire cost; O-6 inherits a much smaller number.
6. **Knowledge error:** unchanged class (post-FS 2^-211 [MODEL], one
   fewer level in R).

**The honest negative (F-4): the sqrt law is refuted.** R-2
hypothesized the eval proof "shrinks by roughly the square root" of
the 13x ring reduction (~3.6x). It does not, and the reason is
structural: DA's deep-recursion schedules run to the LaBRADOR floor
set by the per-level regrowth terms r_i·kappa·l_t + r_i(r_i+1)·l_gh,
which are INDEPENDENT of the starting witness size — every
configuration bottoms out at a ~490-650-ring final witness (78-95 KiB
bare) plus level messages. Dense encoding removes ~2 recursion levels
(level messages -8.4 KiB/level) and shortens the terminal-batch
sumcheck, worth ~15-25 KiB total — real, and enough to matter at a
4-10% overage, but not sqrt(13). The sqrt intuition belongs to the
SINGLE-level Greyhound regime (verifier O(sqrt N)), which the
byte-optimal schedules never use. [PROVEN arithmetic — spike tables;
recorded so nobody re-imports the sqrt expectation into O-8.]

### 2.3 The norm-chain re-derivation (the D-1 digit table)

Spike-printed (value-width-aware `schedule2`, which self-check B4
proves collapses exactly to DA's `schedule` on a single 31-bit class):

| shape | encoding | slack model | e0 | witness limb-rings | gamma_z | headroom to gamma_max | top MSIS [core-SVP] |
|---|---|---|---:|---:|---|---:|---:|
| 2^20 | slot | per-level | 3 | 4,417,336 | 2^20.92 | 0.16 b | 132.1 |
| 2^20 | dense | per-level | 6 | 74,736 | 2^20.97 | 0.10 b | 131.3 |
| 2^20 | dense | exact-digit | 7 | 74,568 | 2^21.97 | 0.15 b | 132.0 |
| FFN | slot | per-level | **1** | 66,890,808 | 2^20.88 | 0.20 b | 132.6 |
| FFN | slot | exact-digit | 2 | 34,524,288 | 2^21.40 | 0.72 b | 140.0 |
| FFN | dense | per-level | **4** | 441,920 | 2^20.26 | **0.82 b** | 141.4 |
| FFN | dense | exact-digit | **5** | 397,688 | 2^21.18 | **0.94 b** | 143.2 |

Readings: (a) DA's alarming FFN e0 = 1 row — "the deepest
decomposition the chain admits", the first concrete signal of q31's
tightness — is an artifact of the slot encoding, not of the shape;
(b) at 2^20 dense the base saturates at e0 = 6-7 (values are 8-15 bit
— barely decomposed at all); (c) headroom at FFN dense is 4-5x the
slot row's, which loosens exactly the "one lost bit anywhere flips
the verdict" posture of DA 3.3; (d) MSIS hardness RISES (smaller
extracted bounds) — no security regression anywhere on the table.
The aux class (S8, 31-bit) rides the same decomposition at its own
limb count — 200 rings at FFN, negligible by construction, priced in
every row above.

### 2.4 Recommendation (per tensor class)

**RECOMMENDED: dense value encoding for Y, UP, Z — slot form retained
NOWHERE in the committed layout.** Per class:

| tensor class | encoding | rationale |
|---|---|---|
| X (offset codes) | dense, 8-bit class | already dense (unchanged) |
| Y (SiLU out), UP | **dense, 8-bit class** | this document |
| Z (Hadamard out) | **dense, 15-bit class** | this document |
| lookup aux: m, mask, blinder columns | K-coordinate layout kept (16 consecutive base coeffs per K-element), 31-bit class | S8 — already junk-free; pins read it via `PinTerm::Kelems` unchanged |
| T_blind | unchanged (DA 2.5), 31-bit class | EC's surface; Section 6.2 |
| weights (if committed; IA-O1-5) | dense int8 when they enter the global layout | same F-2 logic applies; sized in Section 3.4 (D-R2) |

The answer is NOT mixed: no claim retains slot-packed material. What
IS retained is the slot FIELD everywhere the engine already uses it
(S7): the descents run over K, batched claims are checked
slot-complete with per-slot-injective quinary weights (I-3/I-4 stand
unchanged), and CR-L2 remains the ring-claim workhorse. "Drop H3
packing" and "keep the 8-slot CRT engine" are orthogonal statements,
and this design does both. IA-O1-4 is hereby CONFIRMED as the layout
(closing R-2); DA's Section 2.1 segment table amends to X 1 coeff/el,
Y/UP/Z 1 coeff/el, lookup material as today — total T_data 22,041
commits = 176,328 rings at FFN, 4,117 commits = 32,936 rings at 2^20.
