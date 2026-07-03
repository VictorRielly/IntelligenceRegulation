# Review Notes and Development Roadmap: zkMatrix Reproduction and the Lattice Track

*Independent code-and-paper review, July 2026. Scope: the `zk_matrix` (Python),
`zk_matrix_fast` (C), and `zkmatrix-rs` (Rust) implementations in this repository,
checked against the zkMatrix paper (Cong–Yuen–Yiu, ePrint 2024/161, AsiaCCS 2024,
ePrint revision of 2025-02-05), plus forward-looking notes for the LLM feed-forward
and encrypted-channel milestones. Companion document:*
`zk-matrix-multiplication-lattice.pdf` *(the lattice-based protocol report).*

---

## 1. Status of the paper's performance claims (verified)

The ePrint version of zkMatrix does **not** report an end-to-end implementation.
Section 7 ("Theoretical Performance") microbenchmarks primitive operations
(exponentiation, group addition, pairing, field multiplication) using the Rust
`bls12_381` library, and then *estimates* protocol performance by multiplying
operation counts from Table 2, assuming 16-thread parallelization. Table 3 is
captioned as estimated performance. No public implementation from the authors was
found in a literature/code search (July 2026).

**Consequence:** this repository appears to contain the first end-to-end *measured*
zkMatrix datapoint. This is a citable contribution on its own. State it prominently,
and state it precisely: "first public measured implementation we are aware of," not
"first implementation" (an unreleased artifact by the authors cannot be ruled out;
check the AsiaCCS camera-ready and contact the authors before publishing the claim).

Measured vs. estimated (n = 1024, BLS12-381, ZK batched, Algorithm-6 shape):

| Quantity                          | Paper Table 3 (estimated) | This repo (measured, Apple Silicon) |
|-----------------------------------|---------------------------|--------------------------------------|
| Single-proof prover               | 197.04 s                  | 36.9 s (fixed cost of batch)         |
| Batch t=1024 prover, total        | 512.48 s                  | 296 s (projected from t <= 16 fit: 36.65 + 0.253 t) |
| Amortized prover per proof        | ~0.50 s                   | ~0.29 s                              |
| Amortized verifier per proof      | ~11.8 ms                  | ~2.7 ms (marginal)                   |
| Prover RAM (batched)              | 304 MB                    | **not reproduced** (dense witnesses ~96 GB at t=1024; needs streaming prover) |

Caveats to attach to any published comparison: different hardware; t=1024 figures are
a linear extrapolation from t in {1,...,16}; the RAM claim is unvalidated; setup (SRS
generation, ~3n^2 + 2n G1 points) took 163 s and is excluded from Table 3-style
figures; and there is currently no crossover against optimized float32 GEMM
(~500-70,000x depending on batch size). Report both the "vs. modular matmul" and
"vs. float GEMM" ratios; reporting only the former overstates practicality.

---

## 2. Faithfulness assessment (what matches the paper)

Verified by reading all three implementations and executing what the review sandbox
allowed (Python unit tests: 5/5 pass; C: compiles, self-test passes, n=1024 ZK prove
0.53 s at ~0.15x the in-program modular matmul; Rust: reviewed by reading only — no
edition-2024 toolchain available in the sandbox).

Faithful to the paper:

- **Algorithm 1 (Bulletproof IPA):** exact, including the
  Gentry–Halevi–Lyubashevsky update (`a' = a_L + x^{-1} a_R`, folded bases).
- **Algorithm 4 (MatMul reduction):** exact — challenge `y`, projections
  `a_y = y_L^T A`, `b_y = B y_R`, `d = <flatten(C), y_vec>`, four linked sub-proofs.
- **Algorithm 5 / optimized ZK placement:** both the naive whole-matrix wrapper and
  the paper's recommended optimization (masks inside the four sub-protocols) are
  implemented; the product sub-proof reproduces the quadratic identity
  `masked_out = C_d + x*C_cross + x^2*C_{alpha beta}`.
- **Algorithm 6 (batching):** the soundness-critical ordering is correct — the
  batching challenge `rho` is derived *after* the per-instance `C_d, C_ay, C_by`
  commitments (`challenge_batch_rho` in `structured_matrix.rs`). Per-instance
  product proofs run unbatched, which matches the paper (lines 15–16), and batching
  them is correctly identified in `OPTIMIZATION_ROADMAP.md` as an optimization, not
  a fidelity issue.
- **Base independence:** all base families (`A`, `B`, `C`, `AY`, `BY`, scalar,
  blind) are independent hash-to-group outputs, satisfying the paper's footnote-7
  disjointness requirement for the relaxed sub-relations.

---

## 3. Deviations from the paper — prioritized fixes

### P0 — Restore the fresh decoupling challenge `x` in the sub-proofs

The paper's Algorithms 2 and 3 combine commitments as `x * C_c (+) C_a` with a
**fresh public-coin challenge x**, and the knowledge-soundness proofs (Theorems 2–3)
explicitly rewind over two values `x^(1), x^(2)` to separate the two commitments'
contributions. The paper's "Optimizations" text licenses dropping the Schnorr
`(R, h, z)` component, but not dropping `x`. All three implementations fix this
coefficient to 1 (Python `_prove_zk_*` / `prove_core_matmul`; C; Rust
`masked_input = input_commit + mask_commit * x - blind` — the `x` there multiplies
the ZK *mask*, a different challenge with a different job).

A soundness argument for the coefficient-1 variant may be assemblable (IPA extractor
yields an exact representation over the sub-proof's bases; base families are
independent; `C_a, C_b, C_c` are fixed before `y`; finish with Schwartz–Zippel), but
it is nonstandard, unwritten, and not what the paper proved. **Fix instead of argue:**
derive one extra Fiat–Shamir scalar per sub-proof and use combined commitment
`x * C_out (+) C_in` with output bases scaled by `x` accordingly. Cost: one hash and
one scalar multiplication per sub-proof, in all three code bases. Add regression
tests that fail when `x` is fixed to 1 via an adversarial prover harness if feasible,
or at minimum lock the change with transcript KATs.

### P1 — Document the Section 3 redesign and its assumptions

The Rust verifier replaces the paper's dual `nu`-shifted SRS + q-PDH/q-PKE/q-BSDH
machinery with a **standard KZG opening at a fresh Fiat–Shamir point `zeta`**, with
the verifier evaluating the public folded polynomial in closed form
(`formula_value`, the Eq.-15-style product formulas, including batched variants).
This is arguably cleaner and rests on more standard assumptions (KZG evaluation
binding; AGM / q-SDH-type), but it is a redesign, not a transcription. Add a short
"Deviations from the paper" section to the docs with: the exact check implemented
(`e(C - v*G, H) = e(W, tau*H - zeta*H)`), the assumption profile, and why the fresh
`zeta` after the IPA transcript makes the closed-form evaluation sound.

### P1 — Bind a setup digest into every Fiat–Shamir challenge

Python challenge hashes bind statements and messages but not an explicit digest of
the bases/SRS (bases are deterministic from labels, so binding is implicit — make it
explicit and cheap: absorb `H(srs)` or the generating label set into every challenge,
all implementations). Also absorb protocol version and parameter tuple `(n, m, q)`
where not already present.

### P2 — Trusted-setup handling

Benchmarks generate `tau` locally and (correctly, for benchmarks) discard it. Any
deployment claim requires an MPC ceremony or imported powers-of-tau, plus explicit
subgroup/point-validation checks on imported SRS elements. Add a doc note so nobody
mistakes the benchmark setup for a deployable one. Note also that the SRS is
O(n^2)-sized (~150 MB at n=1024) and shape-specific under the current layout.

### P2 — Table 3 RAM claim needs the streaming prover

Already on the roadmap; keep it prioritized, because the memory figure is the one
Table 3 number the current harness cannot even test. The plan sketched in
`OPTIMIZATION_ROADMAP.md` (seeded witness regeneration, multi-pass aggregation into
one length-n^2 buffer) is the right shape.

### P2 — Test-suite gaps

Current negative tests flip the product wholesale. Add: per-sub-proof tampering
(each of the four, independently); batching cross-instance swap attacks (swap
`C_ay^(i)` between instances i, j after `rho` — must fail); norm/degenerate-value
edge cases (`blind == 0` currently skips the blinding term in `commit_matrix` —
harmless at negligible probability, but make blinding unconditional for uniformity);
differential tests Python <-> C <-> Rust on shared seeds and transcripts (extend
`tests/test_zkmatrix_native_backends.py` to compare full proof bytes, not just
accept/reject); zeroization of blinds and masks after use in the Rust path.

### P2 — Repo hygiene

Pin the exact ePrint revision reviewed (2025-02-05) next to the vendored PDF; fix the
README folder-name drift (`zkmatrix_rs` vs actual `zkmatrix-rs`); add a license file
(currently unspecified, which blocks external contribution and citation); record
hardware, thread count, and library versions inside the results CSVs (dates are
already there — good practice, keep it).

---

## 4. Positioning and literature notes (for the docs and any write-up)

Claims that are supportable: *first public measured implementation of zkMatrix*
(with the precision caveat of Section 1); *measured batched costs at or below the
paper's estimates on consumer hardware*; *a cleaner KZG-based realization of the
Section 3 verifier*.

Claims to avoid: "first ZK proof of matrix multiplication" (occupied: Groth,
CRYPTO 2009 committed linear algebra; Thaler 2013 sumcheck matmul; zkMatrix itself;
DualMatrix 2025; zkMaP 2025); "first use of random projection / Freivalds inside
ZK" (SafetyNets 2017, VeriML, Mystique/QuickSilver line, zkCNN, zkLLM 2024).

Comparison targets for benchmarks: zkMatrix Table 3 (estimates), DualMatrix,
Thaler-style sumcheck matmul (as used in zkLLM, GPU-accelerated), and — for the
post-quantum column — the lattice track below plus LaZer/LaBRADOR/Greyhound
reference numbers.

---

## 5. Two-track strategy: pairing (this repo) vs. lattice (companion PDF)

Both tracks share the same skeleton — commit to matrices, compress the claim by
random projection, prove one inner product — so protocol-level engineering
(batching structure, Fiat–Shamir discipline, layer chaining) transfers.

| Axis                     | Pairing track (zkMatrix)          | Lattice track (companion PDF)          |
|--------------------------|-----------------------------------|----------------------------------------|
| Amortized prover (n=1024)| ~0.29 s measured (batched)        | seconds/proof (reference Z_q route); ring route ~competitive, unmeasured here |
| Proof size               | KB, O(log n)                      | MB (reference); 50–150 KB (ring route); sublinear via LaBRADOR-style folding |
| Verifier                 | O(log n) + pairings               | linear (reference); succinct via folding layer |
| Setup                    | trusted, O(n^2) SRS               | transparent (hashed CRS)               |
| Post-quantum             | **no** (Shor breaks DL)           | yes (SIS / knapsack-LWE)               |
| Maturity of tooling      | mature curve libraries            | LaZer (CCS 2024) auto-parameterizes LNP22/LaBRADOR; prototype the lattice protocols there before hand-rolling |

Recommendation: keep the pairing track as the near-term performance vehicle and the
lattice track as the migration path; make every layer of the stack (commitment
interface, transcript, statement encoding) backend-agnostic now so the swap is a
backend change, not a rewrite. If the governance framework is meant to be long-lived
infrastructure, the post-quantum row should drive the eventual default.

---

## 6. Roadmap notes: extending to a full LLM feed-forward

Decompose a transformer block into provable operations and note which machinery
each needs:

1. **Linear layers, bias adds, residual adds** — free or cheap. Additions are
   homomorphic on commitments; every weight multiplication is a committed matmul
   this repo already proves; attention scores `QK^T` and `AV` are matmuls of two
   *committed* operands (the all-hidden case — supported by both tracks).
2. **Layer chaining (do this first — it is a current gap):** the output commitment
   of layer L must be usable as the input commitment of layer L+1. In the current
   code, `C` is committed under `c_bases` while the next layer's input would need
   `a_bases`/`b_bases` — distinct independent families. Either (a) reuse one base
   family for all matrix roles (check the disjointness requirements per sub-proof
   before collapsing families: within-family sharing is fine per the paper's
   footnote 7, cross-sub-proof sharing of `U', G', H'` is not), or (b) add a
   commitment-equality proof between base families (one extra IPA-sized proof per
   layer boundary). Without one of these, per-layer proofs do not compose into a
   network proof.
3. **Quantization semantics:** field arithmetic is exact mod q; LLM inference is
   fixed-point. Choose scale factors and prove the rescaling steps
   (`divide by 2^s with rounding`) with range/decomposition proofs, and size q so
   intermediate values never wrap (the companion PDF's integer-semantics remark:
   q > 2 n * 2^(a + b) for a-bit times b-bit operands). Every claimed "quantized
   inference" result is only as sound as these range proofs.
4. **Nonlinear activations (ReLU/GELU/SiLU), and the nonlinear parts of
   softmax/normalization:** the field-native approach is **lookup arguments** over
   quantized input/output tables — this is exactly zkLLM's `tlookup` design (CCS
   2024, sumcheck-based, GPU) and the LogUp/plookup family on the SNARK side. For
   this repo's pairing track, the practical route is commit-and-prove composition
   (LegoSNARK-style): keep zkMatrix for the linear layers and glue a
   lookup-capable system for the nonlinear layers via shared Pedersen commitments.
   For the lattice track, use LNP22 range proofs and recent lattice lookup
   techniques; prototype in LaZer. Do not attempt polynomial approximation of GELU
   inside the field without an explicit approximation-error accounting — it changes
   the *statement* being proven.
5. **Softmax and normalization:** prove `exp` via lookup on quantized inputs; prove
   the normalization `sum to one` (or RMS norm) as a linear constraint over the
   looked-up values plus one range-proved division. zkLLM's `zkAttn` is the worked
   precedent; adopt its decomposition rather than reinventing.
6. **Suggested milestone order:** layer chaining -> rescaling range proofs -> ReLU
   via lookup -> single FFN block end-to-end -> attention block -> multi-layer
   composition with one batched proof per operation class (Algorithm 6 batches
   same-shape matmuls across layers and tokens — this is where the amortized
   0.25 s/claim figure starts to pay).

---

## 7. Roadmap notes: bridging the proof to the encrypted channel

Goal as stated: validators verify that *the thing proven* matches *the message sent
through the RSA-encrypted channel*. Before choosing machinery, pin down the trust
model, because the cheap solution and the expensive solution prove different
statements:

- **Option A — bind the commitment, not the plaintext (recommended default).**
  Make the commitments (statement hash `H(C_A, C_B, C_C, params)`) part of the
  transmitted payload: include the statement hash inside the encrypted+signed
  message (or in its authenticated associated data under AEAD). The validator
  decrypts (or receives the opened payload), recomputes the statement hash, and
  checks it equals the one the proof verified against. This needs **no ZK about the
  encryption at all** — the binding is by hashing and channel authentication. It
  covers every case where the validator is a legitimate recipient of the message.
- **Option B — verifiable encryption (only if validators must NOT see the
  plaintext).** If the requirement is "prove the ciphertext encrypts exactly the
  committed value, to parties who cannot decrypt," that is verifiable encryption:
  Camenisch–Shoup-style for Paillier/DL settings, or lattice verifiable encryption
  (Lyubashevsky–Neven line; LNP22 tooling) for the PQ track. Proving statements
  about **RSA-OAEP specifically** in ZK is a poor fit (OAEP's hashing inside a
  circuit is expensive and nonstandard); if Option B is truly needed, change the
  channel primitive to one designed for it rather than proving RSA in-circuit.
- **Option C — hybrid-channel restructuring.** If the channel must stay
  RSA-shaped: RSA-encrypt only a symmetric key; authenticate the payload with an
  AEAD whose associated data includes the statement hash. The bridge then reduces
  to Option A. This is also the standard performance-correct way to use RSA.

Two cross-cutting cautions: (1) **domain-separate and version** the statement hash
that travels in the channel — it must bind CRS/SRS digest, protocol version, shapes,
and all commitments, or proofs become transplantable between contexts; (2) **RSA is
not post-quantum** — if the lattice track exists for harvest-now-decrypt-later
reasons, an RSA channel reintroduces exactly that exposure for the *messages*;
plan a migration to ML-KEM (Kyber) hybrid key establishment so the channel and the
proof system degrade together, not separately.

---

## 8. One-page action summary

1. Add the fresh decoupling challenge `x` to all four sub-proofs, all three
   implementations (P0).
2. Write the "Deviations from the paper" doc section: KZG-at-`zeta` verifier,
   coefficient conventions, assumption profile (P1).
3. Absorb an SRS/parameter digest into every Fiat–Shamir challenge (P1).
4. Extend tests: per-sub-proof tampering, batch cross-instance swaps, cross-impl
   transcript equality (P2).
5. Streaming batched prover; then attempt the full t=1024 Table 3 replication
   including RAM (P2).
6. Solve layer chaining (shared bases or equality proofs) before any multi-layer
   work (roadmap gate).
7. Prototype nonlinearities as lookups (pairing: CP-composition; lattice: LaZer)
   on a single quantized FFN block.
8. Decide the channel-bridge trust model (Option A vs B); default to
   statement-hash binding in authenticated payloads; schedule the PQ channel
   migration.
9. Add license; pin the reviewed ePrint revision; record hardware in results.
10. Before any publication: contact the zkMatrix authors about implementation
    status, and frame the contribution as measured reproduction + verifier
    redesign + batching engineering.
