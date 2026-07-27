# U-AG Aggregation Literature Review: What the Field Offers Against the 11,720x Proof-Size Wall

Status: IN PROGRESS — literature review tranche (U-AG round 1, Agent
GA; searched and read 2026-07-16/17; primary papers verified against
their ePrint pages wherever costs are quoted). Companion to
RANGE_AGGREGATION_DESIGN.md Section 3b (the adopted byte accounting
this review must defeat), the C-03 finding it answers
(codex-audit-2026-07-14/FINDINGS.md), REMEDIATION_PLAN.md Phase 3
(the tranche spec: candidates selected by proof-size and
verifier-cost models, not prover time), TARGET_CONTRACT.md Section 4
(the <= 256 KB / <= 2 s budgets), WAVE_SHARE_MASKING_DESIGN.md
Section 7.1 (the Z1 constraint every candidate must respect),
GATE_ALTERNATIVES.md (option 2, the hash-sumcheck fallback that is
family (d) here), and M4_LOOKUP_LITERATURE.md (the house precedent:
this review copies its format, its pricing discipline, and its
one-engine-many-uses lens).

## Executive verdict (DRAFT — finalized in Section 8 when all families are priced)

The literature offers exactly one architecture with a defensible
analytic path to <= 256 KiB at the full-pass scale, and it is a
COMBINATION, not a single system: (1) collapse the per-wave claim
structure into batched MLE-evaluation claims using the sumcheck/GKR
engine the M4 verdict already committed this repo to build, then
(2) serve those claims from a FEW global lattice polynomial
commitments via a Greyhound-class evaluation proof (Nguyen-Seiler,
CRYPTO 2024: 53 KB evaluation proofs at degree 2^30, O(sqrt N)
verifier), itself compressed by LaBRADOR recursion (Beullens-Seiler,
CRYPTO 2023: 58 KB for 2^20-constraint R1CS) with the 2026
zero-knowledge LaBRADOR toolkit closing the ZK gap. Standalone
opening aggregation (family (a) alone) cannot reach the budget — the
un-aggregated commitments themselves weigh ~0.7 GiB at the measured
2^20 shape (Section 0.3, a component the C-03 subtotal excludes) —
and the hash family (d) is walled off from its cheapest instantiation
by this repo's field (two-adicity 4; Section 4). Full verdict,
runner-ups, and the U-AG2 obligation list: Section 8.

## PROGRESS

- [x] Read-first set (PROGRESS_UAG.md, C-03 + Phase 3,
      RANGE_AGGREGATION_DESIGN 0/3b, TARGET_CONTRACT,
      WAVE_SHARE_MASKING_DESIGN 7.1, GATE_ALTERNATIVES,
      M4_LOOKUP_LITERATURE, SOUNDNESS_REFERENCE 1-3,
      ROUTE_R_BUILD_REPORT / RING_MULT_BOTTLENECK headers,
      PROGRESS_US P3-EXIT, PROGRESS_UZ1 IA-4)
- [x] Section 0: ground rules, the wall, the pricing axes
- [x] Section 1: family (a) LaBRADOR-class (papers verified)
- [x] Section 2: family (b) folding (LatticeFold lineage)
- [x] Section 3: family (c) PCS reroute (Greyhound-class)
- [x] Section 4: family (d) hash-based transcript compression
- [x] Section 5: family (e) SNARK-wrap recursion
- [ ] Section 6: cross-cutting — Z1 compatibility, verifier budget
- [ ] Section 7: the pricing table
- [ ] Section 8: verdict in full
- [ ] Section 9: what we did not find
- [x] References (verified links; grows with sections)

## 0. Ground rules: the wall, the budgets, and what "priced" means

### 0.1 The wall, from the repo's own accounting

The adopted byte accounting (RANGE_AGGREGATION_DESIGN.md Section 3b,
transcribing audit C-03, codex-audit-2026-07-14/FINDINGS.md) prices
the CURRENT proof's per-commitment opening arrays alone — z: n_r x D
signed response coefficients and w1: kappa x D field coefficients at
the rig's n_r = 26, D = 128, kappa = 8 — at:

    shape             | plain openings         | z          | w1        | subtotal
    battery, 4,092 el | 209 data + 152 g = 361 | 9.17 MiB   | 2.82 MiB  | 11.99 MiB
    measured 2^20     | 50,197 data + 38,050 g | 2,240.65   | 689.43    | 2,930.08 MiB
                      |   = 88,247             |   MiB      |   MiB     |

That is ~2.86 GiB at the measured 2^20 layer shape — **11,720x** the
256 KiB target — or ~34.0 KiB per opening (WAVE_SHARE_MASKING_DESIGN
Section 6.3), with linear accounting projections of ~15.4 GiB for one
512x11008 activation tensor's z/w1 arrays and ~492 GiB for 32 such
layers (audit C-03; projections, not runs). Halving every coefficient
to four bytes still leaves ~1.43 GiB. Measured serialized anchors,
whole files (PROGRESS_US.md P3-EXIT, single-wave committed lookup,
statement + proof canonical bytes): 1025 KiB @2^12, 1378 KiB @2^13,
2036 KiB @2^14, 3307 KiB @2^15 — over budget at every shape,
dominated by the ct-round i64 response vectors.

The C-03 subtotal deliberately EXCLUDES h reveals, claim masks,
quadratic proof fields, public commitments, masked descents,
partials, framing, and the statement. Section 0.3 shows one of those
exclusions — the commitments themselves — is independently
budget-fatal, which constrains which families can win at all. The
full component ledger is the GB lane's deliverable
(PROOF_BYTE_LEDGER.md); this review only needs the two facts above.

### 0.2 The budgets, and the two-orders-of-magnitude verifier gap

- **Proof bytes:** <= 256 KB serialized, complete artifact
  (TARGET_CONTRACT.md Section 4; the audit computes gaps against
  256 KiB — the contract line binds, the discrepancy is immaterial
  at this gap, RANGE_AGGREGATION_DESIGN Section 0 item 3).
- **Verifier:** <= 2 s single-threaded on the repo CPU
  (TARGET_CONTRACT.md Section 4). This budget is as broken as the
  byte budget today and gets less attention: the measured 2^20 rate
  is 187.4 us/el verify (audit H-05), i.e. ~196.5 s at ONE 2^20
  slice — ~98x over budget before multiplying by ~24 slices/layer
  and 32 layers (~9.4 h full pass, audit H-05 projection). A
  candidate that fixes bytes but keeps a verifier LINEAR in the
  witness does not meet the contract. This axis eliminates
  candidates in this review (Sections 1, 4).
- **PQ posture:** post-quantum is a mandate, not a preference — the
  curve hybrid was rejected on exactly this ground
  (GATE_ALTERNATIVES.md option 3: "breaks post-quantum security for
  the linked component... Class-3 viability and PQ were mandates").
  A non-PQ candidate can only be recorded, not recommended.
- **Z1-masking compatibility:** the U-Z1 tranche closed audit C-02
  at engine scale (WAVE_SHARE_MASKING_DESIGN status header;
  PROGRESS_UZ1.md IA-4) by masking per-wave share scalars with
  committed pads that cancel only in aggregate. The standing
  constraint on THIS tranche (WAVE_SHARE_MASKING_DESIGN Section 7
  item 1): "any future aggregation scheme (Phase 3) must PRESERVE
  the pad structure or re-derive the privacy argument — an
  aggregator that re-exposes per-wave right-hand sides undoes Z1."
  Every family below carries an explicit Z1 row: does it re-expose
  per-wave RHS, and can it aggregate over MASKED shares?
- **Prover overhead:** priced as a multiplier on the current
  attribution: the committed masked lookup runs at ~23 us/el 1T
  (lkp attribution 23.4 us/el prove at 2^20,
  RANGE_AGGREGATION_DESIGN Section 2b) inside a full prove of
  578.7 us/el (audit H-05). Prover time is explicitly NOT the
  selection criterion (REMEDIATION_PLAN Phase 3: "selected by
  proof-size and verifier-cost models, not prover time alone") —
  but a candidate that multiplies the whole prove by >10x re-breaks
  H-05 and must say so.

### 0.3 A structural fact that constrains every family: openings are not the only GiB

The C-03 subtotal counts z/w1 only. The commitments themselves —
which are prover messages (activations are committed per proof,
TARGET_CONTRACT.md Section 3) and therefore wire bytes — weigh, at
the working CRS shape (kappa 8, n_r 26, msg_r 8;
M4_LOOKUP_DESIGN.md Section "one ct-round at the working CRS
shape"): t1 = kappa ring elements + t2 = msg_r ring elements = 16 x
128 coefficients x 4 B ~ 8 KiB per commitment, so 88,247 commitments
~ **0.67 GiB at the measured 2^20 shape [MODEL, derived here]** —
independent of, and additive to, the 2.86 GiB of openings.

Consequence, load-bearing for the whole review: **a family that
only aggregates the openings and leaves the per-wave commitment
lists on the wire cannot reach 256 KiB at any shape of interest.**
The winning architecture must also collapse the COMMITMENT layer to
O(1)-ish global objects (family (c)'s move), or bind the commitment
list by digest and prove the openings against the digest inside the
aggregate proof (recursion — families (a)/(e) can do this only by
proving hash preimages or by restructuring what is committed).
This fact is not in the audit table (C-03 lists "public commitments"
among exclusions without pricing them); it is this review's first
result, and the GB byte ledger should confirm or correct the 0.67
GiB figure against the serializer.

### 0.4 The engine assets any candidate can ride (the one-engine-many-uses lens)

M4 chose LogUp-GKR partly because its two build obligations (a
sumcheck/GKR transcript layer over GF(q^e); MLE-evaluation claims
against dense lattice commitments) were shared with the
GATE_ALTERNATIVES option-2 fallback — "the sumcheck engine is
bought once and used twice" (M4_LOOKUP_LITERATURE.md Section 3).
Aggregation is the third use of the same engine. In-repo today:

- the 8-slot GF(q^16) CRT structure with |GF(q^16)| ~ 2^496
  (SOUNDNESS_REFERENCE.md Section 1.1) — the large soundness field
  every sumcheck-family candidate needs, for free;
- the built masked sumcheck/GKR descent layer with its HVZK lemmas
  (ring/gkr_masked.rs; Q4.7-Q4.9 per TARGET_CONTRACT Section 3's ZK
  status note) — i.e., the repo already knows how to run
  sumcheck-shaped reductions over MASKED data, which is exactly the
  Z1-compatibility mechanism Section 6 prices;
- kernel-grade ring arithmetic: the A1 aux-NTT dispatch and
  Karatsuba slot kernels at ~0.16-0.20 us/ring-MAC class
  (RING_MULT_BOTTLENECK.md Section 6.5; ROUTE_R_BUILD_REPORT.md U1),
  ~119 mults/committed element on the commit path;
- BDLOP commitments + digit-decomposed openings + the ct-claim
  engine (SOUNDNESS_REFERENCE Sections 2-4) and the U-L cross-
  modulus link (link.rs) — the claim-wiring layer any lattice-side
  candidate composes with;
- Statement v3 + the canonical codec + fresh-process verifier
  (PROGRESS_US.md P3) — the serialization boundary any candidate's
  bytes will be measured through.

### 0.5 Pricing axes (every family gets all eight)

1. projected proof bytes at the measured 2^20 layer shape AND the
   32-layer pass; 2. verifier cost vs <= 2 s; 3. prover overhead vs
   the ~23 us/el attribution / 578.7 us/el whole-prove; 4. PQ
   status; 5. Z1-masking compatibility; 6. engine reuse; 7.
   maturity / external-security-review burden (this repo owes an
   independent review — REMEDIATION_PLAN Phase 2.5,
   WAVE_SHARE_MASKING_DESIGN Section 7.7; a candidate with a
   published security proof and third-party analysis scores
   higher); 8. implementation risk class.

## 1. Family (a): LaBRADOR-class recursive amortized opening proofs

### 1.1 LaBRADOR — what it is and what is verified

LaBRADOR (Beullens-Seiler, "LaBRADOR: Compact Proofs for R1CS from
Module-SIS," CRYPTO 2023, ePrint 2022/1341) proves knowledge of
short vectors satisfying dot-product constraints over the ring
Z_q[X]/(X^64 + 1) — the "principal relation": witness vectors s_1..
s_r with bounded norm satisfying quadratic dot-product constraints
and constant-coefficient constraints. Its engine is recursive
amortization: commit to the witness with Ajtai commitments, reduce
many constraints to a few via random linear combination, fold the
witness by splitting-and-projecting, and RECURSE — the next level
proves the verification relation of the previous one, with proof
size shrinking geometrically. Verified headline (ePrint 2022/1341
abstract): **58 KB for an R1CS mod 2^64 + 1 with 2^20 constraints**,
"an order of magnitude more compact than previous quantum-safe
proofs"; the recursion gives O(log n)-class proof size, with
follow-on literature quoting 60-70 KB up to 2^30 constraints.
Assumption: Module-SIS. Transparent (no trusted setup). FS-in-ROM
with a genuinely multi-round, recursive transcript — the knowledge-
error analysis of that composition is nontrivial and was done
properly only later (Section 1.4).

Two verified structural caveats:

1. **The verifier is linear.** LaBRADOR's verifier does work linear
   in the ORIGINAL statement/witness size — concretely "more than an
   order of magnitude slower than for other quantum-safe succinct
   proofs" (the Greyhound paper positions itself against exactly
   this; see also the zksecurity.xyz analysis, References). For this
   repo that is disqualifying AS A STANDALONE ANSWER: the statement
   at the 2^20 shape includes 88,247 commitments and the constraint
   system that mentions each of them, so verifying the aggregate
   costs the same order as today's 196.5 s/slice verify (Section
   0.2) — bytes fixed, verifier budget still broken ~100x.
2. **Not zero-knowledge as published.** LaBRADOR is a proof of
   knowledge with no witness-privacy claim; ZK arrives via the 2026
   toolkit line (Section 1.3). Any use here must price that layer
   in, because the witnesses being aggregated (openings of
   activation commitments) are exactly the private data Z1 protects.

### 1.2 What LaBRADOR would aggregate here, and the honest arithmetic

The natural encoding is NOT "compress the existing z/w1 arrays" —
it is to REPLACE the per-wave Schnorr-style masked rounds: prove, in
one LaBRADOR instance, knowledge of short openings rho_i for all
commitments in scope (A1 rho_i = t1_i, A2 rho_i + x_i = t2_i)
together with the linear/ct claims about the x_i. The per-opening
34.0 KiB of z/w1 disappears entirely; what remains on the wire is
one recursive proof (~60-100 KB class) plus THE STATEMENT — which
still contains every t1_i/t2_i. By Section 0.3 that is ~0.67 GiB at
2^20 [MODEL]: **family (a) alone lands at ~0.7 GiB per 2^20 slice,
a ~4x win, not a 11,720x win.** To go further the commitments
themselves must become witness data bound by a short digest, and
LaBRADOR proves algebraic (ring) relations, not hash preimages — so
digest-binding means either an algebraic (Ajtai) commitment TREE
over the t_i (a commit-to-commitments restructuring, drifting
toward family (c)), or accepting per-layer granularity with the
commitment list amortized into a reusable, statement-side object.

Two adaptation frictions, both real but engine-compatible:

- **Ring mismatch.** LaBRADOR works over degree-64 power-of-two
  cyclotomics with its own modulus; this repo is D = 128, q31 =
  2^31 - 399 (SOUNDNESS_REFERENCE 1.1). Both are power-of-two
  cyclotomics and the LaBRADOR framework is parameterized, but the
  security analysis (challenge-set operator norms, slack growth
  through recursion levels) must be re-derived at our parameters —
  review-burden work, not new mathematics. The K-mult/A1 kernels
  (Section 0.4) serve the prover arithmetic directly.
- **Relaxed openings compose.** LaBRADOR extraction has slack
  (norm growth per recursion level); the repo's relaxed-binding
  discipline (SOUNDNESS_REFERENCE 2.2) is the same shape, but the
  C2/C3-class parameter chains would need to absorb LaBRADOR's
  slack stack — a derive-time-gate rework.

### 1.3 The ZK layer: the 2026 toolkit

"A Toolkit for Succinct Lattice-Based Zero Knowledge Proofs"
(Biasioli, Bolboceanu, Lyubashevsky, Merino-Gallardo, Osadnik,
Seiler, Steuer; ePrint 2026/1289) adds witness privacy to LaBRADOR
by integrating the linear-size ZK proof of Lyubashevsky-Nguyen-
Plancon (LNP22, CRYPTO 2022) in front: the LNP22 layer hides the
witness, LaBRADOR compresses the (public-witness) verification of
the LNP22 proof. Quoted state of the art: "output sizes under 100 KB
for arbitrarily large statements" with "very fast provers." This is
also the LaZer library lineage (Lyubashevsky-Seiler-Steuer, ACM CCS
2024, ePrint 2024/1846) — meaning maintained, third-party-usable
implementations exist at IBM Research, which materially lowers the
external-review burden relative to bespoke recursion. For this
review: the ZK gap of family (a) is CLOSED IN THE LITERATURE as of
2026, at ~100 KB-class output, but the composition (LNP22 front-end
over OUR BDLOP witnesses at OUR parameters) is exactly the kind of
"first of its shape" adaptation M4 flagged for the lookup track
(M4_LOOKUP_LITERATURE Section 7).

### 1.4 Security-review posture (the axis where (a) scores best)

The Fiat-Shamir security of LaBRADOR's recursive multi-round
structure received a dedicated analysis: "Aggregating Falcon
Signatures with LaBRADOR" (Aardal, Aranha, Boudgoust, Kolby,
Takahashi; ePrint 2024/311) introduces predicate special soundness
(PSS) to bound the knowledge error of exactly this composition, and
demonstrates the "aggregate many small lattice verifications into
one LaBRADOR proof" pattern end-to-end — the closest published
precedent for aggregating many BDLOP-opening verifications. Between
the CRYPTO 2023 paper, the PSS analysis, the CCS 2024 library, and
the 2026 ZK toolkit, family (a) has the deepest published security
stack of any lattice candidate in this review.

### 1.5 Family (a) scorecard (axes of 0.5)

1. **Bytes:** proof proper ~60-100 KB/aggregation unit [verified
   class]; but + ~0.67 GiB commitment statement at 2^20 [MODEL,
   0.3] unless commitments are restructured — standalone, FAILS the
   256 KiB budget at every scope; as the compressor inside family
   (c), MEETS it. 32-layer pass standalone: GiB class (commitment-
   dominated).
2. **Verifier:** linear in statement — minutes-class at 2^20,
   hours-class at full pass [MODEL from 0.2] — FAILS <= 2 s
   standalone; fixed by the Greyhound sqrt structure (Section 3).
3. **Prover:** linear, NTT-heavy, same arithmetic class as the A1
   kernels; literature calls it fast; est. multiplier on whole-prove
   ~1.2-2x [MODEL — must be modeled properly in U-AG2].
4. **PQ:** yes (Module-SIS, transparent).
5. **Z1:** aggregating the split-claim relations inside one proof
   need not reveal per-wave RHS at all — the aggregate can assert
   the zero-sum closing relation directly over committed pads,
   which is REMEDIATION_PLAN Phase 2.3's third option ("an
   aggregation scheme that verifies wave-local openings without
   exposing their right-hand sides") — Z1-compatible, and
   potentially Z1-subsuming; but the proof itself needs the 1.3 ZK
   layer, else the aggregated witness leaks. Detailed in Section 6.
6. **Engine reuse:** ring arithmetic/kernels yes; ct-round layer is
   REPLACED, not reused; Statement v3 codec reused.
7. **Maturity:** best in class (CRYPTO 2023 + PSS analysis + CCS
   2024 library + 2026 ZK toolkit).
8. **Risk class:** parameter re-derivation + recursion slack
   integration — medium; "first of its shape" composition with our
   BDLOP layer — the M4-style flagged unknown.

## 2. Family (b): folding / split-and-fold accumulation (LatticeFold lineage)

### 2.1 The lineage, and what is verified

Folding schemes (the Nova line, lattice edition) accumulate many
same-shaped instances into ONE running instance whose witness stays
one-instance-sized; succinctness comes at the end, from a single
"decider" proof of the accumulated instance. The lattice lineage:

- **LatticeFold** (Boneh-Chen, ePrint 2024/257): the first
  lattice-based folding protocol, from Module-SIS; "as performant as
  HyperNova, while providing plausible post-quantum security"; works
  over small (64-bit) fields [abstract verified]. Norm control by
  decomposing witnesses into low-radix digits before folding — the
  cost model this repo's digit-decomposed openings already live in
  (SOUNDNESS_REFERENCE Sections 2-4) — and a sumcheck at the core of
  every fold.
- **LatticeFold+** (Boneh-Chen, ePrint 2025/247): prover 5-10x
  faster, shorter folding proofs, via a monomial-embedding algebraic
  range proof and a sumcheck-based double-commitment transformation
  [abstract verified; ref 7].
- **Neo** (Nguyen-Setty, ePrint 2025/294): lattice folding for CCS
  with pay-per-bit Ajtai commitments ("committing to a vector of
  bits is 32x cheaper than committing to a vector of 32-bit
  values"), small prime fields (Goldilocks-class), no cyclotomic
  ring requirement [abstract verified]. SuperNeo (ePrint 2026/242)
  extends the line; M4 already recorded this family as "the
  structural competitor to watch, not the M4 move"
  (M4_LOOKUP_LITERATURE.md Section 1.37) because pay-per-bit
  economics do not arrive by swapping a kernel under our dense
  Sigma-protocol openings.

### 2.2 What folding buys HERE — the honest wire arithmetic

The natural instance is ONE WAVE's ct-round relation (~133
commitments sharing a challenge, PROOF_BYTE_LEDGER.md Section 0.1),
not one opening: 670 instances at 2^20, 3,597 at FFN-layer scale
(PROOF_BYTE_LEDGER.md Sections 1-2). Folding then prices as follows
[MODEL, unit costs from PROOF_BYTE_LEDGER.md Section 0]:

- **Fold messages.** Each fold step emits commitment-sized cross
  material (an Ajtai commitment and/or sumcheck rounds), ~4-8 KiB at
  our kappa/msg_r shape. 669 steps x ~8 KiB ~ **5.4 MiB at 2^20**
  (~29 MiB at FFN scale) — a ~500x cut of the opening layer, far
  short of 14,175x, and that is BEFORE the decider.
- **The decider.** The accumulated witness is one-wave-sized, so a
  naive decider re-sends one wave's openings: ~133 x 30,864 B ~ 3.9
  MiB — over budget alone. The decider must itself be compressed by
  a family (a)/(c) proof (~60-100 KB class); folding does not remove
  the need for a succinct final argument, it amortizes it.
- **The identities stay.** Every instance's commitments are its
  public IO; the folding verifier must read them. The 0.67 GiB
  commitment layer (Section 0.3; confirmed at 695.6 MiB by
  PROOF_BYTE_LEDGER.md Section 1 row 3) is untouched: **family (b)
  standalone lands at ~0.7 GiB at 2^20, identity-dominated — the
  same structural ceiling as family (a).** Only commitment
  restructuring (family (c)) or digest-binding-with-recursion
  escapes it.

Verifier: each fold-verify is an RLC over ~16 ring elements plus
transcript hashing — no opening re-check, ~ms class per step, so
~0.7-4 s single-threaded across 670-3,597 steps [MODEL] plus the
decider verify. That is linear in waves with a small constant:
inside the 2 s budget only marginally at layer scale, and it
violates the letter of the sublinearity rule PROOF_BYTE_LEDGER.md
Section 3.2 imposes (verifier work sublinear in commitments x
waves) unless the folds are arranged in a tree whose upper levels
are proven rather than replayed — which is recursion, i.e. family
(a) machinery again.

**Where folding IS the right primitive: the cross-layer axis.** The
byte ledger's budget table flags that at one descent pair per layer,
a 32-layer pass costs 32 x 103.2 KiB = 3.2 MiB in descents alone —
"cross-layer descent aggregation/folding is ALSO mandatory, not
optional" (PROOF_BYTE_LEDGER.md Section 3.1). Folding accumulates
layer k's aggregated claim into layer k+1 at O(1) wire per layer
with one final decider — exactly the shape of the not-yet-built
multi-layer chaining (TARGET_CONTRACT.md Section 5). No other
family provides this axis natively: (a) and (c) prove one batch
ever-so-compactly but need to be re-run or tree-composed per layer.

### 2.3 Z1 and engine fit

Z1: folding is random linear combination over instances. Post-Z1
the per-wave RHS are already committed pads plus one zero-sum
closing claim (WAVE_SHARE_MASKING_DESIGN.md Sections 2-3); folding
over the MASKED instances keeps every pad committed and publishes
only RLC-aggregated images, so no per-wave RHS re-appears —
compatible, PROVIDED the folding challenges are drawn after the pad
commitments in the FS order (the same discipline as WSMD Section
3.4's multi-round composition, which must be extended to cover the
fold rounds — a U-AG2 lemma obligation). Engine fit is the best of
any family: every fold step is a sumcheck over GF(q^16)-class
extensions plus Ajtai RLC — the U-K1..K9 sumcheck stack and the A1
kernels are the exact required objects, and the digit-decomposed
witnesses are already in LatticeFold's low-norm form.

### 2.4 Family (b) scorecard (axes of 0.5)

1. **Bytes:** fold messages ~5.4 MiB @2^20 / ~29 MiB @FFN [MODEL] +
   decider + the untouched ~0.7 GiB identity layer — standalone
   FAILS the budget at every scope; as the CROSS-LAYER accumulator
   over family (c) units, adds O(1) per layer — MEETS it.
2. **Verifier:** linear in waves at small constant (~seconds class);
   sublinear only via tree + recursion. Marginal standalone.
3. **Prover:** one sumcheck + RLC per wave over one-wave witnesses —
   [MODEL] ~1.1-1.5x on whole-prove; LatticeFold+ exists because
   the naive version was 5-10x slower — parameters matter.
4. **PQ:** yes (Module-SIS, transparent).
5. **Z1:** compatible over masked instances; FS-ordering lemma owed
   (fold rounds into the WSMD 3.4 composition argument).
6. **Engine reuse:** highest of all families — sumcheck stack,
   kernels, digit decomposition all load-bearing.
7. **Maturity:** ePrint line 2024-2026, no production deployment, no
   maintained library (contrast LaZer for family (a)); Neo/SuperNeo
   still moving. Security analyses are paper-only.
8. **Risk class:** high standalone (decider + parameter chains +
   heterogeneous-wave shaping); LOW as an add-on accumulator once a
   family (c) unit proof exists — the fold then operates on a few
   small instances per layer, not 670.

## 3. Family (c): polynomial-commitment reroute (Greyhound-class)

### 3.1 Greyhound — what it is and what is verified

Greyhound (Nguyen-Seiler, "Greyhound: Fast Polynomial Commitments
from Lattices," CRYPTO 2024, ePrint 2024/1293) is the first
concretely efficient lattice polynomial commitment: a two-tier
Ajtai structure over the coefficient matrix, a three-round
evaluation protocol whose verifier runs in **O(sqrt N)**, and
LaBRADOR as the compression layer for the evaluation proof.
Verified headline (ePrint 2024/1293 abstract): **evaluation proofs
of 53 KB at degree N = 2^30**, >10^4x smaller than SLAP; assumption
Module-SIS; transparent. M4 already logged it as the existence
proof that "MLE/polynomial evaluation claims against lattice
commitments is a solved problem class" (M4_LOOKUP_LITERATURE.md
Section 1.37).

Frontier caveat, load-bearing for expectations: HyperWolf (ePrint
2025/922) claimed a lattice PCS with O(log N) proof size AND
verifier time — and was **withdrawn** (October 2025, per its ePrint
page). Nothing confirmed currently beats Greyhound's sqrt verifier
in the lattice-PCS class; Section 9 records this as the field's
honest state, and Orthus (ePrint 2026/398, Section 6) as the
adjacent sqrt-verifier result for batch-verifying lattice
relations.

### 3.2 The reroute — a re-architecture, not an add-on

Families (a)/(b) hit the same ceiling: they compress openings but
inherit the per-wave COMMITMENT LIST (Section 0.3; 695.6 MiB at
2^20, PROOF_BYTE_LEDGER.md Section 1 row 3). Family (c) removes the
ceiling by changing what is committed. Today each tensor is
scattered across tens of thousands of msg_r = 8 BDLOP commitments
(~1,024 coefficients each) because the per-wave ct-round and the
C2 wave cap shaped the commitment layer around Sigma-protocol
openings (TARGET_CONTRACT.md Section 3: the cap binds near 2^17
elements). The reroute:

1. commit each tensor (Y/UP/Z, lookup material, pads) as a FEW
   global polynomial commitments — one 5.6e6-coefficient tensor is
   degree ~2^22.4, well inside Greyhound's published 2^30;
2. collapse the claim structure (9 pins, ~169k zeta claims, ~705k
   Hadamard chunk claims, lookup/range claims at FFN scale —
   PROOF_BYTE_LEDGER.md Section 2) into a FEW batched
   MLE-evaluation claims via the masked sumcheck/GKR engine — the
   M4 obligations E3/E4 verbatim (M4_LOOKUP_LITERATURE.md Section
   6); aggregation is the third use of the engine bought for the
   lookup;
3. serve the batched evaluation claims with Greyhound evaluation
   proofs, LaBRADOR-compressed — a handful of 53 KB-class objects,
   batchable further by random linear combination of claims at a
   common point (standard MLE batching; soundness at our GF(q^16)
   slot field to be re-derived, U-AG2).

Bottom-up wire arithmetic at FFN-layer scale [MODEL, components
priced against PROOF_BYTE_LEDGER.md Section 3.1's allocation]:
statement ~4-8 KiB; global commitment identities ~10 x 8.3 KiB
class; masked descent pair 103.2 KiB at the canonical 4 B/limb
width (PROOF_BYTE_LEDGER.md Section 3.1); one-to-few batched
evaluation proofs 53-110 KiB; O(1) aggregated claim scalars. Total
**~200-260 KiB — the only family whose bottom-up sum lands at the
budget line at the complete-FFN-layer scale.** Tight, not
comfortable: the descent pair plus one eval proof already spends
~60% of the budget, so claim batching (ONE eval proof, not five)
and the 4 B/limb descent codec are both load-bearing. The 32-layer
pass multiplies by 32 unless family (b) folds across layers —
which is exactly the (b)+(c) composition Section 8 recommends.

Verifier [MODEL]: sumcheck/GKR verify is polylog; Greyhound verify
is O(sqrt N) — at N = 2^23, ~2^11.5 ring-op class, milliseconds on
the A1 kernels' measured ~0.16-0.20 us/ring-MAC class
(RING_MULT_BOTTLENECK.md Section 6.5); LaBRADOR's linear verifier
runs over the ALREADY-SQRT-SIZED Greyhound relation, not the
witness — this is how the composition dodges family (a)'s
disqualifier. Orders of headroom under 2 s; the only family that
fixes BOTH broken budgets (bytes 76,162x, verifier ~528x —
PROOF_BYTE_LEDGER.md Sections 2, 3.2) with published components.

Prover [MODEL — U-AG2 must model properly]: Greyhound commit =
Ajtai matvecs (linear, kernel-served); evaluation prover linear;
sumcheck linear with the M4-class constants (~43 ext-mults/el
class, M4_LOOKUP_LITERATURE.md Section 4). Est. 1.5-3x on the
578.7 us/el whole-prove — inside the <10x H-05 line, unverified.

Frictions, both U-AG2 design work: (i) parameter re-derivation at
D = 128 / q31 (Greyhound and LaBRADOR publish at degree-64 rings;
same friction class as Section 1.2's ring mismatch — review
burden, not new mathematics); (ii) claim-class reduction — the
ct-engine's pin/zeta/QuadRing claims and the U-L cross-modulus
link must all be re-expressed as evaluation claims against the
global commitments; the committed-executions gate (the quadratic
layer) is the hard case, and if any claim class cannot reduce, a
residual per-wave structure survives and re-imports the old bytes.

### 3.3 Z1 under the reroute

The reroute does not aggregate the per-wave RHS — it ABOLISHES
them: no wave structure survives, so nothing per-wave can be
re-exposed, and the WSMD Section 7.1 constraint is met by its
second branch ("or re-derive the privacy argument"). The
re-derivation rides built machinery: the sumcheck runs over MASKED
MLEs (ring/gkr_masked.rs, HVZK lemmas Q4.7-Q4.9 — the repo already
runs masked sumcheck at engine scale), and the final evaluation
values are blinded by pad-polynomial terms folded into the batched
claim, with the ZK gap of the Greyhound/LaBRADOR layer closed the
same way as family (a)'s (the 2026 toolkit line, ePrint
2026/1289). Obligations, not blockers: an aggregated-transcript
simulator in the WSMD Section 3 style, and an
aggregated-transcript analogue of the rank/recovery battery
(PROOF_BYTE_LEDGER.md Section 4, R3). Note Greyhound, like
LaBRADOR, is a proof of knowledge as published — the ZK layer is
owed in U-AG2's design, not assumed.

### 3.4 Family (c) scorecard (axes of 0.5)

1. **Bytes:** ~200-260 KiB per complete FFN-layer statement
   [MODEL] — the only family AT the budget; 32-layer pass needs
   the (b) accumulator on top (else x32 ~ 7-8 MiB).
2. **Verifier:** polylog sumcheck + O(sqrt N) Greyhound —
   ms-to-sub-second class [MODEL]; MEETS <= 2 s with headroom;
   fixes the ~528x verifier gap.
3. **Prover:** [MODEL] ~1.5-3x whole-prove; linear, kernel-served;
   U-AG2 modeling obligation.
4. **PQ:** yes (Module-SIS, transparent).
5. **Z1:** subsumes the constraint (no per-wave RHS exists);
   privacy argument re-derivation owed on built masked-sumcheck
   machinery; ZK layer for the eval proof owed.
6. **Engine reuse:** the M4 one-engine-many-uses payoff realized —
   sumcheck/GKR (E3), MLE-eval claims (E4), A1 kernels, Statement
   v3 codec; the per-wave ct-round layer is RETIRED, not reused.
7. **Maturity:** CRYPTO 2024, author implementation, LaBRADOR
   stack beneath it (Section 1.4's review depth applies to the
   compression layer); less end-to-end precedent than (a) — nobody
   has published "GKR claim aggregation + Greyhound serving" as
   one system.
8. **Risk class:** highest single-family restructuring (retires
   the wave architecture) — but the byte ledger shows the
   restructuring is FORCED regardless: identities and reveals are
   independently budget-fatal (PROOF_BYTE_LEDGER.md Section 3.1),
   and no family that keeps the wave structure can pay them.

## 4. Family (d): hash-based sumcheck/FRI transcript compression

### 4.1 The shape, and what it inherits from GATE_ALTERNATIVES

This is option 2 of GATE_ALTERNATIVES.md, promoted from "gate
fallback" to "carry the whole claim structure": commit the witness
additionally under a hash-based polynomial commitment
(Brakedown/Ligero/FRI class — "linear-time committing, no FFT,
GPU-friendly, post-quantum"), prove all claims with sumcheck over
the hash commitments, and tie hash-committed to lattice-committed
values with the link-row machinery priced for the gadget-modulus
decision (~59 KB/tensor, GADGET_MODULUS_DECISION.md Section 3.5
via GATE_ALTERNATIVES.md option 2). The recorded cons scale up
with the promotion: every tensor committed twice, and "two proof
systems to maintain and audit."

### 4.2 What the hash family achieves where the field permits

Verified state of the art: WHIR (Arnon-Chiesa-Fenzi-Yogev, ePrint
2024/1586) reports, at degree 2^22 and 100 bits of security, **63
KiB proofs verified in 360 microseconds** [abstract verified] —
both repo budgets met with orders of headroom, on paper, at
exactly our witness scale. The surrounding ecosystem is the most
production-hardened in this review: M4 already relies on it as
precedent ("Stwo/SP1 ... running LogUp over FRI at field sizes
like 2^31, our field class," M4_LOOKUP_LITERATURE.md Section 4),
and the whole family is transparent and hash-PQ.

### 4.3 The wall: this repo's field cannot host the cheap instantiation

FRI/STIR/WHIR encode over Reed-Solomon domains — multiplicative
subgroups of smooth (power-of-two) order. Our protocol field: q31
= 2^31 - 399 with q ≡ 17 (mod 32) (SOUNDNESS_REFERENCE.md 1.1),
so q - 1 = 16 x (2^27 - 25) and **v2(q-1) = 4** [DERIVED]: the
largest power-of-two subgroup of F_q* has SIXTEEN elements,
against codewords of length 2^22+. Extending does not rescue it:
v2(q^16 - 1) = v2(q-1) + v2(q+1) + v2(16) - 1 = 4 + 1 + 4 - 1 =
8 [DERIVED, lifting-the-exponent], a 256-point domain. (The A1
report describes its ring generation as q ≡ 5 (mod 8) with
v2(q-1) = 2, A1_AUX_NTT_REPORT.md; either reading is 18+ doublings
short — the conclusion does not depend on which.) The repo already
imports the Goldilocks prime (v2(p-1) = 32) for prover-internal
NTTs, but that import "carries no protocol role"
(A1_AUX_NTT_REPORT.md) — an RNS trick for exact integer
arithmetic, structurally unable to host commitments the
verification equations see.

### 4.4 The escapes, each priced

1. **Field-agnostic codes — BaseFold** (Zeilberger-Chen-Fisch,
   ePrint 2023/1705): multilinear PCS from random foldable codes,
   O(log^2 n) verifier, O(n log n) encoding "over any sufficiently
   large field" [abstract verified] — directly instantiable over
   q31/GF(q^16). Cost honesty: the abstract quotes only relative
   numbers (proofs >10x smaller than Hyperplonk-with-Brakedown,
   verification >30x faster at 2^20+ gates); log^2-class proofs
   are materially larger than WHIR's 63 KiB at equal scale, and no
   published table prices BaseFold at our exact shape — budget-
   adjacent, [MODEL]-only, must be concretely priced before this
   family is ever activated.
2. **Brakedown itself** (Golovnev-Lee-Setty-Thaler-Wahby, ePrint
   2021/1043): field-agnostic, linear-time prover [abstract
   verified] — but sqrt-sized proofs (the BaseFold abstract's
   ">10x smaller" is measured AGAINST it): MB-class at our scales,
   over budget as the outer layer; usable only under a wrapping
   compressor, which re-imports family (e).
3. **ECFFT** (Ben-Sasson-Carmon-Kopparty-Levit, "Scalable and
   Transparent Proofs over All Large Fields, via Elliptic Curves,"
   TCC 2022, ePrint 2022/1542): RS-style scalable IOPs over ALL
   large fields, replacing the smooth subgroup with
   elliptic-curve-derived FFT domains [ePrint page verified]. The
   curves are combinatorial (domain structure), not cryptographic
   — PQ is preserved. Asymptotic rescue with no concrete
   deployment-grade cost tables; highest engineering burden in
   this family.
4. **Field-switch + link**: hash-commit the witness over an
   FFT-friendly field (Goldilocks/BabyBear) and bind to the q31
   lattice commitments with U-L-style cross-modulus link rows
   (link.rs; the integer-exact pattern of
   GADGET_MODULUS_DECISION.md Section 3.5). The links are the
   bytes: ~59 KB/tensor x 3 tensors x 32 layers ~ 5.7 MB — the
   link layer itself must then be aggregated, which is the
   original problem one level down. Viable only if the links ride
   INSIDE the hash proof (proving the lattice-opening relation in
   the hash circuit — family (e) in disguise).

### 4.5 Z1, verifier, prover

Z1: the sumcheck side runs over masked data exactly as in family
(c) (the built masked-GKR machinery applies); hash commitments
hide via salting; NEW obligation — the cross-commitment link
argument must be simulatable too, and the double-committed witness
doubles the surface the rank/recovery battery class must cover.
Verifier: polylog hashing — meets <= 2 s trivially [verified
class: WHIR's 360 us]. Prover: a second full commitment pass over
all witness data (hashing, ~GB/s class — cheap next to the 578.7
us/el whole-prove) plus the sumcheck constants already priced in
M4; est. 1.3-2x whole-prove [MODEL].

### 4.6 Family (d) scorecard (axes of 0.5)

1. **Bytes:** 63 KiB-class IF the field permitted (it does not);
   over our field: BaseFold-class ~150-400 KiB [MODEL, unpriced by
   any paper at our shape] or field-switch with an unsolved
   link-aggregation residue — budget-adjacent with the widest
   error bars in this review.
2. **Verifier:** polylog, sub-ms-to-ms class — MEETS, best in
   review.
3. **Prover:** ~1.3-2x [MODEL]; second commit pass is cheap.
4. **PQ:** yes (hash; ECFFT's curves are combinatorial).
5. **Z1:** compatible via masked sumcheck; link-layer simulation
   and double-commitment coverage are NEW obligations.
6. **Engine reuse:** the sumcheck engine (E3) is reused — the
   one-engine-two-uses argument that made this the recorded
   fallback; but the PCS, codec extension, and transcript layer
   are all new, and the lattice claim engine is bypassed rather
   than composed.
7. **Maturity:** components most production-hardened in the
   review (FRI ecosystems) — but NOT at our field; the
   field-agnostic corner (BaseFold 2023, ECFFT 2022) is young and
   thinly deployed.
8. **Risk class:** medium: no new cryptography, but the
   two-adicity wall forces either young codes or a cross-field
   link whose aggregation is unsolved; the two-proof-system audit
   burden is permanent (GATE_ALTERNATIVES.md option 2's own con,
   now applied to the repo's largest subsystem).

## 5. Family (e): SNARK-wrap of the verifier (generic recursion)

### 5.1 The shape

Keep the current proof EXACTLY as it is — then never send it: make
the whole artifact witness data, and prove in an off-the-shelf
succinct system that "there exists an artifact today's verifier
accepts." The wire carries one wrapper proof; the verifier runs
the wrapper's verifier. Bytes and verifier budget are subsumed in
one move — on paper. Instantiations split by the PQ mandate:

- **PQ wrappers**: STARK-class zkVMs (RISC-V guest programs) or
  bespoke AIR circuits — hash-based, transparent. Notably these
  EVADE the family (d) field wall: the wrapper proves over ITS
  OWN FFT-friendly field and merely emulates our q31/ring
  arithmetic as guest computation — the evasion is paid for in
  emulation overhead.
- **Non-PQ wrappers** (Groth16/KZG-class, the standard "wrap for
  on-chain" move): excluded by mandate — the curve hybrid was
  rejected on exactly this ground (GATE_ALTERNATIVES.md option 3;
  Section 0.2). Recorded, not priced.
- **The lattice-native instantiation of this idea is family (a)**:
  LaBRADOR's recursion IS a SNARK-wrap of its own verifier,
  executed natively in the same ring with no emulation. Family (e)
  as a distinct family means the GENERIC wrap; everything that
  makes recursion attractive here is available without emulation
  inside families (a)/(c).

### 5.2 The honest arithmetic — the prover axis is fatal standalone

The wrapped computation is today's verify: 196.5 s native
single-thread at 2^20 and ~1,056 s at FFN-layer scale
(PROOF_BYTE_LEDGER.md Section 3.2) — a ~10^11-12 field-op-class
computation whose advice is the 3.46 GiB / 18.59 GiB artifact
(PROOF_BYTE_LEDGER.md Sections 1-2). Two repo-anchored kills:

1. **Prover lower bound.** Even at a fantasy 1x arithmetization
   overhead (proving as cheap per operation as native execution),
   the wrap costs >= the verifier's native work: ~1,056 s/layer of
   ADDED prover time — ~0.35x the whole-prove — before any real
   overhead. Real arithmetization of non-native modular
   arithmetic (q31 in a foreign field, per-instruction zkVM
   emulation) multiplies native work by orders of magnitude
   [MODEL; conservative band 10^2-10^4x] — prover cost lands in
   the days-to-weeks class PER LAYER, a >10^3x H-05 re-break. No
   published PQ recursion stack prices a witness of this shape
   (Section 9).
2. **The witness does not fit.** The FFN-scale advice tape is
   18.59 GiB against the 15 GiB reference box that already OOMs at
   the 2^22 serialize wall (PROGRESS_UZ1.md IA-4; PROGRESS_UR.md
   S2) — the wrap's input cannot even be materialized on the
   contract hardware, independent of proving speed.

Both kills are AGAINST THE CURRENT ARTIFACT. They dissolve if the
wrapped verifier is already small — which inverts the family's
role: (e) is not an aggregation strategy, it is an OPTIONAL
endgame compressor for whatever families (b)/(c) leave (a
sqrt-verifier, KB-class artifact), if an O(1)-verifier object is
ever needed for an on-chain or embedded consumer. At that point
its cost is trivial and its PQ instantiations are mature.

### 5.3 Z1 and the composition caveat

Z1: structurally the best in the review — the entire per-wave
transcript becomes witness and NOTHING per-wave reaches the wire;
the WSMD Section 7.1 constraint is met by construction, provided
the wrapper runs in its ZK mode (standard in STARK stacks).
Composition caveat owed in any adoption: proving "the FS verifier
accepts" inside another FS-compiled system is heuristic ROM-in-ROM
composition; family (a)'s line is the only one in this review with
a dedicated published analysis of exactly this pattern (PSS,
ePrint 2024/311 — Section 1.4). A generic zkVM wrap would carry an
UNANALYZED version of the same composition.

### 5.4 Family (e) scorecard (axes of 0.5)

1. **Bytes:** wrapper proof ~100-300 KB class [verified class for
   STARK stacks] at ANY scope, including the 32-layer pass —
   nominally MEETS; meaningless standalone given axis 3.
2. **Verifier:** wrapper verify, ms class — MEETS.
3. **Prover:** FAILS standalone by lower bound: >= +1,056 s/layer
   at 1x overhead, realistically 10^2-10^4x that [MODEL]; the
   witness cannot be materialized on the reference box. The kill
   axis.
4. **PQ:** yes for STARK wrappers; the convenient curve wraps are
   mandate-excluded.
5. **Z1:** subsumed by construction (ZK wrapper mode); ROM-in-ROM
   composition unanalyzed for generic wraps.
6. **Engine reuse:** none — a foreign stack emulating our ring
   arithmetic; the repo's engine assets are bypassed entirely.
7. **Maturity:** commercially mature ecosystems; zero precedent
   for wrapping GiB-scale lattice Sigma-protocol transcripts.
8. **Risk class:** extreme standalone (prover + memory + ops);
   LOW as a post-(c) endgame wrap of an already-small verifier —
   the only role this review assigns it.

## 6. Cross-cutting: Z1 compatibility and the verifier budget — PENDING

## 7. The pricing table — PENDING

## 8. The verdict in full — PENDING

## 9. What we did not find — PENDING

## 10. References (verified 2026-07-16/17 unless noted)

1. Ward Beullens, Gregor Seiler. "LaBRADOR: Compact Proofs for R1CS
   from Module-SIS." CRYPTO 2023; IACR ePrint 2022/1341.
   https://eprint.iacr.org/2022/1341 [abstract verified: 58 KB @
   2^20 R1CS constraints mod 2^64+1]
2. Ngoc Khanh Nguyen, Gregor Seiler. "Greyhound: Fast Polynomial
   Commitments from Lattices." CRYPTO 2024; IACR ePrint 2024/1293.
   https://eprint.iacr.org/2024/1293 [abstract verified: 53 KB
   evaluation proofs at degree 2^30; O(sqrt N) verifier; composed
   with LaBRADOR; >10^4x smaller than SLAP]
3. Beatrice Biasioli, Madalina Bolboceanu, Vadim Lyubashevsky,
   Antonio Merino-Gallardo, Michal Osadnik, Gregor Seiler, Patrick
   Steuer. "A Toolkit for Succinct Lattice-Based Zero Knowledge
   Proofs." IACR ePrint 2026/1289.
   https://eprint.iacr.org/2026/1289 [abstract verified: ZK via
   LNP22 integration into LaBRADOR; <100 KB class for arbitrarily
   large statements]
4. Marius A. Aardal, Diego F. Aranha, Katharina Boudgoust,
   Sebastian Kolby, Akira Takahashi. "Aggregating Falcon Signatures
   with LaBRADOR." CRYPTO 2024; IACR ePrint 2024/311.
   https://eprint.iacr.org/2024/311 [abstract verified: predicate
   special soundness framework for LaBRADOR's recursive FS
   composition]
5. Vadim Lyubashevsky, Gregor Seiler, Patrick Steuer. "The LaZer
   Library: Lattice-Based Zero Knowledge and Succinct Proofs for
   Quantum-Safe Privacy." ACM CCS 2024; IACR ePrint 2024/1846.
   https://eprint.iacr.org/2024/1846 [existence + scope verified via
   search; C library + Python interface; LaBRADOR and LNP22 backends]
6. Dan Boneh, Binyi Chen. "LatticeFold: A Lattice-based Folding
   Scheme and its Applications to Succinct Proof Systems." IACR
   ePrint 2024/257. https://eprint.iacr.org/2024/257
7. Dan Boneh, Binyi Chen. "LatticeFold+: Faster, Simpler, Shorter
   Lattice-Based Folding for Succinct Proof Systems." IACR ePrint
   2025/247. https://eprint.iacr.org/2025/247 [abstract verified:
   prover 5-10x faster than LatticeFold, shorter folding proofs,
   via algebraic range proof + sumcheck-based double-commitment
   transformation]
8. zksecurity.xyz. "Playing with LaBRADOR: Building Compact
   Lattice-based Proofs with Recursion."
   https://blog.zksecurity.xyz/posts/labrador/ [third-party
   analysis; source for the linear-verifier characterization and
   the 60-70 KB @ up-to-2^30-constraints class]
9. Wilson Nguyen, Srinath Setty. "Neo: Lattice-based folding scheme
   for CCS over small fields and pay-per-bit commitments." IACR
   ePrint 2025/294. https://eprint.iacr.org/2025/294 [abstract
   verified: lattice folding for CCS; pay-per-bit Ajtai (bits 32x
   cheaper than 32-bit values to commit); small fields
   (Goldilocks-class); no cyclotomic requirement; plausible PQ]
10. Lizhen Zhang, Shang Gao, Bin Xiao. "HyperWolf: Efficient
    Polynomial Commitment Schemes from Lattices." IACR ePrint
    2025/922. https://eprint.iacr.org/2025/922 [ePrint page
    verified: claimed O(log N) proof size and verifier time,
    linear prover; **WITHDRAWN October 2025** — cited here only as
    the negative result that no confirmed lattice PCS beats
    Greyhound's sqrt verifier]
11. Gal Arnon, Alessandro Chiesa, Giacomo Fenzi, Eylon Yogev.
    "WHIR: Reed-Solomon Proximity Testing with Super-Fast
    Verification." IACR ePrint 2024/1586.
    https://eprint.iacr.org/2024/1586 [abstract verified: 63 KiB
    proof at degree 2^22 / 100-bit security, 360 us verification;
    RS-domain-bound, hence walled off by our field's two-adicity]
12. Hadas Zeilberger, Binyi Chen, Ben Fisch. "BaseFold: Efficient
    Field-Agnostic Polynomial Commitment Schemes from Foldable
    Codes." IACR ePrint 2023/1705.
    https://eprint.iacr.org/2023/1705 [abstract verified:
    O(log^2 n) verifier, O(n log n) encoding over any sufficiently
    large field; relative sizes only (>10x smaller than
    Hyperplonk-with-Brakedown)]
13. Alexander Golovnev, Jonathan Lee, Srinath Setty, Justin
    Thaler, Riad S. Wahby. "Brakedown: Linear-time and
    field-agnostic SNARKs for R1CS." IACR ePrint 2021/1043.
    https://eprint.iacr.org/2021/1043 [abstract verified:
    linear-time prover, arbitrary fields of sufficient size; no
    concrete sizes in abstract — sqrt-class proofs, MB-class at
    our scales per the BaseFold comparison]
14. Eli Ben-Sasson, Dan Carmon, Swastik Kopparty, David Levit.
    "Scalable and Transparent Proofs over All Large Fields, via
    Elliptic Curves (ECFFT part II)." TCC 2022; IACR ePrint
    2022/1542. https://eprint.iacr.org/2022/1542 [ePrint page
    verified: scalable IOPs over any field of size at least
    quadratic in computation length, removing the FFT-friendly
    requirement]

---

*Changelog: 2026-07-17 — Sections 0-1 first commit (U-AG GA lane,
mid-tranche checkpoint per orchestrator request); families (b)-(e),
cross-cutting, table, and verdict follow in subsequent commits.*
