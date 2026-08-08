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

## 3. O-2: the reconciled closed-form byte model

### 3.1 Reconciliation decisions (what changed vs DA's Section 5 and DB's Section 10, and why)

R-8 left the two lanes' byte accountings un-merged. The reconciled
model makes four decisions, each recorded so FINAL can audit them:

- **R8-a (the merge line is one of DB's instances).** DA's skeleton
  carried a separate "batch-merge sumcheck [MODEL]" line (dw·4
  K-elements) for multi-point landing; DB's instance list carries "the
  terminal batch sumcheck" (CR-L4, shared rounds). These are the SAME
  object — the one point-family merge of R-3. The reconciled model
  prices it ONCE, inside the per-instance transcript (Section 3.5
  gives the point-family arithmetic DA's I-1 asked for).
- **R8-b (instances priced individually).** DB's "+27-40 KiB [MODEL]"
  band is replaced by per-instance arithmetic: rounds x on-wire
  K-elements per round (degree-d sumcheck sends d evaluations per
  round — the send-3 optimization, M4_LOOKUP_DESIGN 3.4) + 4 boundary
  values per instance [MODEL]. Self-check B5 verifies the derived
  complete-layer numbers land inside/near DB's band (25.1-29.6 KiB at
  FFN dense — the low half of the band).
- **R8-c (claim values from DB's entry count).** The claimed-value
  wire line is DB 10.2's batch-entry count (one K value per entry;
  100-170 at the complete layer, midpoint 135; ~48-68 at the ledger
  unit, midpoint 60 [MODEL]) — replacing DA's "16 claims x 8 slots"
  [both happen to land ~8 KiB at the complete layer; the agreement is
  a coincidence of constants, not a derivation].
- **R8-d (slot form priced as COMPLETED).** DA's slot rows carry no
  packing-image apparatus and are therefore INCOMPLETE under DB's
  reduction (the R-2 violation): the value claims (Hadamard, lookup
  terminals) have no dense object to run on. The honest slot
  configuration ("slot+image") adds the 6.3 apparatus: dense copies
  of Y/UP/Z committed alongside the packed forms (+16,512 commits at
  FFN), 3 packing-image sumchecks, +6 entries. DA's as-priced rows
  appear only as the A2 self-check baseline.

Two statement SCOPES are priced, because the two lanes silently used
different ones:

- **ledger-unit** — the PROOF_BYTE_LEDGER Section 1/2 statement (one
  activation tensor, SiLU lookup + Hadamard, arm A): the 18.59-GiB
  baseline's unit and the unit DA's tables actually priced (no matmul
  instances exist in that statement). Instances: Hadamard zero-check
  + terminal batch (+ packing-image x3 at slot+image).
- **complete-layer** — TARGET_CONTRACT Section 1's workload (3
  matmuls + Hadamard + SiLU + requant edges + range arm): DB's 10.1
  instance list and R1's honest target. Adds 3 matmul sumchecks
  (degree 2; 12+12+14 rounds), 1-2 requant zero-checks, and the
  range-arm table descent (28 rounds), with the range-arm WITNESS side
  assumed to rho-share the SiLU witness descent [MODEL — risk D-R1].

### 3.2 The closed form

In ledger unit-cost style (widths from PROOF_BYTE_LEDGER Section 0;
kappa = 10, two super-commitments; 512-row JL in the per-level
config):

    bytes = 4,096                                   (statement, v3)
          + 2 · (4 + kappa·516)                     (outer identities u)
          + kel(dw, dt) · 64                        (masked descent pair, I-8)
          + [ sum_inst rounds_i · deg_wire_i · 64
              + 4·64 · n_inst ]                     (NEW instance transcript, R8-b)
          + stop_level · 7,220 + 1,024·(stop_level−1)   (eval-proof level msgs + 512-JL)
          + n_L · 128 · ceil((e_L+1)/8)             (final bare witness)
          + n_entries · 64                          (batch-entry claimed values, R8-c)
          + 2,048                                   (framing [MODEL])

with the level schedule from the value-width-aware recursion
(`schedule2`) at the Section 2.4 encoding. Every constant is a ledger
width, a DA-derived shape, or a DB count; [MODEL] items: boundary/
framing constants, entry midpoints, the rho-sharing assumption.

### 3.3 The tables

**FFN 512x11008, per-level + 512-row JL, both encodings, both scopes**
(spike-printed; exact-digit variants in the verdict list below):

| component | slot+image, ledger-unit | dense, ledger-unit | slot+image, complete | dense, complete |
|---|---:|---:|---:|---:|
| statement (v3) | 4,096 | 4,096 | 4,096 | 4,096 |
| 2 outer identities (kappa = 10) | 10,328 | 10,328 | 10,328 | 10,328 |
| masked descent pair (dw 24 + dt 9) | 105,664 | 105,664 | 105,664 | 105,664 |
| NEW sumcheck transcript | 21,632 (5 inst) | 9,728 (2 inst) | 42,240 (11 inst) | 30,336 (8 inst) |
| eval proof: level msgs (incl. JL) | 64,928 (8) | 48,440 (6) | 64,928 (8) | 48,440 (6) |
| eval proof: final bare witness | 77,568 (606 rings) | 82,688 (646 rings) | 77,568 | 82,688 |
| batch-entry claimed values | 4,224 (66) | 3,840 (60) | 9,024 (141) | 8,640 (135) |
| framing [MODEL] | 2,048 | 2,048 | 2,048 | 2,048 |
| **TOTAL** | **290,488 = 1.11x** | **266,832 = 1.02x** | **315,896 = 1.21x** | **292,240 = 1.11x** |

**The delta table** (dense vs completed slot form — the D-1 bytes
verdict):

| shape | scope | slack model | slot+image | dense | delta |
|---|---|---|---:|---:|---:|
| 2^20 | ledger-unit | per-level | 263,108 (1.00x) | **242,128 (0.92x PASS)** | −8.0% |
| 2^20 | ledger-unit | exact-digit | 275,524 (1.05x) | 256,208 (0.98x PASS) | −7.0% |
| FFN | ledger-unit | per-level | 290,488 (1.11x) | **266,832 (1.02x)** | −8.1% |
| FFN | ledger-unit | exact-digit | 300,600 (1.15x) | 280,324 (1.07x) | −6.7% |
| FFN | complete-layer | per-level | 315,896 (1.21x) | **292,240 (1.11x)** | −7.5% |
| FFN | complete-layer | exact-digit | 326,008 (1.24x) | 305,732 (1.17x) | −6.2% |

With the digit bit-packing lever (DA's lever 2, R4 codec extension
[MODEL]; the packed stop-scan sometimes prefers a different stop):
2^20 dense exact-digit 237,584 (0.91x), FFN dense exact-digit ledger-
unit **262,544 (1.0015x — 400 B over the line)**, FFN dense complete
exact-digit 287,952 (1.10x); zero gain at the per-level optima (their
stops are already byte-aligned).

### 3.4 Cross-check against DA, and the named divergences

Where configurations overlap, the spike reproduces DA's numbers
EXACTLY (self-check A2: all six recorded totals, 252,868 ..
41,593,548, from DA's own functions). The reconciled rows then differ
from DA's for exactly three audited reasons: (i) R8-a/b/c replace
DA's two [MODEL] lines (−13,568 B at 2^20) with the per-instance
transcript + entries (+13,024-23,552 B depending on scope/encoding);
(ii) R8-d adds the 6.3 apparatus to slot rows; (iii) the dense rows
use the Section 2.3 schedules. Net headline shifts vs DA Section 5.2:

- DA's 2^20 PASS at 0.96x becomes **1.00x OVER at completed slot form
  — and 0.92x PASS at dense**: the R-2 finding was not cosmetic; the
  honest reconciliation consumes DA's whole 9.3 KiB margin unless the
  encoding flips.
- DA's FFN 1.04-1.06x becomes 1.11x (slot+image) / **1.02x (dense)**
  at the DA-comparable ledger-unit scope: dense buys back almost
  exactly what the honest transcript accounting costs.

Named model risks (each a sensitivity line in the spike):

- **D-R1 (range-arm sharing).** The complete-layer rows assume the
  range arm's witness descent rho-shares the SiLU witness descent
  (same depth class, table-agnostic layer relation — the M4 Section 5
  batching pattern extended across tables [MODEL]). If it cannot, the
  worst case is a second full pair: +105,664 B -> 1.52x. DB's 10.1
  lists the range pair at "~same pair" rounds while its +27-40 KiB
  band cannot contain one — the tension is resolved here by the
  sharing assumption and is an explicit build-round verification item.
- **D-R2 (eval-proof count).** DB 10.2 allows "up to 3" eval proofs.
  Each extra proof at this shape's schedule costs ~136 KiB —
  budget-fatal. ONE batched opening across every claim domain
  (activations + aux + weights if committed + T_blind) is therefore
  load-bearing, which requires all committed domains to share the
  two-tier geometry so the cross-commitment nu-RLC (CR-L4b) folds
  them into one opening — obligation E-O2. Under IA-O1-5's
  weights-committed reading the weight domain joins the same batch;
  its dense int8 rings (~1.06e6 at FFN) would still fold into a
  witness 2x SMALLER than today's slot-form activations alone.
- **Entry/requant band.** DB's count bands move the FFN dense
  complete-layer total 285,328-294,480 B (1.09-1.12x) — the verdict
  is band-stable.

### 3.5 Point-family arithmetic (DA I-1, closed)

DA priced each point family beyond the first at 5.4-6.1 KiB and
flagged >~4 as eroding the line. From DB's ACTUAL instance list: every
terminal (9 matmul + 3 Hadamard + ~6 lookup + pins + requant) merges
in the ONE terminal-batch sumcheck (CR-L4a/b shared rounds), which is
priced at 4,800-5,568 B (25-29 rounds x 3 K-el x 64 B) — inside DA's
per-family price. Point families beyond it: **zero**. I-1 is
therefore SATISFIED BY CONSTRUCTION in the reconciled model; the
"family count" knob DA worried about does not exist post-reduction —
what exists is the batch sumcheck's round count, which scales with
log(committed coefficients) and is already in the tables.

### 3.6 Verifier, prover, knowledge error at the recommendation

[MODEL], DA's accounting run on the dense schedules (spike-printed):
verifier 0.029 s (2^20) / 0.060 s (FFN) single-threaded vs DA's slot
rows 0.18 / 0.93 s — the R2 headroom at FFN goes from 2.2x to 33x,
and the level-1 statement pass stops being the dominant term; prover
commit-path marginal +0.2 us/el (+0.03% of whole-prove) vs +25.6
us/el (+4%) at slot form — O-6's inherited number; knowledge error
unchanged in class: post-FS 2^-211 [MODEL] (512-row JL, PSS-style
linear-in-Q loss), 2^-217-class exact-digit.

## 4. The pass-vs-layer budget scope

### 4.1 What TARGET_CONTRACT's text actually pins

The budget sentence (TARGET_CONTRACT.md Section 4): "**Proof size
budget: <= 256 KB serialized**", sitting under "Hardware, statistics,
and budgets" for the headline claim, whose workload (Sections 1/3) is
the 32-block FFN surrogate at T = 512 prefill — ONE proof whose clock
"stops when the serialized proof bytes exist". Three textual anchors,
none of them a per-layer reading:

1. The proof of the claim is the proof of the WORKLOAD — 32 blocks
   under one statement (Section 5's "multi-layer chaining (32 blocks
   under one statement)" row is the missing piece named by the
   contract itself). Nothing in the text scopes the byte budget to a
   sub-unit of that statement.
2. The TIGHTNESS FLAG in the same section prices "the masked lookup
   transcript alone ... 150 KB" against the budget — and that figure
   is the PER-PASS LKP-7 row ("masked transcript 150 KB/pass",
   Section 5). The contract's own arithmetic treats a per-pass object
   as pressing against the 256 KB line.
3. The verifier budget in the same bullet list ("<= 2 s ... statement
   validation included") is unambiguously per-proof = per-pass; the
   byte budget sits in the same list with the same grammar.

Against that: the per-LAYER reading exists only downstream — the
ledger's Section 3.1 allocation ("this allocation holds for ONE layer
statement", explicitly a PROPOSAL) and the U-AG-B1 gate spec (Tier B
asserts the layer number and "prints the pass number against the
recorded budget scope decision" — i.e. the ledger itself records the
scope as UNDECIDED and the pass number as mandatory output). R1
requires "the 32-layer-pass number also stated and the budget's
pass-vs-layer scope decided and recorded".

**Reading: the contract text pins the budget to the PASS.** The
per-layer number is an engineering waypoint the repo invented for
tractability — legitimately, but it is not what Section 4 says.
[This is a textual finding, not a preference; the counter-argument —
that Section 4's budget was written when "proof" loosely meant the
per-layer artifacts then being modeled at "~120-170 KB" — is
recorded for FINAL, but the 150-KB/pass tightness flag already reads
the budget per-pass IN the contract.]

### 4.2 The 32-layer numbers under this model

| configuration | per-layer | x 32 (pass) | vs 262,144 B per-pass |
|---|---:|---:|---:|
| dense, per-level, complete-layer | 292,240 B | 9,351,680 B = 8.92 MiB | 35.7x |
| slot+image, per-level, complete-layer | 315,896 B | 10,108,672 B = 9.64 MiB | 38.6x |

(DA's 8.5-8.9 MiB pass estimate is reproduced in class; the honest
reconciled number is at its top edge.)

### 4.3 The pass levers, priced

The ~2x-class levers DA/GA flagged, evaluated against the 35.7x gap:

| lever | owner | worth (per pass) | note |
|---|---|---:|---|
| statement sharing (one v3 statement for the pass) | build round | −31 x 4 KiB = −124 KiB | real, small |
| digit bit-packing (DA lever 2) | R4 codec ext | 0 to −18 KiB/layer | config-dependent; zero at per-level optima |
| descent-side compression / dw reduction | GKR engine (I-8) | the descent pair is 105.7 KiB/layer = 36-40% of every artifact | the single biggest line; any improvement moves layer AND pass one-for-one |
| cross-layer folding of descents + openings (family (b)) | **O-8** | −31 descent pairs − 31 eval proofs ~ −7.3 MiB | THE pass mechanism |

**The O-8 floor, computed honestly:** even with ONE descent pair and
ONE eval proof for the whole pass (perfect folding of the heavy
lines), the 32 per-layer instance transcripts + entries alone are
32 x 38,976 B = 1,247,232 B -> pass floor ~1,500,496 B = **5.7x** the
per-pass budget [MODEL]. Conclusion the FINAL needs: under the
per-pass reading, the (b) accumulator must fold the sumcheck
INSTANCES themselves (one folded transcript for 32 layers), not just
the openings — that is precisely the folding-design scope (Nova-class
claim accumulation over the house engine) that PROGRESS_UAG3.md
defers to the next round. No lever priced this round closes the pass
gap; nothing here contradicts the feasibility of instance folding
(the layers are structurally identical — the best possible case for
an accumulator), but it is undesigned.

### 4.4 Recommendation

**Recommendation to FINAL (not adopted here):** adopt the PER-PASS
reading as the contract's binding interpretation — the text supports
no other honest reading (4.1) — and simultaneously: (a) keep the
per-layer 262,144 B line as the U-AG-B1 Tier-A/B engineering gate
(the ledger's proposal, now with the scope recorded as decided);
(b) declare O-8 (cross-layer folding: descents + eval proofs +
INSTANCE accumulation) MANDATORY on the target path, per the O-8
interaction recorded in 4.3 — U-AG4 should be the folding design
round; (c) any public statement of "proof size" before O-8 lands must
say "per layer, 32 needed per pass" — the TARGET_CONTRACT honesty
pattern. If FINAL instead adopts the per-layer reading, the contract
text should be AMENDED to say so explicitly (one sentence in Section
4), because as written it does not.

## 5. Verdict

### 5.1 The D-1 + O-2 verdict row

**D-1 DECIDED (recommendation to FINAL): dense value encoding for
Y/UP/Z; slot form retained nowhere in the committed layout; IA-O1-4
CONFIRMED; R-2 closed.** Dense re-encoding is sound with zero added
claims (Section 2.1), strictly dominates the completed slot form on
every axis measured (bytes −6.2..−8.1%, norm headroom 4-5x, verifier
15x, prover marginal ~100x, apparatus deleted), and the only D-1-level
cost is layout metadata (E-O1).

**At the recommended encoding (dense, per-level slack + 512-row JL):**

| shape / scope | bytes | vs 262,144 B | verdict |
|---|---:|---:|---|
| 2^20 layer, ledger-unit | 242,128 | **0.92x** | **PASS** (slot+image: 1.00x OVER — dense is what preserves the PASS) |
| FFN layer, ledger-unit (DA-comparable) | 266,832 | **1.02x** | **FAILS by 4,688 B (1.8%)** |
| FFN layer, ledger-unit, exact-digit + bit-packing lever | 262,544 | 1.0015x | FAILS by 400 B [MODEL lever] |
| FFN layer, complete-layer (honest R1 unit) | 292,240 | **1.11x** | **FAILS by 30,096 B** (band 1.09-1.12x) |
| 32-layer pass (if per-pass scope) | 9,351,680 | 35.7x | FAILS — O-8 mandatory (Section 4.3) |

The FFN gap has one named owner: the masked descent pair is 105,664 B
= 36-40% of every artifact above (I-8 — the GKR engine's shape, not
this lane's). A ~5% descent-side improvement (dw reduction, round
elimination, or the O-8 fold) flips the ledger-unit verdict; ~28%
flips the complete-layer verdict. No further commitment-layer or
encoding-layer lever of comparable size exists in this model — the
encoding decision has extracted what the commitment side had to give.

### 5.2 Claim grades

| claim | grade |
|---|---|
| consumer enumeration S1-S8 complete (grep-driven, all call sites visited) | [PROVEN] against source this session |
| F-1: no claim class needs slot-packed Y/UP/Z under the new engine | [PROVEN* — enumeration + DB's certified reductions CR-3/CR-6/CR-8/CR-9/CR-10] |
| F-2: slot form forces 31-bit coefficients; dense is 8/15-bit; 151x witness reduction | [PROVEN arithmetic — spike D-1 table] |
| dense soundness, zero added claims (2.1) | [PROVEN* at design level; per-class digit plumbing = E-O1] |
| norm-chain re-derivation (e0 4/5, headroom, MSIS) | [MODEL] (DA's concentration + core-SVP conventions, anchor-checked) |
| sqrt-law refutation (F-4) | [PROVEN arithmetic — floor-dominated schedules] |
| reconciled byte tables (3.3) | [MODEL] (constants cited per line; DA overlap machine-checked; DB band-checked) |
| D-R1 range-arm rho-sharing | [MODEL — build-round verification item] |
| E-O2 single-batched-opening geometry | [OBLIGATION] |
| budget scope reads per-pass (4.1) | textual finding; decision at FINAL |
| O-8 floor 5.7x (instance folding mandatory under per-pass) | [MODEL] |

### 5.3 Obligations raised here (for the ledger)

- **E-O1 (layout metadata, build round):** Statement v3 manifest
  carries per-segment value-width classes (8/15/31) and per-class
  digit bases; segment boundaries bit-block aligned (extends R-1's
  requirement). Includes deleting `slot_pack`/`slot_pin_weights`/
  zeta machinery from the target path (retirements S1-S5).
- **E-O2 (one batched opening):** all committed domains (T_data,
  T_blind, weights if committed, any q46 residue) share the two-tier
  geometry so CR-L4b's nu-RLC folds every claim into ONE eval proof
  — each extra proof is ~136 KiB (D-R2). Owner: build round with DA's
  layout; FINAL should pin it as a design rule now.
- **E-O3 (D-R1 verification):** confirm the range-arm witness descent
  rho-shares the SiLU witness descent (or price the split honestly);
  build-round battery item.
- The bit-packing lever, if ever exercised, is an R4 canonical-codec
  EXTENSION requiring review (DA lever 2, unchanged).

## 6. Exports to O-4 / O-7 (Agents EC / EB)

Recorded here because the encoding decision changes surfaces both
lanes ride; numbers spike-printed.

### 6.1 To EB (O-7, extraction-slack composition) — the kill switch's geometry moved

1. **The norm chain EB's composition rides is now the Section 2.3
   dense chain**: gamma_z = 2^20.26 (per-level) / 2^21.18
   (exact-digit) at FFN, e0 = 4/5, C2' headroom 0.82/0.94 bits — not
   DA's 0.16-0.20-bit razor edge. Slack budget arithmetic that was
   marginal at slot form has 4-5x more room; nothing in EB's lemma
   should still cite the e0 = 1 row except as the vacated baseline.
2. **The compounded reading's blast radius shrank ~34x and its
   one-level-only signature is GONE:** at dense, gamma_z at the
   deepest base (e = 1) is 2^18.24 < gamma_max(L = 2) = 2^19.03, so
   the compounded budget HOSTS a second fold level (spike self-check
   C2); the compounded byte floor at dense FFN is ~1,225,536 B = 4.7x
   budget (2 levels, 8,356-ring final witness) vs 41.6 MB = 158.67x
   at slot form [MODEL]. Consequence for the fallback boundary
   (AGGREGATION_PARAMS_DESIGN 6.3): "compounded => exactly one fold
   level => 41.6 MB floor" is no longer the correct statement of the
   trigger at the recommended encoding — compounded still
   architecture-FAILS on bytes (4.7x), so the kill switch still
   kills, but EB's verdict row should restate the boundary with the
   dense numbers. The exact-digit escape hatch also widens (e0 = 5
   admits the deterministic digit claims at 2-3 limbs).
3. Unchanged and still owed to EB: the per-level vs compounded lemma
   itself, the batched-claim extractor (DA 4.4), the RLC-over-
   partially-split-rings composition (DB 10.4) — this lane adds no
   new obligation, it re-parameterizes the existing ones.

### 6.2 To EC (O-4, ZK layer) — the exposure surface got smaller

1. **The slot-junk channel no longer exists.** At dense there are no
   junk coordinates anywhere in T_data — the packed-junk surface
   (which honest provers zeroed but which was a REAL mask-discipline
   surface at slot form: zeta shares, junk-bearing commitments) is
   gone. The three exposure surfaces of AGGREGATION_CLAIM_REDUCTION
   Section 11 are unchanged in kind — masked sumcheck rounds,
   terminal values, eval-proof internals — with FEWER instances on
   surface (i) than slot+image would have had (no packing-image
   sumchecks to mask: 3 fewer masked-instance budgets at FFN).
2. **T_blind sizing is unaffected by the encoding decision**
   (2^10-2^12 rings, DA 2.5); in the dense digit chain it rides the
   31-bit aux class (Section 2.3) — its columns decompose at the
   class base, priced in every schedule; the claim-blinding segment
   folds with unit weight into every batch exactly as DA drew it.
   The new-instance mask budget EC owes (matmul/Hadamard/requant/
   batch, the DB Section 11 list) is the COMPLETE-LAYER instance
   list of Section 3.1 — 8 instances at FFN dense, degrees <= 3;
   masks are per-instance Libra-class (Q4.7-9 pattern), and the
   masked-transcript byte delta is already inside the Section 3.3
   tables (the transcript lines ARE the masked wire).
3. **Terminal-value blinding count:** the entries line (60/135
   [MODEL]) is the population of surface-(ii) values EC's counting
   lemma must cover; each is one K value against a global commitment
   with the U-K5c aggregate-only discipline carried over (DB Section
   11 row C4/C5).
4. Masked material that DISAPPEARS from the wire entirely at dense:
   nothing that Z1/WSMD masks today re-appears — the zeta wire was
   already identically zero (WSMD 1.2) and its claim family
   dissolves; no per-wave object returns (waves are gone regardless
   of encoding). Dense strictly shrinks EC's obligation list; it adds
   nothing.

## 7. References

1. AGGREGATION_PARAMS_DESIGN.md (U-AG2 DA) — layout, level machinery,
   slack models, O-2 skeleton; its spike imported and re-anchored by
   this lane's spike.
2. AGGREGATION_CLAIM_REDUCTION.md (U-AG2 DB) — CR-L1..L6, CR-1..10,
   6.3 packing-image price, 10.1/10.2 instance and entry counts,
   Section 11 exposure surfaces.
3. PROOF_BYTE_LEDGER.md (U-AG GB) — unit costs, inventories, budget
   decomposition, R1-R6 exit sheet, U-AG-B1 gate spec.
4. TARGET_CONTRACT.md — the frozen benchmark boundary; Sections 1-5
   are the scope ruling's text.
5. WAVE_SHARE_MASKING_DESIGN.md 0.1/1.2, SOUNDNESS_REFERENCE.md 8.3,
   M4_LOOKUP_DESIGN.md 3.1/3.2/3.4/7'' — the slot-form record.
6. Source files as cited inline (ct_engine.rs, link.rs, lookup.rs,
   ring_matmul.rs) — all read in this worktree at 5d6c6f1.

---

*Changelog: 2026-07-27 — first edition (U-AG3 Agent EA lane): D-1
consumer enumeration + derivation (dense recommended, R-2 closed),
O-2 reconciled byte model (R8-a..d, two scopes, DA overlap
machine-checked), pass-vs-layer scope analysis (per-pass reading,
O-8 mandatory), verdict + EB/EC exports. Spike
`aggregation_byte_model_spike.py` 21/21.*

*2026-08-08 (U-AG-B1 Agent BA) — Section 8 appended: the three
Section 5.3 obligations dispositioned (E-O1 params frozen here /
engine exported; E-O2 rule restated per-group per the U-AG4 W-C
adoption / engine exported; E-O3 exported whole). No pre-existing
text edited.*

## 8. E-O1..E-O3 dispositions (dated addition, 2026-08-08, U-AG-B1 Agent BA)

Lane rule applied: params/doc content lands here; anything requiring
Rust engine code is exported to lane BB with an acceptance criterion
(the lane briefs' discipline). Nothing ends silent.

### 8.1 E-O1 — layout metadata: params FROZEN here, manifest/deletion work EXPORTED

**Landed (the frozen layout parameters).** The per-class value widths
and the adopted digit bases are now FROZEN constants with
both-direction enforcement (`scripts/aggregation_freeze_rows.py`
rows FC2-cls-* and FC2-*-e0, under the suite):

| parameter | frozen value | source |
|---|---|---|
| value-width classes (dense) | X/Y/UP 8-bit; Z 15-bit; lookup aux + T_blind 31-bit | 2.3/2.4; TARGET_CONTRACT S2 |
| pass-scope adopted e0, activation group | 2 (robust point, zero byte premium) | FOLDING_DESIGN F-IF1.5/F-N3 |
| pass-scope adopted e0, weight group (W-C) | 1 (sign-binary; exact-digit branch load-bearing, F-N2) | FOLDING_DESIGN 5.2 |
| per-class limb rule | limbs(c) = max(1, ceil(bits_c / e0)) | 2.3 schedule2; freeze script Section 5 |
| segment-boundary rule | bit-block aligned (R-1 extension), layer = the 5 HIGH index bits | 5.3; FOLDING_DESIGN 3 (IA-O1-1) |

**Exported to BB (E-O1-BB, engine):** (a) Statement v3 manifest
extension — per-segment value-width class, per-class digit base, the
32-row layer-segment map and privacy-class group map (one object with
F-O1; the manifest is hashed into h0_agg BEFORE every draw, AZB-10's
edge). Acceptance: statement-inventory prints the class/base per
segment; a manifest missing either field fails validation; the
statement-negative battery gains a wrong-class and a wrong-base
vector. (b) The S1-S5 retirements on the target path (delete
`slot_pack` consumption, `slot_pin_weights`, zeta machinery from the
aggregate route — legacy paths stay for the old rigs). Acceptance:
no aggregate-path claim references slot-packed Y/UP/Z; grep-level
check recorded in BB's status.

### 8.2 E-O2 — the one-batched-opening rule: RESTATED PER-GROUP (dated amendment), enforcement EXPORTED

As written above (5.3), E-O2 demanded ONE eval proof across every
committed domain. The U-AG4 FINAL adopted the W-C TWO-PROOF layout
(FOLDING_DESIGN F-IF1.4 + TARGET_CONTRACT Amendment A1), which
supersedes the single-proof form. The rule as now binding:

> **E-O2':** one batched evaluation proof PER COMMITMENT GROUP —
> activation group always; weight group per deployment mode — with
> nu_g drawn per group (the AFS-L8 two-group extractor's hypothesis),
> no claim crossing groups (F-IF1.4 "by construction"), and every
> committed domain WITHIN a group (T_data segments, T_blind, q46
> residue if any survives) sharing the two-tier geometry so the
> group's nu-RLC folds its claims into that ONE opening. Each
> unplanned extra opening still costs ~136-147 KiB (D-R2's number at
> layer scale; 143,572-146,644 B at pass scale) — the rule's teeth
> are unchanged, the unit is now the group.

**Exported to BB (E-O2-BB, engine):** the pass statement builder must
emit exactly one batched opening per declared group and REFUSE a
second within a group (build error, not a warning). Acceptance:
statement-inventory prints openings-per-group == 1 for every group in
the deployment's group map; a two-opening-one-group vector fails.

### 8.3 E-O3 — D-R1 rho-sharing verification: EXPORTED whole

E-O3 (confirm the range-arm witness descent rho-shares the SiLU
witness descent, or price the split honestly) cannot land in a
paper lane: it is a property of the BUILT folded descent rig.
**Exported to BB (E-O3-BB):** when the pass-scope descent pair lands
(BB item 2/3 territory), run the D-R1 verification: (a) the range
arm rides the folded SiLU witness descent's rho at dw+5 with a
battery leg showing a range lie still REJECTS through the shared
descent (the F5 both-directions shape); or (b) if sharing fails,
record the honest split price (+1 full pass descent pair =
+143,104 B at FFN-pass, FOLDING_DESIGN 6.3's break row — verdict
band-stable, 0.618 MiB still 2.3x under the floor) as a dated
amendment to the FOLDING_DESIGN 6.1 table. Acceptance: either the
battery leg green + a dated "D-R1 holds at pass scope" note, or the
split row landed; NOT silent. (BC's battery lane runs the leg if BB
hands over the rig — ownership of the RESULT stays with this export
row.)
