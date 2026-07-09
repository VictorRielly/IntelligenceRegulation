# Alternatives for the Multiplication Gate (the "64 repetitions" problem)

Status: reference survey, written alongside the committed-executions gate
design (AUTOMORPHISM_GATE_DESIGN.md Section 7 / Appendix B). The MAIN
PLAN is the committed-executions gate; this document records the
alternatives considered, including out-of-family ones, for future
consideration if the main plan hits an obstacle.

## 0. The problem, restated plainly

To prove C = A * B with all three matrices hidden, the verifier must be
convinced that thousands of inner products between committed rows and
committed columns are all correct, without seeing any of them. Lattice
commitments only stay sound if the random challenges that combine
committed data are SMALL (big challenges blow up the opening norms and
break the security reduction). Small challenges carry only a few bits of
soundness each — hence Route Z's 64 repetitions. Route R's ring-valued
challenges are small AND high-entropy, which fixed every LINEAR proof
step at one shot; but pushed through the bilinear gate they contaminate
the verified coefficient with junk (finding F2). The alternatives below
are different ways of buying high-entropy soundness for the one bilinear
step. (Note: there are NO elliptic curves anywhere in Route R today —
the tension is entirely internal to the lattice setting. Curves appear
in this repo only as the separate pairing-track backend, and re-using
them for the gate is option 3 below.)

## 1. MAIN PLAN — the committed-executions gate (in-family, depth-1)

The trace-gate identity (spike-verified) rewrites the gate as a sum over
all 128 Galois twists. The cost problem was opening 3 x 128 derived
objects. Resolution: the prover COMMITS the 128-entry execution vectors
YA, YB, YC as fresh commitments (128 message slots each — cheap), ties
each to the original commitments with ONE challenge-batched combination
claim (per-slot sound, one digit-opened combination), and the whole gate
becomes ONE ring-valued quadratic claim. All identities machine-verified
in `ring_matmul gate-spike` ("committed-executions gate" section),
including the tampered-C negative and the norm-chain feasibility prints.

- Soundness: r = 1, per-slot 2^-296-class at every layer. Post-quantum.
- Cost per matmul claim (CORRECTED from the first ~300 KB estimate,
  which was a single-slot spike artifact): the execution-vector
  commitments scale with the matrix inner dimension, giving ~350 KB at
  demo shapes, ~1.7 MB at n = 2048, ~3.3 MB at FFN — **~5-8x below the
  scalar gate, at full r = 1**. MEASURED at the demo shape (U-B2/U-B3):
  marginal 345 KB, prove ~260 ms / verify ~75 ms at r = 1 — the
  estimate confirmed. Prove TIME returns to the one-shot class;
  per-claim SIZE stays MB-class at scale, so small-proof deployments
  eventually need option 2 or 3 as an aggregation layer on top.
- Built (U-B1..U-B4): the twisted quadratic claim in the engine, the
  end-to-end gate demo with full tamper batteries, freeze rows. Still
  open: the tie as a first-class in-round claim (the real remaining
  design item — AUTOMORPHISM_GATE_DESIGN.md Appendix B.1 records the
  obstruction and candidate route; the earlier "proof unchanged" note
  was an overclaim), then the pi2 default switch, then the ZK write-up.

## 2. Hash-based sumcheck gate (out-of-family, post-quantum)

Run ONLY the bilinear step in a different proof system: commit A, B, C
additionally under a hash-based polynomial commitment (Brakedown/Ligero
class — linear-time committing, no FFT, GPU-friendly, post-quantum), and
prove the product relation with the classical sumcheck protocol (log n
rounds, no repetitions, 100 KB-class). Tie the hash-committed values to
the lattice-committed values with the integer link rows already designed
and priced for the gadget-modulus decision (GADGET_MODULUS_DECISION.md
Section 3.5 — the same machinery serves both).

- Pros: mature, no lattice norm interactions at all, post-quantum.
- Cons: every matrix committed twice (hashing is fast, but it is a
  second pass over all data); the link rows add ~59 KB/tensor; two proof
  systems to maintain and audit. A strong fallback if the main plan's
  build hits a wall; also the natural bridge toward recursion/aggregation
  systems later.

## 3. Elliptic-curve gate (the pairing-track hybrid) — NOT post-quantum

This repo already contains a curve-based backend (the pairing track:
KZG and inner-product arguments, bins `section3_kzg` / `curve_ipa`, with
M0-M2 gadgets and LinkEqual manifest support). Curve inner-product
arguments prove the gate in one shot with tiny proofs because curve
challenges can be full-size field scalars — the norm problem that forces
small challenges simply does not exist there. A hybrid would commit the
gate operands additionally on the curve side and link across (the same
link-row machinery).

- Pros: smallest proofs, one-shot soundness, code partially exists.
- Cons: **breaks post-quantum security for the linked component**, which
  undermines the lattice track's reason to exist (Class-3 viability and
  PQ were mandates); curve ops are slower per element than hashing.
  Documented because the instinct "curves don't need 64 repetitions" is
  correct — but the price is the security model. Revisit only if PQ is
  ever descoped.

## 4. Fully-splitting modulus (q = 1 mod 2d) + ALS20 soundness rework

With a fully-splitting modulus the ring becomes d independent small
fields: true NTT multiplication everywhere (kernel win) and slot-wise
products. But per-slot Schwartz-Zippel then gives only q^-1 = 2^-31 per
slot, challenge differences stop being invertible (the LS18 story
collapses), and soundness must be rebuilt on automorphism stability
(ALS20's setting). This is a whole-protocol redesign, not a gate patch;
the k = 8 partial split was chosen precisely to avoid it. Keep as the
documented far alternative.

## 5. Explored and rejected (recorded so they are not re-explored)

- Inline repairs of the ring-challenge gate: committed corrections,
  twisted C-side functionals, coordinate-axis packing — all fail on the
  same non-commutation/junk obstruction (ROUTE_R_BUILD_REPORT.md F2,
  AUTOMORPHISM_GATE_DESIGN.md Appendix A.2).
- Amortized openings feeding the quadratic layer directly: the
  per-object virtual openings do not survive amortization (Appendix A.2).
- Public-weight bypass: for open-weight models one hopes the gate
  vanishes (weights public => Pi1-shaped claims). Analyzed: revealing
  blinded activation combinations does not escape the non-commutation
  obstruction either (ring challenges still cannot cross a general
  public matrix), so public weights do NOT remove the gate; the
  committed-executions gate serves both hidden- and public-weight
  deployments.
- Deeper subgroup/density trades: the measured law (executions x
  1/density = d) makes every point equivalent in the product; only the
  committed-executions reformulation escapes it, by never opening the
  executions individually.

## 6. Comparison

| option | soundness/rep count | proof size/claim | PQ | new machinery | status |
|---|---|---|---|---|---|
| 1. committed-executions gate | r = 1, 2^-296 | ~1.7-3.3 MB at scale (corrected) | yes | small engine additions | MAIN PLAN (spike-verified) |
| 2. hash sumcheck + link | r = 1 | ~100-200 KB + links | yes | second proof system | strong fallback |
| 3. curve hybrid + link | r = 1 | smallest | **no** | reuse pairing track | only if PQ descoped |
| 4. full-split + ALS20 | r = 1 | unknown | yes | whole-protocol redesign | far alternative |
| scalar gate (today) | r_g = 43-64 | ~13-15 MB | yes | shipped | current fallback, kept behind flag |
