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
- [ ] Section 2: family (b) folding (LatticeFold lineage)
- [ ] Section 3: family (c) PCS reroute (Greyhound-class)
- [ ] Section 4: family (d) hash-based transcript compression
- [ ] Section 5: family (e) SNARK-wrap recursion
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

## 2. Family (b): folding / split-and-fold accumulation — PENDING (next commit)

## 3. Family (c): polynomial-commitment reroute (Greyhound-class) — PENDING

## 4. Family (d): hash-based transcript compression — PENDING

## 5. Family (e): SNARK-wrap recursion — PENDING

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

---

*Changelog: 2026-07-17 — Sections 0-1 first commit (U-AG GA lane,
mid-tranche checkpoint per orchestrator request); families (b)-(e),
cross-cutting, table, and verdict follow in subsequent commits.*
